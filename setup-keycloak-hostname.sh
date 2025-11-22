#!/bin/bash

# Setup script for Keycloak hostname with Colima
# This script adds keycloak.local to /etc/hosts pointing to the Docker container IP

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🔧 KEYCLOAK HOSTNAME SETUP FOR COLIMA"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if Colima is running
if ! colima status &> /dev/null; then
    echo "❌ Colima is not running!"
    echo "   Start it with: colima start --cpu 1 --memory 2 --disk 10"
    exit 1
fi

echo "✅ Colima is running"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose not found!"
    exit 1
fi

echo "Step 1: Starting Keycloak container..."
docker-compose up -d keycloak

echo ""
echo "Step 2: Waiting for container to be ready..."
sleep 3

# Get the container IP
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keycloak)

if [ -z "$CONTAINER_IP" ]; then
    echo "❌ Could not get container IP!"
    echo "   Container might not be running."
    exit 1
fi

echo "✅ Container IP: $CONTAINER_IP"
echo ""

# Check if we need to update /etc/hosts
HOSTNAME="keycloak.local"
HOSTS_ENTRY="$CONTAINER_IP $HOSTNAME"

if grep -q "$HOSTNAME" /etc/hosts; then
    echo "⚠️  $HOSTNAME already exists in /etc/hosts"
    echo ""
    echo "Current entry:"
    grep "$HOSTNAME" /etc/hosts
    echo ""
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Updating /etc/hosts (requires sudo)..."
        sudo sed -i.bak "/$HOSTNAME/d" /etc/hosts
        echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
        echo "✅ Updated /etc/hosts"
    fi
else
    echo "Adding $HOSTNAME to /etc/hosts (requires sudo)..."
    echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ Added to /etc/hosts"
fi

echo ""
echo "Step 3: Verifying setup..."
echo ""

# Test DNS resolution
RESOLVED_IP=$(getent hosts $HOSTNAME | awk '{ print $1 }')
if [ "$RESOLVED_IP" = "$CONTAINER_IP" ]; then
    echo "✅ DNS resolution: $HOSTNAME → $CONTAINER_IP"
else
    echo "⚠️  DNS resolution mismatch!"
    echo "   Expected: $CONTAINER_IP"
    echo "   Got: $RESOLVED_IP"
fi

echo ""
echo "Step 4: Testing connectivity..."

# Wait for Keycloak to be ready
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://$HOSTNAME:3081" | grep -q "200\|302\|303"; then
        echo "✅ Keycloak is accessible at http://$HOSTNAME:3081"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "⚠️  Keycloak not responding yet (might still be starting up)"
        echo "   Try accessing: http://$HOSTNAME:3081"
    else
        echo -n "."
        sleep 1
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ SETUP COMPLETE!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📌 Keycloak is accessible at:"
echo "   - From host (browser): http://keycloak.local:3081"
echo "   - From host (localhost): http://localhost:3081"
echo "   - Container IP: $CONTAINER_IP:3081"
echo ""
echo "📌 Why keycloak.local?"
echo "   - Reactor Netty bypasses proxy for 'localhost' and '127.*'"
echo "   - Using 'keycloak.local' (resolving to $CONTAINER_IP)"
echo "   - This allows proxy to intercept OAuth2 traffic!"
echo ""
echo "📌 Next steps:"
echo "   1. Update application-proxy.yml to use keycloak.local"
echo "   2. Start mitmproxy: ./mitm-proxy.sh"
echo "   3. Start app: ./gradlew bootRun --args='--spring.profiles.active=proxy'"
echo ""
echo "═══════════════════════════════════════════════════════════"

