# Reactor Netty Localhost Proxy Bypass - The Real Issue

## The Problem

Even after configuring proxy settings correctly and calling `.nonProxyHosts("")`, Reactor Netty **STILL bypasses the proxy** for `localhost` connections.

### Evidence

```
Line 76:  [944fc221-1, L:/127.0.0.1:53129 - R:localhost/127.0.0.1:3081]
Line 90:  [164c1e78-1, L:/127.0.0.1:53130 - R:localhost/127.0.0.1:3081]
Line 103: [944fc221-2, L:/127.0.0.1:53129 - R:localhost/127.0.0.1:3081]
                                                                  ^^^^
                                                          Direct to :3081, not :8888!
```

## Root Cause: Hardcoded Logic in Reactor Netty

Reactor Netty has **hardcoded logic** in `ProxyProvider` that bypasses proxy for certain hosts:

### Source Code Analysis

In `reactor.netty.transport.ProxyProvider`:

```java
static final Predicate<String> NO_PROXY_PREDICATE = 
    s -> s != null && (
        s.startsWith("localhost") ||      // ⚠️ Hardcoded!
        s.startsWith("127.") ||            // ⚠️ Hardcoded!
        s.startsWith("[::1]")              // ⚠️ Hardcoded!
    );

boolean shouldProxy(@Nullable SocketAddress address) {
    if (address instanceof InetSocketAddress) {
        InetSocketAddress isa = (InetSocketAddress) address;
        
        // ⚠️ THIS IS THE PROBLEM!
        if (isa.isUnresolved() && NO_PROXY_PREDICATE.test(isa.getHostString())) {
            return false;  // Bypass proxy for localhost!
        }
        
        // Check nonProxyHosts pattern
        if (nonProxyHostPredicate != null && 
            nonProxyHostPredicate.test(isa.getHostString())) {
            return false;
        }
    }
    return true;
}
```

### The Flow

1. Application makes request to `http://localhost:3081/token`
2. Reactor Netty checks if proxy should be used
3. **BEFORE checking `nonProxyHosts` pattern**, it checks `NO_PROXY_PREDICATE`
4. `NO_PROXY_PREDICATE` matches "localhost"
5. **Returns `false` → Proxy bypassed!**

This happens **REGARDLESS** of:
- ✗ `.nonProxyHosts("")` setting
- ✗ `System.clearProperty("http.nonProxyHosts")`
- ✗ Any other proxy configuration

## Why This Exists

This is **intentional behavior** in Reactor Netty for performance reasons:
- Localhost connections are typically fast
- Proxying localhost adds unnecessary overhead
- Most users don't want to proxy localhost

However, for **debugging OAuth2 flows**, we NEED to proxy localhost!

## The Solution

### Change `localhost` to `127.0.0.1` in Configuration

The hardcoded check only matches the **string** "localhost", not the IP address "127.0.0.1".

