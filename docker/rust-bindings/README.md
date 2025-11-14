# SSI Python Bindings

Rust-based Python bindings for the SpruceID SSI crate, providing mDoc issuance and OID4VCI support.

## Features

- **mDoc Issuance**: Issue ISO 18013-5 mobile document credentials
- **DID Management**: Generate and manage Decentralized Identifiers
- **OID4VCI Protocol**: Implement OpenID for Verifiable Credential Issuance

## Requirements

- Rust 1.70+ (install from [rustup.rs](https://rustup.rs/))
- Python 3.8+
- maturin (Python package for building Rust extensions)

## Installation

### 1. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 2. Build the Extension with UV (Recommended)

UV is a fast Python package manager that creates isolated virtual environments:

```bash
cd docker/rust-bindings
./build-uv.sh
```

For a release build (optimized):

```bash
./build-uv.sh --release
```

### 3. Activate the Virtual Environment

```bash
source .venv/bin/activate
```

### 4. Verify Installation

```bash
python -c "import ssi_python; print('Success!')"
```

### 5. Run Tests

```bash
python test_bindings.py
```

### Alternative: Build with pip (Not Recommended)

If you prefer not to use UV:

```bash
cd docker/rust-bindings
./build.sh
```

## Usage

### Basic Example

```python
from ssi_python import MdocIssuer, DidManager, Oid4VciIssuer

# Generate issuer DID
did_manager = DidManager()
issuer_did, issuer_key = did_manager.generate_did_key()

# Create mDoc issuer
issuer = MdocIssuer(issuer_key, issuer_did)

# Issue a credential
claims = {
    "org.iso.18013.5.1": {
        "family_name": "Doe",
        "given_name": "John",
        "birth_date": "1990-01-01"
    }
}

holder_did, holder_key = did_manager.generate_did_key()
holder_public = did_manager.get_public_key(holder_key)

mdoc = issuer.issue_mdoc(
    doctype="org.iso.18013.5.1.mDL",
    claims=claims,
    holder_public_key=holder_public,
    validity_days=365
)
```

### OID4VCI Credential Offer

```python
from ssi_python import Oid4VciIssuer

# Create issuer
oid4vci = Oid4VciIssuer("https://issuer.example.com")

# Generate credential offer
offer_url = oid4vci.generate_credential_offer(
    credential_type="org.iso.18013.5.1.mDL",
    pre_authorized_code="code-123",
    user_pin_required=False
)

print(offer_url)
# openid-credential-offer://?credential_offer=...
```

## API Reference

### MdocIssuer

Issue ISO 18013-5 mobile document credentials.

```python
MdocIssuer(issuer_key_jwk: str, issuer_did: str)
```

**Methods:**

- `issue_mdoc(doctype, claims, holder_public_key, validity_days=365)` - Issue an mDoc
- `create_mso(doctype, claims, validity_days)` - Create Mobile Security Object
- `get_issuer_did()` - Get issuer's DID
- `compute_digest(value)` - Compute SHA-256 digest of claim value

### DidManager

Manage Decentralized Identifiers.

```python
DidManager()
```

**Methods:**

- `generate_did_key()` - Generate new DID:key with P-256 curve
- `generate_did_key_ed25519()` - Generate new DID:key with Ed25519
- `resolve_did(did)` - Resolve DID to DID Document
- `get_public_key(jwk_json)` - Extract public key from JWK
- `get_jwk_thumbprint(jwk_json)` - Get JWK thumbprint
- `did_to_verification_method(did, key_id="key-1")` - Create verification method ID

### Oid4VciIssuer

Implement OID4VCI credential issuance protocol.

```python
Oid4VciIssuer(issuer_url: str)
```

**Methods:**

- `generate_credential_offer(credential_type, pre_authorized_code, user_pin_required)` - Create offer URL
- `generate_credential_offer_with_auth_code(credential_type, issuer_state, authorization_server=None)` - Create offer with auth code
- `generate_credential_response(credential_data, format)` - Create credential response
- `generate_deferred_credential_response(acceptance_token)` - Create deferred response
- `validate_access_token(access_token, expected_scope)` - Validate access token
- `generate_issuer_metadata(supported_credentials, token_endpoint=None, credential_endpoint=None)` - Generate metadata
- `get_issuer_url()` - Get issuer URL

## Running the Example

```bash
cd docker/rust-bindings
source .venv/bin/activate
python test_bindings.py
```

This will demonstrate:
1. Generating DIDs (P-256 and Ed25519)
2. Creating an mDoc issuer
3. Generating OID4VCI credential offers
4. Issuing mDoc credentials
5. Complete end-to-end issuance flow

## Development

### Building for Development

```bash
cd docker/rust-bindings
maturin develop
```

### Building a Wheel

```bash
maturin build --release
```

The wheel will be created in `target/wheels/`.

### Running Tests

```bash
cargo test
```

## Integration with PrivacyIDEA

See `docker/plugins/custom-tokens/mdoc_token.py` for an example of integrating
these bindings into a PrivacyIDEA token type.

## Troubleshooting

### Rust not found

Install Rust from [rustup.rs](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Maturin not found

```bash
pip3 install maturin
```

### Import error after building

Make sure you're using the same Python environment where you ran `maturin develop`:

```bash
which python3
pip3 list | grep ssi-python
```

## License

See LICENSE.txt in the project root.
