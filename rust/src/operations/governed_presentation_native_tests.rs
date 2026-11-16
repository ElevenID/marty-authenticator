//! Explicitly executed only by the owned TLS/Transit qualification runner.
//! All identity-signing private keys remain non-exportable in disposable Bao.
use super::*;
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use marty_crypto_test_support::openbao_transit::{DisposableOpenBao, ScopedTransitSigner};
use serde_json::Value;
use sha2::{Digest, Sha256};

fn ec_public(signer: &ScopedTransitSigner) -> Value {
    let key: Value = serde_json::from_str(signer.public_jwk()).unwrap();
    json!({"crv":key["crv"],"kty":key["kty"],"x":key["x"],"y":key["y"]})
}
fn thumbprint(key: &Value) -> String {
    let mut canonical = key.clone();
    canonical.sort_all_objects();
    URL_SAFE_NO_PAD.encode(Sha256::digest(serde_json::to_vec(&canonical).unwrap()))
}
fn signed(key: &ScopedTransitSigner, header: Value, claims: &Value) -> String {
    let input = format!(
        "{}.{}",
        URL_SAFE_NO_PAD.encode(serde_json::to_vec(&header).unwrap()),
        URL_SAFE_NO_PAD.encode(serde_json::to_vec(claims).unwrap())
    );
    let signature = key.sign(input.as_bytes()).unwrap();
    format!("{input}.{}", URL_SAFE_NO_PAD.encode(signature))
}

