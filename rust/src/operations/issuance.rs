//! Issuance operations.

use crate::api::{
    FrbAuthorizationRequest, FrbCredentialOffer, FrbCredentialResponse, FrbIssuerMetadata,
    FrbTokenResponse,
};

pub(crate) async fn wallet_parse_credential_offer(
    offer_uri: String,
) -> anyhow::Result<FrbCredentialOffer> {
    let engine = marty_oid4vci::WalletEngine::new();
    let offer = engine
        .parse_credential_offer(&offer_uri)
        .await
        .map_err(|e| anyhow::anyhow!("Credential offer parse error: {}", e))?;

    let pre_authorized_code = offer
        .grants
        .pre_authorized_code
        .as_ref()
        .map(|pa| pa.pre_authorized_code.clone());
    let tx_code_required = offer
        .grants
        .pre_authorized_code
        .as_ref()
        .and_then(|pa| pa.tx_code.as_ref())
        .is_some();
    let issuer_state = offer
        .grants
        .authorization_code
        .as_ref()
        .and_then(|ac| ac.issuer_state.clone());

    Ok(FrbCredentialOffer {
        credential_issuer: offer.credential_issuer,
        credential_configuration_ids: offer.credential_configuration_ids,
        pre_authorized_code,
        tx_code_required,
        issuer_state,
    })
}

pub(crate) async fn wallet_fetch_issuer_metadata(
    issuer_url: String,
) -> anyhow::Result<FrbIssuerMetadata> {
    let engine = marty_oid4vci::WalletEngine::new();
    let meta = engine
        .fetch_issuer_metadata(&issuer_url)
        .await
        .map_err(|e| anyhow::anyhow!("Issuer metadata fetch error: {}", e))?;
    Ok(FrbIssuerMetadata::from(meta))
}

pub(crate) async fn wallet_exchange_pre_auth_token(
    token_endpoint: String,
    pre_auth_code: String,
    tx_code: Option<String>,
) -> anyhow::Result<FrbTokenResponse> {
    let engine = marty_oid4vci::WalletEngine::new();
    let token = engine
        .exchange_pre_auth_code(&token_endpoint, &pre_auth_code, tx_code.as_deref())
        .await
        .map_err(|e| anyhow::anyhow!("Token exchange error: {}", e))?;
    Ok(FrbTokenResponse::from(token))
}

pub(crate) fn wallet_build_auth_request(
    issuer_metadata_json: String,
    credential_configuration_id: String,
    client_id: String,
    redirect_uri: String,
    issuer_state: Option<String>,
) -> anyhow::Result<FrbAuthorizationRequest> {
    let frb_meta: FrbIssuerMetadata = serde_json::from_str(&issuer_metadata_json)
        .map_err(|e| anyhow::anyhow!("Invalid issuer_metadata_json: {}", e))?;
    let meta = marty_oid4vci::IssuerMetadata {
        credential_issuer: frb_meta.credential_issuer.clone(),
        token_endpoint: Some(frb_meta.token_endpoint.clone()),
        nonce_endpoint: None,
        credential_endpoint: frb_meta.credential_endpoint.clone(),
        authorization_endpoint: frb_meta.authorization_endpoint.clone(),
        grant_types_supported: frb_meta.grant_types_supported.clone(),
        credential_configurations_supported: serde_json::from_str(
            &frb_meta.credential_configurations_json,
        )
        .unwrap_or_default(),
        extra: Default::default(),
    };
    let engine = marty_oid4vci::WalletEngine::new();
    let (auth_req, code_verifier) = engine
        .build_authorization_request(
            &meta,
            &credential_configuration_id,
            &client_id,
            &redirect_uri,
            issuer_state,
        )
        .map_err(|e| anyhow::anyhow!("Authorization request build error: {}", e))?;
    let auth_endpoint_fallback = format!("{}/authorize", frb_meta.credential_issuer);
    let auth_endpoint = meta
        .authorization_endpoint
        .as_deref()
        .unwrap_or(&auth_endpoint_fallback);
    let authorization_url = engine
        .authorization_redirect_url(auth_endpoint, &auth_req)
        .map_err(|e| anyhow::anyhow!("Authorization URL build error: {}", e))?;
    let state = auth_req.state.clone().unwrap_or_default();
    let redir = auth_req.redirect_uri.clone().unwrap_or(redirect_uri);
    Ok(FrbAuthorizationRequest {
        authorization_url,
        code_verifier,
        state,
        redirect_uri: redir,
    })
}

pub(crate) async fn wallet_exchange_auth_code_token(
    token_endpoint: String,
    code: String,
    code_verifier: String,
    redirect_uri: Option<String>,
    client_id: Option<String>,
) -> anyhow::Result<FrbTokenResponse> {
    let engine = marty_oid4vci::WalletEngine::new();
    let token = engine
        .exchange_auth_code(
            &token_endpoint,
            &code,
            &code_verifier,
            redirect_uri.as_deref(),
            client_id.as_deref(),
        )
        .await
        .map_err(|e| anyhow::anyhow!("Auth code token exchange error: {}", e))?;
    Ok(FrbTokenResponse::from(token))
}

pub(crate) fn wallet_create_proof_jwt(
    holder_kid: String,
    c_nonce: String,
    issuer_url: String,
    jwk_json: String,
) -> anyhow::Result<String> {
    let engine = marty_oid4vci::WalletEngine::new();
    engine
        .create_proof_jwt(&holder_kid, &c_nonce, &issuer_url, &jwk_json)
        .map_err(|e| anyhow::anyhow!("Proof JWT creation error: {}", e))
}

pub(crate) async fn wallet_request_credential(
    credential_endpoint: String,
    access_token: String,
    credential_format: String,
    credential_configuration_id: Option<String>,
    proof_jwt: String,
) -> anyhow::Result<FrbCredentialResponse> {
    use marty_oid4vci::types::CredentialFormat;
    let format = CredentialFormat::from_str_loose(&credential_format)
        .ok_or_else(|| anyhow::anyhow!("Unknown credential format: {}", credential_format))?;
    let engine = marty_oid4vci::WalletEngine::new();
    let resp = engine
        .request_credential(
            &credential_endpoint,
            &access_token,
            &format,
            credential_configuration_id.as_deref(),
            &proof_jwt,
        )
        .await
        .map_err(|e| anyhow::anyhow!("Credential request error: {}", e))?;
    Ok(FrbCredentialResponse::from(resp))
}
