# privacyIDEA Authenticator Demo Setup

This setup provides a complete demonstration environment for testing the privacyIDEA Authenticator app with a local backend server **and containerized Flutter web app**.

## Components

- **privacyIDEA Authenticator (Web)**: Containerized Flutter web app accessible via browser
- **privacyIDEA Server**: Backend authentication server with web UI
- **MySQL Database**: Database for storing authentication tokens and user data
- **Plugin Development Environment**: Code server for developing custom plugins

## Quick Start

### 1. Start the Complete Stack

```bash
# Start all services (backend + web app + development environment)
docker compose up -d --build

# Check that all services are running
docker ps
```

This will start:

- MySQL database on port 3306
- privacyIDEA server on port 8080
- Flutter web app on port 3000
- Plugin development server on port 8443

### 2. Access the Interfaces

**Flutter Authenticator Web App**: http://localhost:3000/

- The containerized authenticator app ready for testing

**privacyIDEA Admin Interface**: http://localhost:8080/

- Username: `admin`
- Password: `admin123`

**Plugin Development Environment**: http://localhost:8443/

- Password: `developer`
- Web-based VS Code for plugin development

### 3. Develop Custom Plugins

The setup includes mounted directories for plugin development:

```bash
# Plugin directories are automatically mounted:
./docker/plugins/       # General plugins
./docker/plugins/custom-tokens/        # Custom token types
./docker/plugins/custom-eventhandlers/ # Event handlers
./docker/plugins/custom-resolvers/     # User resolvers
```

**Development Workflow**:

1. Access code server at http://localhost:8443
2. Edit plugins in the mounted directories
3. Restart privacyIDEA to load changes: `docker compose restart privacyidea`

## Demo Workflow

### Initial Setup

1. **Access the privacyIDEA Admin Interface**:
   - Navigate to http://localhost:8080/
   - Login with `admin` / `admin123`

2. **Create a Test User**:
   - Go to Users → Create User
   - Username: `testuser`
   - Password: `test123`

3. **Enroll a TOTP Token**:
   - Go to Tokens → Enroll Token
   - Select "TOTP" token type
   - Choose the test user
   - Generate QR code

### Testing with the Web App

1. **QR Code Enrollment**:
   - In the authenticator web app (http://localhost:3000)
   - Use the enrollment feature to scan QR codes
   - Tokens will be added to the web interface

2. **Generate OTP Codes**:
   - Use the web app to generate OTP codes
   - Test authentication in the admin interface

3. **Plugin Testing**:
   - Install the demo token plugin
   - Test custom token enrollment and authentication

## Plugin Development

### Quick Plugin Development

1. **Access the development environment**:

   ```bash
   # Open code server in browser
   open http://localhost:8443
   # Password: developer
   ```

2. **Create a custom token**:

   ```bash
   # Edit files in the code server or locally
   # Files are in ./custom-tokens/
   # Example: demotoken.py is already provided
   ```

3. **Test the plugin**:

   ```bash
   # Restart privacyIDEA to load new plugins
   docker compose restart privacyidea

   # Check logs for errors
   docker logs privacyidea-server
   ```

### Plugin Types Available

- **Custom Tokens** (`custom-tokens/`): New token types for authentication
- **Event Handlers** (`custom-eventhandlers/`): Automation and notifications
- **User Resolvers** (`custom-resolvers/`): Custom user directory integration
- **General Plugins** (`docker/plugins/`): Other extensions

### Example: Demo Token Plugin

The setup includes a demo token plugin at `custom-tokens/demotoken.py` that demonstrates:

- Custom token enrollment
- QR code generation
- Challenge-response authentication
- Integration with the Flutter web app

## Container Management

```bash
# View logs
docker logs privacyidea-server
docker logs privacyidea-mysql

# Stop services
docker compose down

# Start services
docker compose up -d

# Remove everything (including data)
docker compose down -v
```

## Database Access

If you need direct database access:

- Host: `localhost:3306`
- Database: `privacyidea`
- Username: `pi_user`
- Password: `pi_password`

## API Testing

The privacyIDEA API is available at `http://localhost:8080/`. Key endpoints:

- **Authentication**: `/auth`
- **Token management**: `/token/`
- **User management**: `/user/`
- **Admin interface**: `/`

Example API call:

```bash
# Get server info
curl http://localhost:8080/
```

## Troubleshooting

### Container Issues

```bash
# Check container status
docker ps -a

# View detailed logs
docker logs -f privacyidea-server

# Restart services
docker compose restart
```

### Network Issues

- Ensure ports 8080 and 3306 are not in use by other applications
- Check firewall settings if accessing from other devices

### App Connection Issues

- Verify the app can reach http://localhost:8080 from the browser
- Check that CORS is properly configured if testing from different origins

## Configuration

The Docker Compose setup includes:

- **MySQL 8.0** database with persistent storage
- **privacyIDEA server** configured for development
- **Persistent volumes** for data retention
- **Health checks** for service monitoring

Environment variables can be modified in `docker-compose.yml` to customize the setup.

## Security Note

This is a development/demo setup with default passwords and keys. **Do not use in production** without proper security configuration.
