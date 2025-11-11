# Plugin Development Structure

This directory contains custom plugins for privacyIDEA development. The Docker Compose setup mounts these directories directly into the privacyIDEA container for live plugin development.

## Directory Structure

```
plugins/
├── development-README.md     # This file
├── custom-tokens/           # Custom token types
├── custom-eventhandlers/    # Custom event handlers
└── custom-resolvers/        # Custom user resolvers
```

## Plugin Development Workflow

1. **Start the development environment**:

   ```bash
   ./plugin-dev.sh start
   ```

2. **Access the code server** for plugin development (if enabled):
   - URL: http://localhost:8443
   - Password: `developer`

3. **Develop plugins** in the mounted directories:

   ```bash
   # Edit plugins locally
   vim plugins/custom-tokens/demotoken.py
   ```

4. **Restart privacyIDEA** to load new plugins:
   ```bash
   ./plugin-dev.sh restart
   ```

## Plugin Types

### Custom Tokens (`custom-tokens/`)

Create new token types by extending the TokenClass.

Example: `custom-tokens/mytoken.py`

```python
from privacyidea.lib.tokenclass import TokenClass

class MyTokenClass(TokenClass):
    def __init__(self, db_token):
        TokenClass.__init__(self, db_token)
        self.set_type("mytoken")

    def get_class_type(cls):
        return "mytoken"
```

### Event Handlers (`custom-eventhandlers/`)

Create custom event handlers for automation.

Example: `custom-eventhandlers/myhandler.py`

```python
from privacyidea.lib.eventhandler.base import BaseEventHandler

class MyEventHandler(BaseEventHandler):
    identifier = "MyHandler"
    description = "My custom event handler"

    def do(self, action, options=None):
        # Custom logic here
        pass
```

### User Resolvers (`custom-resolvers/`)

Create custom user resolvers for different user stores.

Example: `custom-resolvers/myresolver.py`

```python
from privacyidea.lib.resolvers.UserIdResolver import UserIdResolver

class MyUserResolver(UserIdResolver):

    def __init__(self):
        self.i_am_bound = False

    @staticmethod
    def setup_resolver(config, realm=None):
        # Setup logic
        return config
```

## Testing Plugins

1. **Install plugin dependencies** in the container:

   ```bash
   docker exec -it privacyidea-server pip install your-dependency
   ```

2. **Restart the server** to load plugins:

   ```bash
   docker compose restart privacyidea
   ```

3. **Check logs** for any errors:
   ```bash
   docker logs privacyidea-server
   ```

## Plugin Installation

For plugins to be recognized, ensure they are properly structured and follow privacyIDEA plugin conventions. The container will automatically load Python modules from these directories.
