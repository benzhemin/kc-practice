# The REAL Solution for Colima + Keycloak + Proxy

## The Truth: My Previous Solution Doesn't Work

I apologize - I was wrong. The `keycloak.local` approach **does NOT work** with Colima because:

1. **`172.20.0.10` is not routable** from macOS host
2. **Port mapping only works with `localhost` or `127.0.0.1`**
3. **Custom hostnames pointing to container IPs don't work**

### Test Results (Real)

```bash
# DNS resolves correctly
getent hosts keycloak.local
# 172.20.0.10     keycloak.local ✅

# But connection fails
curl http://keycloak.local:3081
# Resolving timed out ❌

ping keycloak.local
# 100% packet loss ❌
```

---

## The Real Problem

**You CANNOT bypass Reactor Netty's hardcoded proxy exclusion with Colima's network setup.**

Reactor Netty will ALWAYS bypass proxy for:
- `localhost`
- `127.*`
- `[::1]`

And with Colima, you can ONLY access containers via `localhost` or `127.0.0.1` (through port mapping).

**This creates an impossible situation:**
- Need non-localhost hostname → Reactor Netty uses proxy ✅
- But Colima only allows localhost access → Can't connect ❌

---

## Real Working Solutions

### Solution 1: Use Docker Desktop Instead of Colima (Easiest)

Docker Desktop has better network bridging that makes container IPs accessible from the host.

```bash
# Uninstall Colima
colima stop
colima delete

# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop

# Then the keycloak.local approach would actually work
```

**Why this works:** Docker Desktop bridges the Docker network to your host, making `172.20.0.10` actually accessible.

---

### Solution 2: Run Keycloak on a Different Machine (Best for Debugging)

Run Keycloak on a different machine or VM with a real IP address.

```bash
# On another machine (e.g., 192.168.1.100)
docker run -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest start-dev
```

```yaml
# application-proxy.yml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://192.168.1.100:8080/realms/dev-realm
```

**Why this works:** `192.168.1.100` is not `localhost` or `127.*`, so Reactor Netty uses the proxy.

---

### Solution 3: Use ngrok or Similar Tunnel (Quick Test)

Expose Keycloak through ngrok to get a public URL.

```bash
# Terminal 1: Start Keycloak
docker-compose up keycloak

# Terminal 2: Start ngrok
ngrok http 3081
```

```yaml
# application-proxy.yml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://abc123.ngrok.io/realms/dev-realm
```

**Why this works:** The ngrok URL is not localhost, so Reactor Netty uses the proxy.

---

### Solution 4: Modify Reactor Netty (Advanced, Not Recommended)

Create a custom `HttpClient` that forces ALL traffic through proxy.

```java
@Bean
public WebClient webClient(...) {
    // Create HttpClient that connects DIRECTLY to proxy for ALL requests
    HttpClient httpClient = HttpClient.create()
        .remoteAddress(() -> new InetSocketAddress("localhost", 8888))
        .wiretap(true);
    
    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .filter(oauth2)
        .build();
}
```

**Problems:**
- ALL requests go through proxy (not just OAuth2)
- Breaks non-HTTP traffic
- Complex to maintain
- May break OAuth2 client functionality

---

### Solution 5: Accept You Can't Proxy Localhost with Colima

The simplest solution: **Accept that you can't proxy localhost OAuth2 traffic with Colima.**

Instead, use other debugging methods:

1. **Enable DEBUG logging**
   ```yaml
   logging:
     level:
       org.springframework.security.oauth2: DEBUG
       org.springframework.security.oauth2.client.endpoint: TRACE
   ```

2. **Use Spring Security's built-in logging**
   - Token exchanges are logged (without full token content)
   - You can see request/response status codes
   - Errors are logged with details

3. **Use Keycloak's admin console**
   - View sessions
   - See token contents
   - Check user attributes

4. **Add custom logging in your app**
   ```java
   @Component
   public class OAuth2LoggingFilter implements WebFilter {
       @Override
       public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
           return chain.filter(exchange)
               .doOnSuccess(v -> {
                   OAuth2AuthorizedClient client = ...;
                   if (client != null) {
                       log.info("Access Token: {}", client.getAccessToken().getTokenValue());
                   }
               });
       }
   }
   ```

