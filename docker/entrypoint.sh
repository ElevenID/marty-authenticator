#!/bin/sh
set -eu

echo "Starting privacyIDEA..."

# Wait for database to be ready
echo "Waiting for database connection..."
max_retries=30
retry_count=0
until python3 -c "
import sys
import sqlalchemy as sa
try:
    engine = sa.create_engine('${PI_DB_VENDOR}+pymysql://${PI_DB_USER}:${PI_DB_PASSWORD}@${PI_DB_HOST}:${PI_DB_PORT}/${PI_DB_NAME}')
    engine.connect()
    sys.exit(0)
except Exception:
    sys.exit(1)
" 2>/dev/null || [ $retry_count -eq $max_retries ]; do
    retry_count=$((retry_count+1))
    echo "Database not ready, retrying ($retry_count/$max_retries)..."
    sleep 2
done

if [ $retry_count -eq $max_retries ]; then
    echo "ERROR: Database did not become ready in time"
    exit 1
fi

echo "Database connected successfully!"

# Create encryption key if it doesn't exist
if [ ! -f /etc/privacyidea/enckey ]; then
    echo "Creating encryption key..."
    /opt/privacyidea/bin/pi-manage create_enckey
    # Fix ownership for nonroot user
    chown nonroot:nonroot /etc/privacyidea/enckey || true
fi

# Run database migrations if needed
echo "Running database migrations..."
/opt/privacyidea/bin/pi-manage db upgrade -d /opt/privacyidea/lib/privacyidea/migrations || true

# Create admin user if specified and doesn't exist
if [ -n "${PI_ADMIN_USER:-}" ] && [ -n "${PI_ADMIN_PASSWORD:-}" ]; then
    echo "Checking for admin user..."
    # Try to add admin user (will fail silently if already exists)
    /opt/privacyidea/bin/pi-manage admin add "${PI_ADMIN_USER}" \
        -e "${PI_ADMIN_EMAIL:-admin@localhost}" \
        -p "${PI_ADMIN_PASSWORD}" 2>/dev/null && echo "Admin user created" || echo "Admin user already exists"
fi

# Start the gunicorn process
echo "Starting privacyIDEA server..."
cd /opt/privacyidea
exec python3 -m gunicorn \
    --worker-tmp-dir /dev/shm \
    --bind 0.0.0.0:8080 \
    "privacyidea.app:create_app(config_name='production', config_file='/etc/privacyidea/pi.cfg')"