struct Fixture {
    verifier: ScopedTransitSigner,
    holder: ScopedTransitSigner,
    holder_json: String,
    credential: String,
    issuer: String,
    governance: Value,
    request_claims: Value,
    request_header: Value,
    locator: String,
    capture: std::path::PathBuf,
}
impl Fixture {
    fn new() -> Self {
        let owner =
            std::env::var("MARTY_TEST_WALLET_OWNER_NONCE").expect("owned wallet fixture marker");
        assert!(owner.len() >= 32);
        assert_eq!(
            std::env::var("MARTY_TEST_OPENBAO_DISPOSABLE_NONCE").unwrap(),
            owner
        );
        let receiver = std::env::var("MARTY_TEST_WALLET_RECEIVER").expect("owned TLS receiver");
        let uri = url::Url::parse(&receiver).unwrap();
        assert_eq!(uri.scheme(), "https");
        assert_eq!(uri.host_str(), Some("127.0.0.1"));
        assert!(
            uri.port().is_some()
                && uri.username().is_empty()
                && uri.password().is_none()
                && uri.path() == "/"
                && uri.query().is_none()
                && uri.fragment().is_none()
        );
        let capture = std::path::PathBuf::from(
            std::env::var("MARTY_TEST_WALLET_CAPTURE").expect("owned receiver capture"),
        );
        assert!(!capture.exists(), "receiver must start empty");
        // Shared accepted fixture verifies a fresh TLS marker before creating
        // any key, and gives each signer only a bounded sign-only token.
        let backend = DisposableOpenBao::from_marked_env();
        let verifier = backend.create_es256();
        let issuer = backend.create_es256();
        let holder = backend.create_es256();
        let binding = backend.create_ed25519();
        let verifier_jwk = ec_public(&verifier);
        let issuer_jwk = ec_public(&issuer);
        let holder_jwk = ec_public(&holder);
        let ed: Value = serde_json::from_str(binding.public_jwk()).unwrap();
        let binding_jwk = json!({"crv":ed["crv"],"kty":ed["kty"],"x":ed["x"]});
        let did = format!(
            "did:jwk:{}",
            URL_SAFE_NO_PAD.encode(verifier_jwk.to_string())
        );
        let client = format!("decentralized_identifier:{did}");
        let kid = format!("{did}#0");
        let instance = uuid::Uuid::new_v4().to_string();
        let profile = uuid::Uuid::new_v4().to_string();
        let issuer_profile = uuid::Uuid::new_v4().to_string();
        let base = receiver.trim_end_matches('/');
        let locator = format!("{base}/v1/flows/instances/{instance}/request");
        let recipient = format!("{base}/v1/flows/instances/{instance}/submit");
        let now = Utc::now();
        let whole = DateTime::from_timestamp(now.timestamp(), 0).unwrap();
        let request_claims = json!({"iss":client,"client_id":client,"aud":"https://self-issued.me/v2",
            "iat":whole.timestamp(),"exp":whole.timestamp()+300,"response_type":"vp_token","response_mode":"direct_post",
            "response_uri":recipient,"nonce":"native-disposable-challenge","state":instance,
            "dcql_query":{"credentials":[{"id":"identity","format":"dc+sd-jwt","meta":{"vct_values":["Identity"]},"claims":[{"path":["age"]}]}]},
            "client_metadata":{"vp_formats_supported":{"dc+sd-jwt":{"sd-jwt_alg_values":["ES256"],"kb-jwt_alg_values":["ES256"]}}}});
        let request_header = json!({"alg":"ES256","typ":"oauth-authz-req+jwt","kid":kid});
        let jws = signed(&verifier, request_header.clone(), &request_claims);
        let holder_key = |jwk: Value, algorithm: &str| json!({"key_id":uuid::Uuid::new_v4().to_string(),"algorithm":algorithm,"version":1,"public_jwk":jwk,"jwk_thumbprint":thumbprint(&jwk)});
        let governance = json!({"contract":"marty.wallet/device-verifier-governance/v2","observed_at":now,"expires_at":now+Duration::seconds(60),
            "scope":{"credential_id":uuid::Uuid::new_v4().to_string(),"registration_id":uuid::Uuid::new_v4().to_string(),"pairing_id":uuid::Uuid::new_v4().to_string(),
                "device_id":"native-fixture-device","user_id":"native-fixture-user","organization_id":"native-fixture-org","issuer_trust_profile_id":issuer_profile,"verifier_trust_profile_id":profile,
                "credential_expires_at":now+Duration::minutes(10),"holder_binding_key":holder_key(binding_jwk,"EdDSA"),"presentation_signing_key":holder_key(holder_jwk.clone(),"ES256")},
            "verifier":{"contract":"marty.wallet/verifier-authority/v2","organization_id":"native-fixture-org","trust_profile_id":profile,"observed_at":now,"expires_at":now+Duration::seconds(60),
                "authority":{"authority_id":format!("{profile}/{}",uuid::Uuid::new_v4()),"revision":"native-fixture-revision-1","key_purpose":"oid4vp_request_signing","algorithm":"ES256","request_clock_skew_seconds":30,"max_request_lifetime_seconds":900,
                    "registration":{"client_id":client,"request_key_id":kid,"public_jwk":verifier_jwk,"response_uris":[recipient],"valid_from":whole-Duration::seconds(60),"valid_until":whole+Duration::minutes(10)}},
                "request":{"producer_id":"native-fixture-owner","instance_id":instance,"request_uri":locator,"response_uri":recipient,"nonce":"native-disposable-challenge",
                    "compact_request_jws":jws,"request_jws_sha256":format!("{:x}",Sha256::digest(jws.as_bytes())),"request_issued_at":whole,"request_expires_at":whole+Duration::seconds(300)}}});
        let disclose = |name: &str, value: Value| {
            URL_SAFE_NO_PAD.encode(
                serde_json::to_vec(&json!([uuid::Uuid::new_v4().to_string(), name, value]))
                    .unwrap(),
            )
        };
        let age = disclose("age", json!(21));
        let family = disclose("family_name", json!("not-approved"));
        let issuer_claims = json!({"iss":"https://native-fixture-issuer.example","vct":"Identity","iat":whole.timestamp(),"exp":whole.timestamp()+600,
            "sub":9007199254740993_u64,"_sd_alg":"sha-256","_sd":[URL_SAFE_NO_PAD.encode(Sha256::digest(age.as_bytes())),URL_SAFE_NO_PAD.encode(Sha256::digest(family.as_bytes()))],"cnf":{"jwk":holder_jwk}});
        let issuer_jwt = signed(
            &issuer,
            json!({"alg":"ES256","typ":"dc+sd-jwt","kid":"native-fixture-issuer-key"}),
            &issuer_claims,
        );
        let credential = format!("{issuer_jwt}~{age}~{family}~");
        let mut issuer_key = issuer_jwk;
        issuer_key["kid"] = json!("native-fixture-issuer-key");
        issuer_key["alg"] = json!("ES256");
        let issuer = json!({"organization_id":"native-fixture-org","trust_profile_id":issuer_profile,"generated_at":now,"expires_at":now+Duration::seconds(60),
            "issuer_keys":[{"issuer":"https://native-fixture-issuer.example","key_id":"native-fixture-issuer-key","algorithm":"ES256","public_jwk":issuer_key}]}).to_string();
        let mut enrolled = holder_jwk;
        enrolled["kid"] = json!("native-fixture-enrolled-public-id");
        Self {
            verifier,
            holder,
            holder_json: enrolled.to_string(),
            credential,
            issuer,
            governance,
            request_claims,
            request_header,
            locator,
            capture,
        }
    }
    fn review(&self, runtime: &tokio::runtime::Runtime) -> String {
        let raw = runtime
            .block_on(review(
                self.locator.clone(),
                self.governance.to_string(),
                self.credential.clone(),
                self.issuer.clone(),
                self.holder_json.clone(),
            ))
            .unwrap();
        let projection: Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(
            projection["credential"]["always_shared"]["sub"],
            "9007199254740993"
        );
        assert_eq!(
            projection["request"]["client_id"],
            self.request_claims["client_id"]
        );
        projection["session_id"].as_str().unwrap().to_owned()
    }
    fn prepare(&self, runtime: &tokio::runtime::Runtime, handle: &str) -> PreparedSelection {
        runtime
            .block_on(prepare(
                handle,
                &["age".into()],
                &self.governance.to_string(),
                &self.issuer,
                &self.holder_json,
            ))
            .unwrap()
    }
}