---

## Why My Previous Solution Was Wrong

I made several incorrect assumptions:

### ❌ Assumption 1: Port mapping makes container IP accessible

**Wrong!** Port mapping only makes `localhost:3081` accessible, not `172.20.0.10:3081`.

```bash
curl http://localhost:3081        # ✅ Works
curl http://127.0.0.1:3081        # ✅ Works
curl http://172.20.0.10:3081      # ❌ Timeout
curl http://keycloak.local:3081   # ❌ Timeout (if pointing to 172.20.0.10)
```

### ❌ Assumption 2: OS falls back to localhost

**Wrong!** If DNS resolves to an unreachable IP, the OS doesn't automatically fall back to localhost.

```bash
# /etc/hosts
172.20.0.10 keycloak.local

curl http://keycloak.local:3081
# DNS: keycloak.local → 172.20.0.10
# Try to connect: 172.20.0.10:3081
# Timeout (no fallback to localhost)
```

### ❌ Assumption 3: keycloak.local would work like Docker Desktop

**Wrong!** Colima's networking is different from Docker Desktop. Container IPs are not bridged to the host.

---

## The Actual Network Architecture with Colima

```
┌─────────────────────────────────────────────────────────────┐
│ macOS Host                                                   │
│                                                              │
│ Can ONLY access: localhost:3081 or 127.0.0.1:3081          │
│ CANNOT access: 172.20.0.10:* (any port)                    │
│                                                              │
│ Port 3081 → SSH tunnel → Colima VM → Container             │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                         ↑
                         │ SSH tunnel
                         │
┌────────────────────────┼─────────────────────────────────────┐
│ Colima VM              │                                     │
│                        ↓                                     │
│  ┌──────────────────────────────────┐                       │
│  │ Docker Network: 172.20.0.0/16    │                       │
│  │                                   │                       │
│  │  Container: 172.20.0.10:8080     │                       │
│  └──────────────────────────────────┘                       │
│                                                              │
│  Only accessible from:                                      │
│  - Inside VM ✅                                             │
│  - Other containers ✅                                      │
│  - macOS host via localhost:3081 ✅                         │
│  - macOS host via 172.20.0.10:* ❌                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Recommendation

For your use case (debugging OAuth2 flows with mitmproxy on Colima), I recommend:

### Option A: Switch to Docker Desktop

If you want to use mitmproxy to capture OAuth2 traffic:

1. Switch from Colima to Docker Desktop
2. Use the `keycloak.local` approach (which will actually work)
3. Capture traffic in mitmproxy

### Option B: Keep Colima, Use Alternative Debugging

If you want to keep Colima:

1. Use Spring Security's DEBUG logging
2. Add custom logging to capture tokens
3. Use Keycloak's admin console
4. Accept you can't use mitmproxy for localhost traffic

### Option C: Run Keycloak on Different Machine

If you really need mitmproxy with Colima:

1. Run Keycloak on a different machine/VM
2. Use that machine's IP in your config
3. Proxy will work because it's not localhost

---

## My Apologies

I apologize for the confusion. I was making assumptions about how Colima's networking works without properly testing it. The `keycloak.local` solution I proposed **does not work** with Colima's network isolation.

The fundamental issue is:
- **Colima**: Container IPs not accessible from host
- **Reactor Netty**: Bypasses proxy for localhost/127.*
- **Result**: No way to proxy localhost OAuth2 traffic with Colima

You need either:
- Different Docker runtime (Docker Desktop)
- Different Keycloak location (not localhost)
- Different debugging approach (not mitmproxy)

---

## What Actually Works with Colima

```yaml
# docker-compose.yml
services:
  keycloak:
    ports:
      - "3081:8080"  # This is all you need

# application.yml (without proxy)
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://localhost:3081/realms/dev-realm
            # Use localhost - it works, but can't proxy it
```

This works, but you **cannot** capture the OAuth2 traffic in mitmproxy because Reactor Netty bypasses the proxy for localhost.

**That's the reality with Colima.** 🎯

