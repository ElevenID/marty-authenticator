"""
Example Custom Token for privacyIDEA

This is a demonstration token that integrates with the Flutter authenticator app.
It shows how to create a custom token type that can work with the mobile app.
"""

import logging

from privacyidea.lib import _
from privacyidea.lib.crypto import geturandom
from privacyidea.lib.tokenclass import TokenClass

log = logging.getLogger(__name__)


class DemoTokenClass(TokenClass):
    """
    Demo Token Class for Flutter Authenticator Integration

    This token demonstrates how to create custom tokens that work
    with the Flutter authenticator app.
    """

    def __init__(self, db_token):
        """
        Initialize the Demo Token
        """
        TokenClass.__init__(self, db_token)
        self.set_type("demo")
        self.mode = ["authenticate"]

    @staticmethod
    def get_class_type():
        """
        Return the class type identifier
        """
        return "demo"

    @staticmethod
    def get_class_prefix():
        """
        Return the prefix used for this token
        """
        return "DEMO"

    @staticmethod
    def get_class_info(key=None, ret="all"):
        """
        Return information about the token class
        """
        res = {
            "type": "demo",
            "title": "Demo Token",
            "description": _("A demonstration token for Flutter app integration."),
            "init": {},
            "config": {},
            "user": ["enroll"],
            "ui_enroll": ["webui", "mobile"],
            "policy": {},
        }

        if key:
            ret = res.get(key, {})
        elif ret == "all":
            ret = res

        return ret

    def update(self, param, reset_failcount=True):
        """
        Update token with new parameters
        """
        # Generate a demo secret
        if "genkey" in param:
            # Generate a random key for demonstration
            key = geturandom(20)  # 160 bit key
            self.add_tokeninfo("demo_key", key.hex())
            del param["genkey"]

        # Set demo data
        if "demo_data" in param:
            self.add_tokeninfo("demo_data", param.get("demo_data"))

        TokenClass.update(self, param, reset_failcount)

    def create_challenge(self, transactionid=None, options=None):
        """
        Create a challenge for this token
        """
        challenge = geturandom(8).hex()  # 8 byte random challenge
        message = f"Demo challenge: {challenge}"

        return challenge, message, True, {}

    def check_challenge_response(self, user=None, passw=None, options=None):
        """
        Check the response to a challenge
        """
        challenge = self.get_tokeninfo("challenge")
        expected_response = self.generate_response(challenge)

        if passw == expected_response:
            return 1
        return -1

    def generate_response(self, challenge):
        """
        Generate the expected response for a challenge
        """
        # Simple demo: reverse the challenge string
        return challenge[::-1]

    def check_otp(self, anOtpVal, counter=None, window=None, options=None):
        """
        Check OTP value
        """
        # For demo purposes, accept any 6-digit number
        if len(anOtpVal) == 6 and anOtpVal.isdigit():
            return 1
        return -1

    def get_init_detail(self, params=None, user=None):
        """
        Return initialization details for enrollment
        """
        response_detail = TokenClass.get_init_detail(self, params, user)

        # Add QR code data for mobile enrollment
        demo_data = {
            "token_type": "demo",
            "secret": self.get_tokeninfo("demo_key"),
            "demo_data": self.get_tokeninfo("demo_data", "Default demo data"),
        }

        # Create otpauth URL for QR code
        otpauth_url = (
            f"otpauth://demo/{user.login}?"
            f"secret={demo_data['secret']}&"
            f"issuer=DemoToken&"
            f"demo_data={demo_data['demo_data']}"
        )

        response_detail.update(
            {
                "otpkey": {
                    "value": demo_data["secret"],
                    "description": _("Demo Token Secret"),
                },
                "demo_data": {
                    "value": demo_data["demo_data"],
                    "description": _("Demo Data"),
                },
                "googleurl": {
                    "value": otpauth_url,
                    "description": _("QR Code for Demo Token"),
                    "img": otpauth_url,
                },
            }
        )

        return response_detail

    def get_as_dict(self):
        """
        Return token as dictionary
        """
        token_dict = TokenClass.get_as_dict(self)

        # Add demo-specific information
        token_dict.update(
            {
                "demo_key": self.get_tokeninfo("demo_key"),
                "demo_data": self.get_tokeninfo("demo_data"),
            }
        )

        return token_dict