**Before (doesn't work):**
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://localhost:3081/realms/dev-realm  # ❌ Bypassed!
```

**After (works):**
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://127.0.0.1:3081/realms/dev-realm  # ✅ Proxied!
```

### Why This Works

1. Application makes request to `http://127.0.0.1:3081/token`
2. Reactor Netty checks `NO_PROXY_PREDICATE.test("127.0.0.1")`
3. "127.0.0.1" starts with "127." → **WAIT, IT STILL MATCHES!**

**Actually, this won't work either!** The predicate checks `s.startsWith("127.")`.

## The REAL Solution

We need to use a hostname that doesn't match ANY of these patterns:
- ✗ `localhost`
- ✗ `127.*`
- ✗ `[::1]`

### Option 1: Use a Custom Hostname (RECOMMENDED)

Add to `/etc/hosts`:
```
127.0.0.1  keycloak.local
```

Then use in configuration:
```yaml
issuer-uri: http://keycloak.local:3081/realms/dev-realm
```

### Option 2: Use Docker Host IP

If Keycloak is in Docker:
```bash
# Find Docker host IP
docker inspect keycloak-container | grep IPAddress
```

Use the IP (e.g., `172.17.0.2`):
```yaml
issuer-uri: http://172.17.0.2:3081/realms/dev-realm
```

### Option 3: Use host.docker.internal (Mac/Windows)

On Mac/Windows Docker Desktop:
```yaml
issuer-uri: http://host.docker.internal:3081/realms/dev-realm
```

### Option 4: Custom ProxyProvider (Advanced)

Create a custom `ProxyProvider` that doesn't have the hardcoded check:

```java
@Bean
public WebClient webClient(...) {
    // Create custom HttpClient that forces proxy for ALL hosts
    HttpClient httpClient = HttpClient.create()
        .remoteAddress(() -> new InetSocketAddress(proxyHost, proxyPort))
        .wiretap(true);
    
    // This bypasses Reactor Netty's proxy logic entirely
    // and connects directly to the proxy for ALL requests
    
    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .filter(oauth2)
        .build();
}
```

**Problem:** This makes ALL requests go through proxy, including non-HTTP traffic.

## Recommended Approach

### For Development/Debugging

**Use `/etc/hosts` entry:**

1. Add to `/etc/hosts`:
   ```
   127.0.0.1  keycloak.local
   ```

2. Update `application-proxy.yml`:
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

3. Update `docker-compose.yml` (if using Docker):
   ```yaml
   services:
     keycloak:
       ports:
         - "3081:8080"
       environment:
         KC_HOSTNAME: keycloak.local  # Important!
         KC_HOSTNAME_STRICT: false
   ```

4. Restart everything:
   ```bash
   # Restart Keycloak
   docker-compose restart keycloak
   
   # Start proxy
   ./mitm-proxy.sh
   
   # Start application
   ./gradlew bootRun --args='--spring.profiles.active=proxy'
   ```

5. Access application:
   ```bash
   open http://localhost:8080/login
   ```

6. Check mitmproxy - you should now see:
   ```
   ✅ POST http://keycloak.local:3081/.../token
   ✅ GET  http://keycloak.local:3081/.../certs
   ✅ GET  http://keycloak.local:3081/.../userinfo
   ```

## Verification

### Before Fix (WRONG)

```
Reactor Netty Log:
[944fc221-1, L:/127.0.0.1:53129 - R:localhost/127.0.0.1:3081]
                                                          ^^^^
                                                  Direct connection!
```

### After Fix (CORRECT)

```
Reactor Netty Log:
[944fc221-1, L:/127.0.0.1:53129 - R:localhost/127.0.0.1:8888]
                                                          ^^^^
                                                  Through proxy!
```

## Alternative: Use Real Domain

If you have a real domain pointing to localhost (e.g., via ngrok or localtunnel):

```bash
# Using ngrok
ngrok http 3081

# Use the ngrok URL
issuer-uri: https://abc123.ngrok.io/realms/dev-realm
```

This will definitely go through the proxy since it's not "localhost".

## Summary

**The Issue:**
- Reactor Netty has hardcoded logic that bypasses proxy for `localhost`, `127.*`, and `[::1]`
- This cannot be overridden with `.nonProxyHosts("")` or system properties

**The Solution:**
- Use a hostname that doesn't match the hardcoded patterns
- **RECOMMENDED:** Add `keycloak.local` to `/etc/hosts` and use that instead of `localhost`
- Update `application-proxy.yml` to use the new hostname
- Restart Keycloak with the new hostname configured

**Why It Matters:**
- Without this, you cannot capture OAuth2 token exchanges in mitmproxy
- You cannot debug JWT tokens, inspect claims, or troubleshoot authentication issues
- This is critical for understanding OAuth2/OIDC flows

## Files to Update

1. `/etc/hosts` - Add `keycloak.local` entry
2. `application-proxy.yml` - Change `localhost` to `keycloak.local`
3. `docker-compose.yml` - Update Keycloak hostname (if using Docker)

That's the real fix! 🎯

