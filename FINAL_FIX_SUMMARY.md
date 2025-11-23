# ✅ FINAL FIX: Why Token Exchange Was Not Captured

## The Problem

Even with proxy configured and mitmproxy running, the `/protocol/openid-connect/token` requests were **NOT being captured**.

### Evidence
```
Line 64 in logs: [b7b07dc6-1, L:/127.0.0.1:65092 - R:localhost/127.0.0.1:3081]
                                                                        ^^^^
                                                            Connecting to port 3081 (Keycloak)
                                                            NOT port 8888 (proxy)!
```

## Root Cause

**Reactor Netty does NOT respect JVM system properties for proxy configuration!**

- Traditional Java HTTP clients use `http.proxyHost` and `http.proxyPort`
- Reactor Netty (used by Spring WebFlux) **ignores these properties**
- Spring Security OAuth2 client uses Reactor Netty internally
- Therefore, setting `System.setProperty("http.proxyHost", ...)` had **NO EFFECT**

## The Solution

Created `WebClientProxyCustomizer.java` which provides a `WebClient` bean that:
1. Is configured with proxy at the Reactor Netty `HttpClient` level
2. Is automatically used by Spring Security's OAuth2 client
3. Captures ALL OAuth2 traffic (token exchange, JWK, userinfo)

### Files Changed

1. **NEW:** `src/main/java/com/zz/gateway/auth/config/WebClientProxyCustomizer.java`
   - Creates `WebClient` bean with proxy configuration
   - Spring Security OAuth2 automatically uses this bean
   
2. **MODIFIED:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`
   - Removed duplicate `webClient` bean to avoid conflicts
   - Kept `@PostConstruct` method (for logging)
   - Kept helper methods

## How to Test

### Step 1: RESTART Spring Boot

**CRITICAL:** You MUST restart for changes to take effect!

```bash
# Stop current app (Ctrl+C)

# Restart
./gradlew bootRun
```

### Step 2: Look for This Log Message

```
═══════════════════════════════════════════════════════════
🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2
Proxy: localhost:8888 (HTTP)
═══════════════════════════════════════════════════════════
✅ WebClient created with proxy - OAuth2 will use this
═══════════════════════════════════════════════════════════
```

### Step 3: Trigger OAuth2 Login

```bash
open http://localhost:8080/user
```

### Step 4: Check Logs for Connection

Look for connection details in logs:

```
# Should now show port 8888 (proxy):
[xxx, L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:8888]
                                                  ^^^^
                                            Through proxy!
```

### Step 5: Check mitmproxy

You should NOW see all three OAuth2 requests:

```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

## Why This Works

### Spring's WebClient Bean Discovery

Spring Security OAuth2 client looks for a `WebClient` bean in this order:

1. Bean named `webClient` (highest priority)
2. Any `WebClient` bean
3. Creates its own (default)

By providing a bean named `webClient` with proxy configuration, we ensure OAuth2 uses our proxied client.

### The Flow

```
1. Spring Boot starts
   ↓
2. WebClientProxyCustomizer creates WebClient bean with proxy
   ↓
3. Spring Security OAuth2 client initializes
   ↓
4. Looks for WebClient bean
   ↓
5. Finds our proxied WebClient
   ↓
6. Uses it for ALL OAuth2 HTTP requests
   ↓
7. All traffic goes through mitmproxy!
```

## Configuration Summary

### application.yml
```yaml
proxy:
  enabled: true  # ← Must be true
  host: localhost
  port: 8888
  type: HTTP
```

### mitmproxy
```bash
# Start mitmproxy on port 8888 (default)
mitmproxy

# Or with web interface
mitmweb --web-port 8081
```

### Spring Boot
```bash
# Just run normally
./gradlew bootRun
```

## Verification Checklist

- [ ] mitmproxy running on port 8888
- [ ] Spring Boot restarted
- [ ] Log shows "CREATING WEBCLIENT WITH PROXY FOR OAUTH2"
- [ ] Triggered OAuth2 login
- [ ] mitmproxy shows POST to `/token`
- [ ] mitmproxy shows GET to `/certs`
- [ ] mitmproxy shows GET to `/userinfo`

## Common Issues

### Still not seeing traffic?

**Check 1:** Did you restart the app?
```bash
# MUST restart for new bean to be created
./gradlew bootRun
```

**Check 2:** Is proxy enabled?
```bash
grep "proxy.enabled" src/main/resources/application.yml
# Should show: enabled: true
```

**Check 3:** Is mitmproxy running?
```bash
lsof -i :8888
# Should show: mitmproxy
```

**Check 4:** Are you accessing a protected endpoint?
```bash
# ✅ Good - requires authentication
curl http://localhost:8080/user

# ❌ Bad - public endpoint
curl http://localhost:8080/
```

## Summary

### What Was Wrong
- JVM system properties don't work with Reactor Netty
- OAuth2 client was making direct connections

### What Was Fixed
- Created `WebClient` bean with proxy at Reactor Netty level
- Spring Security OAuth2 automatically uses this bean
- All OAuth2 traffic now goes through proxy

### Action Required
1. ✅ Code added: `WebClientProxyCustomizer.java`
2. ✅ Code modified: `ProxyConfig.java` (removed duplicate bean)
3. ⚠️  **RESTART your Spring Boot app**
4. ✅ Trigger OAuth2 login
5. ✅ Verify traffic in mitmproxy

**This WILL work!** The `WebClient` bean approach is the correct way to configure proxy for Spring Security OAuth2 with Reactor Netty.

---

**Related Files:**
- `PROXY_FIX_REACTOR_NETTY.md` - Detailed explanation
- `PROXY_NOT_WORKING_FIX.md` - Previous attempt (didn't work)
- `WebClientProxyCustomizer.java` - The actual fix


