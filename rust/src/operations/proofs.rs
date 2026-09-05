//! Proofs operations.

pub(crate) fn zk_prove_from_presentation_definition(
    presentation_definition_json: String,
    mdoc_bytes: Vec<u8>,
    issuer_pkx: String,
    issuer_pky: String,
    doc_type: String,
    secrets_json: String,
    session_nonce: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    #[derive(serde::Deserialize)]
    struct PD {
        input_descriptors: Vec<ID>,
    }
    #[derive(serde::Deserialize)]
    struct ID {
        id: String,
    }

    let pd: PD = serde_json::from_str(&presentation_definition_json)
        .map_err(|e| anyhow::anyhow!("Invalid Presentation Definition JSON: {}", e))?;
    let secrets: std::collections::HashMap<String, String> = serde_json::from_str(&secrets_json)
        .map_err(|e| anyhow::anyhow!("Invalid Secrets JSON: {}", e))?;

    if let Some(descriptor) = pd.input_descriptors.into_iter().next() {
        let predicate = marty_zkp::ZkPredicate::from_id(&descriptor.id);
        let claim_name = predicate.required_claim();
        let claim_value = secrets.get(claim_name).ok_or_else(|| {
            anyhow::anyhow!(
                "Missing '{}' in secrets for predicate '{}'",
                claim_name,
                descriptor.id
            )
        })?;
        let attr = marty_zkp::AttributeRequest::new(
            "org.iso.18013.5.1",
            claim_name,
            claim_value.as_bytes().to_vec(),
        );
        let input = marty_zkp::MdocProveInput {
            mdoc: mdoc_bytes.clone(),
            issuer_pkx: issuer_pkx.clone(),
            issuer_pky: issuer_pky.clone(),
            transcript: session_nonce.clone(),
            attributes: vec![attr],
            now: chrono::Utc::now().to_rfc3339(),
            doc_type: doc_type.clone(),
        };
        let circuit = marty_zkp::Circuit::generate(input.attributes.len())
            .map_err(|e| anyhow::anyhow!("Circuit generation failed: {}", e))?;
        return marty_zkp::Prover::prove(&circuit, &input)
            .map_err(|e| anyhow::anyhow!("ZK proof generation failed: {}", e));
    }
    Err(anyhow::anyhow!(
        "No input descriptors found in Presentation Definition"
    ))
}

pub(crate) fn zk_prove(
    predicate_id: String,
    claim_value: String,
    mdoc_bytes: Vec<u8>,
    issuer_pkx: String,
    issuer_pky: String,
    doc_type: String,
    session_nonce: Vec<u8>,
) -> anyhow::Result<Vec<u8>> {
    let predicate = marty_zkp::ZkPredicate::from_id(&predicate_id);
    let claim_name = predicate.required_claim();
    let attr = marty_zkp::AttributeRequest::new(
        "org.iso.18013.5.1",
        claim_name,
        claim_value.as_bytes().to_vec(),
    );
    let input = marty_zkp::MdocProveInput {
        mdoc: mdoc_bytes,
        issuer_pkx,
        issuer_pky,
        transcript: session_nonce,
        attributes: vec![attr],
        now: chrono::Utc::now().to_rfc3339(),
        doc_type,
    };
    let circuit = marty_zkp::Circuit::generate(input.attributes.len())
        .map_err(|e| anyhow::anyhow!("Circuit generation failed: {}", e))?;
    marty_zkp::Prover::prove(&circuit, &input)
        .map_err(|e| anyhow::anyhow!("ZK proof generation failed: {}", e))
}

pub(crate) fn zk_is_supported_on_device() -> bool {
    true
}
