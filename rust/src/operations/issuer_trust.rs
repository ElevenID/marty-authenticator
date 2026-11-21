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
    issuance_authorizations: Vec<IssuanceAuthorization>,
}

#[derive(Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(deny_unknown_fields)]
struct Grant {
    format: String,
    vct: String,
}

/// Exact metadata-selected issuance inputs. These stay native with the receipt.
#[derive(Clone, PartialEq, Eq)]
pub(crate) struct IssuanceSelection {
    pub credential_issuer: String,
    pub credential_configuration_id: String,
    pub format: String,
    pub vct: String,
    pub authorization_server: String,
    pub token_endpoint: String,
}

#[derive(Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(deny_unknown_fields)]
struct IssuanceAuthorization {
    credential_issuer: String,
    credential_configuration_id: String,
    format: String,
    vct: String,
    authorization_server: Option<String>,
    token_endpoint: Option<String>,
}

fn bounded_text(value: &str, max: usize) -> bool {
    !value.is_empty()
        && value.len() <= max
        && value.trim() == value
        && !value.chars().any(char::is_control)
}
fn exact_https(value: &str, query: bool) -> bool {
    bounded_text(value, 2048)
        && !value.contains('*')
        && url::Url::parse(value).is_ok_and(|u| {
            u.scheme() == "https"
                && u.host_str().is_some()
                && u.username().is_empty()
                && u.password().is_none()
                && u.fragment().is_none()
                && (query || u.query().is_none())
        })
}
impl IssuanceAuthorization {
    fn validate(&self) -> anyhow::Result<()> {
        ensure!(
            exact_https(&self.credential_issuer, false)
                && bounded_text(&self.credential_configuration_id, 256)
                && matches!(self.format.as_str(), "dc+sd-jwt" | "vc+sd-jwt")
                && bounded_text(&self.vct, 2048)
                && url::Url::parse(&self.vct).is_ok()
                && match (&self.authorization_server, &self.token_endpoint) {
                    (None, None) => true,
                    (Some(server), Some(endpoint)) =>
                        exact_https(server, false) && exact_https(endpoint, true),
                    _ => false,
                },
            "issuer issuance grant is invalid"
        );
        Ok(())
    }
    fn permits(&self, selection: &IssuanceSelection) -> bool {
        self.credential_issuer == selection.credential_issuer
            && self.credential_configuration_id == selection.credential_configuration_id
            && self.format == selection.format
            && self.vct == selection.vct
            && match (&self.authorization_server, &self.token_endpoint) {
                (Some(server), Some(endpoint)) => {
                    server == &selection.authorization_server
                        && endpoint == &selection.token_endpoint
                }
                (None, None) => {
                    selection.authorization_server == self.credential_issuer
                        && exact_https(&selection.token_endpoint, true)
                        && url::Url::parse(&selection.token_endpoint)
                            .ok()
                            .map(|u| u.origin())
                            == url::Url::parse(&self.credential_issuer)
                                .ok()
                                .map(|u| u.origin())
                }
                _ => false,
            }
    }
}

pub(crate) struct IssuanceAdmission {
    scope: super::verifier_governance::DeviceScope,
    revision: Revision,
    issuers: std::collections::BTreeSet<String>,
    pub expires_at: DateTime<Utc>,
}

pub(crate) fn preflight_issuance(json: &str, holder: &str) -> anyhow::Result<()> {
    parse_authority(json, holder, Utc::now())?;
    Ok(())
}

pub(crate) fn admit_issuance(
    json: &str,
    holder: &str,
    selection: &IssuanceSelection,
    now: DateTime<Utc>,
) -> anyhow::Result<IssuanceAdmission> {
    ensure!(
        exact_https(&selection.authorization_server, false)
            && exact_https(&selection.token_endpoint, true),
        "issuance endpoints are invalid"
    );
    let envelope = parse_authority(json, holder, now)?;
    let issuers: std::collections::BTreeSet<_> = envelope
        .issuer
        .issuer_keys
        .iter()
        .filter(|key| {
            key.issuance_authorizations
                .iter()
                .any(|grant| grant.permits(selection))
        })
        .map(|key| key.issuer.clone())
        .collect();
    ensure!(
        !issuers.is_empty(),
        "issuance service and configuration are not authorized"
    );
    Ok(IssuanceAdmission {
        scope: envelope.scope,
        revision: envelope.issuer.revision,
        issuers,
        expires_at: envelope.expires_at.min(envelope.issuer.expires_at),
    })
}

