//! Status-list transport parsing for the mobile bridge.
//!
//! Raw fetched JSON cannot establish a status authority. The legacy evaluation
//! entry point remains ABI-compatible but fails closed until a native governed
//! resolver can supply authenticated issuer/key and freshness evidence to Core.

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use url::Url;

const MAX_STATUS_ENTRIES: usize = 32;
const MAX_ENTRY_JSON_BYTES: usize = 256 * 1024;
const MAX_STATUS_CREDENTIAL_JSON_BYTES: usize = 2 * 1024 * 1024;
const MAX_IRI_CHARS: usize = 4096;
const STATUS_AUTHORITY_UNAVAILABLE: &str = "STATUS_AUTHORITY_UNAVAILABLE";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbStatusEntry {
    pub id: String,
    pub purpose: String,
    pub index: u64,
    pub list_url: String,
    pub entry_json: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct FrbStatusDecision {
    pub purpose: String,
    pub index: u64,
    pub asserted: bool,
    pub list_size: u64,
}

pub fn parse_status_entries(credential_status_json: String) -> anyhow::Result<Vec<FrbStatusEntry>> {
    check_document_size(&credential_status_json, MAX_ENTRY_JSON_BYTES)?;
    let value: Value = serde_json::from_str(&credential_status_json)?;
    let entries = match &value {
        Value::Array(entries) => entries.iter().collect::<Vec<_>>(),
        Value::Object(_) => vec![&value],
        _ => anyhow::bail!("credentialStatus must be an object or array"),
    };
    if entries.is_empty() || entries.len() > MAX_STATUS_ENTRIES {
        anyhow::bail!("credentialStatus must contain between 1 and 32 entries");
    }
    entries.into_iter().map(parse_entry).collect()
}

// Compatibility entry point for callers that only have raw network data.
//
// A proof-shaped object, HTTPS response, or decoded zero bit is not verified
// status. This API has no trusted issuer/key resolver or authenticated freshness
// context, so it must never produce a successful decision. Activation requires
// a separate native authority-bound API using Core's verification contracts.
pub fn evaluate_bitstring_status(
    entry_json: String,
    status_list_credential_json: String,
) -> anyhow::Result<FrbStatusDecision> {
    check_document_size(&entry_json, MAX_ENTRY_JSON_BYTES)?;
    check_document_size(
        &status_list_credential_json,
        MAX_STATUS_CREDENTIAL_JSON_BYTES,
    )?;
    let entry_value: Value = serde_json::from_str(&entry_json)?;
    parse_entry(&entry_value)?;
    anyhow::bail!(
        "{STATUS_AUTHORITY_UNAVAILABLE}: status requires native issuer/key authorization, proof verification, and freshness evidence"
    )
}

fn parse_entry(value: &Value) -> anyhow::Result<FrbStatusEntry> {
    let object = value
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("credential status entry must be an object"))?;
    if required_string(object.get("type"), "credential status type")? != "BitstringStatusListEntry"
    {
        anyhow::bail!("unsupported credential status type");
    }
    let id = required_string(object.get("id"), "credential status id")?.to_string();
    let purpose = required_string(object.get("statusPurpose"), "status purpose")?;
    if !matches!(purpose, "revocation" | "suspension") {
        anyhow::bail!("status purpose must be revocation or suspension");
    }
    let list_url = required_string(object.get("statusListCredential"), "statusListCredential")?;
    let parsed_url = Url::parse(list_url)?;
    if parsed_url.scheme() != "https"
        || parsed_url.host_str().is_none()
        || !parsed_url.username().is_empty()
        || parsed_url.password().is_some()
        || parsed_url.fragment().is_some()
    {
        anyhow::bail!(
            "statusListCredential must be an absolute HTTPS URL without user information or a fragment"
        );
    }
    let index = parse_index(object.get("statusListIndex"))?;

    Ok(FrbStatusEntry {
        id,
        purpose: purpose.to_string(),
        index,
        list_url: list_url.to_string(),
        entry_json: serde_json::to_string(value)?,
    })
}

