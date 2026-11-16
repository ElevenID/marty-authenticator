//! Convert a fresh, bearer-scoped Trust Profile projection into Core's
//! explicit public issuer-key resolver. The caller must fetch it for each use.

use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::types::SigningAlgorithm;
use marty_oid4vci::{ResolvedSdJwtIssuerKey, TrustedSdJwtIssuerKeys};
use serde::Deserialize;
use serde_json::Value;

const MAX_SNAPSHOT_BYTES: usize = 256 * 1024;

pub(crate) struct FreshIssuerTrust {
    pub resolver: TrustedSdJwtIssuerKeys,
    pub expires_at: DateTime<Utc>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Snapshot {
    organization_id: String,
    trust_profile_id: String,
    generated_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    issuer_keys: Vec<IssuerKey>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct IssuerKey {
    issuer: String,
    key_id: Option<String>,
    algorithm: SigningAlgorithm,
    public_jwk: Value,
}

pub(crate) fn contains_private_material(value: &Value) -> bool {
    match value {
        Value::Array(values) => values.iter().any(contains_private_material),
        Value::Object(values) => values.iter().any(|(key, value)| {
            let normalized: String = key
                .to_lowercase()
                .chars()
                .filter(char::is_ascii_alphanumeric)
                .collect();
            matches!(
                normalized.as_str(),
                "d" | "p" | "q" | "dp" | "dq" | "qi" | "oth" | "k"
            ) || normalized.contains("private")
                || normalized.contains("secret")
                || normalized.contains("seed")
                || contains_private_material(value)
        }),
        _ => false,
    }
}

pub(crate) fn resolver_from_snapshot(
    json: &str,
    now: DateTime<Utc>,
) -> anyhow::Result<FreshIssuerTrust> {
    anyhow::ensure!(
        json.len() <= MAX_SNAPSHOT_BYTES,
        "issuer trust snapshot is too large"
    );
    // Validate the original transport bytes before any Value can discard
    // repeated members, including escaped names in nested public JWKs.
    let original = marty_crypto::strict_json::parse_unique_json(json.as_bytes())?;
    anyhow::ensure!(
        !contains_private_material(&original),
        "issuer trust snapshot contains private key material"
    );
    let snapshot: Snapshot = serde_json::from_str(json)?;
    anyhow::ensure!(
        !snapshot.organization_id.is_empty()
            && uuid::Uuid::parse_str(&snapshot.trust_profile_id).is_ok(),
        "issuer trust scope is invalid"
    );
    anyhow::ensure!(
        snapshot.generated_at <= now + Duration::seconds(5)
            && snapshot.expires_at > now
            && snapshot.expires_at > snapshot.generated_at
            && snapshot.expires_at <= snapshot.generated_at + Duration::minutes(1),
        "issuer trust snapshot is stale or invalid"
    );
    anyhow::ensure!(
        !snapshot.issuer_keys.is_empty() && snapshot.issuer_keys.len() <= 256,
        "issuer trust key count is invalid"
    );
    let keys = snapshot
        .issuer_keys
        .into_iter()
        .map(|key| {
            anyhow::ensure!(key.public_jwk.is_object(), "issuer key JWK is invalid");
            let jwk = serde_json::to_string(&key.public_jwk)?;
            Ok(ResolvedSdJwtIssuerKey::new(
                key.issuer,
                key.key_id,
                key.algorithm,
                jwk,
            ))
        })
        .collect::<anyhow::Result<Vec<_>>>()?;
    Ok(FreshIssuerTrust {
        resolver: TrustedSdJwtIssuerKeys::new(keys)?,
        expires_at: snapshot.expires_at,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use marty_oid4vci::SdJwtIssuerKeyResolver;
    use serde_json::json;

    fn snapshot(now: DateTime<Utc>) -> Value {
        json!({
            "organization_id": "org-1",
            "trust_profile_id": "11111111-2222-4333-8444-555555555555",
            "generated_at": now,
            "expires_at": now + Duration::seconds(30),
            "issuer_keys": [{
                "issuer": "did:web:issuer.example",
                "key_id": "issuer-key-1",
                "algorithm": "ES256",
                "public_jwk": {
                    "kty": "EC", "crv": "P-256",
                    "x": "-Jl4FT1j_1FtOcJZbWn0OVENdmNCdPleCn0Hu1dTIWg",
                    "y": "mstlY3LgpnfcH3qca8C2LuiH0igN2LsDp9yPZ2RgLS4",
                    "kid": "issuer-key-1"
                }
            }]
        })
    }

    #[test]
    fn fresh_public_snapshot_resolves_only_the_exact_issuer_identity() {
        let now = Utc::now();
        let trusted = resolver_from_snapshot(&snapshot(now).to_string(), now).unwrap();
        let resolver = trusted.resolver;
        assert!(resolver
            .resolve(
                "did:web:issuer.example",
                Some("issuer-key-1"),
                SigningAlgorithm::ES256
            )
            .is_ok());
        assert!(resolver
            .resolve(
                "did:web:other.example",
                Some("issuer-key-1"),
                SigningAlgorithm::ES256
            )
            .is_err());
        assert!(resolver
            .resolve("did:web:issuer.example", None, SigningAlgorithm::ES256)
            .is_err());
    }

    #[test]
    fn rejects_stale_private_or_ambiguous_snapshots() {
        let now = Utc::now();
        let mut value = snapshot(now);
        value["expires_at"] = json!(now - Duration::seconds(1));
        assert!(resolver_from_snapshot(&value.to_string(), now).is_err());

        value = snapshot(now);
        value["issuer_keys"][0]["public_jwk"]["d"] = json!("private");
        assert!(resolver_from_snapshot(&value.to_string(), now).is_err());

        value = snapshot(now);
        let key = value["issuer_keys"][0].clone();
        value["issuer_keys"].as_array_mut().unwrap().push(key);
        assert!(resolver_from_snapshot(&value.to_string(), now).is_err());
    }

    #[test]
    fn rejects_original_duplicate_snapshot_members_at_every_depth() {
        let now = Utc::now();
        let original = snapshot(now).to_string();
        for (needle, replacement) in [
            (
                "\"organization_id\":",
                "\"organization_id\":\"different\",\"organization_id\":",
            ),
            (
                "\"issuer\":",
                "\"issuer\":\"did:web:other.example\",\"issuer\":",
            ),
            ("\"kty\":", "\"kty\":\"RSA\",\"\\u006bty\":"),
        ] {
            let ambiguous = original.replacen(needle, replacement, 1);
            assert_ne!(ambiguous, original);
            // These would retain the valid last member with ordinary decoding.
            let decoded: Value = serde_json::from_str(&ambiguous).unwrap();
            assert_eq!(decoded, snapshot(now));
            assert!(resolver_from_snapshot(&ambiguous, now).is_err());
        }
    }

    #[test]
    fn rejects_nested_and_normalized_private_custody_fields_without_echoing_them() {
        let now = Utc::now();
        for name in [
            "d",
            "D",
            "Private-Key",
            "s_e_c_r_e_t",
            "seedPhrase",
            "oth",
            "k",
        ] {
            let mut value = snapshot(now);
            value["issuer_keys"][0]["public_jwk"]["extension"] =
                json!({"nested":[{name:"sensitive-test-sentinel"}]});
            let error = resolver_from_snapshot(&value.to_string(), now)
                .err()
                .unwrap();
            assert!(error.to_string().contains("private key material"));
            assert!(!error.to_string().contains("sensitive-test-sentinel"));
        }
    }
}
