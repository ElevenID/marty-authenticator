use super::*;
use serde_json::json;

#[test]
fn issuer_metadata_conversion_requires_a_resolved_token_endpoint() {
    let raw = json!({
        "credential_issuer": "https://issuer.example",
        "credential_endpoint": "https://issuer.example/credential"
    });
    let mut metadata: marty_oid4vci::IssuerMetadata = serde_json::from_value(raw).unwrap();
    assert!(FrbIssuerMetadata::try_from(metadata.clone()).is_err());
    metadata.token_endpoint = Some("https://as.example/custom-token".into());
    let converted = FrbIssuerMetadata::try_from(metadata).unwrap();
    assert_eq!(converted.token_endpoint, "https://as.example/custom-token");
}

fn encode_query_json(value: &str) -> String {
    url::form_urlencoded::byte_serialize(value.as_bytes()).collect()
}

fn policy_json() -> String {
    json!({
        "id": "mobile-policy",
        "name": "Mobile policy",
        "description": null,
        "purpose": "Test the canonical mobile adapter",
        "accepted_credential_types": ["EmployeeCredential"],
        "required_claims": [{
            "claim_name": "employee_id",
            "credential_type": "EmployeeCredential",
            "accept_predicate": false,
            "required_value": null
        }],
        "holder_binding": "none",
        "trust_profile_id": null,
        "allowed_issuers": [],
        "freshness_requirements": {
            "max_credential_age_seconds": null,
            "max_proof_age_seconds": 300,
            "require_live_revocation_check": false
        },
        "prefer_predicates": false,
        "single_presentation": false,
        "derived_attribute_preferences": {},
        "credential_ranking_strategy": "freshest_first",
        "credential_ranking_weights": {},
        "metadata": {},
        "version": 1
    })
    .to_string()
}

fn verified_facts_json(claims: serde_json::Value) -> String {
    json!({
        "credential_types": ["EmployeeCredential"],
        "claims": claims,
        "issuer_id": "did:example:issuer",
        "trust_profile_verified": true,
        "issued_at_epoch_seconds": null,
        "proof_epoch_seconds": null,
        "evaluation_time_epoch_seconds": 1_800_000_000u64,
        "holder_binding_verified": false,
        "revocation_checked": false,
        "not_revoked": null,
        "presentation_count": 1
    })
    .to_string()
}

fn service_policy_request_json(signature_verified: bool) -> String {
    let mut vector: serde_json::Value = serde_json::from_str(include_str!(
        "../../../test/fixtures/presentation_policy_service.json"
    ))
    .unwrap();
    let credential = &mut vector["request"]["credentials"][0];
    credential["signature_verified"] = json!(signature_verified);
    credential["signature_failure_reason"] = if signature_verified {
        serde_json::Value::Null
    } else {
        json!("invalid signature")
    };
    vector["request"].to_string()
}
#[test]
fn mobile_policy_adapter_uses_rust_evaluator_for_allow_and_deny() {
    let allowed = evaluate_presentation_request(
        verified_facts_json(json!({"employee_id": "123"})),
        vec![policy_json()],
        Vec::new(),
    )
    .unwrap();
    assert!(allowed.is_satisfied);
    assert_eq!(allowed.minimum_disclosure_claims, ["employee_id"]);

    let denied = evaluate_presentation_request(
        verified_facts_json(json!({})),
        vec![policy_json()],
        Vec::new(),
    )
    .unwrap();
    assert!(!denied.is_satisfied);
    assert_eq!(denied.missing_required_claims, ["employee_id"]);
}

#[test]
fn mobile_policy_adapter_rejects_missing_verified_facts() {
    let error = evaluate_presentation_request("{}".to_string(), vec![policy_json()], Vec::new())
        .unwrap_err();
    assert!(error.to_string().contains("verified policy facts"));
}

#[test]
fn mobile_service_policy_adapter_matches_canonical_allow_and_deny() {
    let vector: serde_json::Value = serde_json::from_str(include_str!(
        "../../../test/fixtures/presentation_policy_service.json"
    ))
    .unwrap();
    let allowed: serde_json::Value = serde_json::from_str(
        &evaluate_service_presentation_policy(service_policy_request_json(true)).unwrap(),
    )
    .unwrap();
    assert_eq!(allowed["result"], vector["expected"]["result"]);
    assert_eq!(allowed["decision"], vector["expected"]["decision"]);
    assert_eq!(
        allowed["verified_claims"],
        vector["expected"]["verified_claims"]
    );

    let denied: serde_json::Value = serde_json::from_str(
        &evaluate_service_presentation_policy(service_policy_request_json(false)).unwrap(),
    )
    .unwrap();
    assert_eq!(denied["decision"], "deny");
    assert!(denied["errors"]
        .as_array()
        .unwrap()
        .iter()
        .any(|error| error["code"] == "signature_invalid"));
}

