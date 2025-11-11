"""
OID4VC Token Implementation for privacyIDEA
Supports OpenID for Verifiable Credentials (OID4VC) authentication flows
"""

import base64
import hashlib
import io
import json
import logging
import secrets
import uuid
from datetime import datetime

import jwt
import qrcode
from privacyidea.api.lib.utils import getParam
from privacyidea.lib.decorators import check_token_locked
from privacyidea.lib.log import log_with
from privacyidea.lib.policy import ACTION, SCOPE
from privacyidea.lib.tokenclass import TokenClass

log = logging.getLogger(__name__)


class OID4VCTokenClass(TokenClass):
    """
    OpenID for Verifiable Credentials Token

    Implements OID4VP (Verifiable Presentations) for authentication and
    OID4VCI (Verifiable Credential Issuance) for credential management.

    Features:
    - Present verifiable credentials for authentication
    - Request specific credential presentations
    - Issue new credentials after successful authentication
    - Support for selective disclosure
    - DID-based authentication
    """

    using_pin = True
    hKeyRequired = False

    def __init__(self, db_token):
        TokenClass.__init__(self, db_token)
        self.set_type("oid4vc")
        self.hKeyRequired = False

    @staticmethod
    def get_class_type():
        """Return the token type identifier"""
        return "oid4vc"

    @staticmethod
    def get_class_prefix():
        """Return the token prefix"""
        return "OID4VC"

    @staticmethod
    def get_class_info(key=None, ret="all"):
        """
        Return token class information for the management UI
        """
        res = {
            "type": "oid4vc",
            "title": "OID4VC Token - OpenID for Verifiable Credentials",
            "description": "Token for authenticating with verifiable credentials using OID4VP and issuing credentials using OID4VCI",
            "init": {},
            "config": {},
            "user": ["enroll"],
            "realms": [],
            "policy": {
                SCOPE.ENROLL: {
                    ACTION.MAXTOKENUSER: {
                        "type": "int",
                        "desc": "Maximum number of OID4VC tokens per user",
                    },
                    ACTION.MAXACTIVETOKENS: {
                        "type": "int",
                        "desc": "Maximum number of active OID4VC tokens per realm",
                    },
                },
                SCOPE.AUTH: {
                    "oid4vc_required_credentials": {
                        "type": "str",
                        "desc": "Comma-separated list of required credential types",
                    },
                    "oid4vc_selective_disclosure": {
                        "type": "bool",
                        "desc": "Enable selective disclosure for presentations",
                    },
                },
            },
        }

        if key:
            ret = res.get(key, {})
        elif ret == "all":
            ret = res

        return ret

    @log_with(log)
    def update(self, param, reset_failcount=True):
        """
        Update/initialize the token
        """
        if getParam(param, "genkey", optional=True):
            # Generate new key pair for this token
            self._generate_keypair()

        # Set DID identifier
        did = getParam(param, "did", optional=True)
        if not did:
            did = self._generate_did()
        self.add_tokeninfo("did", did)

        # Set verifier endpoint
        verifier_endpoint = getParam(param, "verifier_endpoint", optional=True)
        if verifier_endpoint:
            self.add_tokeninfo("verifier_endpoint", verifier_endpoint)

        # Set issuer endpoint for OID4VCI
        issuer_endpoint = getParam(param, "issuer_endpoint", optional=True)
        if issuer_endpoint:
            self.add_tokeninfo("issuer_endpoint", issuer_endpoint)

        # Set required credential types
        required_credentials = getParam(param, "required_credentials", optional=True)
        if required_credentials:
            self.add_tokeninfo("required_credentials", required_credentials)

        # Enable selective disclosure
        selective_disclosure = getParam(param, "selective_disclosure", optional=True)
        if selective_disclosure:
            self.add_tokeninfo("selective_disclosure", selective_disclosure)

        TokenClass.update(self, param, reset_failcount)

    def _generate_keypair(self):
        """Generate a new key pair for DID operations"""
        # In a real implementation, you'd use proper cryptographic libraries
        # This is a simplified example
        private_key = secrets.token_hex(32)
        # Generate corresponding public key (simplified)
        public_key = hashlib.sha256(private_key.encode()).hexdigest()

        self.add_tokeninfo("private_key", private_key)
        self.add_tokeninfo("public_key", public_key)

        return private_key, public_key

    def _generate_did(self):
        """Generate a DID identifier"""
        # Generate a simple DID (in practice, use proper DID methods)
        did_suffix = secrets.token_hex(16)
        return f"did:web:privacyidea.org:{did_suffix}"

    @log_with(log)
    def get_init_detail(self, params=None, user=None):
        """
        Return initialization details including QR code for wallet setup
        """
        response_detail = TokenClass.get_init_detail(self, params, user)

        # Generate enrollment URL for mobile wallet
        enrollment_data = self._create_enrollment_data()
        qr_url = self._create_enrollment_url(enrollment_data)

        # Generate QR code
        qr_code_data = self._generate_qr_code(qr_url)

        response_detail["oid4vc"] = {
            "enrollment_url": qr_url,
            "qrcode": qr_code_data,
            "did": self.get_tokeninfo("did"),
            "required_credentials": self.get_tokeninfo("required_credentials", ""),
            "instructions": "Scan QR code with your wallet app to enroll for OID4VC authentication",
        }

        return response_detail

    def _create_enrollment_data(self):
        """Create enrollment data for wallet registration"""
        return {
            "token_id": self.get_serial(),
            "did": self.get_tokeninfo("did"),
            "verifier_endpoint": self.get_tokeninfo("verifier_endpoint", ""),
            "issuer_endpoint": self.get_tokeninfo("issuer_endpoint", ""),
            "required_credentials": self.get_tokeninfo(
                "required_credentials", ""
            ).split(","),
            "selective_disclosure": self.get_tokeninfo("selective_disclosure", "false")
            == "true",
            "enrollment_time": datetime.utcnow().isoformat(),
        }

    def _create_enrollment_url(self, enrollment_data):
        """Create enrollment URL for wallet apps"""
        base_url = "openid-credential-offer://"

        # Create credential offer for enrollment
        offer = {
            "credential_issuer": enrollment_data.get(
                "issuer_endpoint", "https://issuer.example.com"
            ),
            "credentials": [
                {
                    "format": "jwt_vc_json",
                    "types": [
                        "VerifiableCredential",
                        "PrivacyIDEAEnrollmentCredential",
                    ],
                }
            ],
            "grants": {
                "authorization_code": {"issuer_state": enrollment_data["token_id"]}
            },
        }

        # Encode offer as URL parameter
        offer_param = base64.urlsafe_b64encode(json.dumps(offer).encode()).decode()
        return f"{base_url}?credential_offer={offer_param}"

    def _generate_qr_code(self, data):
        """Generate QR code image data"""
        try:
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(data)
            qr.make(fit=True)

            img = qr.make_image(fill_color="black", back_color="white")
            img_buffer = io.BytesIO()
            img.save(img_buffer, format="PNG")
            img_data = img_buffer.getvalue()

            return "data:image/png;base64," + base64.b64encode(img_data).decode()

        except Exception as e:
            log.error("Error generating QR code: %s", str(e))
            return ""

    @check_token_locked
    def authenticate(self, passw, user, options=None):
        """
        Authenticate using verifiable credential presentation

        The 'passw' parameter should contain the verifiable presentation
        in JWT format or as JSON.
        """
        options = options or {}
        pin_match = False
        otp_match = False

        # Extract PIN and presentation
        pin, presentation = self.split_pin_pass(passw)

        # Verify PIN if required
        if self.check_pin(pin, user, options=options):
            pin_match = True

            # Verify the verifiable presentation
            otp_match = self._verify_presentation(presentation, options)

            # If authentication successful, optionally issue new credentials
            if otp_match and pin_match:
                self._handle_post_auth_issuance(user, options)

        return pin_match, otp_match, {"message": "OID4VC authentication"}

    def _verify_presentation(self, presentation, options):
        """
        Verify a verifiable presentation
        """
        try:
            # Parse presentation (could be JWT or JSON)
            if isinstance(presentation, str):
                if presentation.startswith("ey"):  # Looks like JWT
                    vp_data = self._verify_jwt_presentation(presentation)
                else:
                    vp_data = json.loads(presentation)
            else:
                return False

            # Verify presentation structure
            if not self._validate_presentation_structure(vp_data):
                return False

            # Check required credentials
            if not self._check_required_credentials(vp_data):
                return False

            # Verify cryptographic proofs
            if not self._verify_cryptographic_proofs(vp_data):
                return False

            # Store presentation for audit
            self._store_presentation_audit(vp_data)

            return True

        except Exception as e:
            log.error("Error verifying presentation: %s", str(e))
            return False

    def _verify_jwt_presentation(self, jwt_presentation):
        """Verify and decode JWT verifiable presentation"""
        try:
            # In a real implementation, verify JWT signature with proper key resolution
            # This is simplified for demonstration
            decoded = jwt.decode(jwt_presentation, verify=False)  # Don't verify in demo
            return decoded
        except Exception as e:
            log.error("Error decoding JWT presentation: %s", str(e))
            return None

    def _validate_presentation_structure(self, vp_data):
        """Validate the structure of the verifiable presentation"""
        required_fields = ["@context", "type", "verifiableCredential"]

        for field in required_fields:
            if field not in vp_data:
                log.error("Missing required field in presentation: %s", field)
                return False

        # Ensure it's a VerifiablePresentation
        if "VerifiablePresentation" not in vp_data.get("type", []):
            log.error("Invalid presentation type")
            return False

        return True

    def _check_required_credentials(self, vp_data):
        """Check if presentation contains required credential types"""
        required_creds = self.get_tokeninfo("required_credentials", "")
        if not required_creds:
            return True  # No specific requirements

        required_types = [t.strip() for t in required_creds.split(",")]
        presented_creds = vp_data.get("verifiableCredential", [])

        for required_type in required_types:
            found = False
            for cred in presented_creds:
                cred_types = cred.get("type", [])
                if required_type in cred_types:
                    found = True
                    break

            if not found:
                log.error("Required credential type not found: %s", required_type)
                return False

        return True

    def _verify_cryptographic_proofs(self, vp_data):
        """Verify cryptographic proofs in the presentation"""
        # In a real implementation, verify:
        # 1. Signature of the presentation
        # 2. Signatures of individual credentials
        # 3. Zero-knowledge proofs if applicable
        # 4. Revocation status

        # Simplified verification for demonstration
        proof = vp_data.get("proof")
        if not proof:
            log.error("No proof found in presentation")
            return False

        # Check proof structure
        if "type" not in proof or "proofValue" not in proof:
            log.error("Invalid proof structure")
            return False

        # In practice, verify the actual cryptographic proof
        return True

    def _store_presentation_audit(self, vp_data):
        """Store presentation data for audit purposes"""
        audit_data = {
            "presentation_id": vp_data.get("id", ""),
            "credential_count": len(vp_data.get("verifiableCredential", [])),
            "presentation_time": datetime.utcnow().isoformat(),
            "token_serial": self.get_serial(),
        }

        # Store audit data (in practice, use proper audit system)
        self.add_tokeninfo("last_presentation", json.dumps(audit_data))

    def _handle_post_auth_issuance(self, user, options):
        """Handle credential issuance after successful authentication"""
        issuer_endpoint = self.get_tokeninfo("issuer_endpoint")
        if not issuer_endpoint:
            return  # No issuance configured

        # Create credential offer for post-authentication issuance
        offer = self._create_post_auth_credential_offer(user)

        # Store offer for later retrieval
        offer_id = str(uuid.uuid4())
        self.add_tokeninfo(f"pending_offer_{offer_id}", json.dumps(offer))

        log.info("Created post-authentication credential offer: %s", offer_id)

    def _create_post_auth_credential_offer(self, user):
        """Create a credential offer after successful authentication"""
        return {
            "credential_issuer": self.get_tokeninfo("issuer_endpoint"),
            "credentials": [
                {
                    "format": "jwt_vc_json",
                    "types": ["VerifiableCredential", "AuthenticationCredential"],
                    "credentialSubject": {
                        "id": self.get_tokeninfo("did"),
                        "authenticated": True,
                        "authTime": datetime.utcnow().isoformat(),
                        "method": "oid4vc",
                    },
                }
            ],
            "grants": {
                "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                    "pre-authorized_code": secrets.token_urlsafe(32)
                }
            },
        }

    def get_multi_otp(
        self, count=1, epoch_start=0, epoch_end=0, curTime=None, timestamp=None
    ):
        """
        Return multiple OTPs - not applicable for OID4VC tokens
        """
        return {}

    def resync(self, otp1, otp2, options=None):
        """
        Resync token - refresh DID document or credential status
        """
        # In practice, refresh DID document and credential status
        return True

    @classmethod
    def get_default_settings(cls, g, params):
        """
        Return default settings for OID4VC tokens
        """
        ret = {}

        # Default verifier endpoint
        if hasattr(g, "Config"):
            ret["OID4VC.verifier_endpoint"] = g.Config.get(
                "OID4VC_VERIFIER_ENDPOINT", "https://verifier.example.com"
            )
            ret["OID4VC.issuer_endpoint"] = g.Config.get(
                "OID4VC_ISSUER_ENDPOINT", "https://issuer.example.com"
            )

        return ret
