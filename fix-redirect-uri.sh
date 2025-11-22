#!/bin/bash

echo "=========================================="
echo "Fix Keycloak Redirect URI Configuration"
echo "=========================================="
echo ""

# Get admin token
echo "Getting admin access token..."
ADMIN_TOKEN=$(curl -s -X POST "http://keycloak.local:3081/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "Trying with 192.168.2.24..."
    ADMIN_TOKEN=$(curl -s -X POST "http://192.168.2.24:3081/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin" \
      -d "password=admin" \
      -d "grant_type=password" \
      -d "client_id=admin-cli" | jq -r '.access_token')
    
    if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
        echo "❌ Failed to get admin token"
        exit 1
    fi
    KEYCLOAK_HOST="http://192.168.2.24:3081"
else
    KEYCLOAK_HOST="http://keycloak.local:3081"
fi

echo "✅ Got admin token"
echo ""

# Get client ID (internal UUID)
echo "Fetching client configuration..."
CLIENT_DATA=$(curl -s -X GET "${KEYCLOAK_HOST}/admin/realms/dev-realm/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.[] | select(.clientId=="app-client")')

CLIENT_UUID=$(echo "$CLIENT_DATA" | jq -r '.id')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
    echo "❌ Client 'app-client' not found"
    exit 1
fi

echo "✅ Found client (UUID: $CLIENT_UUID)"
echo ""

# Show current redirect URIs
echo "Current redirect URIs:"
echo "$CLIENT_DATA" | jq -r '.redirectUris[]' | while read -r uri; do
    echo "  - $uri"
done
echo ""

# Update redirect URIs
echo "Updating redirect URIs..."

# Prepare the new redirect URIs array
NEW_REDIRECT_URIS='["http://localhost:8080/login/oauth2/code/*", "http://localhost:8080/*", "http://localhost:8080"]'

# Update the client
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X PUT "${KEYCLOAK_HOST}/admin/realms/dev-realm/clients/${CLIENT_UUID}" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(echo "$CLIENT_DATA" | jq --argjson redirectUris "$NEW_REDIRECT_URIS" '.redirectUris = $redirectUris')")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Successfully updated redirect URIs!"
    echo ""
    echo "New redirect URIs:"
    echo "  - http://localhost:8080/login/oauth2/code/*"
    echo "  - http://localhost:8080/*"
    echo "  - http://localhost:8080"
    echo ""
    echo "🎉 Configuration fixed!"
    echo ""
    echo "Now try logging in again: http://localhost:8080/login"
else
    echo "❌ Failed to update (HTTP $HTTP_CODE)"
    echo "$RESPONSE" | sed '/HTTP_CODE:/d'
fi

