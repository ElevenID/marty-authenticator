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
    let request_digest = super::verified_presentation::request_digest(&request)?;
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
        client_id: request.client_id,
        nonce: request.nonce,
        response_uri: request.response_uri,
        response_mode: request.response_mode,
        state: request.state,
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
    response_uri: String,
    presentation_definition_json: String,
    credentials_json: String,
    zk_proofs: Vec<FrbZkProofEntry>,
) -> anyhow::Result<FrbPresentationResponse> {
    use marty_oid4vci::verifier::PresentationDefinition;
    let definition: PresentationDefinition = serde_json::from_str(&presentation_definition_json)
        .map_err(|e| anyhow::anyhow!("Invalid presentation_definition_json: {}", e))?;
    let credentials: std::collections::HashMap<String, String> =
        serde_json::from_str(&credentials_json)
            .map_err(|e| anyhow::anyhow!("Invalid credentials_json: {}", e))?;
    let proofs: Vec<marty_oid4vci::ZkProofEntry> = zk_proofs.into_iter().map(Into::into).collect();
    let engine = marty_oid4vci::WalletEngine::new();
    let (vp_token, submission) = engine
        .build_zk_presentation(&definition, credentials, proofs)
        .map_err(|e| anyhow::anyhow!("ZK presentation build error: {}", e))?;
    let resp = engine
        .submit_presentation(&response_uri, &vp_token, &submission)
        .await
        .map_err(|e| anyhow::anyhow!("ZK presentation submission error: {}", e))?;
    Ok(FrbPresentationResponse::from(resp))
}

#[cfg(test)]
mod tests {
    use super::wallet_build_and_submit_presentation;

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
}