fn parse_index(value: Option<&Value>) -> anyhow::Result<u64> {
    match value {
        Some(Value::String(value))
            if !value.is_empty() && value.bytes().all(|byte| byte.is_ascii_digit()) =>
        {
            Ok(value.parse()?)
        }
        Some(Value::Number(value)) => value
            .as_u64()
            .ok_or_else(|| anyhow::anyhow!("statusListIndex must be a non-negative integer")),
        _ => anyhow::bail!("statusListIndex must be a decimal string or non-negative integer"),
    }
}

fn required_string<'a>(value: Option<&'a Value>, name: &str) -> anyhow::Result<&'a str> {
    value
        .and_then(Value::as_str)
        .filter(|value| {
            !value.is_empty()
                && value.trim() == *value
                && value.chars().count() <= MAX_IRI_CHARS
                && !value.chars().any(char::is_control)
        })
        .ok_or_else(|| anyhow::anyhow!("{name} must be a bounded non-empty string"))
}

fn check_document_size(value: &str, maximum: usize) -> anyhow::Result<()> {
    if value.len() > maximum {
        anyhow::bail!("status document exceeds the supported byte limit");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture() -> Value {
        serde_json::from_str(include_str!(
            "../../test/fixtures/status_list_behavior.json"
        ))
        .unwrap()
    }

    #[test]
    fn raw_status_vectors_never_establish_authority() {
        for vector in fixture()["vectors"].as_array().unwrap() {
            let result = evaluate_bitstring_status(
                vector["entry"].to_string(),
                vector["status_list_credential"].to_string(),
            );
            let error = result.expect_err("raw status bytes cannot produce a verified decision");
            assert!(
                error.to_string().contains(STATUS_AUTHORITY_UNAVAILABLE),
                "{}: {error}",
                vector["id"]
            );
        }
    }

    #[test]
    fn arbitrary_proofs_and_mutated_bits_cannot_produce_success() {
        let fixture = fixture();
        let vector = &fixture["vectors"][0];
        let mut credential = vector["status_list_credential"].clone();
        for proof in [
            serde_json::json!({"anything": true}),
            serde_json::json!([{"proofValue": "not-a-signature"}]),
            Value::Null,
        ] {
            credential["proof"] = proof;
            for encoded in ["", "uAAAA", "attacker-controlled-bitstring"] {
                credential["credentialSubject"]["encodedList"] = encoded.into();
                let error =
                    evaluate_bitstring_status(vector["entry"].to_string(), credential.to_string())
                        .expect_err("unverified bytes must remain unknown");
                assert!(error.to_string().contains(STATUS_AUTHORITY_UNAVAILABLE));
            }
        }
    }

    #[test]
    fn transport_entries_require_bounded_https_urls() {
        let mut entry = fixture()["vectors"][0]["entry"].clone();
        for url in [
            "http://issuer.example/status/1",
            "https://user:password@issuer.example/status/1",
            "https://issuer.example/status/1#fragment",
            "file:///status/1",
        ] {
            entry["statusListCredential"] = url.into();
            assert!(parse_status_entries(entry.to_string()).is_err(), "{url}");
        }
        entry["statusListCredential"] =
            format!("https://issuer.example/{}", "x".repeat(MAX_IRI_CHARS)).into();
        assert!(parse_status_entries(entry.to_string()).is_err());
        assert!(parse_status_entries(" ".repeat(MAX_ENTRY_JSON_BYTES + 1)).is_err());
        assert!(evaluate_bitstring_status(
            fixture()["vectors"][0]["entry"].to_string(),
            " ".repeat(MAX_STATUS_CREDENTIAL_JSON_BYTES + 1),
        )
        .is_err());
    }

    #[test]
    fn malformed_entries_fail_closed() {
        assert!(parse_status_entries("null".to_string()).is_err());
        assert!(parse_status_entries(r#"{"type":"Unknown"}"#.to_string()).is_err());
        assert!(parse_status_entries("[]".to_string()).is_err());
    }
}
