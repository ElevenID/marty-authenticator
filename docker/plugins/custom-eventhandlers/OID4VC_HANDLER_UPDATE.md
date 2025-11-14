# OID4VC Handler Update

## Overview

Updated the PrivacyIDEA OID4VC event handler to use the new SSI Python bindings for full OpenID for Verifiable Credential Issuance (OID4VCI) protocol support with mDoc credentials.

## Changes Made

### 1. **Added SSI Python Bindings Integration**

```python
try:
    from ssi_python import MdocIssuer, DidManager, Oid4VciIssuer
    SSI_AVAILABLE = True
except ImportError:
    SSI_AVAILABLE = False
```

- Graceful fallback if bindings not installed
- Enables advanced mDoc and DID functionality

### 2. **Enhanced Handler Initialization**

```python
def __init__(self):
    super(OID4VCEventHandler, self).__init__()
    self.did_manager = None
    self.mdoc_issuer = None
    self.oid4vci_issuer = None

    if SSI_AVAILABLE:
        self.did_manager = DidManager()
```

- Initializes SSI components on startup
- Maintains state for DID and mDoc issuers

### 3. **New Actions**

Added new event handler actions:

- `issue_mdoc` - Generic mDoc credential issuance
- `issue_mdoc_driver_license` - mDL (mobile driver's license)
- `issue_mdoc_identity` - mDoc identity credentials
- `generate_issuer_did` - Generate DID for issuer

### 4. **Refactored Action Dispatcher**

```python
def do(self, action, options=None):
    action_map = {
        "issue_credential": self._issue_credential,
        "issue_mdoc": self._issue_mdoc_credential,
        "issue_mdoc_driver_license": self._issue_mdoc_driver_license,
        ...
    }
    return action_map.get(action, lambda x: False)(options)
```

- Cleaner action routing
- Easier to extend with new actions

### 5. **New mDoc Issuance Methods**

#### `_generate_issuer_did(options)`

Generates a new DID for the credential issuer using SSI bindings.

**Supports:**

- P-256 (default)
- Ed25519 key types

#### `_initialize_mdoc_issuer(handler_def)`

Initializes an `MdocIssuer` instance with DID and keys.

**Features:**

- Auto-generates DID if not configured
- Returns ready-to-use issuer instance

#### `_issue_mdoc_credential(options)`

Issues ISO 18013-5 compliant mDoc credentials.

**Workflow:**

1. Initialize mDoc issuer with DID
2. Initialize OID4VCI issuer
3. Extract user information
4. Build mDoc claims
5. Generate holder key pair
6. Issue mDoc credential
7. Create OID4VCI credential offer
8. Generate credential response
9. Deliver offer to wallet

#### `_issue_mdoc_driver_license(options)`

Convenience method for issuing mobile driver's licenses (mDL).

**Document Type:** `org.iso.18013.5.1.mDL`

#### `_issue_mdoc_identity(options)`

Convenience method for issuing identity credentials.

**Document Type:** `org.iso.18013.5.1.identity`

#### `_build_mdoc_claims(user_info, mdoc_config)`

Constructs mDoc claims from user info and configuration.

**Claims Include:**

- Issue date
- Expiry date
- Issuing authority
- Authenticated user
- Authentication time & method
- Custom user claims from config

### 6. **Enhanced Credential Offer Generation**

Updated `_send_credential_offer()` to support both:

- Standard verifiable credentials
- mDoc credentials using SSI bindings

**Configuration:**

```python
{
    "offer_type": "mdoc",  # or "standard"
    "credential_type": "org.iso.18013.5.1.mDL",
    "issuer_url": "https://issuer.example.com"
}
```

## Configuration Examples

### Basic mDoc Issuance

```python
handler_def = {
    "options": {
        "issuer_url": "https://issuer.example.com",
        "issuer_did": "did:key:z6Mkh...",
        "issuer_key": '{"kty":"EC","crv":"P-256",...}',
        "mdoc_config": {
            "doctype": "org.iso.18013.5.1.mDL",
            "validity_days": 365,
            "namespace": "org.iso.18013.5.1",
            "issuing_authority": "State DMV",
            "user_claims": {
                "family_name": "Doe",
                "given_name": "John",
                "birth_date": "1990-01-01"
            }
        }
    }
}
```

### Credential Offer with mDoc

```python
handler_def = {
    "options": {
        "offer_type": "mdoc",
        "credential_type": "org.iso.18013.5.1.mDL",
        "issuer_url": "https://issuer.example.com",
        "delivery_method": "webhook",
        "webhook_url": "https://wallet.example.com/offers"
    }
}
```

### Generate Issuer DID

```python
handler_def = {
    "options": {
        "key_type": "p256"  # or "ed25519"
    }
}
```

## OID4VCI Protocol Support

The handler now fully implements:

1. **Pre-Authorized Code Flow**
   - Generates pre-authorized code
   - Creates credential offer URL
   - No user authentication required

2. **Authorization Code Flow**
   - Generates issuer state
   - Creates authorization-based offer
   - Requires user authentication

3. **Credential Response**
   - Returns mDoc in `mso_mdoc` format
   - Includes base64-encoded CBOR
   - Compatible with OID4VCI spec

## Integration with SSI Python Bindings

### DID Management

```python
did_manager = DidManager()
issuer_did, issuer_key = did_manager.generate_did_key()
holder_public = did_manager.get_public_key(holder_key)
```

### mDoc Issuance

```python
mdoc_issuer = MdocIssuer(issuer_key, issuer_did)
mdoc = mdoc_issuer.issue_mdoc(
    doctype="org.iso.18013.5.1.mDL",
    claims=claims,
    holder_public_key=holder_public,
    validity_days=365
)
```

### OID4VCI Protocol

```python
oid4vci = Oid4VciIssuer(issuer_url)
offer_url = oid4vci.generate_credential_offer(
    credential_type=doctype,
    pre_authorized_code=pre_auth_code,
    user_pin_required=False
)
response = oid4vci.generate_credential_response(
    credential_data=mdoc,
    format="mso_mdoc"
)
```

## Benefits

1. **Standards Compliance**
   - ISO 18013-5 mDoc format
   - OID4VCI protocol
   - W3C Verifiable Credentials

2. **Security**
   - DID-based issuer identity
   - Cryptographic signing via Rust
   - Secure key management

3. **Flexibility**
   - Multiple credential types
   - Configurable claims
   - Multiple delivery methods

4. **Performance**
   - Rust-powered cryptography
   - Efficient CBOR encoding
   - Fast DID operations

## Usage in PrivacyIDEA

### Event Configuration

1. Create an event handler in PrivacyIDEA admin UI
2. Select "OID4VC" as handler type
3. Choose action (e.g., "issue_mdoc_driver_license")
4. Configure options (issuer URL, DID, claims, etc.)
5. Set conditions (token type, realm, etc.)
6. Save and enable

### Trigger Events

- Post-authentication: Issue credential after successful login
- Token enrollment: Issue credential during token creation
- Manual trigger: Issue on-demand via API

## Requirements

- SSI Python bindings installed (`ssi-python` package)
- Rust 1.70+ (for building bindings)
- Python 3.8+
- PrivacyIDEA 3.x+

## Testing

Install the bindings:

```bash
cd docker/rust-bindings
./build-uv.sh
source .venv/bin/activate
python test_bindings.py
```

Test the handler:

```bash
# In PrivacyIDEA environment
python -c "from oid4vc_handler import OID4VCEventHandler; h = OID4VCEventHandler(); print('✓ Handler loaded')"
```

## Next Steps

1. ✅ SSI Python bindings integrated
2. ✅ mDoc issuance implemented
3. ✅ OID4VCI protocol support
4. 🔄 Add credential revocation with status lists
5. 🔄 Implement batch issuance workflows
6. 🔄 Add QR code generation for offers
7. 🔄 Support additional mDoc document types

## Compatibility

- **Backward Compatible**: Existing "issue_credential" action still works
- **Optional Dependencies**: Falls back gracefully if SSI bindings not available
- **Standard VCs**: Still supports non-mDoc verifiable credentials

## Documentation

For more details see:

- [SSI Python Bindings README](../../rust-bindings/README.md)
- [OID4VCI Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [ISO 18013-5 mDL](https://www.iso.org/standard/69084.html)
