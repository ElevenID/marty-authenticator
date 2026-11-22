//! Presentation operations.

use crate::api::{FrbPresentationRequest, FrbPresentationResponse, FrbZkProofEntry};

pub(crate) async fn wallet_parse_presentation_request(
    request_uri: String,
) -> anyhow::Result<FrbPresentationRequest> {
    let engine = marty_oid4vci::WalletEngine::new();
    let request = engine
        .parse_presentation_request(&request_uri)
        .await
        .map_err(|e| anyhow::anyhow!("Presentation request parse error: {}", e))?;
    // This parser supplies untrusted routing/display data only. Governed
    // consent uses Core's digest of the authenticated original signed bytes.
    let mut canonical = serde_json::to_value(&request)?;
    canonical.sort_all_objects();
    use sha2::Digest;
    let request_digest = format!(
        "{:x}",
        sha2::Sha256::digest(serde_json::to_vec(&canonical)?)
    );
    request_projection(&request, request_digest)
}

pub(crate) fn request_projection(
    request: &marty_oid4vci::ParsedPresentationRequest,
    request_digest: String,
) -> anyhow::Result<FrbPresentationRequest> {
    let presentation_definition_json = request
        .presentation_definition
        .as_ref()
        .map(serde_json::to_string)
        .transpose()
        .map_err(|e| anyhow::anyhow!("PresentationDefinition serialization error: {}", e))?;
    let dcql_query_json = request
        .dcql_query
        .as_ref()
        .map(serde_json::to_string)
        .transpose()
        .map_err(|e| anyhow::anyhow!("DCQL query serialization error: {}", e))?;
    let query_type = match request.query_type {
        marty_oid4vci::PresentationRequestQueryType::PresentationDefinition => {
            "presentation_definition"
        }
        marty_oid4vci::PresentationRequestQueryType::DcqlQuery => "dcql_query",
    }
    .to_string();
    Ok(FrbPresentationRequest {
        client_id: request.client_id.clone(),
        nonce: request.nonce.clone(),
        response_uri: request.response_uri.clone(),
        response_mode: request.response_mode.clone(),
        state: request.state.clone(),
        request_digest,
        query_type,
        presentation_definition_json,
        dcql_query_json,
    })
}

pub(crate) async fn wallet_build_and_submit_presentation(
    _response_uri: String,
    _presentation_definition_json: Option<String>,
    _dcql_query_json: Option<String>,
    _credentials_json: String,
) -> anyhow::Result<FrbPresentationResponse> {
    // This generated FRB entry point is retained until the verified remote
    // presenter replaces it. It cannot receive the original request nonce,
    // client_id, state, or issuer trust context and must never submit a VP.
    Err(anyhow::anyhow!(
        "REMOTE_KMS_REQUIRED: verified remote presentation is not available"
    ))
}

pub(crate) async fn wallet_build_and_submit_zk_presentation(
    _response_uri: String,
    _presentation_definition_json: String,
    _credentials_json: String,
    _zk_proofs: Vec<FrbZkProofEntry>,
) -> anyhow::Result<FrbPresentationResponse> {
    // Retain the generated ABI, but this legacy endpoint has no approved
    // request, challenge, issuer trust or paired remote-signature context.
    // A caller-supplied proof cannot authorize a network submission.
    Err(anyhow::anyhow!(
        "REMOTE_KMS_REQUIRED: verified remote ZK presentation is not available"
    ))
}

#[cfg(test)]
mod tests {
    use super::{wallet_build_and_submit_presentation, wallet_build_and_submit_zk_presentation};

    #[test]
    fn retired_presentation_entry_point_rejects_without_submitting() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .build()
            .expect("test runtime");
        let result = runtime.block_on(wallet_build_and_submit_presentation(
            "https://verifier.invalid/submit".into(),
            None,
            Some(r#"{"credentials":[]}"#.into()),
            "{}".into(),
        ));
        let error = result.expect_err("unverified presentation must be rejected");
        assert!(error.to_string().contains("REMOTE_KMS_REQUIRED"));
    }

    #[test]
    fn retired_zk_entry_point_rejects_before_parsing_or_submitting() {
        // A runtime without networking is intentional: rejection must not
        // inspect caller payloads, build a presentation, or open a connection.
        let runtime = tokio::runtime::Builder::new_current_thread()
            .build()
            .expect("test runtime");
        for payload in ["not-json", "{}"] {
            let result = runtime.block_on(wallet_build_and_submit_zk_presentation(
                "https://verifier.invalid/submit".into(),
                payload.into(),
                payload.into(),
                vec![],
            ));
            let error = result.expect_err("unverified ZK presentation must be rejected");
            assert!(error.to_string().contains("REMOTE_KMS_REQUIRED"));
        }
    }
}
