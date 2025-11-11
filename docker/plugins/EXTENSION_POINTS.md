# privacyIDEA Extension Points Guide

## 🔌 Multiple Ways to Extend privacyIDEA

### 1. **Custom Tokens** (`/custom-tokens/`)

**What**: New authentication methods and token types
**Examples**:

- Hardware tokens (Yubikey variants)
- Mobile app integrations
- Biometric tokens
- Custom challenge-response systems

```python
from privacyidea.lib.tokenclass import TokenClass

class MyTokenClass(TokenClass):
    def __init__(self, db_token):
        TokenClass.__init__(self, db_token)
        self.set_type("mytoken")

    @classmethod
    def get_class_type(cls):
        return "mytoken"

    def authenticate(self, passw, user, options=None):
        # Custom authentication logic
        return (True, pin_match, reply)
```

### 2. **Event Handlers** (`/custom-eventhandlers/`)

**What**: Automation and workflow triggers
**Examples**:

- User notifications (email, SMS, Slack)
- Token lifecycle management
- Security incident response
- Audit log processing
- Custom webhooks
- Container orchestration

**Built-in handlers include**:

- UserNotificationEventHandler
- TokenEventHandler
- ScriptEventHandler
- FederationEventHandler
- CounterEventHandler
- RequestManglerEventHandler
- ResponseManglerEventHandler
- LoggingEventHandler
- CustomUserAttributesHandler
- WebHookHandler
- ContainerEventHandler

```python
from privacyidea.lib.eventhandler.base import BaseEventHandler

class MyEventHandler(BaseEventHandler):
    identifier = "MyHandler"
    description = "My custom event handler"

    def check_condition(self, options=None):
        # Check if this handler should run
        return True

    def do(self, action, options=None):
        # Custom logic here - send notifications, update systems, etc.
        return True
```

### 3. **User Resolvers** (`/custom-resolvers/`)

**What**: Connect to different user directories and authentication sources
**Examples**:

- Active Directory variants
- Custom LDAP schemas
- Database user stores
- Cloud identity providers (Azure AD, Okta, etc.)
- REST API-based user stores
- File-based systems

**Built-in resolvers include**:

- PasswdIdResolver (Unix passwd files)
- LDAPIdResolver (LDAP/Active Directory)
- SQLIdResolver (Database)
- HTTPResolver (REST APIs)
- SCIMIdResolver (SCIM protocol)
- EntraIDResolver (Azure AD/Entra ID)
- KeycloakResolver (Keycloak integration)

```python
from privacyidea.lib.resolvers.UserIdResolver import UserIdResolver

class MyUserResolver(UserIdResolver):

    def __init__(self):
        self.i_am_bound = False

    @staticmethod
    def setup_resolver(config, realm=None):
        # Setup logic for your custom user store
        return config

    def getUserInfo(self, userId):
        # Retrieve user information from your custom source
        return {"username": userId, "email": "user@example.com"}
```

### 4. **Machine Resolvers**

**What**: Connect to machine/device registries
**Examples**:

- Asset management systems
- Device certificates
- IoT device registries

### 5. **Authentication Modules**

**What**: Custom authentication backends and protocols
**Examples**:

- SAML extensions
- OAuth2 providers
- Custom protocols

### 6. **Audit Modules**

**What**: Custom audit logging and analysis
**Examples**:

- SIEM integration
- Custom log formats
- Real-time alerting

### 7. **Challenge Response Systems**

**What**: Custom challenge-response mechanisms
**Examples**:

- Visual puzzles
- Voice challenges
- Custom QR codes

## 🚀 Extension Loading Mechanism

privacyIDEA uses **dynamic module loading** via configuration:

### Configuration Options:

- `PI_TOKEN_MODULES`: Custom token types
- `PI_RESOLVER_MODULES`: Custom user resolvers
- `PI_EVENTHANDLER_MODULES`: Custom event handlers
- `PI_MACHINE_RESOLVER_MODULES`: Custom machine resolvers

### Example Configuration:

```ini
# In pi.cfg or environment variables
PI_TOKEN_MODULES = "privacyidea.lib.tokens.custom.mytoken,privacyidea.lib.tokens.custom.anothertoken"
PI_RESOLVER_MODULES = "mycompany.resolvers.ldap,mycompany.resolvers.api"
```

## 🔧 Development Workflow

1. **Create your extension** in the appropriate directory
2. **Configure loading** in `pi.cfg` or environment variables
3. **Restart privacyIDEA** to load new modules
4. **Test via admin interface** or API

## 📱 Real-World Use Cases

### Enterprise Integration:

- **HR Systems**: Auto-create/disable tokens when employees join/leave
- **Help Desk**: Custom event handlers for password reset workflows
- **Security Teams**: Custom audit modules for SIEM integration

### Custom Authentication:

- **Biometric Integration**: Fingerprint/face recognition tokens
- **Hardware Security**: Smart card or HSM-based tokens
- **Mobile Apps**: Custom mobile app authentication protocols

### Workflow Automation:

- **Provisioning**: Auto-enroll tokens for new users
- **Compliance**: Custom audit trails and reporting
- **Monitoring**: Real-time alerts for security events

## 🎯 Current Setup

Your development environment already supports all these extension types:

- **Tokens**: `plugins/custom-tokens/` ✅ (DemoToken working)
- **Event Handlers**: `plugins/custom-eventhandlers/` ✅ (Ready for development)
- **Resolvers**: `plugins/custom-resolvers/` ✅ (Ready for development)

All plugin directories are live-mounted and ready for development!
