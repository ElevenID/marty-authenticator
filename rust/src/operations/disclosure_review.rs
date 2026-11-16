//! Consent projection of the exact issuer JWT after governed verification.
//! Decoding alone never authorizes a candidate or supplies trust material.

use anyhow::{ensure, Context};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::Utc;
use serde_json::json;
use std::collections::BTreeMap;

fn exact_members(bytes: &[u8], maximum: usize) -> anyhow::Result<BTreeMap<String, String>> {
    ensure!(bytes.len() <= maximum, "consent document is too large");
    let checked = marty_crypto::strict_json::parse_unique_json(bytes)?;
    ensure!(
        checked
            .as_object()
            .is_some_and(|object| object.len() <= 256),
        "consent document is unsupported"
    );
    // Decode directly from original bytes, never a reserialized Value. JSON
    // lexemes retain numeric identifiers/exponents beyond JavaScript precision.
    let members: BTreeMap<String, Box<serde_json::value::RawValue>> =
        serde_json::from_slice(bytes)?;
    Ok(members
        .into_iter()
        .map(|(key, value)| (key, value.get().to_owned()))
        .collect())
}

pub(crate) fn review(
    credential: &str,
    issuer_snapshot_json: &str,
    holder_public_jwk_json: &str,
) -> anyhow::Result<String> {
    ensure!(
        !credential.is_empty() && credential.len() <= 1024 * 1024,
        "credential is invalid"
    );
    let trusted = super::issuer_trust::resolver_from_snapshot(issuer_snapshot_json, Utc::now())?;
    let verified = marty_oid4vci::WalletEngine::new().verify_received_sd_jwt_credential(
        credential,
        holder_public_jwk_json,
        &trusted.resolver,
    )?;
    // Core has just verified this same immutable string, including unique JSON
    // members, issuer signature, time policy, disclosures and holder binding.
    // Preserve every signed payload member: protocol metadata and identifiers
    // are sent with the issuer JWT too, even when no optional claims are chosen.
    let issuer_jwt = credential
        .split('~')
        .next()
        .context("issuer JWT is absent")?;
    let encoded_header = issuer_jwt
        .split('.')
        .next()
        .context("issuer header is absent")?;
    let header_bytes = URL_SAFE_NO_PAD.decode(encoded_header)?;
    let header = exact_members(&header_bytes, 144 * 1024)?;
    let encoded = issuer_jwt
        .split('.')
        .nth(1)
        .context("issuer payload is absent")?;
    let bytes = URL_SAFE_NO_PAD.decode(encoded)?;
    let claims = exact_members(&bytes, 64 * 1024)?;
    ensure!(
        trusted.expires_at > Utc::now(),
        "issuer trust snapshot expired"
    );
    let projection = serde_json::to_string(&json!({
        "issuer": verified.issuer,
        "credential_type": verified.credential_type,
        "format": verified.format,
        "protected_header": header,
        "always_shared": claims,
    }))?;
    ensure!(
        projection.len() <= 512 * 1024,
        "consent projection is too large"
    );
    Ok(projection)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    fn fixture() -> (String, String, String) {
        let vector: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let now = Utc::now();
        let mut jwk = vector["issuer_public_jwk"].clone();
        jwk["kid"] = vector["issuer_key_id"].clone();
        jwk["alg"] = json!("ES256");
        let snapshot = json!({"organization_id":"org-1", "trust_profile_id":"11111111-2222-4333-8444-555555555555",
            "generated_at":now, "expires_at":now+chrono::Duration::seconds(30),
            "issuer_keys":[{"issuer":vector["issuer"], "key_id":vector["issuer_key_id"], "algorithm":"ES256", "public_jwk":jwk}]});
        (
            vector["credential"].as_str().unwrap().into(),
            snapshot.to_string(),
            vector["holder_public_jwk"].to_string(),
        )
    }

    #[test]
    fn governed_signature_and_holder_verification_precede_full_signed_payload_review() {
        let (credential, snapshot, holder) = fixture();
        let result: Value =
            serde_json::from_str(&review(&credential, &snapshot, &holder).unwrap()).unwrap();
        let payload = credential
            .split('~')
            .next()
            .unwrap()
            .split('.')
            .nth(1)
            .unwrap();
        let expected: Value =
            serde_json::from_slice(&URL_SAFE_NO_PAD.decode(payload).unwrap()).unwrap();
        let restored: BTreeMap<String, Value> = result["always_shared"]
            .as_object()
            .unwrap()
            .iter()
            .map(|(key, value)| {
                (
                    key.clone(),
                    serde_json::from_str(value.as_str().unwrap()).unwrap(),
                )
            })
            .collect();
        assert_eq!(
            serde_json::to_value(restored).unwrap(),
            expected,
            "no signed member may be silently omitted"
        );
        assert_eq!(result["issuer"], expected["iss"]);
        let encoded_header = credential.split('.').next().unwrap();
        let expected_header: Value =
            serde_json::from_slice(&URL_SAFE_NO_PAD.decode(encoded_header).unwrap()).unwrap();
        let restored_header: BTreeMap<String, Value> = result["protected_header"]
            .as_object()
            .unwrap()
            .iter()
            .map(|(key, value)| {
                (
                    key.clone(),
                    serde_json::from_str(value.as_str().unwrap()).unwrap(),
                )
            })
            .collect();
        assert_eq!(
            serde_json::to_value(restored_header).unwrap(),
            expected_header
        );
        assert!(result["always_shared"].get("cnf").is_some());
        assert!(result["always_shared"].get("_sd").is_some());
    }

    #[test]
    fn exact_lexemes_keep_large_identifiers_nested_types_and_escapes_without_accepting_duplicates()
    {
        let members = exact_members(br#"{"sub":9007199254740993,"nested":{"ids":[9007199254740993,true,null]},"exponent":1.2300e+20,"escaped":"a\u0062\n"}"#, 1024).unwrap();
        assert_eq!(members["sub"], "9007199254740993");
        assert_eq!(members["nested"], r#"{"ids":[9007199254740993,true,null]}"#);
        assert_eq!(members["exponent"], "1.2300e+20");
        assert_eq!(members["escaped"], r#""a\u0062\n""#);
        assert!(exact_members(br#"{"sub":1,"\u0073ub":2}"#, 1024).is_err());
        assert!(exact_members(br#"{"nested":{"key":1,"key":2}}"#, 1024).is_err());
        assert!(exact_members(br#"{}"#, 1).is_err());
        assert!(exact_members(br#"[]"#, 1024).is_err());
    }

    #[test]
    fn forged_credentials_wrong_holder_and_untrusted_issuer_have_no_consent_projection() {
        let (credential, snapshot, holder) = fixture();
        let mut forged = credential
            .split('~')
            .next()
            .unwrap()
            .split('.')
            .map(str::to_owned)
            .collect::<Vec<_>>();
        forged[1] = URL_SAFE_NO_PAD.encode(br#"{"iss":"did:attacker","sub":"hidden-identifier"}"#);
        assert!(review(&(forged.join(".") + "~"), &snapshot, &holder).is_err());
        assert!(review(&credential, &snapshot, "{}").is_err());
        let mut untrusted: Value = serde_json::from_str(&snapshot).unwrap();
        untrusted["issuer_keys"][0]["issuer"] = json!("did:attacker");
        assert!(review(&credential, &untrusted.to_string(), &holder).is_err());
    }
}
