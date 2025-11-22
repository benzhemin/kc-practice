#!/bin/bash

# Script to set up custom hostname for proxy debugging
# This bypasses Reactor Netty's hardcoded localhost proxy exclusion

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Setting up custom hostname for proxy debugging"
echo "═══════════════════════════════════════════════════════════"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Please run this script as a normal user (it will ask for sudo when needed)"
    exit 1
fi

# Step 1: Add keycloak.local to /etc/hosts
echo ""
echo "Step 1: Adding 'keycloak.local' to /etc/hosts..."
echo ""

if grep -q "keycloak.local" /etc/hosts; then
    echo "✅ keycloak.local already exists in /etc/hosts"
else
    echo "Adding: 127.0.0.1  keycloak.local"
    echo "127.0.0.1  keycloak.local" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ Added keycloak.local to /etc/hosts"
fi

# Verify
echo ""
echo "Verifying /etc/hosts entry:"
grep "keycloak.local" /etc/hosts

# Step 2: Update application-proxy.yml
echo ""
echo "Step 2: Updating application-proxy.yml..."
echo ""

APP_PROXY_YML="src/main/resources/application-proxy.yml"

if [ ! -f "$APP_PROXY_YML" ]; then
    echo "❌ Error: $APP_PROXY_YML not found!"
    exit 1
fi

# Backup original file
cp "$APP_PROXY_YML" "$APP_PROXY_YML.backup"
echo "✅ Created backup: $APP_PROXY_YML.backup"

# Replace localhost with keycloak.local in issuer-uri and jwk-set-uri
sed -i.tmp 's|http://localhost:3081/realms/dev-realm|http://keycloak.local:3081/realms/dev-realm|g' "$APP_PROXY_YML"
rm -f "$APP_PROXY_YML.tmp"

echo "✅ Updated $APP_PROXY_YML"

# Step 3: Show what was changed
echo ""
echo "Changes made to $APP_PROXY_YML:"
echo "────────────────────────────────────────────────────────────"
grep "issuer-uri\|jwk-set-uri" "$APP_PROXY_YML"
echo "────────────────────────────────────────────────────────────"

# Step 4: Test hostname resolution
echo ""
echo "Step 3: Testing hostname resolution..."
echo ""

if ping -c 1 keycloak.local > /dev/null 2>&1; then
    echo "✅ keycloak.local resolves correctly to 127.0.0.1"
else
    echo "❌ Error: keycloak.local does not resolve!"
    echo "Please check /etc/hosts"
    exit 1
fi

# Step 5: Instructions
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
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
echo "   ✅ POST http://keycloak.local:3081/.../token"
echo "   ✅ GET  http://keycloak.local:3081/.../certs"
echo "   ✅ GET  http://keycloak.local:3081/.../userinfo"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "To revert changes:"
echo "  mv $APP_PROXY_YML.backup $APP_PROXY_YML"
echo "  sudo sed -i '' '/keycloak.local/d' /etc/hosts"
echo ""

