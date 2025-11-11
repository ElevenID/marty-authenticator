"""
Custom User Resolver Example: REST API Resolver
This resolver connects to a REST API to authenticate users and retrieve user information.
"""

import logging

import requests
from privacyidea.lib.resolvers.UserIdResolver import UserIdResolver

log = logging.getLogger(__name__)


class RestAPIUserResolver(UserIdResolver):
    """
    Custom user resolver that connects to a REST API for user authentication.

    Example use cases:
    - Connect to HR systems
    - Integrate with custom user databases
    - Use cloud identity providers with REST APIs
    - Connect to CRM systems for customer authentication
    """

    # Define the resolver type
    resolver_name = "restapi"

    def __init__(self):
        self.i_am_bound = False
        self.api_base_url = None
        self.api_key = None
        self.timeout = 30

    @staticmethod
    def getResolverClassType():
        """Return the resolver type"""
        return "restapi"

    @staticmethod
    def getResolverType():
        """Return the resolver type"""
        return RestAPIUserResolver.getResolverClassType()

    @staticmethod
    def getResolverClassDescriptor():
        """Return description of this resolver"""
        return "REST API User Resolver"

    @classmethod
    def getResolverDescription(cls):
        """Return description of this resolver"""
        return cls.getResolverClassDescriptor()

    def loadConfig(self, config):
        """Load configuration for this resolver"""
        self.api_base_url = config.get("api_base_url", "")
        self.api_key = config.get("api_key", "")
        self.timeout = int(config.get("timeout", "30"))

        if self.api_base_url and self.api_key:
            self.i_am_bound = True
            log.info("REST API resolver successfully configured")
        else:
            log.error("REST API resolver missing required configuration")

        return self.i_am_bound

    def checkPass(self, uid, password):
        """
        Check password against the REST API
        """
        if not self.i_am_bound:
            return False

        try:
            # Make authentication request to API
            auth_url = f"{self.api_base_url}/auth"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            payload = {"username": uid, "password": password}

            response = requests.post(
                auth_url, json=payload, headers=headers, timeout=self.timeout
            )

            if response.status_code == 200:
                result = response.json()
                return result.get("authenticated", False)
            else:
                log.warning(
                    "Authentication failed for user %s: HTTP %s",
                    uid,
                    response.status_code,
                )
                return False

        except Exception as e:
            log.error("Error authenticating user %s: %s", uid, str(e))
            return False

    def getUserInfo(self, userId):
        """
        Get user information from the REST API
        """
        if not self.i_am_bound:
            return {}

        try:
            # Make user info request to API
            user_url = f"{self.api_base_url}/users/{userId}"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            response = requests.get(user_url, headers=headers, timeout=self.timeout)

            if response.status_code == 200:
                user_data = response.json()

                # Map API response to privacyIDEA user info format
                return {
                    "username": user_data.get("username", userId),
                    "userid": userId,
                    "email": user_data.get("email", ""),
                    "givenname": user_data.get("first_name", ""),
                    "surname": user_data.get("last_name", ""),
                    "phone": user_data.get("phone", ""),
                    "mobile": user_data.get("mobile", ""),
                    "description": user_data.get("description", ""),
                }
            else:
                log.warning(
                    "Failed to get user info for %s: HTTP %s",
                    userId,
                    response.status_code,
                )
                return {}

        except Exception as e:
            log.error("Error getting user info for %s: %s", userId, str(e))
            return {}

    def getUsername(self, userId):
        """Get username for a given user ID"""
        user_info = self.getUserInfo(userId)
        return user_info.get("username", userId)

    def getUserId(self, LoginName):
        """Get user ID for a given login name"""
        if not self.i_am_bound:
            return ""

        try:
            # Search for user by login name
            search_url = f"{self.api_base_url}/users/search"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            params = {"username": LoginName}

            response = requests.get(
                search_url, headers=headers, params=params, timeout=self.timeout
            )

            if response.status_code == 200:
                results = response.json()
                if results and len(results) > 0:
                    return results[0].get("id", LoginName)

        except Exception as e:
            log.error("Error searching for user %s: %s", LoginName, str(e))

        return LoginName

    def getUserList(self, searchDict):
        """
        Get list of users matching search criteria
        """
        if not self.i_am_bound:
            return []

        try:
            # Make search request to API
            search_url = f"{self.api_base_url}/users"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

            # Convert searchDict to API parameters
            params = {}
            if "username" in searchDict:
                params["username"] = searchDict["username"]
            if "email" in searchDict:
                params["email"] = searchDict["email"]

            response = requests.get(
                search_url, headers=headers, params=params, timeout=self.timeout
            )

            if response.status_code == 200:
                users = response.json()
                result = []

                for user in users:
                    user_info = {
                        "username": user.get("username", ""),
                        "userid": user.get("id", ""),
                        "email": user.get("email", ""),
                        "givenname": user.get("first_name", ""),
                        "surname": user.get("last_name", ""),
                        "phone": user.get("phone", ""),
                        "mobile": user.get("mobile", ""),
                    }
                    result.append(user_info)

                return result
            else:
                log.warning("Failed to search users: HTTP %s", response.status_code)
                return []

        except Exception as e:
            log.error("Error searching users: %s", str(e))
            return []

    @staticmethod
    def getResolverSetupDesc():
        """
        Return the description of the setup parameters for this resolver
        """
        return {
            "api_base_url": {
                "type": "str",
                "required": True,
                "description": "Base URL of the REST API (e.g., https://api.company.com/v1)",
            },
            "api_key": {
                "type": "password",
                "required": True,
                "description": "API key or bearer token for authentication",
            },
            "timeout": {
                "type": "int",
                "required": False,
                "default": "30",
                "description": "Timeout in seconds for API requests",
            },
        }

    @staticmethod
    def setup_resolver(config, realm=None):
        """
        Setup the resolver configuration
        """
        # Validate required configuration
        required_fields = ["api_base_url", "api_key"]
        for field in required_fields:
            if field not in config:
                raise Exception(f"Missing required configuration field: {field}")

        # Validate URL format
        api_url = config["api_base_url"]
        if not (api_url.startswith("http://") or api_url.startswith("https://")):
            raise Exception("API base URL must start with http:// or https://")

        return config


# Factory function for dynamic loading
def get_resolver_class():
    """Return the resolver class for dynamic loading"""
    return RestAPIUserResolver
