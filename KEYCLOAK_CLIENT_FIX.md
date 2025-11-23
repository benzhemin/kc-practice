# Fix: Invalid client or Invalid client credentials

## Problem
Your Spring application is getting `401 Unauthorized` with error:
```
[unauthorized_client] Invalid client or Invalid client credentials
```

## Root Cause
The client secret in your `application.yml` does NOT match the secret in Keycloak.

Current secret in config: `FQQfVbUasU5SACttjYmeZmdv7I3l5moG`

## Solution Steps

### Step 1: Access Keycloak Admin Console

1. Open browser: `http://192.168.2.24:3081/admin`
2. Login:
   - Username: `admin`
   - Password: `admin`

### Step 2: Navigate to Client

1. Make sure you're in **dev-realm** (check top-left dropdown)
2. Click **"Clients"** in the left sidebar
3. Find and click **"app-client"** in the list

### Step 3: Get the Correct Client Secret

#### Method A: View Existing Secret

1. Click the **"Credentials"** tab (top tabs)
2. You should see:
   ```
   Client Authenticator: Client Id and Secret
   Client Secret: ••••••••••••••••••••
   ```
3. Click the **eye icon** (👁️) to reveal the secret
4. Click the **copy icon** (📋) to copy it
5. **Write it down or copy to clipboard**

#### Method B: Regenerate New Secret (if you can't see the old one)

1. Click the **"Credentials"** tab
2. Click the **"Regenerate"** button next to Client Secret
3. Confirm the regeneration
4. The new secret will be displayed
5. Click the **copy icon** (📋) to copy it
6. **Save this secret!**

### Step 4: Verify Client Settings

While you're in the client configuration, verify these settings:

**Settings Tab → Capability config:**
- ✅ **Client authentication**: Must be **ON**
- ✅ **Standard flow**: Must be **Enabled**
- ✅ **Direct access grants**: Must be **Enabled** (for testing)

**Settings Tab → Access settings:**
- **Valid redirect URIs**: Should have:
  - `http://localhost:8080/login/oauth2/code/*`
  - OR `http://localhost:8080/login/oauth2/code/gateway`

**Settings Tab → Advanced → Client Authenticator:**
- Should be: **"Client Id and Secret"**

Click **"Save"** if you made any changes.

### Step 5: Update application.yml

Replace the secret in your `src/main/resources/application.yml`:

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          gateway:
            client-id: app-client
            client-secret: YOUR_NEW_SECRET_HERE  # ← Replace this
            scope: openid,profile,email
            authorization-grant-type: authorization_code
            redirect-uri: "{baseUrl}/login/oauth2/code/gateway"
            client-authentication-method: client_secret_basic
```

### Step 6: Test the Configuration

Run the test script again:

```bash
# Update the secret in the script first
nano test-keycloak-client.sh
# Change CLIENT_SECRET="..." to your new secret

# Run the test
./test-keycloak-client.sh
```

You should see:
```
✅ SUCCESS with client_secret_basic!
```

### Step 7: Restart Your Application

```bash
./gradlew bootRun
```

Then test the login flow:
```
http://localhost:8080/login
```

## Quick Verification Commands

### Check if client exists:
```bash
curl -s "http://192.168.2.24:3081/realms/dev-realm/.well-known/openid-configuration" | jq .
```

### Test with correct secret (after you get it):
```bash
curl -X POST "http://192.168.2.24:3081/realms/dev-realm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic $(echo -n 'app-client:YOUR_SECRET' | base64)" \
  -d "grant_type=password" \
  -d "username=john" \
  -d "password=john123"
```

If this returns a token, your secret is correct!

## Common Mistakes

1. ❌ **Copied secret with extra spaces** → Trim whitespace
2. ❌ **Using old/expired secret** → Regenerate if unsure
3. ❌ **Client authentication is OFF** → Must be ON for confidential clients
4. ❌ **Wrong realm** → Make sure you're in `dev-realm`, not `master`
5. ❌ **Direct access grants disabled** → Enable it for testing

## Alternative: Use Public Client (Not Recommended for Production)

If you want to test without a secret (public client):

1. In Keycloak: Clients → app-client → Settings
2. Set **Client authentication**: **OFF**
3. Save
4. In `application.yml`, remove the `client-secret` line
5. Add: `client-authentication-method: none`

**⚠️ Warning:** Public clients are less secure and should only be used for SPAs/mobile apps, not server-side applications!

## Next Steps

After fixing the secret:
1. ✅ Restart your Spring application
2. ✅ Test login: `http://localhost:8080/login`
3. ✅ You should be redirected to Keycloak login
4. ✅ Login with `john` / `john123`
5. ✅ You should be redirected back to your app
6. ✅ Check the logs - no more 401 errors!


