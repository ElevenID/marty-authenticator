# privacyIDEA Authenticator with Plugin Development Environment

A complete development and demo setup for the privacyIDEA Flutter authenticator app with custom plugin development capabilities.

## 📁 **Project Structure**

```
marty-authenticator/
├── docker/                     # Docker configuration
│   ├── docker-compose.yml      # Complete stack definition
│   ├── Dockerfile.flutter      # Flutter web app container
│   ├── .dockerignore           # Docker build optimization
│   └── plugins/                # Plugin development
│       ├── custom-tokens/      # Custom token implementations
│       ├── custom-eventhandlers/ # Event automation plugins
│       ├── custom-resolvers/   # User directory integrations
│       └── development-README.md # Plugin development guide
├── lib/                        # Flutter app source code
├── scripts/
│   ├── plugin-dev.sh           # Development helper script
│   └── ...                     # Other utility scripts
├── DEMO_TOKEN_TESTING.md       # Demo token testing guide
└── ...                        # Other Flutter project files
```

## 🚀 **Quick Start**

### **Start Complete Environment**

````bash
# Start backend + database + plugin development
### Start Services

```bash
./scripts/plugin-dev.sh start
````

Check status:
./scripts/plugin-dev.sh status

# Access interfaces

open http://localhost:8080 # Admin interface (admin/admin123)
open http://localhost:8443 # Plugin development (developer)

````

### **Develop Plugins**
```bash
# Edit plugins
vim docker/plugins/custom-tokens/demotoken.py

# Reload changes
### Reload Plugin Changes

```bash
## Getting Started (Quick)

```bash
./scripts/plugin-dev.sh start
````

## Manual Setup Steps

1. **Restart Services** (after plugin changes):
   ./scripts/plugin-dev.sh restart

```
Test the plugin:
./scripts/plugin-dev.sh test-plugin
```

### **Run Flutter App**

```bash
# Run against local backend
flutter run -d chrome -t lib/main_document.dart

# App will connect to http://localhost:8080
```

## 🔧 **Components**

### **Backend Stack**

- **privacyIDEA Server**: Authentication server with plugin support
- **MySQL Database**: Persistent token and user storage
- **Plugin Development**: Live-mounted plugin directories

### **Development Tools**

- **Helper Script**: `./scripts/plugin-dev.sh` for easy management
- **Plugin Hot-reload**: Edit plugins, restart server, test immediately
- **Example Plugin**: Working demo token included

### **Plugin Types Supported**

1. **Custom Tokens** (`docker/plugins/custom-tokens/`): New authentication methods
2. **Event Handlers** (`docker/plugins/custom-eventhandlers/`): Automation workflows
3. **User Resolvers** (`docker/plugins/custom-resolvers/`): Custom user directories

## 📱 **Demo Token Plugin**

Includes a fully functional demo token plugin that demonstrates:

- Custom token class implementation
- QR code generation for mobile enrollment
- Challenge-response authentication
- Flutter app integration patterns

**Test the demo token**: Follow the guide in [`DEMO_TOKEN_TESTING.md`](./DEMO_TOKEN_TESTING.md)

## 🔄 **Development Workflow**

### **1. Plugin Development**

```bash
# Start environment
./plugin-dev.sh start

# Edit plugin files in docker/plugins/
vim docker/plugins/custom-tokens/mytoken.py

# Restart to load changes
./plugin-dev.sh restart

# Test in admin interface
open http://localhost:8080
```

### **2. Flutter App Development**

```bash
# Run app with backend connection
flutter run -d chrome -t lib/main_document.dart

# App connects to localhost:8080 for:
# - Token enrollment via QR codes
# - Authentication testing
# - API integration
```

### **3. Testing & Demo**

```bash
# Test specific plugin
./scripts/plugin-dev.sh test-plugin

# View logs
./scripts/plugin-dev.sh logs

# Clean environment
./scripts/plugin-dev.sh clean
```

## 🎯 **Key Benefits**

### **For Development**

- ✅ **No Local Installation**: Everything runs in containers
- ✅ **Live Plugin Development**: Edit locally, reload instantly
- ✅ **Complete Backend**: Full privacyIDEA functionality
- ✅ **Database Persistence**: Data survives container restarts

### **For Demos**

- ✅ **Single Command Setup**: `./scripts/plugin-dev.sh start`
- ✅ **Self-Contained**: No external dependencies
- ✅ **Multiple Interfaces**: Admin UI + Development tools
- ✅ **Example Content**: Demo token and test users ready

### **For Plugin Development**

- ✅ **Multiple Plugin Types**: Tokens, handlers, resolvers
- ✅ **Working Examples**: Demo token shows best practices
- ✅ **Hot Reload**: Fast development cycle
- ✅ **API Access**: Test via web UI and REST API

## 📋 **Available Commands**

```bash
./scripts/plugin-dev.sh start         # Start all services
./scripts/plugin-dev.sh stop          # Stop all services
./scripts/plugin-dev.sh restart       # Restart privacyIDEA (reload plugins)
./scripts/plugin-dev.sh status        # Show service status
./scripts/plugin-dev.sh logs          # View privacyIDEA logs
./scripts/plugin-dev.sh test-plugin   # Test demo token plugin
./scripts/plugin-dev.sh dev           # Open development environment
./scripts/plugin-dev.sh clean         # Clean up everything
```

## 🔗 **Access Points**

- **privacyIDEA Admin**: http://localhost:8080 (`admin`/`admin123`)
- **Plugin Development**: http://localhost:8443 (`developer`)
- **Database**: localhost:3306 (`pi_user`/`pi_password`)
- **Flutter App**: Run locally or via container (port 3000)

## 📚 **Documentation**

- [`DEMO_TOKEN_TESTING.md`](./DEMO_TOKEN_TESTING.md) - Test the demo token plugin
- [`docker/plugins/development-README.md`](./docker/plugins/development-README.md) - Plugin development guide
- [`ENHANCED_SETUP_SUMMARY.md`](./ENHANCED_SETUP_SUMMARY.md) - Detailed setup information

## 🎉 **Ready to Use**

This environment provides everything needed for:

- **Flutter authenticator app development**
- **privacyIDEA plugin development**
- **Complete authentication system testing**
- **Live demos and presentations**

Start with `./scripts/plugin-dev.sh start` and begin exploring! 🚀
