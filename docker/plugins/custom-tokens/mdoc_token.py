"""
mDoc Token Type for PrivacyIDEA using Rust SSI bindings

This module provides a token type for issuing ISO 18013-5 mobile document
credentials through the OID4VCI protocol using the Rust SSI Python bindings.
"""

from privacyidea.lib.tokenclass import TokenClass
from privacyidea.lib import _
from privacyidea.lib.log import log_with
import logging
import json
import secrets
from datetime import datetime

try:
    from ssi_python import MdocIssuer, DidManager, Oid4VciIssuer
    SSI_AVAILABLE = True
except ImportError:
    # Fallback if bindings not available
    MdocIssuer = None
    DidManager = None
    Oid4VciIssuer = None
    SSI_AVAILABLE = False

log = logging.getLogger(__name__)


class MdocTokenClass(TokenClass):
    """
    Token class for issuing mDoc credentials using Rust SSI bindings
    
    This token type supports:
    - ISO 18013-5 mobile document issuance
    - OID4VCI credential offer generation
    - DID-based issuer identity
    - Configurable document types (mDL, etc.)
    """
    
    @staticmethod
    def get_class_type():
        return "mdoc"
    
    @staticmethod
    def get_class_prefix():
        return "MDOC"
    
    @staticmethod
    def get_class_info(key=None, ret='all'):
        """
        Returns token type information
        """
        info = {
            'type': 'mdoc',
            'title': _('mDoc Token'),
            'description': _('Mobile document credential token using ISO 18013-5 and OID4VCI'),
            'init': {},
            'config': {},
            'user': ['enroll'],
            'policy': {
                'enrollment': {
                    'mdoc_issuer_url': {
                        'type': 'str',
                        'desc': _('OID4VCI issuer URL'),
                        'value': 'https://issuer.example.com'
                    },
                    'mdoc_doctype': {
                        'type': 'str', 
                        'desc': _('Document type (e.g., org.iso.18013.5.1.mDL)'),
                        'value': 'org.iso.18013.5.1.mDL'
                    },
                    'mdoc_validity_days': {
                        'type': 'int',
                        'desc': _('Number of days the credential is valid'),
                        'value': 365
                    }
                }
            }
        }
        return info if ret == 'all' else info.get(key, {})
    
    @log_with(log)
    def __init__(self, db_token):
        TokenClass.__init__(self, db_token)
        self.set_type(u"mdoc")
        self.mode = ['challenge']
        
        # Initialize issuer components if available
        if SSI_AVAILABLE:
            self._init_issuer()
        else:
            log.warning("SSI Python bindings not available. Install ssi-python package.")
            self.mdoc_issuer = None
    
    def _init_issuer(self):
        """Initialize mDoc issuer with DID and keys"""
        try:
            # Get or generate issuer DID
            issuer_key = self.get_tokeninfo('issuer_key')
            issuer_did = self.get_tokeninfo('issuer_did')
            
            if not issuer_key or not issuer_did:
                # Generate new DID:key
                did_manager = DidManager()
                issuer_did, issuer_key = did_manager.generate_did_key()
                
                self.add_tokeninfo('issuer_key', issuer_key)
                self.add_tokeninfo('issuer_did', issuer_did)
                log.info(f"Generated new issuer DID: {issuer_did}")
            
            self.mdoc_issuer = MdocIssuer(issuer_key, issuer_did)
            
        except Exception as e:
            log.error(f"Failed to initialize mDoc issuer: {e}")
            self.mdoc_issuer = None
    
    def update(self, param):
        """Process enrollment/update request"""
        TokenClass.update(self, param)
        
        # Store mDoc-specific metadata
        doctype = param.get('doctype', 'org.iso.18013.5.1.mDL')
        self.add_tokeninfo('doctype', doctype)
        
        # Store OID4VCI issuer URL
        issuer_url = param.get('issuer_url', 'https://issuer.example.com')
        self.add_tokeninfo('issuer_url', issuer_url)
        
        # Store validity period
        validity_days = param.get('validity_days', 365)
        self.add_tokeninfo('validity_days', str(validity_days))
        
        log.info(f"mDoc token enrolled with doctype: {doctype}")
    
    def create_challenge(self, transaction_id=None, options=None):
        """
        Create OID4VCI credential offer for mDoc issuance
        
        This method generates a credential offer URL that can be scanned
        by the mobile authenticator app to initiate credential issuance.
        
        Returns:
            tuple: (success, offer_url, transaction_id, attributes)
        """
        options = options or {}
        
        if not self.mdoc_issuer:
            log.error("mDoc issuer not initialized")
            return False, "Issuer not available", transaction_id, {}
        
        try:
            # Get configuration
            issuer_url = self.get_tokeninfo('issuer_url')
            doctype = self.get_tokeninfo('doctype')
            
            # Create OID4VCI issuer
            oid4vci = Oid4VciIssuer(issuer_url)
            
            # Generate pre-authorized code
            pre_auth_code = transaction_id or self._generate_code()
            
            # Create credential offer URL
            offer_url = oid4vci.generate_credential_offer(
                credential_type=doctype,
                pre_authorized_code=pre_auth_code,
                user_pin_required=False
            )
            
            # Store transaction state
            self.add_tokeninfo(f'transaction_{pre_auth_code}', json.dumps({
                'state': 'offered',
                'doctype': doctype,
                'created': datetime.now().isoformat()
            }))
            
            log.info(f"Created credential offer for {doctype}")
            return True, offer_url, pre_auth_code, {}
            
        except Exception as e:
            log.error(f"Failed to create credential offer: {e}")
            return False, str(e), transaction_id, {}
    
    def issue_credential(self, holder_public_key, claims):
        """
        Issue the actual mDoc credential
        
        Args:
            holder_public_key (str): Holder's public key as JWK JSON
            claims (dict): Dictionary of claims organized by namespace
                          Example: {
                              "org.iso.18013.5.1": {
                                  "family_name": "Doe",
                                  "given_name": "John",
                                  "birth_date": "1990-01-01"
                              }
                          }
        
        Returns:
            str: Base64-encoded mDoc credential
        """
        if not self.mdoc_issuer:
            raise ValueError("mDoc issuer not initialized")
        
        doctype = self.get_tokeninfo('doctype')
        validity_days = int(self.get_tokeninfo('validity_days', '365'))
        
        try:
            mdoc = self.mdoc_issuer.issue_mdoc(
                doctype=doctype,
                claims=claims,
                holder_public_key=holder_public_key,
                validity_days=validity_days
            )
            
            log.info(f"Issued mDoc credential: {doctype}")
            return mdoc
            
        except Exception as e:
            log.error(f"Failed to issue mDoc: {e}")
            raise
    
    def validate_check(self, passw, options=None):
        """
        Validate credential presentation
        
        This would be called when the user presents their credential.
        For now, this is a placeholder for future implementation.
        """
        # TODO: Implement credential presentation validation
        return True, {}
    
    def _generate_code(self):
        """Generate random pre-authorized code"""
        return secrets.token_urlsafe(32)


