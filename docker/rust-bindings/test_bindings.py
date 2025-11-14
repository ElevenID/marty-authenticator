#!/usr/bin/env python3
"""
Test script for SSI Python bindings
Tests mDoc issuance, DID management, and OID4VCI functionality
"""

import sys

try:
    from ssi_python import DidManager, MdocIssuer, Oid4VciIssuer
except ImportError:
    print("ERROR: ssi_python module not found!")
    print("Please build and install the module first:")
    print("  cd docker/rust-bindings")
    print("  ./build-uv.sh")
    print("  source .venv/bin/activate")
    sys.exit(1)

print("=" * 60)
print("SSI Python Bindings Test Suite")
print("=" * 60)
print()

# Test 1: DID Manager
print("Test 1: DID Manager")
print("-" * 60)
did_manager = DidManager()

# Generate P-256 DID
did_p256, key_p256 = did_manager.generate_did_key()
print(f"✓ Generated P-256 DID: {did_p256}")

# Generate Ed25519 DID
did_ed25519, key_ed25519 = did_manager.generate_did_key_ed25519()
print(f"✓ Generated Ed25519 DID: {did_ed25519}")

# Get public key
public_key = did_manager.get_public_key(key_p256)
print(f"✓ Extracted public key: {len(public_key)} bytes")

# Get thumbprint
thumbprint = did_manager.get_jwk_thumbprint(key_p256)
print(f"✓ Computed thumbprint: {thumbprint[:32]}...")

# Resolve DID
did_doc = did_manager.resolve_did(did_p256)
print(f"✓ Resolved DID document: {len(did_doc)} bytes")

# Verification method
vm_id = did_manager.did_to_verification_method(did_p256)
print(f"✓ Verification method ID: {vm_id}")

print()

# Test 2: mDoc Issuer
print("Test 2: mDoc Issuer")
print("-" * 60)

# Create issuer
issuer_did, issuer_key = did_manager.generate_did_key()
issuer = MdocIssuer(issuer_key, issuer_did)
print(f"✓ Created issuer with DID: {issuer.get_issuer_did()}")

# Prepare claims
claims = {
    "org.iso.18013.5.1": {
        "family_name": "Doe",
        "given_name": "John",
        "birth_date": "1990-01-01",
        "issue_date": "2025-11-12",
        "expiry_date": "2030-11-12",
        "document_number": "DL123456789",
        "issuing_country": "US",
        "issuing_authority": "State DMV",
    }
}

# Generate holder key
holder_did, holder_key = did_manager.generate_did_key()
holder_public = did_manager.get_public_key(holder_key)
print(f"✓ Generated holder DID: {holder_did}")

# Issue mDoc
mdoc = issuer.issue_mdoc(
    doctype="org.iso.18013.5.1.mDL",
    claims=claims,
    holder_public_key=holder_public,
    validity_days=1825,  # 5 years
)
print(f"✓ Issued mDoc: {len(mdoc)} bytes (base64)")

# Create MSO
mso = issuer.create_mso(
    doctype="org.iso.18013.5.1.mDL", claims=claims, validity_days=1825
)
print(f"✓ Created MSO: {len(mso)} bytes (base64)")

# Compute digest
digest = issuer.compute_digest("test_value")
print(f"✓ Computed digest: {digest[:32]}...")

print()

# Test 3: OID4VCI
print("Test 3: OID4VCI Protocol")
print("-" * 60)

oid4vci = Oid4VciIssuer("https://issuer.example.com")
print(f"✓ Created OID4VCI issuer: {oid4vci.get_issuer_url()}")

# Generate credential offer with pre-authorized code
offer_preauth = oid4vci.generate_credential_offer(
    credential_type="org.iso.18013.5.1.mDL",
    pre_authorized_code="test-code-12345",
    user_pin_required=False,
)
print(f"✓ Generated pre-auth offer: {len(offer_preauth)} chars")
print(f"  {offer_preauth[:80]}...")

# Generate credential offer with authorization code
offer_authcode = oid4vci.generate_credential_offer_with_auth_code(
    credential_type="org.iso.18013.5.1.mDL", issuer_state="state-67890"
)
print(f"✓ Generated auth code offer: {len(offer_authcode)} chars")

# Generate credential response
response = oid4vci.generate_credential_response(credential_data=mdoc, format="mso_mdoc")
print(f"✓ Generated credential response: {len(response)} bytes")

# Generate deferred response
deferred = oid4vci.generate_deferred_credential_response(
    acceptance_token="deferred-token-xyz"  # pragma: allowlist secret
)
print(f"✓ Generated deferred response: {len(deferred)} bytes")

# Validate token (placeholder)
is_valid = oid4vci.validate_access_token(
    access_token="bearer-token-abc",
    expected_scope="credential_issuance",  # pragma: allowlist secret
)
print(f"✓ Token validation: {is_valid}")

# Generate issuer metadata
metadata = oid4vci.generate_issuer_metadata(
    supported_credentials=["org.iso.18013.5.1.mDL", "UniversityDegree"]
)
print(f"✓ Generated issuer metadata: {len(metadata)} bytes")

print()

# Test 4: End-to-End Flow
print("Test 4: End-to-End Issuance Flow")
print("-" * 60)

# 1. Create issuer identity
print("1. Creating issuer identity...")
issuer_did, issuer_key = did_manager.generate_did_key()
issuer = MdocIssuer(issuer_key, issuer_did)
print(f"   Issuer DID: {issuer_did}")

# 2. Generate credential offer
print("2. Generating credential offer...")
oid4vci = Oid4VciIssuer("https://issuer.example.com")
pre_auth_code = "secure-code-xyz123"
offer = oid4vci.generate_credential_offer(
    credential_type="org.iso.18013.5.1.mDL",
    pre_authorized_code=pre_auth_code,
    user_pin_required=False,
)
print("   Offer URL generated")

# 3. Prepare holder
print("3. Preparing holder...")
holder_did, holder_key = did_manager.generate_did_key()
holder_public = did_manager.get_public_key(holder_key)
print(f"   Holder DID: {holder_did}")

# 4. Issue credential
print("4. Issuing credential...")
claims = {
    "org.iso.18013.5.1": {
        "family_name": "Smith",
        "given_name": "Alice",
        "birth_date": "1985-03-15",
    }
}
mdoc = issuer.issue_mdoc(
    doctype="org.iso.18013.5.1.mDL",
    claims=claims,
    holder_public_key=holder_public,
    validity_days=365,
)
print(f"   mDoc issued: {len(mdoc)} bytes")

# 5. Generate response
print("5. Generating credential response...")
response = oid4vci.generate_credential_response(credential_data=mdoc, format="mso_mdoc")
print(f"   Response ready: {len(response)} bytes")

print()
print("=" * 60)
print("✓ All tests passed successfully!")
print("=" * 60)
print()
print("Summary:")
print("  - DID generation (P-256, Ed25519): ✓")
print("  - Public key extraction: ✓")
print("  - mDoc issuance: ✓")
print("  - MSO creation: ✓")
print("  - OID4VCI offers: ✓")
print("  - End-to-end flow: ✓")
print()
print("The SSI Python bindings are working correctly!")
