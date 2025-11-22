#!/bin/bash

echo "=========================================="
echo "Verify Redirect URI Configuration"
echo "=========================================="
echo ""

# From your logs, Spring is sending this redirect_uri:
EXPECTED_REDIRECT_URI="http://localhost:8080/login/oauth2/code/gateway"

echo "Spring is sending this redirect_uri:"
echo "  $EXPECTED_REDIRECT_URI"
echo ""

echo "Your Keycloak Valid redirect URIs should include:"
echo "  ✓ http://localhost:8080/login/oauth2/code/*"
echo "  ✓ http://localhost:8080/login/oauth2/code/gateway"
echo ""

echo "From your screenshot, you have:"
echo "  ✓ http://localhost:8080/login/oauth2/code/*"
echo ""

echo "This SHOULD work because the wildcard (*) matches 'gateway'"
echo ""

echo "=========================================="
echo "Checking Keycloak Client Configuration..."
echo "=========================================="
echo ""

# Get admin token
echo "Step 1: Getting admin access token..."
ADMIN_TOKEN=$(curl -s -X POST "http://keycloak.local:3081/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Failed to get admin token"
    echo "   Trying with 192.168.2.24 instead..."
    
    ADMIN_TOKEN=$(curl -s -X POST "http://192.168.2.24:3081/realms/master/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "username=admin" \
      -d "password=admin" \
      -d "grant_type=password" \
      -d "client_id=admin-cli" | jq -r '.access_token')
    
    if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
        echo "❌ Still failed. Please check Keycloak is running."
        exit 1
    else
        KEYCLOAK_HOST="http://192.168.2.24:3081"
    fi
else
    KEYCLOAK_HOST="http://keycloak.local:3081"
fi

echo "✅ Got admin token"
echo ""

# Get client configuration
echo "Step 2: Fetching app-client configuration..."
CLIENT_CONFIG=$(curl -s -X GET "${KEYCLOAK_HOST}/admin/realms/dev-realm/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.[] | select(.clientId=="app-client")')

if [ -z "$CLIENT_CONFIG" ]; then
    echo "❌ Client 'app-client' not found in realm 'dev-realm'"
    exit 1
fi

echo "✅ Found app-client"
echo ""

# Extract redirect URIs
echo "Step 3: Checking redirect URIs..."
REDIRECT_URIS=$(echo "$CLIENT_CONFIG" | jq -r '.redirectUris[]')

echo "Current Valid redirect URIs in Keycloak:"
echo "$REDIRECT_URIS" | while read -r uri; do
    echo "  ✓ $uri"
done
echo ""

# Check if the expected redirect URI matches
echo "Step 4: Validating..."
MATCHES=false

echo "$REDIRECT_URIS" | while read -r uri; do
    # Convert wildcard pattern to regex
    PATTERN=$(echo "$uri" | sed 's/\*/\.\*/g')
    
    if echo "$EXPECTED_REDIRECT_URI" | grep -qE "^${PATTERN}$"; then
        echo "✅ '$EXPECTED_REDIRECT_URI' matches pattern '$uri'"
        MATCHES=true
    fi
done

if [ "$MATCHES" = "false" ]; then
    echo "⚠️  The redirect URI might not match!"
    echo ""
    echo "Recommendation:"
    echo "  Add this to Valid redirect URIs in Keycloak:"
    echo "    $EXPECTED_REDIRECT_URI"
fi

echo ""
echo "=========================================="
echo "Additional Checks"
echo "=========================================="
echo ""

# Check client authentication
CLIENT_AUTH=$(echo "$CLIENT_CONFIG" | jq -r '.publicClient')
if [ "$CLIENT_AUTH" = "false" ]; then
    echo "✅ Client authentication: ON (confidential client)"
else
    echo "⚠️  Client authentication: OFF (public client)"
    echo "   This might cause issues with client_secret"
fi

# Check standard flow
STANDARD_FLOW=$(echo "$CLIENT_CONFIG" | jq -r '.standardFlowEnabled')
if [ "$STANDARD_FLOW" = "true" ]; then
    echo "✅ Standard flow: Enabled"
else
    echo "❌ Standard flow: Disabled"
    echo "   You need to enable this for authorization_code grant!"
fi

# Check direct access grants
DIRECT_GRANTS=$(echo "$CLIENT_CONFIG" | jq -r '.directAccessGrantsEnabled')
if [ "$DIRECT_GRANTS" = "true" ]; then
    echo "✅ Direct access grants: Enabled"
else
    echo "⚠️  Direct access grants: Disabled (needed for password grant testing)"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If you're still getting 'Invalid parameter: redirect_uri' error:"
echo ""
echo "1. Make sure these URIs are in Keycloak Valid redirect URIs:"
echo "   - http://localhost:8080/login/oauth2/code/*"
echo "   - http://localhost:8080/login/oauth2/code/gateway"
echo ""
echo "2. Check for typos (trailing slashes, http vs https)"
echo ""
echo "3. Make sure you clicked 'Save' in Keycloak after changes"
echo ""
echo "4. Try clearing browser cache/cookies"
echo ""

