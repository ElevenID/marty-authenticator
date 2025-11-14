# privacyIDEA Development Setup

This directory contains a complete Docker-based development environment for privacyIDEA with custom plugin support.

## 🚀 Quick Start

1. **Start the full development environment:**

   ```bash
   ./plugin-dev.sh start
   ```

2. **Access the services:**
   - **privacyIDEA Admin Console**: http://localhost:8080
     - Username: `testadmin`
     - Password: `admin123` # pragma: allowlist secret
   - **Plugin Development Environment**: http://localhost:8443
     - Password: `development` # pragma: allowlist secret
   - **MySQL Database**: `localhost:3306`
     - Username: `privacyidea`
     - Password: `privacyidea123` # pragma: allowlist secret

## 🔧 Plugin Development

### Custom Plugins Available

- **DemoToken** (`plugins/custom-tokens/demotoken.py`): Example token plugin for authenticator app integration
- **Custom Event Handlers** (`plugins/custom-eventhandlers/`): Example event handlers
- **Custom Resolvers** (`plugins/custom-resolvers/`): Example user resolvers

### Plugin Development Workflow

1. **Edit plugins** in the `plugins/` directory
2. **Restart privacyIDEA** to reload plugins:
   ```bash
   ./plugin-dev.sh restart
   ```
3. **Test in admin console** at http://localhost:8080

### Live Development

- Plugins are mounted as volumes for live editing
- Use the Code Server at http://localhost:8443 for web-based development
- All changes are reflected immediately after container restart

## 📖 Available Commands

```bash
./plugin-dev.sh [command]

Commands:
  start         Start all services (with build and initialization)
  stop          Stop all services
  restart       Restart privacyIDEA server (reload plugins)
  logs          Show privacyIDEA server logs
  dev           Open development environment
  test-plugin   Test plugin installation
  clean         Clean up containers and volumes
  status        Show service status
```

## 🧪 Testing DemoToken Plugin

1. **Login to admin console**: http://localhost:8080 (testadmin/admin123)
2. **Navigate to**: Tokens → Enroll Token
3. **Select**: "DemoToken" from the dropdown
4. **Configure** the token for a user in `demorealm`
5. **Scan QR code** with Flutter authenticator app
6. **Test authentication** via API or admin interface

## 🔗 API Testing

Test the validation API:

```bash
# Validate a token (replace with actual values)
curl -X POST "http://localhost:8080/validate/check" \
  -d "user=testuser&realm=demorealm&pass=123456" \
  -H "Content-Type: application/x-www-form-urlencoded"
```

## 🐛 Troubleshooting

### Check Service Status

```bash
./plugin-dev.sh status
```

### View Logs

```bash
./plugin-dev.sh logs
```

### Reset Environment

```bash
./plugin-dev.sh clean
./plugin-dev.sh start
```

### Manual Initialization

If automatic initialization fails:

```bash
cd docker
./init-privacyidea.sh
```

## 📁 Directory Structure

```
docker/
├── docker-compose.yml          # Main service definitions
├── init-privacyidea.sh        # Initialization script
└── README.md                  # This file

plugins/
├── custom-tokens/             # Custom token plugins
│   └── demotoken.py          # Example token for authenticator apps
├── custom-eventhandlers/     # Custom event handler plugins
└── custom-resolvers/         # Custom user resolver plugins
```

## 🔐 Security Notes

- Default passwords are for development only
- Change all default credentials in production
- Plugin directory is mounted with write access for development
- Database credentials are stored in environment variables

## 📚 Resources

- [privacyIDEA Documentation](https://privacyidea.readthedocs.io/)
- [Plugin Development Guide](https://privacyidea.readthedocs.io/en/latest/installation/index.html#plugin-development)
- [REST API Documentation](https://privacyidea.readthedocs.io/en/latest/modules/api/index.html)