#[test]
fn mobile_policy_format_aliases_match_shared_vectors() {
    let vector: serde_json::Value = serde_json::from_str(include_str!(
        "../../../test/fixtures/presentation_policy_service.json"
    ))
    .unwrap();
    for format in vector["format_vectors"].as_array().unwrap() {
        assert_eq!(
            marty_verification::policy::canonical_credential_format(
                format["input"].as_str().unwrap()
            ),
            format["expected"].as_str().unwrap()
        );
    }
}

#[test]
fn mobile_service_policy_adapter_rejects_malformed_and_oversized_requests() {
    assert!(evaluate_service_presentation_policy("{}".to_string()).is_err());
    assert!(evaluate_service_presentation_policy("x".repeat(1_000_001)).is_err());
}

#[tokio::test]
async fn wallet_parse_presentation_request_reports_dcql_shape() {
    let dcql_query = r#"{"credentials":[{"id":"member_credential","format":"dc+sd-jwt"}]}"#;
    let request_uri = format!(
        "openid4vp://authorize?client_id={}&nonce=nonce-123&response_uri={}&dcql_query={}",
        encode_query_json("https://verifier.example"),
        encode_query_json("https://verifier.example/submit"),
        encode_query_json(dcql_query),
    );

    let parsed = wallet_parse_presentation_request(request_uri)
        .await
        .unwrap();

    assert_eq!(parsed.query_type, "dcql_query");
    assert!(parsed.presentation_definition_json.is_none());
    assert!(parsed.dcql_query_json.is_some());
    assert_eq!(parsed.response_uri, "https://verifier.example/submit");
}

#[tokio::test]
async fn wallet_parse_presentation_request_preserves_legacy_pe_shape() {
    let presentation_definition = r#"{"id":"pd-1","input_descriptors":[{"id":"member_credential","constraints":{"fields":[]}}]}"#;
    let request_uri = format!(
        "openid4vp://authorize?client_id={}&nonce=nonce-123&response_uri={}&presentation_definition={}",
        encode_query_json("https://verifier.example"),
        encode_query_json("https://verifier.example/submit"),
        encode_query_json(presentation_definition),
    );

    let parsed = wallet_parse_presentation_request(request_uri)
        .await
        .unwrap();

    assert_eq!(parsed.query_type, "presentation_definition");
    assert!(parsed.presentation_definition_json.is_some());
    assert!(parsed.dcql_query_json.is_none());
}

#[tokio::test]
async fn wallet_qr_validation_uses_canonical_rust_parsers() {
    let offer = json!({
        "credential_issuer": "https://issuer.example",
        "credential_configuration_ids": ["pid"],
        "grants": {}
    })
    .to_string();
    let validated = wallet_validate_qr_input(offer).await.unwrap().unwrap();
    assert_eq!(validated.kind, "credential_offer");
    assert!(validated
        .normalized
        .starts_with("openid-credential-offer://"));
    assert!(!validated.requires_external_provider);

    let presentation_definition =
        r#"{"id":"pd-1","input_descriptors":[{"id":"member","constraints":{"fields":[]}}]}"#;
    let request_uri = format!(
        "openid4vp://authorize?client_id={}&nonce=nonce-123&response_uri={}&presentation_definition={}",
        encode_query_json("https://verifier.example"),
        encode_query_json("https://verifier.example/submit"),
        encode_query_json(presentation_definition),
    );
    let validated = wallet_validate_qr_input(request_uri)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(validated.kind, "presentation_request");

    const ISO_QR: &str = "mdoc:owBjMS4wAYIB2BhYS6QBAiABIVgglyWXuAyJ6iRNc8OlYXenvkJt23rJPdtIhlawXqr-yf0iWCC1GQSH8tIwTYVwha_ZoPL20_saYXrGIbrCm133H0ki-QKBgwIBowD1AfQKUH2RiuAEbUVzrsrOiUnSPDw";
    let validated = wallet_validate_qr_input(ISO_QR.to_string())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(validated.kind, "mdoc_device_engagement");
}

#[tokio::test]
async fn wallet_qr_validation_rejects_malformed_protocol_input() {
    assert!(wallet_validate_qr_input("openid4vp://".to_string())
        .await
        .is_err());
    assert!(wallet_validate_qr_input(
        "openid-credential-offer://?credential_offer=not-json".to_string()
    )
    .await
    .is_err());
    assert!(wallet_validate_qr_input("mdoc:not-cbor".to_string())
        .await
        .is_err());
    assert!(wallet_validate_qr_input("https://example.com".to_string())
        .await
        .unwrap()
        .is_none());
}

#[tokio::test]
async fn wallet_qr_validation_parses_push_registration_in_rust() {
    let validated = wallet_validate_qr_input(
        "marty://push-register?org=acme&api=https%3A%2F%2Fapi.example%2Fpush&token=secret&user=alice"
            .to_string(),
    )
    .await
    .unwrap()
    .unwrap();

    assert_eq!(validated.kind, "push_registration");
    assert!(!validated.requires_external_provider);
    let content: serde_json::Value = serde_json::from_str(&validated.parsed_content_json).unwrap();
    assert_eq!(content["organization_id"], "acme");
    assert_eq!(content["api_url"], "https://api.example/push");
    assert_eq!(content["registration_token"], "secret");
    assert_eq!(content["user_id"], "alice");
}

