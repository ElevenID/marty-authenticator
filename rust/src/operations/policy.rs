//! Policy operations.

use super::credentials::get_credential_claims;
use crate::api::{IssuerCheckResultOutput, PolicyEvaluationResult, RankableCredentialInput};
use crate::credential::Credential;

pub(crate) async fn sync_policies(
    license_jwt: String,
    endpoint: String,
) -> anyhow::Result<Vec<marty_verification::policy::PresentationPolicy>> {
    use marty_sync::PolicySyncProvider;

    let provider = PolicySyncProvider::new(endpoint, license_jwt);
    provider
        .fetch_all()
        .await
        .map_err(|e| anyhow::anyhow!("Policy sync failed: {}", e))
}

pub(crate) fn evaluate_presentation_request(
    request_json: String,
    policies_json: Vec<String>,
    _credentials: Vec<Credential>,
) -> anyhow::Result<PolicyEvaluationResult> {
    use marty_verification::policy::{PolicyEvaluationInput, PolicyEvaluator, PresentationPolicy};

    // Parse policies
    let policies: Vec<PresentationPolicy> = policies_json
        .iter()
        .map(|json| serde_json::from_str(json))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| anyhow::anyhow!("Failed to parse policies: {}", e))?;

    // For now, use first policy (TODO: match by verifier ID)
    let policy = policies
        .first()
        .ok_or_else(|| anyhow::anyhow!("No policies provided"))?;

    // Security-sensitive facts must come from the protocol verifier. This
    // adapter does not infer trust, holder binding, freshness, or revocation
    // from display-oriented wallet credential models.
    let input: PolicyEvaluationInput = serde_json::from_str(&request_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse verified policy facts: {}", e))?;
    let evaluation = PolicyEvaluator::new(policy.clone()).evaluate(&input);

    Ok(PolicyEvaluationResult {
        is_satisfied: evaluation.is_satisfied,
        minimum_disclosure_claims: evaluation.minimum_disclosure_set,
        missing_required_claims: evaluation.missing_claims,
        policy_id: policy.id.clone(),
    })
}

pub(crate) fn evaluate_service_presentation_policy(request_json: String) -> anyhow::Result<String> {
    use marty_verification::policy::{evaluate_service_policy, ServicePolicyEvaluationRequest};

    const MAX_REQUEST_BYTES: usize = 1_000_000;
    if request_json.len() > MAX_REQUEST_BYTES {
        return Err(anyhow::anyhow!(
            "Service presentation policy request exceeds {MAX_REQUEST_BYTES} bytes"
        ));
    }

    let request: ServicePolicyEvaluationRequest = serde_json::from_str(&request_json)
        .map_err(|e| anyhow::anyhow!("Invalid service presentation policy request: {e}"))?;
    let result = evaluate_service_policy(request)
        .map_err(|e| anyhow::anyhow!("Service presentation policy evaluation failed: {e}"))?;
    serde_json::to_string(&result)
        .map_err(|e| anyhow::anyhow!("Failed to serialize policy result: {e}"))
}

pub(crate) fn get_minimum_disclosure_set(
    policy_json: String,
    credential: Credential,
) -> anyhow::Result<Vec<String>> {
    use marty_verification::policy::{MinimumDisclosureResolver, PresentationPolicy};

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let available_claims = get_credential_claims(&credential);
    let resolver = MinimumDisclosureResolver::new(&policy);
    let disclosure = resolver.resolve(&available_claims);

    Ok(disclosure.claims)
}

pub(crate) fn rank_matching_credentials(
    policy_json: String,
    credentials: Vec<RankableCredentialInput>,
) -> anyhow::Result<Vec<String>> {
    use marty_verification::policy::ranking::RankableCredential;
    use marty_verification::policy::{CredentialRanker, PresentationPolicy};
    use std::time::{SystemTime, UNIX_EPOCH};

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let ranker = CredentialRanker::new(&policy);

    let mut rankable: Vec<RankableCredential> = credentials
        .into_iter()
        .map(|c| {
            let issued_at_epoch_seconds = u64::try_from(c.issued_at_unix)
                .map_err(|_| anyhow::anyhow!("Credential issuance time cannot be negative"))?;
            Ok(RankableCredential {
                credential_id: c.credential_id,
                issuer_id: c.issuer_id,
                issued_at_epoch_seconds,
                trust_level: c.trust_level,
                claim_count: c.claim_count,
            })
        })
        .collect::<anyhow::Result<_>>()?;

    let evaluation_time_epoch_seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| anyhow::anyhow!("System clock is before the Unix epoch"))?
        .as_secs();
    ranker.rank(&mut rankable, evaluation_time_epoch_seconds);

    Ok(rankable.into_iter().map(|r| r.credential_id).collect())
}