#[test]
#[ignore = "requires marked disposable TLS OpenBao, isolated receiver and per-process CA"]
fn actual_remote_keys_authenticate_consent_and_submit_once_with_fresh_scope() {
    let fixture = Fixture::new();
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    // A real verifier signature cannot authorize unsupported semantics or a
    // credential outside its signed VCT/issuer-algorithm policy.
    for (pointer, value) in [
        ("/transaction_data", json!(["unsupported-transaction-data"])),
        (
            "/dcql_query/credentials/0/meta/vct_values",
            json!(["DifferentIdentity"]),
        ),
        (
            "/client_metadata/vp_formats_supported/dc+sd-jwt/sd-jwt_alg_values",
            json!(["EdDSA"]),
        ),
    ] {
        let mut claims = fixture.request_claims.clone();
        if pointer == "/transaction_data" {
            claims["transaction_data"] = value;
        } else {
            *claims.pointer_mut(pointer).unwrap() = value;
        }
        let jws = signed(&fixture.verifier, fixture.request_header.clone(), &claims);
        let mut governance = fixture.governance.clone();
        governance["verifier"]["request"]["compact_request_jws"] = json!(jws);
        governance["verifier"]["request"]["request_jws_sha256"] =
            json!(format!("{:x}", Sha256::digest(jws.as_bytes())));
        assert!(runtime
            .block_on(review(
                fixture.locator.clone(),
                governance.to_string(),
                fixture.credential.clone(),
                fixture.issuer.clone(),
                fixture.holder_json.clone()
            ))
            .is_err());
    }
    let reviewed = fixture.review(&runtime);
    let prepared = fixture.prepare(&runtime, &reviewed);
    assert_ne!(reviewed, prepared.session_id);
    assert!(runtime
        .block_on(prepare(
            &reviewed,
            &["age".into()],
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());
    let signature = fixture.holder.sign(&prepared.signing_input).unwrap();
    let response = runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json,
        ))
        .unwrap();
    assert!(response.ok);
    let receipt: Value = serde_json::from_slice(&std::fs::read(&fixture.capture).unwrap()).unwrap();
    assert_eq!(receipt["count"], 1);
    assert_eq!(
        receipt["path"],
        fixture.request_claims["response_uri"]
            .as_str()
            .unwrap()
            .strip_prefix(
                std::env::var("MARTY_TEST_WALLET_RECEIVER")
                    .unwrap()
                    .trim_end_matches('/')
            )
            .unwrap()
    );
    assert_eq!(receipt["state"], fixture.request_claims["state"]);
    let vp: Value = serde_json::from_str(receipt["vp_token"].as_str().unwrap()).unwrap();
    let presentation = vp["identity"].as_array().unwrap()[0].as_str().unwrap();
    let parts = presentation.split('~').collect::<Vec<_>>();
    assert_eq!(
        parts.len(),
        3,
        "only one approved disclosure and the holder proof"
    );
    assert_eq!(parts[0], fixture.credential.split('~').next().unwrap());
    let disclosure: Value =
        serde_json::from_slice(&URL_SAFE_NO_PAD.decode(parts[1]).unwrap()).unwrap();
    assert_eq!(disclosure[1], "age");
    assert_eq!(disclosure[2], 21);
    let proof =
        jose::verify_compact_jwt_with_public_jwk(parts[2], &fixture.holder_json, "ES256").unwrap();
    assert_eq!(proof.claims["nonce"], fixture.request_claims["nonce"]);
    assert_eq!(proof.claims["aud"], fixture.request_claims["client_id"]);
    assert_eq!(
        proof.claims["sd_hash"],
        URL_SAFE_NO_PAD.encode(Sha256::digest(
            format!("{}~{}~", parts[0], parts[1]).as_bytes()
        ))
    );
    assert!(runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());

    // A fresh, well-formed scope change must consume approval, not renew it.
    for pointer in ["/scope/user_id", "/verifier/authority/revision"] {
        let review = fixture.review(&runtime);
        let mut changed = fixture.governance.clone();
        *changed.pointer_mut(pointer).unwrap() = json!("changed-after-review");
        assert!(runtime
            .block_on(prepare(
                &review,
                &["age".into()],
                &changed.to_string(),
                &fixture.issuer,
                &fixture.holder_json
            ))
            .is_err());
        assert!(runtime
            .block_on(prepare(
                &review,
                &["age".into()],
                &fixture.governance.to_string(),
                &fixture.issuer,
                &fixture.holder_json
            ))
            .is_err());
    }
    let reviewed = fixture.review(&runtime);
    let mut replacement = fixture.governance.clone();
    let mut claims = fixture.request_claims.clone();
    claims["nonce"] = json!("newly-signed-replacement");
    let jws = signed(&fixture.verifier, fixture.request_header.clone(), &claims);
    replacement["verifier"]["request"]["nonce"] = claims["nonce"].clone();
    replacement["verifier"]["request"]["compact_request_jws"] = json!(jws);
    replacement["verifier"]["request"]["request_jws_sha256"] =
        json!(format!("{:x}", Sha256::digest(jws.as_bytes())));
    assert!(runtime
        .block_on(prepare(
            &reviewed,
            &["age".into()],
            &replacement.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());

    for bad_signature in [false, true] {
        let reviewed = fixture.review(&runtime);
        let prepared = fixture.prepare(&runtime, &reviewed);
        let signature = if bad_signature {
            vec![0; 64]
        } else {
            fixture.holder.sign(&prepared.signing_input).unwrap()
        };
        let mut fresh = fixture.governance.clone();
        if !bad_signature {
            fresh["scope"]["presentation_signing_key"]["version"] = json!(2);
        }
        assert!(runtime
            .block_on(complete(
                &prepared.session_id,
                &signature,
                &fresh.to_string(),
                &fixture.issuer,
                &fixture.holder_json
            ))
            .is_err());
        assert!(runtime
            .block_on(complete(
                &prepared.session_id,
                &signature,
                &fixture.governance.to_string(),
                &fixture.issuer,
                &fixture.holder_json
            ))
            .is_err());
    }
    let reviewed = fixture.review(&runtime);
    let prepared = fixture.prepare(&runtime, &reviewed);
    let signature = fixture.holder.sign(&prepared.signing_input).unwrap();
    let mut revoked: Value = serde_json::from_str(&fixture.issuer).unwrap();
    revoked["issuer_keys"] = json!([]);
    assert!(runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &revoked.to_string(),
            &fixture.holder_json
        ))
        .is_err());
    assert!(runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());
    let reviewed = fixture.review(&runtime);
    cancel(&reviewed).unwrap();
    assert!(runtime
        .block_on(prepare(
            &reviewed,
            &["age".into()],
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());
    let unchanged: Value =
        serde_json::from_slice(&std::fs::read(&fixture.capture).unwrap()).unwrap();
    assert_eq!(
        unchanged["count"], 1,
        "replays, replacements and failed signatures must not submit"
    );
}

#[test]
#[ignore = "requires marked disposable TLS OpenBao and an untrusted receiver CA process"]
fn actual_receiver_with_untrusted_ca_cannot_receive_a_native_presentation() {
    let fixture = Fixture::new();
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    let review = fixture.review(&runtime);
    let prepared = fixture.prepare(&runtime, &review);
    let signature = fixture.holder.sign(&prepared.signing_input).unwrap();
    let error = runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json,
        ))
        .unwrap_err();
    assert!(error.to_string().contains("Presentation submission failed"));
    assert!(
        !fixture.capture.exists(),
        "untrusted HTTPS receiver must see no HTTP presentation"
    );
    assert!(runtime
        .block_on(complete(
            &prepared.session_id,
            &signature,
            &fixture.governance.to_string(),
            &fixture.issuer,
            &fixture.holder_json
        ))
        .is_err());
}