#[tokio::test]
async fn wallet_qr_validation_rejects_malformed_push_registration() {
    for malformed in [
        "marty://push-register?org=acme&api=http%3A%2F%2Fapi.example&token=secret&user=alice",
        "marty://push-register?org=acme&api=https%3A%2F%2Fapi.example&token=secret",
        "marty://push-register?org=acme&org=other&api=https%3A%2F%2Fapi.example&token=secret&user=alice",
        "marty://push-register?org=acme&api=https%3A%2F%2Fapi.example&token=secret&user=alice&extra=value",
        "marty://other-action?org=acme",
    ] {
        assert!(wallet_validate_qr_input(malformed.to_string())
            .await
            .is_err());
    }
}

#[test]
fn wallet_routes_presentation_requests_in_rust() {
    let oid4vp = "openid4vp://authorize?client_id=verifier&nonce=nonce&response_uri=https%3A%2F%2Fverifier.example%2Fsubmit&presentation_definition=%7B%22id%22%3A%22pd%22%2C%22input_descriptors%22%3A%5B%5D%7D";
    assert_eq!(
        wallet_route_presentation_request(oid4vp.to_string()).unwrap(),
        "oid4vp"
    );

    const ISO_QR: &str = "mdoc:owBjMS4wAYIB2BhYS6QBAiABIVgglyWXuAyJ6iRNc8OlYXenvkJt23rJPdtIhlawXqr-yf0iWCC1GQSH8tIwTYVwha_ZoPL20_saYXrGIbrCm133H0ki-QKBgwIBowD1AfQKUH2RiuAEbUVzrsrOiUnSPDw";
    assert_eq!(
        wallet_route_presentation_request(ISO_QR.to_string()).unwrap(),
        "mdoc"
    );
    assert!(wallet_route_presentation_request("mdoc:not-cbor".to_string()).is_err());
    assert!(wallet_route_presentation_request(
        "openid-credential-offer://?credential_offer=%7B%7D".to_string()
    )
    .is_err());
}

#[test]
fn wallet_validates_presentation_binding_context_in_rust() {
    let direct = wallet_validate_presentation_context(
        json!({"challenge": "challenge-123", "domain": "verifier.example"}).to_string(),
    )
    .unwrap();
    assert_eq!(direct.challenge, "challenge-123");
    assert_eq!(direct.domain, "verifier.example");

    let oid4vp = wallet_validate_presentation_context(
        json!({"nonce": "nonce-123", "client_id": "https://verifier.example"}).to_string(),
    )
    .unwrap();
    assert_eq!(oid4vp.challenge, "nonce-123");
    assert_eq!(oid4vp.domain, "https://verifier.example");

    for invalid in [
        json!({}),
        json!({"challenge": "", "domain": "verifier.example"}),
        json!({"challenge": "default-challenge", "domain": "default-domain"}),
        json!({"challenge": "one", "nonce": "two", "domain": "verifier.example"}),
        json!({"challenge": 123, "domain": "verifier.example"}),
    ] {
        assert!(wallet_validate_presentation_context(invalid.to_string()).is_err());
    }
}

#[test]
fn credential_api_preserves_nested_claims_and_raw_input() {
    let input = json!({
        "id": "urn:credential:example",
        "issuer": "https://issuer.example",
        "issuance_date": "2026-01-01T00:00:00Z",
        "subject": {},
        "credentialSubject": {
            "id": "did:example:holder",
            "name": "Zoë",
            "degree": {"name": "Computing", "year": 2026},
            "roles": ["student", "member"]
        }
    })
    .to_string();
    let parsed = parse_verifiable_credential(input.clone()).unwrap();
    assert_eq!(parsed.raw_json.as_deref(), Some(input.as_str()));
    assert_eq!(parsed.subject.id.as_deref(), Some("did:example:holder"));
    let claims: serde_json::Value = serde_json::from_str(&parsed.subject.claims_json).unwrap();
    assert_eq!(claims["name"], "Zoë");
    assert_eq!(claims["degree"]["year"], 2026);
    assert_eq!(claims["roles"], json!(["student", "member"]));
    assert!(claims.get("id").is_none());
    let mut names = get_credential_claims(&Credential::VerifiableCredential(parsed));
    names.sort();
    assert_eq!(names, ["degree", "name", "roles"]);
}

#[test]
fn credential_api_retains_context_for_invalid_input() {
    for input in ["not-json", "{}"] {
        let error = parse_verifiable_credential(input.to_string()).unwrap_err();
        assert!(error.to_string().starts_with("Credential parsing failed:"));
    }
}
