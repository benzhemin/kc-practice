# Fix Proxy - Step by Step Guide

## The Problem

Reactor Netty (used by Spring WebFlux) has **hardcoded logic** that bypasses proxy for `localhost`. This cannot be disabled with configuration.

## The Solution

Use a custom hostname instead of `localhost`.

---

## Step 1: Add Custom Hostname to /etc/hosts

```bash
# Open /etc/hosts with sudo
sudo nano /etc/hosts
```

Add this line at the end:
```
127.0.0.1  keycloak.local
```

Save and exit (Ctrl+X, then Y, then Enter).

**Verify it works:**
```bash
ping keycloak.local
# Should respond from 127.0.0.1
```

---

## Step 2: Update application-proxy.yml

Edit `src/main/resources/application-proxy.yml`:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://keycloak.local:3081/realms/dev-realm  # Changed!
            user-name-attribute: preferred_username

      resourceserver:
        jwt:
          issuer-uri: http://keycloak.local:3081/realms/dev-realm  # Changed!
          jwk-set-uri: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs  # Changed!
```

---

## Step 3: Update Keycloak Configuration (if using Docker)

Edit `docker-compose.yml`:

```yaml
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    ports:
      - "3081:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_HOSTNAME: keycloak.local  # Add this!
      KC_HOSTNAME_STRICT: false     # Add this!
      KC_HTTP_ENABLED: true
    command:
      - start-dev
```

**Restart Keycloak:**
```bash
docker-compose down
docker-compose up -d
```

---

## Step 4: Test the Setup

### 4.1 Start mitmproxy

```bash
./mitm-proxy.sh
```

Or manually:
```bash
mitmproxy --listen-port 8888
```

### 4.2 Start the Application

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

Look for these log messages:
```
🔧 CONFIGURING GLOBAL PROXY
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════
🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2
Proxy: localhost:8888 (HTTP)
```

### 4.3 Access the Application

```bash
open http://localhost:8080/login
```

Or in browser: `http://localhost:8080/login`

### 4.4 Check mitmproxy

You should now see:
```
✅ POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

### 4.5 Check Application Logs

Look for:
```
[944fc221-1, L:/127.0.0.1:53129 - R:localhost/127.0.0.1:8888]
                                                          ^^^^
                                                  Port 8888 = Proxy!
```

---

## Troubleshooting

### Issue: "Unable to resolve keycloak.local"

**Solution:** Check `/etc/hosts`:
```bash
cat /etc/hosts | grep keycloak
# Should show: 127.0.0.1  keycloak.local
```

If not there, add it:
```bash
echo "127.0.0.1  keycloak.local" | sudo tee -a /etc/hosts
```

### Issue: Still seeing :3081 in logs instead of :8888

**Check:**
1. Is mitmproxy running? `lsof -i :8888`
2. Is `proxy.enabled=true` in `application-proxy.yml`?
3. Are you using `--spring.profiles.active=proxy`?
4. Did you change `localhost` to `keycloak.local` in ALL places?

### Issue: Keycloak login page doesn't load

**Solution:** Update Keycloak's hostname:

1. Access Keycloak admin console: `http://keycloak.local:3081`
2. Login with admin/admin
3. Go to Realm Settings → General
4. Set Frontend URL: `http://keycloak.local:3081`
5. Save

Or restart Keycloak with environment variables (see Step 3).

### Issue: "Redirect URI mismatch"

**Solution:** Update the client redirect URI in Keycloak:

1. Go to Clients → `app-client`
2. Add to Valid Redirect URIs:
   - `http://localhost:8080/*`
   - `http://127.0.0.1:8080/*`
3. Save

---

## Alternative Solutions

### Option 1: Use Docker Container Name

If Keycloak is in Docker and your app is also in Docker:

```yaml
issuer-uri: http://keycloak:8080/realms/dev-realm
```

### Option 2: Use Real External Proxy

If you have a corporate proxy or external proxy:

```yaml
proxy:
  enabled: true
  host: proxy.company.com  # Not localhost!
  port: 8080
  type: HTTP
```

This will work because the target is not "localhost".

### Option 3: Use ngrok

```bash
# Expose Keycloak
ngrok http 3081

# Use ngrok URL
issuer-uri: https://abc123.ngrok.io/realms/dev-realm
```

---

## Why This is Necessary

Reactor Netty source code (`ProxyProvider.java`):

```java
static final Predicate<String> NO_PROXY_PREDICATE = 
    s -> s != null && (
        s.startsWith("localhost") ||  // ⚠️ Hardcoded!
        s.startsWith("127.") ||        // ⚠️ Hardcoded!
        s.startsWith("[::1]")          // ⚠️ Hardcoded!
    );
```

This check happens **BEFORE** any configuration is evaluated. It's intentional for performance, but breaks our debugging use case.

---

## Summary

**The Fix:**
1. Add `keycloak.local` to `/etc/hosts`
2. Change `localhost` to `keycloak.local` in `application-proxy.yml`
3. Update Keycloak hostname configuration
4. Restart everything

**Result:**
- All OAuth2 traffic goes through mitmproxy
- You can inspect tokens, debug issues, understand the flow
- No more hardcoded bypass!

**Why It Works:**
- "keycloak.local" doesn't match Reactor Netty's hardcoded patterns
- Proxy is used for ALL requests to `keycloak.local`
- Still resolves to 127.0.0.1, so Keycloak works normally

🎉 **Done!** You can now capture and inspect OAuth2 traffic!

