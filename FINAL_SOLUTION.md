# FINAL SOLUTION: Proxy Not Capturing OAuth2 Traffic

## The Problem

After extensive investigation, the issue is **HARDCODED in Reactor Netty** and cannot be fixed with configuration alone.

### Evidence from Logs

```
Line 127: [bd628806-1, L:/127.0.0.1:53951 - R:localhost/127.0.0.1:3081]
Line 141: [94bb06b1-1, L:/127.0.0.1:53952 - R:localhost/127.0.0.1:3081]
Line 154: [bd628806-2, L:/127.0.0.1:53951 - R:localhost/127.0.0.1:3081]
                                                                  ^^^^
                                                          Still going to :3081!
                                                          Should be :8888 (proxy)
```

## Root Cause

Reactor Netty has **hardcoded logic** in `ProxyProvider.java`:

```java
static final Predicate<String> NO_PROXY_PREDICATE = 
    s -> s != null && (
        s.startsWith("localhost") ||  // ⚠️ HARDCODED!
        s.startsWith("127.") ||        // ⚠️ HARDCODED!
        s.startsWith("[::1]")          // ⚠️ HARDCODED!
    );

boolean shouldProxy(@Nullable SocketAddress address) {
    // This check happens BEFORE any configuration is evaluated!
    if (isa.isUnresolved() && NO_PROXY_PREDICATE.test(isa.getHostString())) {
        return false;  // Bypass proxy!
    }
    // ... rest of proxy logic
}
```

**This means:**
- ✗ `.nonProxyHosts("")` doesn't work
- ✗ `System.clearProperty("http.nonProxyHosts")` doesn't work
- ✗ Any proxy configuration doesn't work for `localhost`

## The ONLY Solution

**Use a hostname that doesn't match the hardcoded patterns.**

---

## Automated Setup (RECOMMENDED)

Run the setup script:

```bash
./setup-proxy-hostname.sh
```

This script will:
1. Add `keycloak.local` to `/etc/hosts`
2. Update `application-proxy.yml` to use `keycloak.local`
3. Verify the setup

Then:
```bash
# Start mitmproxy
./mitm-proxy.sh

# Start application
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Access application
open http://localhost:8080/login
```

---

## Manual Setup

### Step 1: Add Custom Hostname

```bash
sudo nano /etc/hosts
```

Add this line:
```
127.0.0.1  keycloak.local
```

Save and exit.

**Verify:**
```bash
ping keycloak.local
# Should respond from 127.0.0.1
```

### Step 2: Update application-proxy.yml

Edit `src/main/resources/application-proxy.yml`:

**Change FROM:**
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://localhost:3081/realms/dev-realm
      resourceserver:
        jwt:
          issuer-uri: http://localhost:3081/realms/dev-realm
          jwk-set-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
```

**Change TO:**
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://keycloak.local:3081/realms/dev-realm
      resourceserver:
        jwt:
          issuer-uri: http://keycloak.local:3081/realms/dev-realm
          jwk-set-uri: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
```

### Step 3: Restart and Test

```bash
# 1. Start mitmproxy
./mitm-proxy.sh

# 2. Start application with proxy profile
./gradlew bootRun --args='--spring.profiles.active=proxy'

# 3. Access the application
open http://localhost:8080/login
```

### Step 4: Verify in mitmproxy

You should now see:
```
✅ POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

### Step 5: Verify in Application Logs

Look for:
```
[bd628806-1, L:/127.0.0.1:53951 - R:localhost/127.0.0.1:8888]
                                                          ^^^^
                                                  Port 8888 = Proxy! ✅
```

---

## Why This Works

### The Hardcoded Check

```java
NO_PROXY_PREDICATE.test("localhost")      // ✗ Returns true → Bypass proxy
NO_PROXY_PREDICATE.test("127.0.0.1")     // ✗ Returns true → Bypass proxy
NO_PROXY_PREDICATE.test("127.0.0.2")     // ✗ Returns true → Bypass proxy
NO_PROXY_PREDICATE.test("[::1]")         // ✗ Returns true → Bypass proxy
NO_PROXY_PREDICATE.test("keycloak.local") // ✅ Returns false → Use proxy!
```

### The Flow

1. Application makes request to `http://keycloak.local:3081/token`
2. Reactor Netty checks: `NO_PROXY_PREDICATE.test("keycloak.local")`
3. Result: `false` (doesn't match hardcoded patterns)
4. Reactor Netty uses proxy: connects to `localhost:8888`
5. mitmproxy forwards request to `keycloak.local:3081`
6. DNS resolves `keycloak.local` to `127.0.0.1`
7. Request reaches Keycloak

**Result:** Traffic goes through proxy! 🎉

---

## Troubleshooting

### Issue: "Unable to resolve keycloak.local"

**Check /etc/hosts:**
```bash
cat /etc/hosts | grep keycloak
```

Should show:
```
127.0.0.1  keycloak.local
```

If not, add it:
```bash
echo "127.0.0.1  keycloak.local" | sudo tee -a /etc/hosts
```

### Issue: Still seeing :3081 in logs

**Verify you changed ALL occurrences:**
```bash
grep -n "localhost:3081" src/main/resources/application-proxy.yml
```

Should return nothing. If it shows results, you missed some.

**Replace all:**
```bash
sed -i '' 's|localhost:3081|keycloak.local:3081|g' src/main/resources/application-proxy.yml
```

### Issue: Keycloak login page doesn't load

**Update Keycloak's hostname** (if using Docker):

Edit `docker-compose.yml`:
```yaml
services:
  keycloak:
    environment:
      KC_HOSTNAME: keycloak.local
      KC_HOSTNAME_STRICT: false
```

Restart:
```bash
docker-compose restart keycloak
```

### Issue: "Redirect URI mismatch"

**Add redirect URI in Keycloak:**

1. Go to: `http://keycloak.local:3081`
2. Login: admin/admin
3. Clients → `app-client` → Settings
4. Add to Valid Redirect URIs:
   - `http://localhost:8080/*`
   - `http://127.0.0.1:8080/*`
5. Save

---

## Alternative Solutions (If Above Doesn't Work)

### Option 1: Use Docker Container Name

If both Keycloak and your app are in Docker:

```yaml
issuer-uri: http://keycloak:8080/realms/dev-realm
```

### Option 2: Use ngrok

```bash
ngrok http 3081
```

Use the ngrok URL:
```yaml
issuer-uri: https://abc123.ngrok.io/realms/dev-realm
```

### Option 3: Use Different Port for Proxy

If Keycloak is on a different machine:

```yaml
proxy:
  enabled: true
  host: proxy-server.local  # Not localhost!
  port: 8888
```

---

## Summary

**The Issue:**
- Reactor Netty has hardcoded logic that bypasses proxy for `localhost`, `127.*`, and `[::1]`
- This is **intentional** for performance but breaks debugging use cases
- Cannot be overridden with any configuration

**The Solution:**
- Use a custom hostname: `keycloak.local`
- Add to `/etc/hosts`: `127.0.0.1  keycloak.local`
- Update `application-proxy.yml` to use `keycloak.local` instead of `localhost`
- Restart everything

**The Result:**
- All OAuth2 traffic goes through mitmproxy
- You can inspect tokens, debug issues, understand the flow
- Complete visibility into the authentication process

**Quick Start:**
```bash
./setup-proxy-hostname.sh
./mitm-proxy.sh
./gradlew bootRun --args='--spring.profiles.active=proxy'
open http://localhost:8080/login
```

🎯 **That's the REAL fix!**

