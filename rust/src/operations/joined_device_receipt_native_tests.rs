//! Run only by the marked cross-repository owner/Device qualification driver.
//! No locally synthesized authority or local holder key is admitted here.
use super::*;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use serde_json::json;

const CASE: &str = "operations::verified_issuance::joined_device_tests::actual_device_authority_and_remote_holder_qualify_receipt";

fn phase(value: &str) {
    eprintln!("MARTY_JOINED_PHASE {value}");
}

fn fail_prepare(error: anyhow::Error) -> ! {
    let message = error.to_string();
    let category = [
        ("Metadata fetch failed", "prepare-metadata-transport"),
        ("Metadata endpoint returned", "prepare-metadata-status"),
        ("metadata does not match", "prepare-issuer-mismatch"),
        ("not authorized", "prepare-service-grant"),
        ("token exchange failed", "prepare-token-exchange"),
        ("Nonce", "prepare-nonce"),
        ("nonce", "prepare-nonce"),
        ("key", "prepare-holder-key"),
        ("configuration", "prepare-configuration"),
        ("offer", "prepare-offer"),
    ]
    .into_iter()
    .find_map(|(text, category)| message.contains(text).then_some(category))
    .unwrap_or("prepare-other");
    phase(category);
    panic!("joined native receipt preparation failed; private error withheld");
}

