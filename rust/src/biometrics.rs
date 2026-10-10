//! Biometric face verification bridge for Flutter.
//!
//! Exposes face matching, quality assessment, and age estimation to the
//! Flutter UI via `flutter_rust_bridge`.

#[path = "biometric_worker.rs"]
mod worker;

use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};
use worker::BiometricWorker;

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
/// Both images must be base64-encoded. `models_dir` must identify the ONNX
/// model directory. Initialization failures are returned to the caller.
/// Repeated calls reuse one worker/runtime/provider for that directory.
pub fn verify_face_match(
    reference_image: String,
    probe_image: String,
    threshold: Option<f32>,
    models_dir: Option<String>,
) -> anyhow::Result<FrbFaceMatchResult> {
    let threshold = threshold.unwrap_or(0.7);

    let result = run_biometric(models_dir, move |state| {
        state
            .runtime
            .block_on(
                state
                    .provider
                    .verify(marty_biometrics::FaceVerificationRequest {
                        reference_image,
                        probe_image,
                        threshold: Some(threshold),
                        ..Default::default()
                    }),
            )
            .map_err(Into::into)
    })?;

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
    let result = run_biometric(models_dir, move |state| {
        state
            .runtime
            .block_on(state.provider.assess_quality(&image))
            .map_err(Into::into)
    })?;

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
    let result = run_biometric(models_dir, move |state| {
        state
            .runtime
            .block_on(state.provider.estimate_age(&image))
            .map_err(Into::into)
    })?;

    Ok(FrbAgeEstimate {
        estimated_age: result.estimated_age,
        confidence: result.confidence,
        age_range_low: result.age_range.0,
        age_range_high: result.age_range.1,
    })
}

/// Apply the canonical active-liveness gesture threshold policy.
#[frb(sync)]
pub fn evaluate_liveness_gesture(
    gesture: String,
    smiling_probability: Option<f64>,
    head_euler_angle_x: Option<f64>,
    head_euler_angle_y: Option<f64>,
) -> anyhow::Result<bool> {
    for value in [smiling_probability, head_euler_angle_x, head_euler_angle_y]
        .into_iter()
        .flatten()
    {
        if !value.is_finite() {
            anyhow::bail!("liveness measurements must be finite");
        }
    }

    let detected = match gesture.as_str() {
        "smile" => smiling_probability.unwrap_or(0.0) > 0.8,
        "turnHeadLeft" => head_euler_angle_y.unwrap_or(0.0) > 45.0,
        "turnHeadRight" => head_euler_angle_y.unwrap_or(0.0) < -45.0,
        "lookUp" => head_euler_angle_x.unwrap_or(0.0) > 20.0,
        "lookDown" => head_euler_angle_x.unwrap_or(0.0) < -20.0,
        _ => anyhow::bail!("unsupported liveness gesture"),
    };
    Ok(detected)
}

// ============================================================================
// Internals
// ============================================================================

// Provider is dropped before its runtime, on the worker thread.
struct BiometricRuntime {
    provider: BiometricProvider,
    runtime: tokio::runtime::Runtime,
}

struct CachedBiometrics {
    model_dir: PathBuf,
    worker: BiometricWorker<BiometricRuntime>,
}

static BIOMETRICS: OnceLock<Mutex<Option<CachedBiometrics>>> = OnceLock::new();

fn run_biometric<T: Send + 'static>(
    models_dir: Option<String>,
    operation: impl FnOnce(&mut BiometricRuntime) -> anyhow::Result<T> + Send + 'static,
) -> anyhow::Result<T> {
    let directory = models_dir
        .filter(|path| !path.trim().is_empty())
        .ok_or_else(|| {
            anyhow::anyhow!("Biometric verification requires an ONNX models directory")
        })?;
    let model_dir = std::fs::canonicalize(&directory).map_err(|error| {
        anyhow::anyhow!("Cannot open biometric models directory {directory}: {error}")
    })?;
    if !model_dir.is_dir() {
        anyhow::bail!("Biometric models path is not a directory: {directory}");
    }
    let mut cached = BIOMETRICS
        .get_or_init(|| Mutex::new(None))
        .lock()
        .map_err(|_| anyhow::anyhow!("Biometric lifecycle lock is poisoned"))?;
    if cached
        .as_ref()
        .is_none_or(|entry| entry.model_dir != model_dir)
    {
        if let Some(previous) = cached.take() {
            previous.worker.shutdown().map_err(anyhow::Error::msg)?;
        }
        let provider_dir = model_dir.clone();
        let worker = BiometricWorker::start(move || {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .map_err(|error| format!("Failed to initialize biometric runtime: {error}"))?;
            let provider = BiometricProvider::onnx(&provider_dir).map_err(|error| {
                format!("Failed to initialize ONNX biometric provider: {error}")
            })?;
            Ok(BiometricRuntime { provider, runtime })
        })
        .map_err(anyhow::Error::msg)?;
        *cached = Some(CachedBiometrics { model_dir, worker });
    }
    cached
        .as_ref()
        .expect("initialized biometric worker")
        .worker
        .run(operation)
        .map_err(anyhow::Error::msg)?
}

