#!/bin/bash

# Test Keycloak Client Configuration
# This script helps diagnose "Invalid client or Invalid client credentials" errors

echo "=========================================="
echo "Keycloak Client Configuration Test"
echo "=========================================="
echo ""

# Configuration
KEYCLOAK_URL="http://192.168.2.24:3081"
REALM="dev-realm"
CLIENT_ID="app-client"
CLIENT_SECRET="FQQfVbUasU5SACttjYmeZmdv7I3l5moG"
USERNAME="john"
PASSWORD="john123"

TOKEN_ENDPOINT="${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"

echo "Configuration:"
echo "  Keycloak URL: ${KEYCLOAK_URL}"
echo "  Realm: ${REALM}"
echo "  Client ID: ${CLIENT_ID}"
echo "  Client Secret: ${CLIENT_SECRET:0:10}..."
echo ""

# Test 1: Check if Keycloak is accessible
echo "Test 1: Checking Keycloak accessibility..."
if curl -s -f "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" > /dev/null; then
    echo "✅ Keycloak is accessible"
else
    echo "❌ Cannot reach Keycloak at ${KEYCLOAK_URL}"
    exit 1
fi
echo ""

# Test 2: Try token exchange with client_secret_basic (Authorization header)
echo "Test 2: Testing client authentication with client_secret_basic (Authorization header)..."
echo "  Method: Authorization: Basic base64(client_id:client_secret)"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)" \
  -d "grant_type=password" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS with client_secret_basic!"
    echo ""
    echo "Response (first 500 chars):"
    echo "$BODY" | head -c 500
    echo ""
    echo ""
    echo "🎉 Your client authentication is working!"
    echo "   Spring Security should use: client-authentication-method: client_secret_basic"
    exit 0
else
    echo "❌ FAILED with HTTP $HTTP_CODE"
    echo "Response:"
    echo "$BODY"
    echo ""
fi

# Test 3: Try token exchange with client_secret_post (in POST body)
echo "Test 3: Testing client authentication with client_secret_post (POST body)..."
echo "  Method: client_id and client_secret in POST body"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS with client_secret_post!"
    echo ""
    echo "Response (first 500 chars):"
    echo "$BODY" | head -c 500
    echo ""
    echo ""
    echo "🎉 Your client authentication is working!"
    echo "   Spring Security should use: client-authentication-method: client_secret_post"
    exit 0
else
    echo "❌ FAILED with HTTP $HTTP_CODE"
    echo "Response:"
    echo "$BODY"
    echo ""
fi

# Test 4: Try with just client_id (public client test)
echo "Test 4: Testing as public client (no secret)..."
echo "  Method: Only client_id, no secret"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "${TOKEN_ENDPOINT}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=${CLIENT_ID}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS as public client!"
    echo ""
    echo "⚠️  WARNING: Your client is configured as PUBLIC (no secret required)"
    echo "   This is insecure for server-side applications!"
    echo "   You should enable 'Client authentication' in Keycloak"
    exit 0
else
    echo "❌ FAILED with HTTP $HTTP_CODE"
    echo "Response:"
    echo "$BODY"
    echo ""
fi

echo "=========================================="
echo "All tests failed!"
echo "=========================================="
echo ""
echo "Possible issues:"
echo "1. Client secret is incorrect"
echo "   → Check Keycloak: Clients → app-client → Credentials tab"
echo ""
echo "2. Client authentication is disabled"
echo "   → Check Keycloak: Clients → app-client → Settings → Client authentication: ON"
echo ""
echo "3. Direct access grants is disabled"
echo "   → Check Keycloak: Clients → app-client → Settings → Direct access grants: Enabled"
echo ""
echo "4. User credentials are wrong"
echo "   → Verify username: ${USERNAME}, password: ${PASSWORD}"
echo ""
echo "5. Client doesn't exist or is in wrong realm"
echo "   → Verify client 'app-client' exists in realm '${REALM}'"
echo ""

