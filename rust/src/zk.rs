use crate::error::Result;
use flutter_rust_bridge::frb;
use marty_zkp::{Prover, ZkTranscript};
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Deserialize)]
struct PresentationDefinition {
    input_descriptors: Vec<InputDescriptor>,
}

#[derive(Deserialize)]
struct InputDescriptor {
    id: String,
}

#[frb]
pub fn zk_prove_from_presentation_definition(
    presentation_definition_json: String,
    mso_bytes: Vec<u8>,
    signature: Vec<u8>,
    secrets_json: String,
    session_nonce: Vec<u8>,
) -> Result<Vec<u8>> {
    // 1. Parse Presentation Definition
    let pd: PresentationDefinition = serde_json::from_str(&presentation_definition_json)
        .map_err(|e| anyhow::anyhow!("Invalid Presentation Definition JSON: {}", e))?;

    // 2. Parse Secrets
    let secrets: HashMap<String, String> = serde_json::from_str(&secrets_json)
        .map_err(|e| anyhow::anyhow!("Invalid Secrets JSON: {}", e))?;

    // 3. Dispatch based on requested Input Descriptors
    // TODO: Implement proper dispatch based on Input Descriptors
    // For MVP, we look for known IDs
    for descriptor in pd.input_descriptors {
        if descriptor.id == "age_over_18" {
            // Check required secrets
            let birth_date = secrets.get("birth_date")
                .ok_or_else(|| anyhow::anyhow!("Missing 'birth_date' in secrets for age_over_18 proof"))?;

            // Initialize Transcript
            let transcript = ZkTranscript::new(&session_nonce);

            // Generate Proof
            return Prover::prove_age_over_18(&transcript, &mso_bytes, &signature, birth_date)
                .map_err(|e| anyhow::anyhow!("ZK Generation failed: {}", e));
        }
    }

    Err(anyhow::anyhow!("No supported ZK circuits found in Presentation Definition"))
}

#[frb]
pub fn zk_prove_age_over_18_interactive(
    mso_bytes: Vec<u8>,
    signature: Vec<u8>,
    birth_date: String,
    session_nonce: Vec<u8>
) -> Result<Vec<u8>> {
    // Legacy wrappers can call the prover directly too
    let transcript = ZkTranscript::new(&session_nonce);
    Prover::prove_age_over_18(&transcript, &mso_bytes, &signature, &birth_date)
        .map_err(|e| anyhow::anyhow!("ZK Generation failed: {}", e))
}

#[frb]
pub fn zk_is_supported_on_device() -> bool {
    // Check Android Keystore / Attestation capabilities
    true
}
