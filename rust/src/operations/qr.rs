//! Qr operations.

use crate::api::{FrbPresentationBindingContext, FrbWalletQrInput};

pub(crate) fn wallet_route_presentation_request(input: String) -> anyhow::Result<String> {
    use marty_oid4vci::WalletInputKind;

    let classified = marty_oid4vci::classify_wallet_input(&input)
        .map_err(|error| anyhow::anyhow!("Presentation request classification error: {error}"))?
        .ok_or_else(|| anyhow::anyhow!("Unsupported presentation request"))?;
    match classified.kind {
        WalletInputKind::PresentationRequest => Ok("oid4vp".to_string()),
        WalletInputKind::MdocDeviceEngagement => {
            marty_iso18013::DeviceEngagement::from_qr_uri(&classified.normalized)
                .map_err(|error| anyhow::anyhow!("mDoc engagement validation error: {error}"))?;
            Ok("mdoc".to_string())
        }
        WalletInputKind::CredentialOffer => Err(anyhow::anyhow!(
            "Credential offers cannot be routed as presentation requests"
        )),
    }
}

pub(crate) fn wallet_validate_presentation_context(
    request_json: String,
) -> anyhow::Result<FrbPresentationBindingContext> {
    const MAX_PRESENTATION_CONTEXT_BYTES: usize = 64 * 1024;
    const MAX_BINDING_VALUE_BYTES: usize = 4096;

    if request_json.len() > MAX_PRESENTATION_CONTEXT_BYTES {
        return Err(anyhow::anyhow!("Presentation context exceeds 64 KiB"));
    }
    let request: serde_json::Value = serde_json::from_str(&request_json)
        .map_err(|error| anyhow::anyhow!("Invalid presentation context JSON: {error}"))?;
    let request = request
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("Presentation context must be a JSON object"))?;

    fn binding_value(
        request: &serde_json::Map<String, serde_json::Value>,
        primary: &str,
        alias: &str,
        max_bytes: usize,
    ) -> anyhow::Result<String> {
        fn optional_string<'a>(
            request: &'a serde_json::Map<String, serde_json::Value>,
            name: &str,
        ) -> anyhow::Result<Option<&'a str>> {
            request
                .get(name)
                .map(|value| {
                    value.as_str().ok_or_else(|| {
                        anyhow::anyhow!("Presentation context `{name}` must be a string")
                    })
                })
                .transpose()
        }
        let primary_value = optional_string(request, primary)?;
        let alias_value = optional_string(request, alias)?;
        if primary_value.is_some() && alias_value.is_some() && primary_value != alias_value {
            return Err(anyhow::anyhow!(
                "Presentation context `{primary}` conflicts with `{alias}`"
            ));
        }
        let value = primary_value.or(alias_value).ok_or_else(|| {
            anyhow::anyhow!("Presentation context requires `{primary}` or `{alias}`")
        })?;
        if value.is_empty()
            || value.trim() != value
            || value.len() > max_bytes
            || value.chars().any(char::is_control)
            || matches!(value, "default-challenge" | "default-domain")
        {
            return Err(anyhow::anyhow!(
                "Presentation context `{primary}` is invalid"
            ));
        }
        Ok(value.to_string())
    }

    Ok(FrbPresentationBindingContext {
        challenge: binding_value(request, "challenge", "nonce", MAX_BINDING_VALUE_BYTES)?,
        domain: binding_value(request, "domain", "client_id", MAX_BINDING_VALUE_BYTES)?,
    })
}

pub(crate) fn wallet_normalize_credential_offer(input: String) -> anyhow::Result<String> {
    marty_oid4vci::normalize_credential_offer_uri(&input)
        .map_err(|error| anyhow::anyhow!("Credential offer normalization error: {}", error))
}