impl IssuanceAdmission {
    pub fn observed_after(
        &self,
        json: &str,
        holder: &str,
        boundary: DateTime<Utc>,
    ) -> anyhow::Result<()> {
        let envelope = parse_authority(json, holder, Utc::now())?;
        ensure!(
            envelope.observed_at >= boundary,
            "issuer authority predates the receipt transition"
        );
        Ok(())
    }
    pub fn revalidate(
        &self,
        json: &str,
        holder: &str,
        selection: &IssuanceSelection,
        now: DateTime<Utc>,
    ) -> anyhow::Result<()> {
        let fresh = admit_issuance(json, holder, selection, now)?;
        ensure!(
            self.scope == fresh.scope
                && self.revision == fresh.revision
                && self.issuers == fresh.issuers,
            "issuance authority changed; restart issuance"
        );
        Ok(())
    }
    pub fn verify(
        &self,
        json: &str,
        holder: &str,
        selection: &IssuanceSelection,
        credential: &str,
        now: DateTime<Utc>,
    ) -> anyhow::Result<FreshIssuerTrust> {
        self.revalidate(json, holder, selection, now)?;
        resolver_for_selection(json, credential, holder, now, Some(selection))
    }
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

fn parse_authority(
    json: &str,
    holder: &str,
    now: DateTime<Utc>,
) -> anyhow::Result<IssuerGovernanceEnvelope> {
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
    let snapshot = &envelope.issuer;
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
    let mut identities = std::collections::BTreeSet::new();
    for key in &snapshot.issuer_keys {
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
        for grant in &key.credential_authorizations {
            ensure!(
                grant.format == "SD_JWT_VC"
                    && !grant.vct.is_empty()
                    && grant.vct.len() <= 2048
                    && url::Url::parse(&grant.vct).is_ok()
                    && grants.insert(grant),
                "issuer credential grants are invalid"
            );
        }
        ensure!(
            key.issuance_authorizations.len() <= 128,
            "issuer issuance grants are invalid"
        );
        let mut issuance_grants = std::collections::BTreeSet::new();
        for grant in &key.issuance_authorizations {
            grant.validate()?;
            ensure!(
                issuance_grants.insert(grant)
                    && key
                        .credential_authorizations
                        .iter()
                        .any(|g| g.vct == grant.vct),
                "issuer issuance grants are invalid"
            );
        }
    }
    Ok(envelope)
}

pub(crate) fn resolver_from_snapshot(
    json: &str,
    credential: &str,
    holder: &str,
    now: DateTime<Utc>,
) -> anyhow::Result<FreshIssuerTrust> {
    resolver_for_selection(json, credential, holder, now, None)
}

pub(crate) fn resolver_for_selection(
    json: &str,
    credential: &str,
    holder: &str,
    now: DateTime<Utc>,
    selection: Option<&IssuanceSelection>,
) -> anyhow::Result<FreshIssuerTrust> {
    let envelope = parse_authority(json, holder, now)?;
    let snapshot = envelope.issuer;
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
    let mut keys = Vec::new();
    for key in snapshot.issuer_keys {
        if !key
            .credential_authorizations
            .iter()
            .any(|grant| grant.vct == vct)
            || selection.is_some_and(|selection| {
                !key.issuance_authorizations
                    .iter()
                    .any(|g| g.permits(selection))
            })
        {
            continue;
        }
        keys.push(ResolvedSdJwtIssuerKey::new(
            key.issuer,
            key.key_id,
            key.algorithm,
            serde_json::to_string(&key.public_jwk)?,
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
        key["issuance_authorizations"] = json!([]);
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

    fn issuance_selection() -> IssuanceSelection {
        IssuanceSelection {
            credential_issuer: "https://service.example/tenant".into(),
            credential_configuration_id: "identity".into(),
            format: "vc+sd-jwt".into(),
            vct: "urn:elevenid:credential:verified-wallet".into(),
            authorization_server: "https://service.example/tenant".into(),
            token_endpoint: "https://service.example/token".into(),
        }
    }
    fn service_grant() -> Value {
        json!({"credential_issuer":"https://service.example/tenant",
            "credential_configuration_id":"identity","format":"vc+sd-jwt",
            "vct":"urn:elevenid:credential:verified-wallet",
            "authorization_server":null,"token_endpoint":null})
    }
    fn issuance_holder() -> String {
        let fixture: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        fixture["holder_public_jwk"].to_string()
    }

    #[test]
    fn issuance_admission_requires_exact_owner_service_configuration_format_and_type() {
        let now = Utc::now();
        let holder = issuance_holder();
        let mut raw = snapshot(now);
        let selected = issuance_selection();
        assert!(admit_issuance(&raw.to_string(), &holder, &selected, now).is_err());
        raw["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([service_grant()]);
        let admitted = admit_issuance(&raw.to_string(), &holder, &selected, now).unwrap();
        // A service URL is not converted to its credential issuer's DID.
        assert!(admitted.issuers.contains("did:web:issuer.example"));
        for selection in [
            IssuanceSelection {
                credential_issuer: "https://service.example/other".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                credential_configuration_id: "other".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                format: "dc+sd-jwt".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                vct: "urn:example:other".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                authorization_server: "https://delegated.example".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                token_endpoint: "https://delegated.example/token".into(),
                ..selected.clone()
            },
            IssuanceSelection {
                token_endpoint: "http://service.example/token".into(),
                ..selected.clone()
            },
        ] {
            assert!(admit_issuance(&raw.to_string(), &holder, &selection, now).is_err());
        }
        raw["issuer"]["issuer_keys"][0]["issuance_authorizations"][0]["authorization_server"] =
            json!("https://delegated.example");
        raw["issuer"]["issuer_keys"][0]["issuance_authorizations"][0]["token_endpoint"] =
            json!("https://delegated.example/token?realm=approved");
        let delegated = IssuanceSelection {
            authorization_server: "https://delegated.example".into(),
            token_endpoint: "https://delegated.example/token?realm=approved".into(),
            ..selected
        };
        assert!(admit_issuance(&raw.to_string(), &holder, &delegated, now).is_ok());
        let wrong_query = IssuanceSelection {
            token_endpoint: "https://delegated.example/token?realm=other".into(),
            ..delegated
        };
        assert!(admit_issuance(&raw.to_string(), &holder, &wrong_query, now).is_err());
    }

    #[test]
    fn issuance_rechecks_full_scope_revision_and_per_key_grants() {
        let now = Utc::now();
        let holder = issuance_holder();
        let selected = issuance_selection();
        let mut raw = snapshot(now);
        raw["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([service_grant()]);
        let admitted = admit_issuance(&raw.to_string(), &holder, &selected, now).unwrap();
        assert!(admitted
            .revalidate(&raw.to_string(), &holder, &selected, now)
            .is_ok());
        for (pointer, value) in [
            ("/scope/device_id", json!("other-device")),
            ("/issuer/revision/version", json!(2)),
            ("/issuer/issuer_keys/0/issuance_authorizations", json!([])),
            (
                "/issuer/issuer_keys/0/issuer",
                json!("did:web:other.example"),
            ),
        ] {
            let mut changed = raw.clone();
            *changed.pointer_mut(pointer).unwrap() = value;
            assert!(admitted
                .revalidate(&changed.to_string(), &holder, &selected, now)
                .is_err());
        }
        let fixture: Value =
            serde_json::from_str(include_str!("fixtures/remote_sd_jwt_wallet_public.json"))
                .unwrap();
        // Same VCT on a second trusted issuer does not grant this service to it.
        let mut other = raw["issuer"]["issuer_keys"][0].clone();
        other["issuer"] = json!("did:web:other.example");
        raw["issuer"]["issuer_keys"][0]["issuance_authorizations"] = json!([]);
        raw["issuer"]["issuer_keys"]
            .as_array_mut()
            .unwrap()
            .push(other);
        let admitted = admit_issuance(&raw.to_string(), &holder, &selected, now).unwrap();
        let trusted = admitted
            .verify(
                &raw.to_string(),
                &holder,
                &selected,
                fixture["credential"].as_str().unwrap(),
                now,
            )
            .unwrap();
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
                "did:web:other.example",
                Some("issuer-key-1"),
                SigningAlgorithm::ES256
            )
            .is_ok());
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
