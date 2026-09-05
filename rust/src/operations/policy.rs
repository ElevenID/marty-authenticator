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
    let policies = provider
        .fetch_all()
        .await
        .map_err(|e| anyhow::anyhow!("Policy sync failed: {}", e))?;

    // marty-sync is released independently from marty-core. Keep this boundary
    // as serialization-only DTO mapping so the mobile bridge exposes the
    // canonical core type without reproducing policy behavior.
    policies
        .into_iter()
        .map(|policy| {
            let value = serde_json::to_value(policy)
                .map_err(|e| anyhow::anyhow!("Failed to map synced policy: {e}"))?;
            serde_json::from_value(value)
                .map_err(|e| anyhow::anyhow!("Synced policy is incompatible with core: {e}"))
        })
        .collect()
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
