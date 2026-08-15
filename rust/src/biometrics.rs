//! Biometric face verification bridge for Flutter.
//!
//! Exposes face matching, quality assessment, and age estimation to the
//! Flutter UI via `flutter_rust_bridge`.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use marty_biometrics::{
    sign_challenge, validate_challenge, BiometricProvider, FaceVerifier, LivenessChallenge,
    LivenessChallengeBuilder, LivenessChallengeConfig, LivenessMode,
};

// ============================================================================
// FFI types
// ============================================================================

/// Result of a face match comparison.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbFaceMatchResult {
    pub verified: bool,
    pub similarity: f32,
    pub threshold: f32,
    pub provider: String,
    pub reference_quality: Option<f32>,
    pub probe_quality: Option<f32>,
    pub processing_time_ms: u64,
}

/// Quality assessment of a face image.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbFaceQuality {
    pub overall_score: f32,
    pub face_detected: bool,
    pub face_count: u32,
    pub sharpness: f32,
    pub brightness: f32,
    pub contrast: f32,
    pub face_size: f32,
    pub pose: f32,
}

/// Age estimation result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbAgeEstimate {
    pub estimated_age: u8,
    pub confidence: f32,
    pub age_range_low: u8,
    pub age_range_high: u8,
}

/// Signed active-liveness challenge created by the canonical biometric kernel.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbLivenessChallenge {
    pub challenge_id: String,
    pub nonce: String,
    pub issued_at: String,
    pub expires_at: String,
    pub gestures: Vec<String>,
    pub signature: String,
    /// Complete canonical challenge required for native verification.
    pub native_payload: String,
}

// ============================================================================
// FFI functions
// ============================================================================

/// Verify that a probe face image matches a reference face image.
///
/// Both images must be base64-encoded. If `models_dir` is provided and
/// contains ONNX model files, real on-device inference is used; otherwise
/// a mock provider returns deterministic results for testing.
pub fn verify_face_match(
    reference_image: String,
    probe_image: String,
    threshold: Option<f32>,
    models_dir: Option<String>,
) -> anyhow::Result<FrbFaceMatchResult> {
    let rt = tokio::runtime::Runtime::new()?;
    let provider = build_provider(models_dir.as_deref());
    let threshold = threshold.unwrap_or(0.7);

    let result = rt.block_on(provider.verify(marty_biometrics::FaceVerificationRequest {
        reference_image,
        probe_image,
        threshold: Some(threshold),
        ..Default::default()
    }))?;

    Ok(FrbFaceMatchResult {
        verified: result.verified,
        similarity: result.similarity,
        threshold: result.threshold,
        provider: result.provider,
        reference_quality: result.reference_quality,
        probe_quality: result.probe_quality,
        processing_time_ms: result.processing_time_ms,
    })
}

/// Assess the quality of a face image before verification.
///
/// Returns a quality assessment with individual factor scores.
pub fn assess_face_quality(
    image: String,
    models_dir: Option<String>,
) -> anyhow::Result<FrbFaceQuality> {
    let rt = tokio::runtime::Runtime::new()?;
    let provider = build_provider(models_dir.as_deref());

    let result = rt.block_on(provider.assess_quality(&image))?;

    Ok(FrbFaceQuality {
        overall_score: result.overall_score,
        face_detected: result.face_detected,
        face_count: result.face_count,
        sharpness: result.factors.sharpness,
        brightness: result.factors.brightness,
        contrast: result.factors.contrast,
        face_size: result.factors.face_size,
        pose: result.factors.pose,
    })
}

/// Estimate the age of the subject in a face image.
///
/// Requires ONNX models — returns an error if models are not available.
pub fn estimate_face_age(
    image: String,
    models_dir: Option<String>,
) -> anyhow::Result<FrbAgeEstimate> {
    let rt = tokio::runtime::Runtime::new()?;
    let provider = build_provider(models_dir.as_deref());

    let result = rt.block_on(provider.estimate_age(&image))?;

    Ok(FrbAgeEstimate {
        estimated_age: result.estimated_age,
        confidence: result.confidence,
        age_range_low: result.age_range.0,
        age_range_high: result.age_range.1,
    })
}