#[test]
#[ignore = "requires marked fresh SQL/Bao, real Trust Profile/Device HTTPS and controlled issuer"]
fn actual_device_authority_and_remote_holder_qualify_receipt() {
    let path = std::path::PathBuf::from(std::env::var("MARTY_TEST_JOINED_NATIVE_INPUT").unwrap());
    let private = path.parent().unwrap();
    assert!(path.is_absolute() && path.file_name().unwrap() == "native-input.json");
    let config: Value =
        serde_json::from_slice(&std::fs::read(private.join("joined-fixture.json")).unwrap())
            .unwrap();
    let input: Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
    let nonce = config["nonce"].as_str().unwrap();
    assert!(nonce.len() >= 32 && nonce.bytes().all(|b| b.is_ascii_hexdigit()));
    assert!(input["nonce"].as_str() == Some(nonce));
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        assert_eq!(
            std::fs::metadata(private).unwrap().permissions().mode() & 0o077,
            0
        );
        assert_eq!(
            std::fs::metadata(&path).unwrap().permissions().mode() & 0o077,
            0
        );
    }
    let device = input["device_origin"].as_str().unwrap();
    let issuer = config["issuer_origin"].as_str().unwrap();
    for origin in [device, issuer] {
        let url = https_endpoint(origin).unwrap();
        assert!(
            url.host_str() == Some("127.0.0.1")
                && url.port().is_some()
                && url.path() == "/"
                && url.query().is_none()
        );
    }
    let holder = input["holder_public_jwk"].to_string();
    let bearer = input["device_bearer"].as_str().unwrap();
    let service_token = input["device_service_token"].as_str().unwrap();
    let ca = std::fs::read(private.join("device-ca.pem")).unwrap();
    let client = reqwest::Client::builder()
        .https_only(true)
        .no_proxy()
        .redirect(reqwest::redirect::Policy::none())
        .timeout(std::time::Duration::from_secs(10))
        .add_root_certificate(reqwest::Certificate::from_pem(&ca).unwrap())
        .build()
        .unwrap();
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    runtime.block_on(async {
        let fetch = || async {
            let response = client.get(format!("{device}/v1/devices/wallet-issuer-keys"))
                .header("x-service-token", service_token).bearer_auth(bearer).send().await.unwrap();
            assert!(response.status().is_success());
            assert_eq!(response.headers()["cache-control"], "no-store");
            let bytes = response.bytes().await.unwrap();
            assert!(bytes.len() <= 256 * 1024);
            let raw = std::str::from_utf8(&bytes).unwrap().to_owned();
            // Pass the original transport bytes into the production parser.
            preflight_issuance(&raw, &holder).unwrap();
            raw
        };
        let offer = json!({"credential_issuer":issuer,"credential_configuration_ids":["identity"],
            "grants":{"urn:ietf:params:oauth:grant-type:pre-authorized_code":{"pre-authorized_code":"owned-joined-code"}}});
        let offer_uri = url::Url::parse_with_params("openid-credential-offer://",
            [("credential_offer",offer.to_string())]).unwrap().to_string();
        for revoke_after_response in [false,true] {
            let initial = fetch().await;
            let evidence: Value = serde_json::from_str(&initial).unwrap();
            assert!(evidence["scope"]["verifier_trust_profile_id"].is_null());
            phase("authority-fetched");
            let prepared = prepare(&offer_uri,None,&holder,&initial).await.unwrap_or_else(|error|fail_prepare(error));
            phase("receipt-prepared");
            let signed = client.post(format!("{device}/v1/devices/holder-signatures"))
                .header("x-service-token",service_token).bearer_auth(bearer)
                .json(&json!({"purpose":"presentation_signing","payload_b64":URL_SAFE_NO_PAD.encode(&prepared.signing_input)}))
                .send().await.unwrap();
            phase("holder-signing-response");
            assert!(signed.status().is_success());
            let signed: Value = signed.json().await.unwrap();
            // Match the production Dart holder adapter: ES256 returns DER plus
            // a separately verified JWS/P1363 encoding for the native proof.
            assert_eq!(signed["signature_encoding"],"der");
            let encoded = signed["transcoded_signature_b64"].as_str().unwrap();
            let signature = URL_SAFE_NO_PAD.decode(encoded).unwrap();
            assert!(signature.len()==64 && URL_SAFE_NO_PAD.encode(&signature)==encoded);
            phase("remote-holder-signed");
            let before_request = fetch().await;
            let response_id = complete(&prepared.session_id,&signature,&before_request).await.unwrap_or_else(|error| {
                phase(if error.to_string() == "issuer credential request failed" {"complete-credential-request"} else {"complete-other"});
                panic!("joined native completion failed; private error withheld");
            });
            phase("credential-response-received");
            let transmitted: Value = serde_json::from_slice(&std::fs::read(private.join("issuer-proof.json")).unwrap()).unwrap();
            let proof = marty_oid4vci::jose::verify_compact_jwt_with_public_jwk(
                transmitted["proof"].as_str().unwrap(),&holder,"ES256").unwrap();
            assert_eq!(proof.claims["nonce"],"owned-joined-nonce");
            assert_eq!(proof.claims["aud"],issuer);
            if revoke_after_response {
                std::fs::write(private.join("native-response-ready"),nonce).unwrap();
                let deadline = std::time::Instant::now()+std::time::Duration::from_secs(20);
                loop {
                    if let Ok(ack) = std::fs::read_to_string(private.join("native-authority-updated")) {
                        assert!(ack == nonce);
                        break;
                    }
                    assert!(std::time::Instant::now() < deadline,"owned authority mutation timed out");
                    tokio::time::sleep(std::time::Duration::from_millis(20)).await;
                }
            }
            let after_response = fetch().await;
            if revoke_after_response {
                assert!(finalize(&response_id,&after_response).is_err(),"changed real authority must refuse storage");
                assert!(finalize(&response_id,&after_response).is_err(),"failed finalization must consume its handle");
                phase("changed-authority-rejected");
            } else {
                let receipt = finalize(&response_id,&after_response).unwrap();
                assert!(receipt.issuer == config["signed_issuer"].as_str().unwrap());
                assert_eq!(receipt.credential_type,"urn:elevenid:credential:identity");
                assert_eq!(receipt.format,"dc+sd-jwt");
                assert!(!receipt.credential.is_empty());
                assert!(finalize(&response_id,&after_response).is_err());
                phase("verified-receipt-admitted");
            }
        }
    });
    phase(CASE);
}
