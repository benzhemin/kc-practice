#!/bin/bash

# Script to set up Keycloak with Docker networking for proxy debugging
# This is the ONLY way to capture OAuth2 traffic through mitmproxy

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Setting up Keycloak with Docker for proxy debugging"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⚠️  This is necessary because Reactor Netty CANNOT proxy"
echo "   localhost or 127.* addresses (hardcoded bypass)."
echo ""
echo "Solution: Use Docker with custom IP (172.20.0.10)"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Step 1: Create docker-compose.yml with custom network
echo "Step 1: Creating docker-compose.yml with custom network..."
echo ""

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_HTTP_ENABLED: true
      KC_HOSTNAME_STRICT: false
      KC_HOSTNAME: localhost
    command:
      - start-dev
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10  # Custom IP (not 127.*)
    ports:
      - "3081:8080"

networks:
  keycloak-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

echo "✅ Created docker-compose.yml"
echo ""

# Step 2: Stop existing Keycloak if running
echo "Step 2: Stopping existing Keycloak containers..."
docker-compose down 2>/dev/null || true
echo "✅ Stopped existing containers"
echo ""

# Step 3: Start Keycloak
echo "Step 3: Starting Keycloak with custom network..."
docker-compose up -d

echo "✅ Keycloak starting..."
echo ""
echo "Waiting for Keycloak to be ready (this may take 30-60 seconds)..."

# Wait for Keycloak to be ready
for i in {1..60}; do
    if curl -s http://localhost:3081 > /dev/null 2>&1; then
        echo "✅ Keycloak is ready!"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# Step 4: Get Keycloak's IP
echo "Step 4: Verifying Keycloak's IP address..."
KEYCLOAK_IP=$(docker inspect keycloak | grep -m 1 '"IPAddress"' | awk -F'"' '{print $4}')

if [ -z "$KEYCLOAK_IP" ]; then
    KEYCLOAK_IP="172.20.0.10"  # Fallback to configured IP
fi

echo "✅ Keycloak IP: $KEYCLOAK_IP"
echo ""

# Step 5: Update application-proxy.yml
echo "Step 5: Updating application-proxy.yml..."
echo ""

APP_PROXY_YML="src/main/resources/application-proxy.yml"

if [ ! -f "$APP_PROXY_YML" ]; then
    echo "❌ Error: $APP_PROXY_YML not found!"
    exit 1
fi

# Backup original file
cp "$APP_PROXY_YML" "$APP_PROXY_YML.backup-docker"
echo "✅ Created backup: $APP_PROXY_YML.backup-docker"

# Replace localhost:3081 with Docker IP
# Note: Keycloak runs on port 8080 inside container
sed -i.tmp "s|http://[^:]*:3081/realms/dev-realm|http://${KEYCLOAK_IP}:8080/realms/dev-realm|g" "$APP_PROXY_YML"
rm -f "$APP_PROXY_YML.tmp"

echo "✅ Updated $APP_PROXY_YML"
echo ""

# Step 6: Show what was changed
echo "Changes made to $APP_PROXY_YML:"
echo "────────────────────────────────────────────────────────────"
grep "issuer-uri\|jwk-set-uri" "$APP_PROXY_YML"
echo "────────────────────────────────────────────────────────────"
echo ""

# Step 7: Instructions for Keycloak configuration
echo "═══════════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⚠️  IMPORTANT: You must configure Keycloak client redirect URI"
echo ""
echo "1. Access Keycloak admin console:"
echo "   http://localhost:3081"
echo ""
echo "2. Login with:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "3. Go to: dev-realm → Clients → app-client → Settings"
echo ""
echo "4. Add to 'Valid Redirect URIs':"
echo "   http://localhost:8080/*"
echo ""
echo "5. Click 'Save'"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps to test proxy:"
echo ""
echo "1. Start mitmproxy:"
echo "   ./mitm-proxy.sh"
echo ""
echo "2. Start the application:"
echo "   ./gradlew bootRun --args='--spring.profiles.active=proxy'"
echo ""
echo "3. Access the application:"
echo "   open http://localhost:8080/login"
echo ""
echo "4. Check mitmproxy - you should now see:"
echo "   ✅ POST http://${KEYCLOAK_IP}:8080/.../token"
echo "   ✅ GET  http://${KEYCLOAK_IP}:8080/.../certs"
echo "   ✅ GET  http://${KEYCLOAK_IP}:8080/.../userinfo"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "To revert changes:"
echo "  docker-compose down"
echo "  mv $APP_PROXY_YML.backup-docker $APP_PROXY_YML"
echo ""

