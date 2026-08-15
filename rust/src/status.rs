//! Strict W3C Bitstring Status List decisions for the mobile bridge.
//!
//! HTTP retrieval and caching remain Dart responsibilities. Parsing, bounded
//! decoding, purpose matching, and the status bit decision live in Rust.

use flutter_rust_bridge::frb;
use marty_status::BitstringStatusList;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use url::Url;

const MAX_STATUS_ENTRIES: usize = 32;

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

pub fn evaluate_bitstring_status(
    entry_json: String,
    status_list_credential_json: String,
) -> anyhow::Result<FrbStatusDecision> {
    let entry_value: Value = serde_json::from_str(&entry_json)?;
    let entry = parse_entry(&entry_value)?;
    let credential: Value = serde_json::from_str(&status_list_credential_json)?;
    let object = credential
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("status-list credential must be an object"))?;

    let credential_id = required_string(object.get("id"), "status-list credential id")?;
    if credential_id != entry.list_url {
        anyhow::bail!("status-list credential id does not match statusListCredential");
    }
    if !has_type(object.get("type"), "BitstringStatusListCredential") {
        anyhow::bail!("status-list credential type must include BitstringStatusListCredential");
    }
    if !has_nonempty_proof(object.get("proof")) {
        anyhow::bail!("status-list credential must carry a proof");
    }

    let subject = object
        .get("credentialSubject")
        .and_then(Value::as_object)
        .ok_or_else(|| anyhow::anyhow!("status-list credentialSubject must be an object"))?;
    if !has_type(subject.get("type"), "BitstringStatusList") {
        anyhow::bail!("status-list credentialSubject type must be BitstringStatusList");
    }
    let purpose = required_string(subject.get("statusPurpose"), "status-list purpose")?;
    if purpose != entry.purpose {
        anyhow::bail!("status-list purpose does not match credential status entry");
    }
    let encoded = required_string(subject.get("encodedList"), "encodedList")?;
    let list = BitstringStatusList::from_base64url_bounded(encoded)?;
    let index =
        usize::try_from(entry.index).map_err(|_| anyhow::anyhow!("status index is too large"))?;
    let asserted = list.get(index)?;

    Ok(FrbStatusDecision {
        purpose: entry.purpose,
        index: entry.index,
        asserted,
        list_size: u64::try_from(list.len()).unwrap_or(u64::MAX),
    })
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
    if !matches!(parsed_url.scheme(), "https" | "http") {
        anyhow::bail!("statusListCredential must use HTTP or HTTPS");
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
        .filter(|value| !value.is_empty() && value.trim() == *value)
        .ok_or_else(|| anyhow::anyhow!("{name} must be a non-empty string"))
}

fn has_type(value: Option<&Value>, expected: &str) -> bool {
    match value {
        Some(Value::String(value)) => value == expected,
        Some(Value::Array(values)) => values.iter().any(|value| value.as_str() == Some(expected)),
        _ => false,
    }
}

fn has_nonempty_proof(value: Option<&Value>) -> bool {
    match value {
        Some(Value::Object(proof)) => !proof.is_empty(),
        Some(Value::Array(proofs)) => proofs.iter().any(|proof| {
            proof
                .as_object()
                .is_some_and(|proof_object| !proof_object.is_empty())
        }),
        _ => false,
    }
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
    fn language_neutral_status_vectors_match_expected_decisions() {
        for vector in fixture()["vectors"].as_array().unwrap() {
            let result = evaluate_bitstring_status(
                vector["entry"].to_string(),
                vector["status_list_credential"].to_string(),
            );
            if let Some(expected) = vector.get("asserted").and_then(Value::as_bool) {
                assert_eq!(result.unwrap().asserted, expected, "{}", vector["id"]);
            } else {
                assert!(result.is_err(), "{} must fail closed", vector["id"]);
            }
        }
    }

    #[test]
    fn malformed_entries_fail_closed() {
        assert!(parse_status_entries("null".to_string()).is_err());
        assert!(parse_status_entries(r#"{"type":"Unknown"}"#.to_string()).is_err());
        assert!(parse_status_entries("[]".to_string()).is_err());
    }
}