pub(crate) async fn wallet_validate_qr_input(
    raw_data: String,
) -> anyhow::Result<Option<FrbWalletQrInput>> {
    use marty_oid4vci::WalletInputKind;

    if let Some(push_registration) = parse_push_registration_qr(&raw_data)? {
        return Ok(Some(push_registration));
    }

    let Some(classified) = marty_oid4vci::classify_wallet_input(&raw_data)
        .map_err(|error| anyhow::anyhow!("Wallet QR classification error: {}", error))?
    else {
        return Ok(None);
    };

    match classified.kind {
        WalletInputKind::CredentialOffer if classified.normalized.starts_with("openid-vc:") => {
            let parsed_content_json = serde_json::json!({
                "offer_uri": classified.normalized,
                "provider_protocol": "openid-vc",
            })
            .to_string();
            Ok(Some(FrbWalletQrInput {
                kind: "credential_offer".to_string(),
                normalized: classified.normalized,
                parsed_content_json,
                requires_external_provider: true,
            }))
        }
        WalletInputKind::CredentialOffer => {
            let engine = marty_oid4vci::WalletEngine::new();
            let offer = engine
                .parse_credential_offer(&classified.normalized)
                .await
                .map_err(|error| anyhow::anyhow!("Credential offer validation error: {}", error))?;
            let parsed_content_json = serde_json::json!({
                "offer_uri": classified.normalized,
                "credential_issuer": offer.credential_issuer,
                "credential_configuration_ids": offer.credential_configuration_ids,
            })
            .to_string();
            Ok(Some(FrbWalletQrInput {
                kind: "credential_offer".to_string(),
                normalized: classified.normalized,
                parsed_content_json,
                requires_external_provider: false,
            }))
        }
        WalletInputKind::PresentationRequest => {
            let engine = marty_oid4vci::WalletEngine::new();
            let request = engine
                .parse_presentation_request(&classified.normalized)
                .await
                .map_err(|error| {
                    anyhow::anyhow!("Presentation request validation error: {}", error)
                })?;
            let parsed_content_json = serde_json::json!({
                "request_uri": classified.normalized,
                "client_id": request.client_id,
                "nonce": request.nonce,
                "response_uri": request.response_uri,
                "query_type": match request.query_type {
                    marty_oid4vci::PresentationRequestQueryType::PresentationDefinition => "presentation_definition",
                    marty_oid4vci::PresentationRequestQueryType::DcqlQuery => "dcql_query",
                },
                "presentation_definition": request.presentation_definition,
                "dcql_query": request.dcql_query,
            })
            .to_string();
            Ok(Some(FrbWalletQrInput {
                kind: "presentation_request".to_string(),
                normalized: classified.normalized,
                parsed_content_json,
                requires_external_provider: false,
            }))
        }
        WalletInputKind::MdocDeviceEngagement => {
            marty_iso18013::DeviceEngagement::from_qr_uri(&classified.normalized)
                .map_err(|error| anyhow::anyhow!("mDoc engagement validation error: {}", error))?;
            Ok(Some(FrbWalletQrInput {
                kind: "mdoc_device_engagement".to_string(),
                normalized: classified.normalized,
                parsed_content_json: "{}".to_string(),
                requires_external_provider: false,
            }))
        }
    }
}

fn parse_push_registration_qr(raw_data: &str) -> anyhow::Result<Option<FrbWalletQrInput>> {
    let parsed = match url::Url::parse(raw_data) {
        Ok(parsed) => parsed,
        Err(error) if raw_data.starts_with("marty:") => {
            return Err(anyhow::anyhow!(
                "Push registration validation error: invalid URI: {error}"
            ));
        }
        Err(_) => return Ok(None),
    };

    if parsed.scheme() != "marty" {
        return Ok(None);
    }
    if parsed.host_str() != Some("push-register") || parsed.path() != "" {
        return Err(anyhow::anyhow!(
            "Push registration validation error: unsupported Marty QR action"
        ));
    }
    if !parsed.username().is_empty() || parsed.password().is_some() || parsed.fragment().is_some() {
        return Err(anyhow::anyhow!(
            "Push registration validation error: credentials and fragments are not allowed"
        ));
    }

    let mut values = std::collections::HashMap::<String, String>::new();
    for (key, value) in parsed.query_pairs() {
        if !matches!(key.as_ref(), "org" | "api" | "token" | "user") {
            return Err(anyhow::anyhow!(
                "Push registration validation error: unsupported query parameter '{key}'"
            ));
        }
        if value.trim().is_empty() {
            return Err(anyhow::anyhow!(
                "Push registration validation error: '{key}' must not be empty"
            ));
        }
        if values.insert(key.to_string(), value.to_string()).is_some() {
            return Err(anyhow::anyhow!(
                "Push registration validation error: duplicate query parameter '{key}'"
            ));
        }
    }

    for required in ["org", "api", "token", "user"] {
        if !values.contains_key(required) {
            return Err(anyhow::anyhow!(
                "Push registration validation error: missing '{required}'"
            ));
        }
    }

    let api_url = url::Url::parse(&values["api"]).map_err(|error| {
        anyhow::anyhow!("Push registration validation error: invalid api URL: {error}")
    })?;
    if api_url.scheme() != "https"
        || api_url.host_str().is_none()
        || !api_url.username().is_empty()
        || api_url.password().is_some()
    {
        return Err(anyhow::anyhow!(
            "Push registration validation error: api must be an HTTPS URL without credentials"
        ));
    }

    let parsed_content_json = serde_json::json!({
        "organization_id": values["org"],
        "api_url": api_url.as_str(),
        "registration_token": values["token"],
        "user_id": values["user"],
    })
    .to_string();

    Ok(Some(FrbWalletQrInput {
        kind: "push_registration".to_string(),
        normalized: parsed.to_string(),
        parsed_content_json,
        requires_external_provider: false,
    }))
}
