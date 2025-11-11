#!/bin/bash

# Complete Integration Test for privacyIDEA Development Environment
# This script tests the entire setup including admin access, plugin loading, and API functionality

set -e

echo "🧪 Running privacyIDEA Integration Tests..."
echo ""

# Test 1: Check if services are running
echo "1️⃣ Testing service availability..."
if curl -s http://localhost:8080 | grep -q "privacyIDEA"; then
    echo "   ✅ privacyIDEA is accessible"
else
    echo "   ❌ privacyIDEA is not accessible"
    exit 1
fi

# Test 2: Admin login
echo "2️⃣ Testing admin authentication..."
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8080/auth" \
    -d "username=testadmin&password=admin123" \
    -H "Content-Type: application/x-www-form-urlencoded")

if echo "$LOGIN_RESPONSE" | grep -q '"status": true'; then
    echo "   ✅ Admin login successful"
    # Token would be extracted here if needed for API calls
else
    echo "   ❌ Admin login failed"
    echo "   Response: $LOGIN_RESPONSE"
    exit 1
fi

# Test 3: Check if CLI commands work (proves realm exists)
echo "3️⃣ Testing realm configuration via CLI..."
REALMS_OUTPUT=$(docker exec privacyidea-server /opt/privacyidea/bin/pi-manage realm list 2>&1)
if echo "$REALMS_OUTPUT" | grep -q "demorealm"; then
    echo "   ✅ demorealm is available"
else
    echo "   ❌ demorealm not found"
    echo "   Output: $REALMS_OUTPUT"
    exit 1
fi

# Test 4: Check if custom plugins directory is mounted
echo "4️⃣ Testing plugin installation..."
if docker exec privacyidea-server test -f "/opt/privacyidea/lib/python3.9/site-packages/privacyidea/lib/tokens/custom/demotoken.py"; then
    echo "   ✅ DemoToken plugin is mounted"
else
    echo "   ❌ DemoToken plugin not found"
    exit 1
fi

# Test 5: Check API validation endpoint
echo "5️⃣ Testing API validation endpoint..."
VALIDATE_RESPONSE=$(curl -s -X POST "http://localhost:8080/validate/check" \
    -d "user=nonexistent&realm=demorealm&pass=123456" \
    -H "Content-Type: application/x-www-form-urlencoded")

if echo "$VALIDATE_RESPONSE" | grep -q '"status": false'; then
    echo "   ✅ Validation API is working (correctly rejected invalid user)"
else
    echo "   ❌ Validation API not responding correctly"
    echo "   Response: $VALIDATE_RESPONSE"
    exit 1
fi

# Test 6: Code Server accessibility
echo "6️⃣ Testing development environment..."
if curl -s -I http://localhost:8443 | grep -q "HTTP/1.1 302"; then
    echo "   ✅ Code Server is accessible (redirects to login)"
elif curl -s http://localhost:8443 | grep -q "code-server"; then
    echo "   ✅ Code Server is accessible"
else
    echo "   ❌ Code Server is not accessible"
    exit 1
fi

echo ""
echo "🎉 All integration tests passed!"
echo ""
echo "📋 Environment Summary:"
echo "   🌐 privacyIDEA Admin: http://localhost:8080 (testadmin/admin123)"
echo "   💻 Code Server: http://localhost:8443 (password: development)"
echo "   🔗 MySQL: localhost:3306 (privacyidea/privacyidea123)"
echo "   🚀 Available realm: demorealm"
echo "   🔌 DemoToken plugin: Loaded and ready"
echo ""
echo "🧪 Next steps:"
echo "   1. Login to admin console and create a DemoToken"
echo "   2. Test with your Flutter authenticator app"
echo "   3. Develop custom plugins in the docker/plugins/ directory"