/// Finish pending biometric calls and release the cached provider and runtime.
/// A subsequent verification call initializes a new worker.
pub fn shutdown_biometrics() -> anyhow::Result<()> {
    let mut cached = BIOMETRICS
        .get_or_init(|| Mutex::new(None))
        .lock()
        .map_err(|_| anyhow::anyhow!("Biometric lifecycle lock is poisoned"))?;
    if let Some(previous) = cached.take() {
        previous.worker.shutdown().map_err(anyhow::Error::msg)?;
    }
    Ok(())
}

#[cfg(test)]
mod liveness_tests {
    use super::*;
    use serde_json::Value;

    fn fixture() -> Value {
        serde_json::from_str(include_str!("../../test/fixtures/liveness_behavior.json")).unwrap()
    }

    #[test]
    fn language_neutral_gesture_vectors_preserve_strict_thresholds() {
        for vector in fixture()["gesture_vectors"].as_array().unwrap() {
            let result = evaluate_liveness_gesture(
                vector["gesture"].as_str().unwrap().to_string(),
                vector.get("smiling_probability").and_then(Value::as_f64),
                vector.get("head_euler_angle_x").and_then(Value::as_f64),
                vector.get("head_euler_angle_y").and_then(Value::as_f64),
            )
            .unwrap();
            assert_eq!(
                result,
                vector["detected"].as_bool().unwrap(),
                "{}",
                vector["id"]
            );
        }
    }
}

#[cfg(test)]
mod runtime_tests {
    use super::*;

    #[test]
    fn missing_models_never_select_a_mock_provider() {
        for directory in [None, Some(String::new()), Some("   ".to_string())] {
            let error = assess_face_quality("image".to_string(), directory).unwrap_err();
            assert!(error
                .to_string()
                .contains("requires an ONNX models directory"));
        }
    }

    #[test]
    fn invalid_model_directory_preserves_initialization_failure() {
        let directory =
            std::env::temp_dir().join(format!("marty-absent-models-{}", uuid::Uuid::new_v4()));
        let error = estimate_face_age(
            "image".to_string(),
            Some(directory.to_string_lossy().into_owned()),
        )
        .unwrap_err();
        assert!(error
            .to_string()
            .contains("Cannot open biometric models directory"));
    }

    #[test]
    fn missing_model_files_preserve_provider_failure_and_allow_retry() {
        let directory =
            std::env::temp_dir().join(format!("marty-empty-models-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir(&directory).unwrap();
        let errors: Vec<_> = (0..2)
            .map(|_| {
                assess_face_quality(
                    "image".to_string(),
                    Some(directory.to_string_lossy().into_owned()),
                )
                .unwrap_err()
                .to_string()
            })
            .collect();
        // The provider must not create files on failed initialization.
        std::fs::remove_dir(&directory).unwrap();
        for error in errors {
            assert!(
                error.contains("Failed to initialize ONNX biometric provider"),
                "{error}"
            );
        }
        shutdown_biometrics().unwrap();
        shutdown_biometrics().unwrap();
    }

    #[tokio::test]
    async fn explicit_test_provider_runtime_can_start_and_stop_inside_async_caller() {
        let worker = BiometricWorker::start(|| {
            let runtime = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .map_err(|error| error.to_string())?;
            Ok(BiometricRuntime {
                provider: BiometricProvider::mock(),
                runtime,
            })
        })
        .unwrap();
        assert_eq!(
            worker
                .run(|state| {
                    assert!(matches!(state.provider, BiometricProvider::Mock(_)));
                    state.runtime.block_on(async {
                        tokio::time::sleep(std::time::Duration::from_millis(1)).await;
                        42
                    })
                })
                .unwrap(),
            42
        );
        worker.shutdown().unwrap();
    }
}