# Example usage in a PrivacyIDEA plugin context
if __name__ == "__main__":
    print("mDoc Token Type Example Usage")
    print("=" * 50)
    
    if not SSI_AVAILABLE:
        print("ERROR: ssi_python module not available!")
        print("Build and install the Rust bindings first:")
        print("  cd docker/rust-bindings")
        print("  ./build.sh")
        exit(1)
    
    # Example: Generate issuer DID
    print("\n1. Generate Issuer DID")
    did_manager = DidManager()
    issuer_did, issuer_key = did_manager.generate_did_key()
    print(f"   DID: {issuer_did}")
    print(f"   Key generated: {len(issuer_key)} bytes")
    
    # Example: Create mDoc issuer
    print("\n2. Create mDoc Issuer")
    issuer = MdocIssuer(issuer_key, issuer_did)
    print(f"   Issuer DID: {issuer.get_issuer_did()}")
    
    # Example: Generate credential offer
    print("\n3. Generate OID4VCI Credential Offer")
    oid4vci = Oid4VciIssuer("https://issuer.example.com")
    offer = oid4vci.generate_credential_offer(
        credential_type="org.iso.18013.5.1.mDL",
        pre_authorized_code="test-code-123",
        user_pin_required=False
    )
    print(f"   Offer URL: {offer[:80]}...")
    
    # Example: Issue mDoc
    print("\n4. Issue mDoc Credential")
    # Generate holder key
    holder_did, holder_key = did_manager.generate_did_key()
    holder_public = did_manager.get_public_key(holder_key)
    
    claims = {
        "org.iso.18013.5.1": {
            "family_name": "Doe",
            "given_name": "John",
            "birth_date": "1990-01-01",
            "issue_date": "2025-11-12",
            "expiry_date": "2030-11-12"
        }
    }
    
    mdoc = issuer.issue_mdoc(
        doctype="org.iso.18013.5.1.mDL",
        claims=claims,
        holder_public_key=holder_public,
        validity_days=365
    )
    print(f"   mDoc issued: {len(mdoc)} bytes (base64)")
    
    print("\n✓ All examples completed successfully!")
