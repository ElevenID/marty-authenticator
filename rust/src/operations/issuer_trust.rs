//! Convert a fresh, bearer-scoped Trust Profile projection into Core's
//! explicit public issuer-key resolver. The caller must fetch it for each use.

use anyhow::{ensure, Context};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use chrono::{DateTime, Duration, Utc};
use marty_oid4vci::types::SigningAlgorithm;
use marty_oid4vci::{ResolvedSdJwtIssuerKey, TrustedSdJwtIssuerKeys};
use serde::Deserialize;
use serde_json::Value;

const MAX_SNAPSHOT_BYTES: usize = 256 * 1024;

pub(crate) struct FreshIssuerTrust {
    pub resolver: TrustedSdJwtIssuerKeys,
    pub expires_at: DateTime<Utc>,
    pub scope: super::verifier_governance::DeviceScope,
    pub revision: Revision,
}

#[derive(Clone, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub(crate) struct Revision {
    id: String,
    version: u32,
    content_digest: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct IssuerGovernanceEnvelope {
    contract: String,
    scope: super::verifier_governance::DeviceScope,
    observed_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    issuer: Snapshot,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Snapshot {
    contract: String,
    organization_id: String,
    trust_profile_id: String,
    generated_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    revision: Revision,
    require_not_before: bool,
    issuer_keys: Vec<IssuerKey>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct IssuerKey {
    issuer: String,
    key_id: Option<String>,
    algorithm: SigningAlgorithm,
    public_jwk: Value,
    credential_authorizations: Vec<Grant>,
}

#[derive(Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(deny_unknown_fields)]
struct Grant {
    format: String,
    vct: String,
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
    credential: &str,
    holder: &str,
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
    let envelope: IssuerGovernanceEnvelope = serde_json::from_str(json)?;
    let snapshot = envelope.issuer;
    envelope.scope.validate_holder(holder, now)?;
    ensure!(
        envelope.contract == "marty.wallet/device-issuer-governance/v2"
            && snapshot.contract == "marty.wallet/issuer-authority/v2"
            && envelope.scope.organization_id == snapshot.organization_id
            && envelope.scope.issuer_trust_profile_id == snapshot.trust_profile_id
            && envelope.observed_at <= now
            && envelope.expires_at > now
            && envelope.expires_at > envelope.observed_at
            && envelope.expires_at <= envelope.observed_at + Duration::seconds(60)
            && envelope.expires_at <= snapshot.expires_at
            && envelope.expires_at <= envelope.scope.credential_expires_at,
        "issuer device scope is invalid"
    );
    ensure!(
        snapshot.revision.id == snapshot.trust_profile_id
            && snapshot.revision.version > 0
            && snapshot
                .revision
                .content_digest
                .strip_prefix("sha256:")
                .is_some_and(|hex| hex.len() == 64
                    && hex
                        .bytes()
                        .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))),
        "issuer revision is invalid"
    );
    anyhow::ensure!(
        !snapshot.organization_id.is_empty()
            && uuid::Uuid::parse_str(&snapshot.trust_profile_id).is_ok(),
        "issuer trust scope is invalid"
    );
    anyhow::ensure!(
        snapshot.generated_at <= now
            && snapshot.expires_at > now
            && snapshot.expires_at > snapshot.generated_at
            && snapshot.expires_at <= snapshot.generated_at + Duration::minutes(1),
        "issuer trust snapshot is stale or invalid"
    );
    anyhow::ensure!(
        !snapshot.issuer_keys.is_empty() && snapshot.issuer_keys.len() <= 256,
        "issuer trust key count is invalid"
    );
    // The unverified VCT is only a resolver selector. No claim may be shown,
    // stored or signed until Core verifies this identical immutable credential.
    ensure!(
        !credential.is_empty() && credential.len() <= 1024 * 1024,
        "credential is invalid"
    );
    let jwt = credential
        .split('~')
        .next()
        .context("issuer JWT is absent")?;
    let segments: Vec<_> = jwt.split('.').collect();
    ensure!(segments.len() == 3, "issuer JWT is invalid");
    let payload_bytes = URL_SAFE_NO_PAD.decode(segments[1])?;
    let payload = marty_crypto::strict_json::parse_unique_json(&payload_bytes)?;
    let vct = payload
        .get("vct")
        .and_then(Value::as_str)
        .context("credential type is absent")?;
    ensure!(
        vct.len() <= 2048 && url::Url::parse(vct).is_ok(),
        "credential type is invalid"
    );
    ensure!(
        payload
            .get("exp")
            .is_some_and(|v| v.as_i64().is_some_and(|exp| exp > now.timestamp())),
        "credential expiry is absent or invalid"
    );
    if snapshot.require_not_before {
        ensure!(
            payload.get("nbf").is_some_and(|v| v.as_i64().is_some()),
            "credential not-before is required"
        );
    }
    if let Some(nbf) = payload.get("nbf") {
        ensure!(
            nbf.as_i64().is_some_and(|value| value <= now.timestamp()),
            "credential is not yet valid"
        );
    }
    let mut identities = std::collections::BTreeSet::new();
    let mut keys = Vec::new();
    for key in snapshot.issuer_keys.into_iter() {
        anyhow::ensure!(key.public_jwk.is_object(), "issuer key JWK is invalid");
        ensure!(
            matches!(
                key.algorithm,
                SigningAlgorithm::ES256 | SigningAlgorithm::EdDSA
            ),
            "issuer key algorithm is unsupported"
        );
        TrustedSdJwtIssuerKeys::new(vec![ResolvedSdJwtIssuerKey::new(
            key.issuer.clone(),
            key.key_id.clone(),
            key.algorithm,
            serde_json::to_string(&key.public_jwk)?,
        )])?;
        ensure!(
            !key.issuer.is_empty()
                && key.issuer.len() <= 2048
                && key
                    .key_id
                    .as_deref()
                    .is_none_or(|id| !id.is_empty() && id.len() <= 2048)
                && key
                    .public_jwk
                    .get("kid")
                    .is_none_or(|id| id.as_str() == key.key_id.as_deref()),
            "issuer key identity is invalid"
        );
        ensure!(
            identities.insert((
                key.issuer.clone(),
                key.key_id.clone(),
                format!("{:?}", key.algorithm)
            )),
            "issuer key identity is ambiguous"
        );
        ensure!(
            !key.credential_authorizations.is_empty() && key.credential_authorizations.len() <= 128,
            "issuer credential grants are invalid"
        );
        let mut grants = std::collections::BTreeSet::new();
        for grant in key.credential_authorizations {
            ensure!(
                grant.format == "SD_JWT_VC"
                    && !grant.vct.is_empty()
                    && grant.vct.len() <= 2048
                    && url::Url::parse(&grant.vct).is_ok()
                    && grants.insert(grant),
                "issuer credential grants are invalid"
            );
        }
        if !grants.iter().any(|grant| grant.vct == vct) {
            continue;
        }
        let jwk = serde_json::to_string(&key.public_jwk)?;
        keys.push(ResolvedSdJwtIssuerKey::new(
            key.issuer,
            key.key_id,
            key.algorithm,
            jwk,
        ));
    }
    ensure!(!keys.is_empty(), "credential type is not authorized");
    Ok(FreshIssuerTrust {
        resolver: TrustedSdJwtIssuerKeys::new(keys)?,
        expires_at: snapshot.expires_at.min(envelope.expires_at),
        scope: envelope.scope,
        revision: snapshot.revision,
    })
}

