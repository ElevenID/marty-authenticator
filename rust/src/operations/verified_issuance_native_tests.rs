//! Executed only on the marked, newly owned TLS/Transit qualification fixtures.
use super::*;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use marty_crypto_test_support::openbao_transit::{DisposableOpenBao, ScopedTransitSigner};
use serde_json::json;

fn public(key: &ScopedTransitSigner) -> Value {
    let key: Value = serde_json::from_str(key.public_jwk()).unwrap();
    json!({"kty":key["kty"],"crv":key["crv"],"x":key["x"],"y":key["y"]})
}
fn fresh(raw: &Value) -> String {
    let now = Utc::now();
    let mut raw = raw.clone();
    raw["observed_at"] = json!(now);
    raw["expires_at"] = json!(now + Duration::seconds(60));
    raw["issuer"]["generated_at"] = json!(now);
    raw["issuer"]["expires_at"] = raw["expires_at"].clone();
    raw.to_string()
}

#[test]
#[ignore = "requires marked disposable TLS OpenBao, isolated issuer and per-process CA"]
fn actual_remote_receipt_authorizes_before_token_and_rechecks_after_response() {
    let nonce = std::env::var("MARTY_TEST_WALLET_OWNER_NONCE").unwrap();
    assert!(nonce.len() >= 32);
    assert_eq!(
        std::env::var("MARTY_TEST_OPENBAO_DISPOSABLE_NONCE").unwrap(),
        nonce
    );
    let service = std::env::var("MARTY_TEST_WALLET_RECEIVER").unwrap();
    let url = https_endpoint(&service).unwrap();
    assert_eq!(url.host_str(), Some("127.0.0.1"));
    assert!(url.port().is_some() && url.path() == "/" && url.query().is_none());
    let service = service.trim_end_matches('/');
    let input = std::path::PathBuf::from(std::env::var("MARTY_TEST_WALLET_ISSUER_INPUT").unwrap());
    let capture =
        std::path::PathBuf::from(std::env::var("MARTY_TEST_WALLET_ISSUER_CAPTURE").unwrap());
    assert!(!input.exists() && !capture.exists());
    let backend = DisposableOpenBao::from_marked_env();
    let issuer = backend.create_es256();
    let holder = backend.create_es256();
    let binding = backend.create_ed25519();
    let holder_jwk = public(&holder);
    let mut enrolled = holder_jwk.clone();
    enrolled["kid"] = json!("native-issuance-holder");
    let holder_json = enrolled.to_string();
    let now = Utc::now();
    let claims = json!({"iss":"did:web:native-issuer.example", "vct":"urn:elevenid:credential:identity",
        "iat":now.timestamp(),"nbf":now.timestamp()-1,"exp":now.timestamp()+600,
        "cnf":{"jwk":holder_jwk},"_sd_alg":"sha-256"});
    let header = json!({"alg":"ES256","typ":"dc+sd-jwt","kid":"native-issuance-key"});
    let signing_input = format!(
        "{}.{}",
        URL_SAFE_NO_PAD.encode(header.to_string()),
        URL_SAFE_NO_PAD.encode(claims.to_string())
    );
    let signature = issuer.sign(signing_input.as_bytes()).unwrap();
    let credential = format!("{signing_input}.{}~", URL_SAFE_NO_PAD.encode(signature));
    let mut issuer_jwk = public(&issuer);
    issuer_jwk["kid"] = json!("native-issuance-key");
    let mut authority = super::super::issuer_trust::fixture_envelope(
        json!({
        "organization_id":"native-issuance-org","trust_profile_id":uuid::Uuid::new_v4().to_string(),
        "generated_at":now,"expires_at":now+Duration::seconds(60),
        "issuer_keys":[{"issuer":"did:web:native-issuer.example","key_id":"native-issuance-key",
            "algorithm":"ES256","public_jwk":issuer_jwk}]}),
        holder_jwk,
        "urn:elevenid:credential:identity",
    );
    let ed: Value = serde_json::from_str(binding.public_jwk()).unwrap();
    let binding_jwk = json!({"kty":ed["kty"],"crv":ed["crv"],"x":ed["x"]});
    authority["scope"]["holder_binding_key"]["public_jwk"] = binding_jwk.clone();
    authority["scope"]["holder_binding_key"]["jwk_thumbprint"] =
        json!(super::super::verifier_governance::thumbprint(&binding_jwk).unwrap());
    authority["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([{
        "credential_issuer":service,"credential_configuration_id":"identity","format":"dc+sd-jwt",
        "vct":"urn:elevenid:credential:identity","authorization_server":null,"token_endpoint":null}]);
    // Synthetic credential material is confined to the task-owned private temp
    // directory and deleted by the fixture driver; no signing private key exits Bao.
    std::fs::write(&input, json!({"credential":credential}).to_string()).unwrap();
    let offer = json!({"credential_issuer":service,"credential_configuration_ids":["identity"],
        "grants":{"urn:ietf:params:oauth:grant-type:pre-authorized_code":{"pre-authorized_code":"owned-fixture-code"}}});
    let offer_uri = url::Url::parse_with_params(
        "openid-credential-offer://",
        [("credential_offer", offer.to_string())],
    )
    .unwrap()
    .to_string();
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    let mut ungranted = authority.clone();
    ungranted["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([]);
    assert!(runtime
        .block_on(prepare(&offer_uri, None, &holder_json, &fresh(&ungranted)))
        .is_err());
    assert!(
        !capture.exists(),
        "ungranted offer must not release its code"
    );
    for reject_old_authority in [true, false] {
        let prepared = runtime
            .block_on(prepare(&offer_uri, None, &holder_json, &fresh(&authority)))
            .unwrap();
        let signature = holder.sign(&prepared.signing_input).unwrap();
        let before_response = fresh(&authority);
        let handle = runtime
            .block_on(complete(&prepared.session_id, &signature, &before_response))
            .unwrap();
        assert!(uuid::Uuid::parse_str(&handle).is_ok());
        let transmitted: Value = serde_json::from_slice(&std::fs::read(&input).unwrap()).unwrap();
        let proof = marty_oid4vci::jose::verify_compact_jwt_with_public_jwk(
            transmitted["transmitted_proof"].as_str().unwrap(),
            &holder_json,
            "ES256",
        )
        .unwrap();
        assert_eq!(proof.claims["nonce"], "owned-fixture-nonce");
        assert_eq!(proof.claims["aud"], service);
        if reject_old_authority {
            let error = finalize(&handle, &before_response).err().unwrap();
            assert!(error.to_string().contains("predates"));
            assert!(finalize(&handle, &fresh(&authority)).is_err());
        } else {
            let verified = finalize(&handle, &fresh(&authority)).unwrap();
            assert_eq!(verified.credential, credential);
            assert_eq!(verified.issuer, "did:web:native-issuer.example");
            assert_eq!(verified.credential_type, "urn:elevenid:credential:identity");
            assert_eq!(verified.format, "dc+sd-jwt");
            assert!(finalize(&handle, &fresh(&authority)).is_err());
        }
    }
    let capture: Value = serde_json::from_slice(&std::fs::read(capture).unwrap()).unwrap();
    assert_eq!(capture, json!({"token":2,"nonce":2,"credential":2}));
}