pub(crate) fn check_issuer_constraints(
    policy_json: String,
    issuer_id: String,
    trust_profile_verified: bool,
) -> anyhow::Result<IssuerCheckResultOutput> {
    use marty_verification::policy::{IssuerConstraintChecker, PresentationPolicy};

    let policy: PresentationPolicy = serde_json::from_str(&policy_json)
        .map_err(|e| anyhow::anyhow!("Failed to parse policy: {}", e))?;

    let checker =
        IssuerConstraintChecker::new(policy.trust_profile_id.as_ref(), &policy.allowed_issuers);

    let result = checker.check_issuer(&issuer_id, trust_profile_verified);

    Ok(IssuerCheckResultOutput {
        is_trusted: result.is_trusted(),
        violation_message: result.violation_message().map(String::from),
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn synced_policy_values_reach_the_bridge_without_remapping() {
        use std::io::{Read, Write};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        listener.set_nonblocking(true).unwrap();
        let endpoint = format!("http://{}", listener.local_addr().unwrap());
        let body = serde_json::json!([{
            "id":"fixture", "name":"Policy", "description":null, "purpose":"test",
            "accepted_credential_types":["example"], "required_claims":[], "holder_binding":"none",
            "trust_profile_id":null, "allowed_issuers":[],
            "freshness_requirements":{"max_credential_age_seconds":null,"max_proof_age_seconds":300,"require_live_revocation_check":false},
            "prefer_predicates":true,"single_presentation":false,"derived_attribute_preferences":{},
            "credential_ranking_strategy":"freshest_first","credential_ranking_weights":{},
            "metadata":{"nested":[1,true,"value"]},"version":7
        }]).to_string();
        let server = std::thread::spawn(move || {
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(5);
            let mut stream = loop {
                match listener.accept() {
                    Ok((stream, _)) => break stream,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(std::time::Instant::now() < deadline, "no local request");
                        std::thread::sleep(std::time::Duration::from_millis(5));
                    }
                    Err(error) => panic!("accept: {error}"),
                }
            };
            stream
                .set_read_timeout(Some(std::time::Duration::from_secs(5)))
                .unwrap();
            let mut request = Vec::new();
            while !request.ends_with(b"\r\n\r\n") {
                let mut byte = [0];
                stream.read_exact(&mut byte).unwrap();
                request.push(byte[0]);
                assert!(request.len() < 8192);
            }
            write!(stream, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body).unwrap();
            String::from_utf8(request).unwrap()
        });
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        let policies = runtime.block_on(async {
            tokio::time::timeout(
                std::time::Duration::from_secs(5),
                super::sync_policies("fixture-token".into(), endpoint),
            )
            .await
            .unwrap()
            .unwrap()
        });
        assert_eq!(policies.len(), 1);
        assert_eq!(policies[0].id, "fixture");
        assert_eq!(policies[0].version, 7);
        assert_eq!(
            policies[0].metadata["nested"],
            serde_json::json!([1, true, "value"])
        );
        let request = server.join().unwrap();
        assert!(request.starts_with("GET /api/v1/identity/presentation-policies/sync "));
        assert!(request
            .to_ascii_lowercase()
            .contains("authorization: bearer fixture-token"));
    }

    #[test]
    fn synced_policies_use_the_bridge_core_type_directly() {
        fn same_type<
            F: std::future::Future<
                Output = Result<
                    Vec<marty_verification::policy::PresentationPolicy>,
                    marty_sync::SyncError,
                >,
            >,
        >(
            _: F,
        ) {
        }
        let provider = marty_sync::PolicySyncProvider::new("invalid URL".into(), String::new());
        same_type(provider.fetch_all());
    }

    #[test]
    fn sync_errors_retain_bridge_context() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        let error = runtime
            .block_on(super::sync_policies(String::new(), "invalid URL".into()))
            .unwrap_err();
        assert!(error.to_string().starts_with("Policy sync failed:"));
    }
}