#[cfg(test)]
pub(crate) fn fixture_envelope(mut projection: Value, mut holder: Value, vct: &str) -> Value {
    use serde_json::json;
    holder.as_object_mut().unwrap().remove("kid");
    let now: DateTime<Utc> = serde_json::from_value(projection["generated_at"].clone()).unwrap();
    let profile = projection["trust_profile_id"].clone();
    let organization = projection["organization_id"].clone();
    projection["contract"] = json!("marty.wallet/issuer-authority/v2");
    projection["revision"] =
        json!({"id":profile,"version":1,"content_digest":format!("sha256:{}","a".repeat(64))});
    projection["require_not_before"] = json!(true);
    for key in projection["issuer_keys"].as_array_mut().unwrap() {
        key["credential_authorizations"] = json!([{"format":"SD_JWT_VC","vct":vct}]);
    }
    let binding =
        json!({"kty":"OKP","crv":"Ed25519","x":"11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo"});
    let key = |id: &str, jwk: Value, algorithm: &str| {
        json!({"key_id":id,"algorithm":algorithm,"version":1,
        "jwk_thumbprint":super::verifier_governance::thumbprint(&jwk).unwrap(),"public_jwk":jwk})
    };
    json!({"contract":"marty.wallet/device-issuer-governance/v2","observed_at":now,"expires_at":projection["expires_at"],
        "scope":{"credential_id":"21111111-2222-4333-8444-555555555555","registration_id":"31111111-2222-4333-8444-555555555555",
            "pairing_id":"41111111-2222-4333-8444-555555555555","device_id":"fixture-device","user_id":"fixture-user",
            "organization_id":organization,"issuer_trust_profile_id":profile,"verifier_trust_profile_id":null,
            "credential_expires_at":now+Duration::hours(1),
            "holder_binding_key":key("51111111-2222-4333-8444-555555555555",binding,"EdDSA"),
            "presentation_signing_key":key("61111111-2222-4333-8444-555555555555",holder,"ES256")},"issuer":projection})
}

#[cfg(test)]
mod tests {
    use super::*;
    use marty_oid4vci::SdJwtIssuerKeyResolver;
    use serde_json::json;

    fn snapshot(now: DateTime<Utc>) -> Value {
        let projection = json!({
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
        });
        let vector: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        fixture_envelope(
            projection,
            vector["holder_public_jwk"].clone(),
            "urn:elevenid:credential:verified-wallet",
        )
    }
    fn resolve(raw: &str, now: DateTime<Utc>) -> anyhow::Result<FreshIssuerTrust> {
        let vector: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        resolver_from_snapshot(
            raw,
            vector["credential"].as_str().unwrap(),
            &vector["holder_public_jwk"].to_string(),
            now,
        )
    }

