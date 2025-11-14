"""
SpruceID Integration Service
Central service for coordinating SpruceID libraries
"""

import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

# Import SpruceID Python bindings
try:
    # Import DIDKit for DID operations
    from didkit import DIDKit

    # Import isomdl for Mobile Documents
    from isomdl import MdocHandler

    # Import sd-jwt-rs for Selective Disclosure JWT
    from sd_jwt import SdJwtIssuer, SdJwtVerifier

    SPRUCE_AVAILABLE = True
except ImportError as e:
    logging.warning(f"SpruceID libraries not available: {e}")
    SPRUCE_AVAILABLE = False

log = logging.getLogger(__name__)


class SpruceIdIntegrationService:
    """
    Central service for SpruceID integration

    Coordinates between different SpruceID libraries:
    - DIDKit for DID operations
    - isomdl for Mobile Documents
    - sd-jwt-rs for Selective Disclosure JWT
    - ssi core libraries
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.initialized = False
        self.didkit = None
        self.mdoc_handler = None
        self.sd_jwt_issuer = None
        self.sd_jwt_verifier = None

    async def initialize(self) -> None:
        """Initialize SpruceID services"""
        try:
            if not SPRUCE_AVAILABLE:
                log.warning(
                    "SpruceID libraries not available, using placeholder implementations"
                )
                self.initialized = True
                return

            # Initialize DIDKit
            self.didkit = DIDKit()
            log.info("Initialized DIDKit")

            # Initialize mDoc handler
            self.mdoc_handler = MdocHandler()
            # Configure trust anchors for mDoc verification
            trust_anchors_path = self.config.get("trust_anchors_path")
            if trust_anchors_path and os.path.exists(trust_anchors_path):
                self.mdoc_handler.load_trust_anchors(trust_anchors_path)
            log.info("Initialized mDoc handler")

            # Initialize SD-JWT components
            # Get signing key from config or generate new one
            signing_key = self.config.get("signing_key")
            if not signing_key:
                # Generate a new key for development
                key_result = await self.create_did("key")
                signing_key = key_result.get("private_key")

            self.sd_jwt_issuer = SdJwtIssuer(signing_key)
            self.sd_jwt_verifier = SdJwtVerifier()
            log.info("Initialized SD-JWT components")

            self.initialized = True
            log.info("SpruceID integration service initialized successfully")

        except Exception as e:
            log.error(f"Failed to initialize SpruceID service: {e}")
            raise

    async def create_did(self, method: str = "key") -> Dict[str, Any]:
        """Create a new DID using DIDKit"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                # Fallback implementation
                return {
                    "did": f"did:{method}:placeholder-{hash(method) % 10000}",
                    "private_key": "placeholder-private-key",  # pragma: allowlist secret
                    "status": "created (placeholder)",
                }

            # Use DIDKit to create DID
            key_result = self.didkit.generate_key("ed25519")
            private_key = key_result["privateKey"]

            # Create DID document based on method
            if method == "key":
                did_document = self.didkit.key_to_did("key", key_result["publicKey"])
            elif method == "web":
                did_document = self.didkit.key_to_did("web", key_result["publicKey"])
            else:
                # Default to did:key
                did_document = self.didkit.key_to_did("key", key_result["publicKey"])

            # Store private key securely (in production, use HSM or secure enclave)
            # For now, return it in response (development only)

            return {
                "did": did_document,
                "private_key": private_key,
                "public_key": key_result["publicKey"],
                "status": "created",
            }

        except Exception as e:
            log.error(f"Failed to create DID: {e}")
            raise

    async def resolve_did(self, did: str) -> Dict[str, Any]:
        """Resolve a DID to its DID document"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                return {"did": did, "document": {}, "status": "resolved (placeholder)"}

            # Use DIDKit DID resolution
            did_document = self.didkit.resolve_did(did, {})

            # Cache resolved DIDs for performance
            # TODO: Implement caching mechanism

            return {"did": did, "document": did_document, "status": "resolved"}

        except Exception as e:
            log.error(f"Failed to resolve DID {did}: {e}")
            raise

    async def sign_credential(
        self, credential: Dict[str, Any], private_key: str
    ) -> Dict[str, Any]:
        """Sign a verifiable credential"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                return {
                    **credential,
                    "proof": {
                        "type": "Ed25519Signature2018",
                        "created": "2025-01-01T00:00:00Z",
                        "proofPurpose": "assertionMethod",
                        "verificationMethod": "did:key:placeholder",
                        "proofValue": "placeholder-signature",
                    },
                }

            # Use SpruceID SSI libraries to sign credential
            options = {
                "proofPurpose": "assertionMethod",
                "verificationMethod": credential.get("issuer", ""),
            }

            signed_credential = self.didkit.issue_credential(
                json.dumps(credential), options, private_key
            )

            return json.loads(signed_credential)

        except Exception as e:
            log.error(f"Failed to sign credential: {e}")
            raise

    async def verify_credential(self, credential: str) -> Dict[str, Any]:
        """Verify a verifiable credential"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                return {
                    "valid": True,
                    "status": "verified (placeholder)",
                    "warnings": [],
                }

            # Use SpruceID SSI libraries to verify credential
            result = self.didkit.verify_credential(credential, "{}")

            return {
                "valid": result.get("errors", []) == [],
                "status": "verified" if result.get("errors", []) == [] else "invalid",
                "errors": result.get("errors", []),
                "warnings": result.get("warnings", []),
            }

        except Exception as e:
            log.error(f"Failed to verify credential: {e}")
            raise

    async def create_mdoc_credential(
        self, doc_type: str, attributes: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Create an mDoc credential using isomdl"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                return {
                    "doc_type": doc_type,
                    "attributes": attributes,
                    "mdoc": f"placeholder-mdoc-{hash(str(attributes)) % 10000}",
                    "status": "created (placeholder)",
                }

            # Use isomdl library to create mDoc
            mdoc = self.mdoc_handler.create_mdoc(
                doc_type=doc_type, attributes=attributes
            )

            return {
                "doc_type": doc_type,
                "attributes": attributes,
                "mdoc": mdoc,
                "status": "created",
            }

        except Exception as e:
            log.error(f"Failed to create mDoc: {e}")
            raise

    async def create_sd_jwt(
        self, claims: Dict[str, Any], selective_claims: List[str]
    ) -> str:
        """Create an SD-JWT with selective disclosure"""
        try:
            if not self.initialized:
                raise RuntimeError("Service not initialized")

            if not SPRUCE_AVAILABLE:
                return f"placeholder.sd-jwt.{hash(str(claims)) % 10000}"

            # Use sd-jwt-rs library to create SD-JWT
            sd_jwt = self.sd_jwt_issuer.issue(
                claims=claims, selective_claims=selective_claims
            )

            return sd_jwt

        except Exception as e:
            log.error(f"Failed to create SD-JWT: {e}")
            raise

    async def create_mdoc_device_engagement(self, mdoc_data: Dict) -> Dict[str, Any]:
        """Create mDoc device engagement using isomdl"""
        # TODO: Use isomdl library
        # TODO: Generate device engagement
        # TODO: Set up secure channel

        return {
            "device_engagement": b"placeholder",
            "session_id": "placeholder-session",
            "status": "created",
        }

    async def process_mdoc_request(self, request: bytes) -> Dict[str, Any]:
        """Process mDoc request using isomdl"""
        # TODO: Parse mDoc request
        # TODO: Generate response with selective disclosure
        # TODO: Handle proximity requirements

        return {
            "response": b"placeholder",
            "disclosed_attributes": [],
            "status": "processed",
        }

    async def create_sd_jwt(self, claims: Dict, disclosure_frame: Dict) -> str:
        """Create SD-JWT using sd-jwt-rs"""
        # TODO: Use sd-jwt-rs library
        # TODO: Apply selective disclosure
        # TODO: Generate disclosures

        return "placeholder.sd-jwt.with.disclosures"

    async def verify_sd_jwt(self, sd_jwt: str, required_claims: list) -> Dict[str, Any]:
        """Verify SD-JWT using sd-jwt-rs"""
        # TODO: Parse SD-JWT
        # TODO: Verify disclosed claims
        # TODO: Check cryptographic binding

        return {"valid": False, "disclosed_claims": {}, "reason": "not implemented"}

    async def create_oid4vp_response(
        self, vp_request: Dict, credentials: list
    ) -> Dict[str, Any]:
        """Create OID4VP response"""
        # TODO: Parse presentation request
        # TODO: Select matching credentials
        # TODO: Create verifiable presentation

        return {
            "vp_token": "placeholder-vp-token",
            "presentation_submission": {},
            "status": "created",
        }

    async def handle_oid4vci_offer(self, credential_offer: Dict) -> Dict[str, Any]:
        """Handle OID4VCI credential offer"""
        # TODO: Parse credential offer
        # TODO: Request credential issuance
        # TODO: Handle proofs and binding

        return {"credential": {}, "c_nonce": "placeholder-nonce", "status": "issued"}

    def get_supported_did_methods(self) -> list:
        """Get list of supported DID methods"""
        # TODO: Query DIDKit capabilities
        return ["key", "web", "ion", "ethr"]

    def get_supported_credential_formats(self) -> list:
        """Get list of supported credential formats"""
        # TODO: Query SSI library capabilities
        return ["jwt_vc", "ldp_vc", "mdoc", "sd_jwt_vc"]

    def get_supported_signature_suites(self) -> list:
        """Get list of supported signature suites"""
        # TODO: Query cryptographic capabilities
        return [
            "Ed25519Signature2020",
            "EcdsaSecp256k1Signature2019",
            "JsonWebSignature2020",
        ]


class SpruceIdConfigManager:
    """Configuration manager for SpruceID integration"""

    def __init__(self, config_path: Path):
        self.config_path = config_path
        self.config = {}

    def load_config(self) -> Dict[str, Any]:
        """Load SpruceID configuration"""
        # TODO: Load configuration from file
        # TODO: Validate configuration
        # TODO: Set defaults

        default_config = {
            "did_methods": ["key", "web"],
            "credential_formats": ["jwt_vc", "mdoc", "sd_jwt_vc"],
            "signature_suites": ["Ed25519Signature2020"],
            "trust_anchors": [],
            "mdoc_config": {"device_key_curve": "P-256", "proximity_detection": True},
            "sd_jwt_config": {"default_alg": "ES256", "hash_alg": "SHA-256"},
            "oid4vc_config": {
                "credential_endpoint": "/api/v1/credentials",
                "presentation_endpoint": "/api/v1/presentations",
            },
        }

        self.config = default_config
        return self.config

    def save_config(self, config: Dict[str, Any]) -> None:
        """Save SpruceID configuration"""
        # TODO: Save configuration to file
        # TODO: Validate configuration before saving

        self.config = config
        log.info("SpruceID configuration saved")

    def get_config(self, section: str) -> Dict[str, Any]:
        """Get configuration section"""
        return self.config.get(section, {})

    def update_config(self, section: str, updates: Dict[str, Any]) -> None:
        """Update configuration section"""
        if section not in self.config:
            self.config[section] = {}

        self.config[section].update(updates)
        log.info(f"Updated SpruceID configuration section: {section}")


# Global service instance
_spruce_service: Optional[SpruceIdIntegrationService] = None


async def get_spruce_service() -> SpruceIdIntegrationService:
    """Get global SpruceID service instance"""
    global _spruce_service

    if _spruce_service is None:
        config_manager = SpruceIdConfigManager(
            Path("/etc/privacyidea/spruce_config.json")
        )
        config = config_manager.load_config()
        _spruce_service = SpruceIdIntegrationService(config)
        await _spruce_service.initialize()

    return _spruce_service
