"""
OID4VC Event Handler for privacyIDEA
Handles credential issuance workflows using OpenID for Verifiable Credential Issuance (OID4VCI)
"""

import logging
import secrets
import uuid
from datetime import datetime

import requests
from privacyidea.lib.eventhandler.base import BaseEventHandler

log = logging.getLogger(__name__)


class OID4VCEventHandler(BaseEventHandler):
    """
    Event handler for OpenID for Verifiable Credentials workflows.

    This handler manages:
    - Credential issuance after successful authentication
    - Batch credential processing
    - Credential revocation
    - Integration with external credential issuers
    """

    identifier = "OID4VC"
    description = "OpenID for Verifiable Credentials Event Handler"

    def __init__(self):
        super(OID4VCEventHandler, self).__init__()

    @property
    def allowed_positions(self):
        """This handler can run in post-event position"""
        return ["post"]

    @property
    def actions(self):
        """Available actions for this handler"""
        return [
            "issue_credential",
            "batch_issue",
            "revoke_credential",
            "send_credential_offer",
            "update_credential_status",
        ]

    def check_condition(self, options=None):
        """
        Check if the event should trigger this handler.
        """
        options = options or {}
        handler_def = options.get("handler_def", {})
        g = options.get("g")

        # Get conditions from handler definition
        conditions = handler_def.get("conditions", {})

        # Check if authentication was successful
        if g and g.audit_object:
            audit_data = g.audit_object.audit_data
            success = audit_data.get("success", False)

            if not success:
                return False  # Only issue credentials on successful auth

        # Check token type condition
        token_type = conditions.get("token_type")
        if token_type and g and g.audit_object:
            audit_token_type = g.audit_object.audit_data.get("token_type", "")
            if token_type.lower() not in audit_token_type.lower():
                return False

        # Check realm condition
        realm = conditions.get("realm")
        if realm and g and g.audit_object:
            audit_realm = g.audit_object.audit_data.get("realm", "")
            if realm.lower() != audit_realm.lower():
                return False

        return True

    def do(self, action, options=None):
        """
        Execute the handler action.
        """
        options = options or {}

        try:
            if action == "issue_credential":
                return self._issue_credential(options)
            elif action == "batch_issue":
                return self._batch_issue_credentials(options)
            elif action == "revoke_credential":
                return self._revoke_credential(options)
            elif action == "send_credential_offer":
                return self._send_credential_offer(options)
            elif action == "update_credential_status":
                return self._update_credential_status(options)
            else:
                log.error("Unknown OID4VC action: %s", action)
                return False

        except Exception as e:
            log.error("OID4VC handler error: %s", str(e))
            return False

    def _issue_credential(self, options):
        """Issue a verifiable credential after successful authentication"""
        handler_def = options.get("handler_def", {})
        g = options.get("g")

        # Get issuer configuration
        issuer_config = self._get_issuer_config(handler_def)
        if not issuer_config:
            log.error("No issuer configuration found")
            return False

        # Extract user information from audit data
        user_info = self._extract_user_info(g)
        if not user_info:
            log.error("Could not extract user information")
            return False

        # Create credential
        credential = self._create_credential(user_info, handler_def)

        # Issue credential via OID4VCI flow
        return self._send_to_issuer(credential, issuer_config)

    def _batch_issue_credentials(self, options):
        """Issue multiple credentials in batch"""
        handler_def = options.get("handler_def", {})

        # Get batch configuration
        batch_config = handler_def.get("options", {}).get("batch_config", {})
        credential_types = batch_config.get("credential_types", [])

        if not credential_types:
            log.error("No credential types specified for batch issuance")
            return False

        success_count = 0

        for cred_type in credential_types:
            # Create modified options for each credential type
            cred_options = options.copy()
            cred_handler_def = handler_def.copy()
            cred_handler_def["options"] = cred_handler_def.get("options", {}).copy()
            cred_handler_def["options"]["credential_type"] = cred_type
            cred_options["handler_def"] = cred_handler_def

            if self._issue_credential(cred_options):
                success_count += 1

        log.info(
            "Batch issuance completed: %d/%d credentials issued",
            success_count,
            len(credential_types),
        )

        return success_count > 0

    def _revoke_credential(self, options):
        """Revoke a verifiable credential"""
        handler_def = options.get("handler_def", {})
        revocation_config = handler_def.get("options", {}).get("revocation", {})

        credential_id = revocation_config.get("credential_id")
        if not credential_id:
            log.error("No credential ID specified for revocation")
            return False

        # Send revocation request to credential status list
        status_list_url = revocation_config.get("status_list_url")
        if status_list_url:
            return self._update_status_list(status_list_url, credential_id, "revoked")

        return False

    def _send_credential_offer(self, options):
        """Send a credential offer to the user's wallet"""
        handler_def = options.get("handler_def", {})
        g = options.get("g")

        # Create credential offer
        offer = self._create_credential_offer(handler_def, g)

        # Send offer via configured method (webhook, QR code, deep link)
        delivery_method = handler_def.get("options", {}).get(
            "delivery_method", "webhook"
        )

        if delivery_method == "webhook":
            return self._send_offer_webhook(offer, handler_def)
        elif delivery_method == "qr_code":
            return self._generate_offer_qr_code(offer, handler_def)
        elif delivery_method == "deep_link":
            return self._send_offer_deep_link(offer, handler_def)
        else:
            log.error("Unknown delivery method: %s", delivery_method)
            return False

    def _update_credential_status(self, options):
        """Update the status of issued credentials"""
        handler_def = options.get("handler_def", {})
        status_config = handler_def.get("options", {}).get("status_update", {})

        credentials = status_config.get("credentials", [])
        new_status = status_config.get("new_status", "active")

        success_count = 0
        for credential_id in credentials:
            if self._update_single_credential_status(
                credential_id, new_status, status_config
            ):
                success_count += 1

        return success_count > 0

    def _get_issuer_config(self, handler_def):
        """Extract issuer configuration from handler definition"""
        options = handler_def.get("options", {})

        return {
            "issuer_url": options.get("issuer_url", ""),
            "client_id": options.get("client_id", ""),
            "client_secret": options.get("client_secret", ""),
            "credential_configuration": options.get("credential_configuration", {}),
            "timeout": int(options.get("timeout", "30")),
        }

    def _extract_user_info(self, g):
        """Extract user information from audit data"""
        if not g or not g.audit_object:
            return None

        audit_data = g.audit_object.audit_data

        return {
            "user_id": audit_data.get("user", ""),
            "realm": audit_data.get("realm", ""),
            "serial": audit_data.get("serial", ""),
            "token_type": audit_data.get("token_type", ""),
            "auth_time": audit_data.get("date", ""),
            "client": audit_data.get("client", ""),
            "user_agent": audit_data.get("user_agent", ""),
        }

    def _create_credential(self, user_info, handler_def):
        """Create a verifiable credential"""
        options = handler_def.get("options", {})
        credential_config = options.get("credential_configuration", {})

        # Base credential structure
        credential = {
            "@context": [
                "https://www.w3.org/2018/credentials/v1",
                "https://schema.privacyidea.org/credentials/v1",
            ],
            "id": f"urn:uuid:{uuid.uuid4()!s}",
            "type": ["VerifiableCredential"],
            "issuer": {
                "id": credential_config.get("issuer_did", "did:web:privacyidea.org"),
                "name": "privacyIDEA Authentication System",
            },
            "issuanceDate": datetime.utcnow().isoformat() + "Z",
            "credentialSubject": {
                "id": f"did:privacyidea:{user_info['user_id']}",
                "authenticated": True,
                "authenticationTime": user_info["auth_time"],
                "authenticationMethod": user_info["token_type"],
                "realm": user_info["realm"],
            },
        }

        # Add custom credential type
        credential_type = options.get("credential_type", "AuthenticationCredential")
        credential["type"].append(credential_type)

        # Add additional subject properties
        additional_props = credential_config.get("additional_properties", {})
        credential["credentialSubject"].update(additional_props)

        # Add expiration if configured
        expiry_days = credential_config.get("expiry_days")
        if expiry_days:
            from datetime import timedelta

            expiry_date = datetime.utcnow() + timedelta(days=int(expiry_days))
            credential["expirationDate"] = expiry_date.isoformat() + "Z"

        return credential

    def _send_to_issuer(self, credential, issuer_config):
        """Send credential to external issuer for signing and issuance"""
        try:
            # Create issuance request
            request_data = {
                "credential": credential,
                "format": "jwt_vc",
                "proof": {"proof_type": "BbsBlsSignature2020"},
            }

            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {issuer_config['client_secret']}",
            }

            # Send to issuer endpoint
            response = requests.post(
                f"{issuer_config['issuer_url']}/credential",
                json=request_data,
                headers=headers,
                timeout=issuer_config["timeout"],
            )

            if response.status_code == 200:
                result = response.json()
                log.info(
                    "Credential issued successfully: %s",
                    result.get("credential_id", ""),
                )
                return True
            else:
                log.error("Credential issuance failed: HTTP %d", response.status_code)
                return False

        except Exception as e:
            log.error("Error sending credential to issuer: %s", str(e))
            return False

    def _create_credential_offer(self, handler_def, g):
        """Create a credential offer"""
        options = handler_def.get("options", {})
        user_info = self._extract_user_info(g)

        offer = {
            "credential_issuer": options.get("issuer_url", ""),
            "credentials": [
                {
                    "format": "jwt_vc_json",
                    "types": [
                        "VerifiableCredential",
                        options.get("credential_type", "AuthenticationCredential"),
                    ],
                }
            ],
            "grants": {
                "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                    "pre-authorized_code": secrets.token_urlsafe(32),
                    "user_pin_required": False,
                }
            },
        }

        return offer

    def _send_offer_webhook(self, offer, handler_def):
        """Send credential offer via webhook"""
        webhook_url = handler_def.get("options", {}).get("webhook_url")
        if not webhook_url:
            return False

        try:
            response = requests.post(webhook_url, json=offer, timeout=30)
            return response.status_code == 200
        except Exception as e:
            log.error("Error sending webhook: %s", str(e))
            return False

    def _generate_offer_qr_code(self, offer, handler_def):
        """Generate QR code for credential offer"""
        # In practice, generate QR code and store/display it
        log.info("Generated QR code for credential offer")
        return True

    def _send_offer_deep_link(self, offer, handler_def):
        """Send credential offer via deep link"""
        # In practice, create deep link and send via configured method
        log.info("Sent credential offer via deep link")
        return True

    def _update_status_list(self, status_list_url, credential_id, status):
        """Update credential status in status list"""
        try:
            # Send status update request
            update_data = {
                "credential_id": credential_id,
                "status": status,
                "timestamp": datetime.utcnow().isoformat(),
            }

            response = requests.patch(status_list_url, json=update_data, timeout=30)
            return response.status_code == 200

        except Exception as e:
            log.error("Error updating status list: %s", str(e))
            return False

    def _update_single_credential_status(self, credential_id, new_status, config):
        """Update status of a single credential"""
        status_list_url = config.get("status_list_url")
        if status_list_url:
            return self._update_status_list(status_list_url, credential_id, new_status)
        return False


# Factory function for dynamic loading
def get_handler_class():
    """Return the handler class for dynamic loading"""
    return OID4VCEventHandler