    #[test]
    fn fresh_public_snapshot_resolves_only_the_exact_issuer_identity() {
        let now = Utc::now();
        let trusted = resolve(&snapshot(now).to_string(), now).unwrap();
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
        assert!(resolve(&value.to_string(), now).is_err());

        value = snapshot(now);
        value["issuer"]["issuer_keys"][0]["public_jwk"]["d"] = json!("private");
        assert!(resolve(&value.to_string(), now).is_err());

        value = snapshot(now);
        let key = value["issuer"]["issuer_keys"][0].clone();
        value["issuer"]["issuer_keys"]
            .as_array_mut()
            .unwrap()
            .push(key);
        assert!(resolve(&value.to_string(), now).is_err());
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
            assert!(resolve(&ambiguous, now).is_err());
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
            value["issuer"]["issuer_keys"][0]["public_jwk"]["extension"] =
                json!({"nested":[{name:"sensitive-test-sentinel"}]});
            let error = resolve(&value.to_string(), now).err().unwrap();
            assert!(error.to_string().contains("private key material"));
            assert!(!error.to_string().contains("sensitive-test-sentinel"));
        }
    }

    #[test]
    fn canonical_policy_scope_and_grants_have_no_legacy_fallback() {
        let now = Utc::now();
        let original = snapshot(now);
        for (pointer, value) in [
            ("/contract", json!("legacy")),
            ("/issuer/contract", json!("legacy")),
            ("/issuer/revision/version", json!(0)),
            ("/issuer/revision/content_digest", json!("unbound")),
            (
                "/issuer/revision/id",
                json!(uuid::Uuid::new_v4().to_string()),
            ),
            ("/issuer/organization_id", json!("other")),
            ("/scope/credential_expires_at", json!(now)),
            ("/scope/presentation_signing_key/version", json!(0)),
            (
                "/scope/presentation_signing_key/jwk_thumbprint",
                json!("wrong"),
            ),
            ("/issuer/issuer_keys/0/credential_authorizations", json!([])),
            (
                "/issuer/issuer_keys/0/credential_authorizations/0/vct",
                json!("urn:other:credential"),
            ),
            (
                "/issuer/issuer_keys/0/credential_authorizations/0/format",
                json!("MDOC"),
            ),
        ] {
            let mut changed = original.clone();
            *changed.pointer_mut(pointer).unwrap() = value;
            assert!(resolve(&changed.to_string(), now).is_err(), "{pointer}");
        }
        assert!(resolve(&original["issuer"].to_string(), now).is_err());
        let mut missing = original.clone();
        missing["issuer"]
            .as_object_mut()
            .unwrap()
            .remove("require_not_before");
        assert!(resolve(&missing.to_string(), now).is_err());
    }

    #[test]
    fn one_key_cannot_borrow_another_keys_credential_grant() {
        let now = Utc::now();
        let mut value = snapshot(now);
        let mut allowed = value["issuer"]["issuer_keys"][0].clone();
        allowed["key_id"] = json!("other-key");
        allowed["public_jwk"]["kid"] = json!("other-key");
        value["issuer"]["issuer_keys"][0]["credential_authorizations"][0]["vct"] =
            json!("urn:other:credential");
        value["issuer"]["issuer_keys"]
            .as_array_mut()
            .unwrap()
            .push(allowed);
        let trusted = resolve(&value.to_string(), now).unwrap();
        assert!(trusted
            .resolver
            .resolve(
                "did:web:issuer.example",
                Some("issuer-key-1"),
                SigningAlgorithm::ES256
            )
            .is_err());
        assert!(trusted
            .resolver
            .resolve(
                "did:web:issuer.example",
                Some("other-key"),
                SigningAlgorithm::ES256
            )
            .is_ok());
    }

    #[test]
    fn exact_signed_time_members_must_satisfy_owner_controls_before_verification() {
        let now = Utc::now();
        let raw = snapshot(now).to_string();
        let vector: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        let credential = vector["credential"].as_str().unwrap();
        let holder = vector["holder_public_jwk"].to_string();
        let pieces: Vec<_> = credential.split('~').next().unwrap().split('.').collect();
        let original = marty_crypto::strict_json::parse_unique_json(
            &URL_SAFE_NO_PAD.decode(pieces[1]).unwrap(),
        )
        .unwrap();
        for (name, value) in [
            ("nbf", Value::Null),
            ("nbf", json!("not-a-time")),
            ("nbf", json!(now.timestamp() + 60)),
            ("exp", Value::Null),
            ("exp", json!(now.timestamp())),
        ] {
            let mut payload = original.clone();
            if value.is_null() {
                payload.as_object_mut().unwrap().remove(name);
            } else {
                payload[name] = value;
            }
            let changed = format!(
                "{}.{}.{}~",
                pieces[0],
                URL_SAFE_NO_PAD.encode(serde_json::to_vec(&payload).unwrap()),
                pieces[2]
            );
            assert!(
                resolver_from_snapshot(&raw, &changed, &holder, now).is_err(),
                "{name}"
            );
        }
    }
}
