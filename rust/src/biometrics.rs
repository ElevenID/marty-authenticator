//! Biometric face verification bridge for Flutter.
//!
//! Exposes face matching, quality assessment, and age estimation to the
//! Flutter UI via `flutter_rust_bridge`.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use marty_biometrics::{BiometricProvider, FaceVerifier};

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
