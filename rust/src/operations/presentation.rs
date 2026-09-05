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
        query_type,
        presentation_definition_json,
        dcql_query_json,
    })
}

pub(crate) async fn wallet_build_and_submit_presentation(
    response_uri: String,
    presentation_definition_json: Option<String>,
    dcql_query_json: Option<String>,
    credentials_json: String,
) -> anyhow::Result<FrbPresentationResponse> {
    let credentials: std::collections::HashMap<String, String> =
        serde_json::from_str(&credentials_json)
            .map_err(|e| anyhow::anyhow!("Invalid credentials_json: {}", e))?;
    let query_type = if dcql_query_json.is_some() {
        marty_oid4vci::PresentationRequestQueryType::DcqlQuery
    } else if presentation_definition_json.is_some() {
        marty_oid4vci::PresentationRequestQueryType::PresentationDefinition
    } else {
        return Err(anyhow::anyhow!(
            "Either presentation_definition_json or dcql_query_json is required"
        ));
    };
    let presentation_definition = presentation_definition_json
        .as_ref()
        .map(|json| serde_json::from_str(json))
        .transpose()
        .map_err(|e| anyhow::anyhow!("Invalid presentation_definition_json: {}", e))?;
    let dcql_query = dcql_query_json
        .as_ref()
        .map(|json| serde_json::from_str(json))
        .transpose()
        .map_err(|e| anyhow::anyhow!("Invalid dcql_query_json: {}", e))?;
    let engine = marty_oid4vci::WalletEngine::new();
    let request = marty_oid4vci::ParsedPresentationRequest {
        client_id: String::new(),
        nonce: String::new(),
        response_uri: response_uri.clone(),
        response_mode: None,
        state: None,
        query_type,
        presentation_definition,
        dcql_query,
    };
    let (vp_token, submission) = engine
        .build_presentation_for_request(&request, credentials)
        .map_err(|e| anyhow::anyhow!("Presentation build error: {}", e))?;
    let resp = engine
        .submit_presentation_optional(&response_uri, &vp_token, submission.as_ref())
        .await
        .map_err(|e| anyhow::anyhow!("Presentation submission error: {}", e))?;
    Ok(FrbPresentationResponse::from(resp))
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