/// Create and sign an active-liveness challenge in Rust.
#[frb(sync)]
pub fn create_liveness_challenge(
    gestures: Vec<String>,
    ttl_seconds: u64,
    signing_secret: String,
) -> anyhow::Result<FrbLivenessChallenge> {
    if gestures.is_empty() || gestures.len() > 5 {
        anyhow::bail!("liveness challenge must contain between 1 and 5 gestures");
    }
    if !(1..=600).contains(&ttl_seconds) {
        anyhow::bail!("liveness challenge TTL must be between 1 and 600 seconds");
    }
    if signing_secret.is_empty() {
        anyhow::bail!("liveness signing secret must not be empty");
    }

    let challenge_id = format!("lv-{}", uuid::Uuid::new_v4().simple());
    let nonce = format!("nonce-{}", uuid::Uuid::new_v4().simple());
    let session_id = format!("mobile-{}", uuid::Uuid::new_v4().simple());
    let config = LivenessChallengeConfig {
        step_count: gestures.len(),
        validity_seconds: ttl_seconds,
        allow_accessibility: true,
        preferred_mode: LivenessMode::OnDevice,
        allow_network_fallback: false,
    };
    let mut builder = LivenessChallengeBuilder::new(&challenge_id, session_id).with_config(config);
    for (index, gesture) in gestures.iter().enumerate() {
        let prompt = gesture_prompt(gesture)?;
        builder = builder.add_head_pose(format!("gesture-{}", index + 1), gesture, prompt, 10_000);
    }
    let mut challenge = builder.build(&nonce);
    sign_challenge(&mut challenge, signing_secret.as_bytes());
    let native_payload = serde_json::to_string(&challenge)?;

    Ok(FrbLivenessChallenge {
        challenge_id,
        nonce,
        issued_at: challenge.issued_at,
        expires_at: challenge.expires_at,
        gestures,
        signature: challenge.signature,
        native_payload,
    })
}

/// Verify a canonical active-liveness challenge and fail closed on expiry,
/// tampering, malformed input, or a wrong key.
#[frb(sync)]
pub fn verify_liveness_challenge(
    native_payload: String,
    signing_secret: String,
) -> anyhow::Result<bool> {
    if signing_secret.is_empty() {
        anyhow::bail!("liveness signing secret must not be empty");
    }
    let challenge: LivenessChallenge = serde_json::from_str(&native_payload)?;
    validate_challenge(&challenge, signing_secret.as_bytes())?;
    Ok(true)
}

// ============================================================================
// Internals
// ============================================================================

fn build_provider(models_dir: Option<&str>) -> BiometricProvider {
    if let Some(dir) = models_dir {
        let path = std::path::Path::new(dir);
        if path.is_dir() {
            match BiometricProvider::onnx(path) {
                Ok(p) => return p,
                Err(_) => {} // fall through to mock
            }
        }
    }
    BiometricProvider::mock()
}

fn gesture_prompt(gesture: &str) -> anyhow::Result<&'static str> {
    match gesture {
        "smile" => Ok("Smile"),
        "turnHeadLeft" => Ok("Turn your head left"),
        "turnHeadRight" => Ok("Turn your head right"),
        "lookUp" => Ok("Look up"),
        "lookDown" => Ok("Look down"),
        _ => anyhow::bail!("unsupported liveness gesture"),
    }
}

#[cfg(test)]
mod liveness_tests {
    use super::*;
    use serde_json::Value;

    fn fixture() -> Value {
        serde_json::from_str(include_str!("../../test/fixtures/liveness_behavior.json")).unwrap()
    }

    #[test]
    fn language_neutral_liveness_vectors_preserve_behavior() {
        for vector in fixture()["vectors"].as_array().unwrap() {
            let gestures = serde_json::from_value(vector["gestures"].clone()).unwrap();
            let result = create_liveness_challenge(
                gestures,
                vector["ttl_seconds"].as_u64().unwrap(),
                vector["signing_secret"].as_str().unwrap().to_string(),
            );
            if vector["valid"].as_bool().unwrap() {
                let challenge = result.unwrap();
                assert_eq!(challenge.signature.len(), 64);
                assert!(verify_liveness_challenge(
                    challenge.native_payload.clone(),
                    vector["signing_secret"].as_str().unwrap().to_string(),
                )
                .unwrap());
                assert!(verify_liveness_challenge(
                    challenge.native_payload,
                    "wrong-key".to_string(),
                )
                .is_err());
            } else {
                assert!(result.is_err(), "{} must fail closed", vector["id"]);
            }
        }
    }
}
