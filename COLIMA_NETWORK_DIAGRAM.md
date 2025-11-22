# Colima + Keycloak + Proxy Network Architecture

## The Complete Picture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ macOS Host (Your Computer)                                                  │
│                                                                              │
│  ┌────────────┐                                                             │
│  │  Browser   │                                                             │
│  └────┬───────┘                                                             │
│       │                                                                      │
│       │ (1) http://localhost:8080/login                                     │
│       │                                                                      │
│       ↓                                                                      │
│  ┌────────────────────────────────────────────────────────────┐            │
│  │  Spring Boot Application (port 8080)                       │            │
│  │                                                             │            │
│  │  ┌──────────────────────────────────────────────────────┐ │            │
│  │  │ Spring Security OAuth2 Client                        │ │            │
│  │  │                                                       │ │            │
│  │  │  Uses: WebClient with Proxy Configuration           │ │            │
│  │  │  Target: http://keycloak.local:3081                  │ │            │
│  │  └──────────────────────────────────────────────────────┘ │            │
│  └────────────────┬───────────────────────────────────────────┘            │
│                   │                                                          │
│                   │ (5) POST http://keycloak.local:3081/token               │
│                   │     (Token Exchange)                                     │
│                   │                                                          │
│       ┌───────────┴──────────────┐                                          │
│       │                           │                                          │
│       │  /etc/hosts               │                                          │
│       │  ┌─────────────────────┐ │                                          │
│       │  │ 172.20.0.10         │ │                                          │
│       │  │ keycloak.local      │ │                                          │
│       │  └─────────────────────┘ │                                          │
│       │                           │                                          │
│       │  DNS Resolution:          │                                          │
│       │  keycloak.local           │                                          │
│       │         ↓                 │                                          │
│       │    172.20.0.10            │                                          │
│       └───────────┬───────────────┘                                          │
│                   │                                                          │
│                   │ ⚠️ NOT 127.0.0.1!                                        │
│                   │ ⚠️ NOT localhost!                                        │
│                   │                                                          │
│                   ↓                                                          │
│  ┌────────────────────────────────────────────────────────────┐            │
│  │  mitmproxy (port 8888)                                     │            │
│  │                                                             │            │
│  │  ✅ Captures ALL requests to keycloak.local                │            │
│  │  ✅ Can inspect tokens, modify requests, etc.              │            │
│  └────────────────┬───────────────────────────────────────────┘            │
│                   │                                                          │
│                   │ (6) Forwards to keycloak.local:3081                      │
│                   │                                                          │
│                   │ Port Mapping: 3081 → 8080                                │
│                   │                                                          │
└───────────────────┼──────────────────────────────────────────────────────────┘
                    │
                    │ Through Colima's network bridge
                    │
┌───────────────────┼──────────────────────────────────────────────────────────┐
│ Colima VM (Linux)                                                            │
│                   │                                                           │
│                   ↓                                                           │
│  ┌────────────────────────────────────────────────────────────┐             │
│  │ Docker Network: keycloak-net (172.20.0.0/16)              │             │
│  │                                                             │             │
│  │  ┌──────────────────────────────────────────────────────┐ │             │
│  │  │ Keycloak Container                                   │ │             │
│  │  │                                                       │ │             │
│  │  │ IP: 172.20.0.10 (static)                            │ │             │
│  │  │ Port: 8080                                           │ │             │
│  │  │ Hostname: keycloak.local                            │ │             │
│  │  │                                                       │ │             │
│  │  │ Mapped to host: 3081:8080                           │ │             │
│  │  └──────────────────────────────────────────────────────┘ │             │
│  └────────────────────────────────────────────────────────────┘             │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## Why This Works: Step-by-Step

### Step 1: Browser Initiates Login

```
Browser → http://localhost:8080/login
```

- User clicks login button
- Browser makes request to Spring Boot app

### Step 2: OAuth2 Redirect

```
Spring Boot → 302 Redirect → http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/auth
```

- Spring Security generates OAuth2 authorization URL
- Browser is redirected to Keycloak

### Step 3: DNS Resolution (Critical!)

```
Browser looks up: keycloak.local
/etc/hosts says: 172.20.0.10
```

- **NOT** `127.0.0.1`
- **NOT** `localhost`
- This is the key to making proxy work!

### Step 4: Browser → Keycloak (Direct)

```
Browser → http://keycloak.local:3081/auth
         ↓
    172.20.0.10:3081 (via port mapping)
         ↓
    Container:8080
```

- Browser connects directly (doesn't use app's proxy)
- User sees login form and enters credentials
- Keycloak validates and redirects back with authorization code

### Step 5: Token Exchange (Proxied!)

```
Spring Boot → WebClient → http://keycloak.local:3081/token
                  ↓
            Reactor Netty checks:
            - Is it "localhost"? NO ✅
            - Is it "127.*"? NO ✅
            - Is it "[::1]"? NO ✅
            → Use proxy!
                  ↓
            mitmproxy:8888 ✅ CAPTURED!
                  ↓
            keycloak.local:3081
                  ↓
            172.20.0.10:3081 (via port mapping)
                  ↓
            Container:8080
```

- **This is what we wanted to capture!**
- Token exchange happens server-to-server
- Goes through mitmproxy
- We can inspect the JWT token!

---

## The Magic: Why keycloak.local Works

### ❌ What Doesn't Work

#### Option 1: Using localhost

```yaml
issuer-uri: http://localhost:3081/realms/dev-realm
```

```
Reactor Netty sees: "localhost"
Hardcoded check: s.startsWith("localhost") → TRUE
Decision: BYPASS PROXY ❌
Result: Direct connection to :3081
```

#### Option 2: Using 127.0.0.1

```yaml
issuer-uri: http://127.0.0.1:3081/realms/dev-realm
```

```
Reactor Netty sees: "127.0.0.1"
Hardcoded check: s.startsWith("127.") → TRUE
Decision: BYPASS PROXY ❌
Result: Direct connection to :3081
```

### ✅ What Works

#### Using keycloak.local

```yaml
issuer-uri: http://keycloak.local:3081/realms/dev-realm
```

```
Reactor Netty sees: "keycloak.local"
Hardcoded checks:
  - s.startsWith("localhost") → FALSE ✅
  - s.startsWith("127.") → FALSE ✅
  - s.startsWith("[::1]") → FALSE ✅
Decision: USE PROXY ✅
Result: Connection to mitmproxy:8888
```

**But wait, doesn't keycloak.local resolve to 172.20.0.10?**

Yes! And that's perfect because:
1. Reactor Netty checks the **hostname string** before DNS resolution
2. "keycloak.local" doesn't match the hardcoded patterns
3. So it decides to use the proxy
4. Then DNS resolves it to `172.20.0.10`
5. Port mapping forwards `3081` → `8080` in container

---

## Port Mapping Explained

```
Host Port 3081 ←→ Container Port 8080
```

### Why We Need This

- Container listens on port `8080` internally
- We can't access `172.20.0.10:8080` directly from host (Colima VM isolation)
- Port mapping creates a tunnel: `host:3081` → `container:8080`

### How It Works

```
Request to: keycloak.local:3081
            ↓
DNS:        172.20.0.10:3081
            ↓
Colima:     Maps 3081 → container:8080
            ↓
Container:  Keycloak receives on :8080
```

### In docker-compose.yml

```yaml
ports:
  - "3081:8080"
    ^^^^  ^^^^
    │     └─ Container port (Keycloak listens here)
    └─ Host port (we connect here)
```

---

## Static IP Configuration

### Why Static IP?

Without static IP:
```yaml
networks:
  - keycloak-net  # Docker assigns random IP
```

- IP might be `172.20.0.2` today
- IP might be `172.20.0.5` tomorrow
- `/etc/hosts` entry becomes invalid
- DNS resolution breaks

### With Static IP:

```yaml
networks:
  keycloak-net:
    ipv4_address: 172.20.0.10  # Always this IP
```

- IP is always `172.20.0.10`
- `/etc/hosts` entry stays valid
- Consistent and reliable

---

## The Reactor Netty Hardcoded Check

### Source Code (Simplified)

```java
// In reactor.netty.transport.ProxyProvider

static final Predicate<String> NO_PROXY_PREDICATE = 
    s -> s != null && (
        s.startsWith("localhost") ||  // ⚠️ Hardcoded!
        s.startsWith("127.") ||        // ⚠️ Hardcoded!
        s.startsWith("[::1]")          // ⚠️ Hardcoded!
    );

boolean shouldProxy(SocketAddress address) {
    if (address instanceof InetSocketAddress) {
        InetSocketAddress isa = (InetSocketAddress) address;
        
        // Check hardcoded patterns FIRST
        if (NO_PROXY_PREDICATE.test(isa.getHostString())) {
            return false;  // Bypass proxy!
        }
        
        // Then check nonProxyHosts pattern
        if (nonProxyHostPredicate != null && 
            nonProxyHostPredicate.test(isa.getHostString())) {
            return false;
        }
    }
    return true;  // Use proxy
}
```

### Why This Exists

- Performance: localhost connections are fast, no need for proxy
- Security: localhost is trusted, no need to intercept
- Common practice: Most apps don't want to proxy localhost

### Why It's a Problem for Us

- We're debugging OAuth2 flows
- We NEED to see token exchanges
- Token exchanges go to "localhost" (Keycloak)
- Reactor Netty bypasses proxy
- We can't see the tokens!

### The Workaround

- Use hostname that doesn't match patterns
- `keycloak.local` doesn't start with "localhost" or "127."
- Reactor Netty allows proxy
- We can see the tokens! 🎉

---

## Configuration Summary

### docker-compose.yml

```yaml
services:
  keycloak:
    environment:
      KC_HOSTNAME: keycloak.local  # Match hostname
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10  # Static IP (not 127.*)
    ports:
      - "3081:8080"  # Port mapping

networks:
  keycloak-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16  # Custom subnet
```

### /etc/hosts

```
172.20.0.10 keycloak.local
```

### application-proxy.yml

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://keycloak.local:3081/realms/dev-realm
        registration:
          keycloak:
            redirect-uri: "{baseUrl}/login/oauth2/code/gateway"
            # baseUrl = http://localhost:8080 (browser accessible)

proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

### WebClientProxyCustomizer.java

```java
@Bean
public WebClient webClient(...) {
    Consumer<ProxyProvider.TypeSpec> proxySpec = proxy -> {
        proxy.type(ProxyProvider.Proxy.HTTP)
             .host(proxyHost)
             .port(proxyPort)
             .nonProxyHosts("");  // Allow ALL hosts through proxy
    };
    
    HttpClient httpClient = HttpClient.create()
            .proxy(proxySpec);
    
    return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .filter(oauth2)
            .build();
}
```

---

## Traffic Flow Comparison

### Without Proxy (Normal)

```
Browser → localhost:8080 → App
                            ↓
                   OAuth2 Redirect
                            ↓
Browser → keycloak.local:3081 → Keycloak
                            ↓
                      Login Form
                            ↓
Browser → Submit credentials → Keycloak
                            ↓
                   Redirect with code
                            ↓
Browser → localhost:8080/callback?code=xxx → App
                            ↓
                   Token Exchange (DIRECT)
                            ↓
App → keycloak.local:3081/token → Keycloak
                            ↓
                   Return JWT token
                            ↓
App → Validate token → Done
```

### With Proxy (Debug Mode)

```
Browser → localhost:8080 → App
                            ↓
                   OAuth2 Redirect
                            ↓
Browser → keycloak.local:3081 → Keycloak
                            ↓
                      Login Form
                            ↓
Browser → Submit credentials → Keycloak
                            ↓
                   Redirect with code
                            ↓
Browser → localhost:8080/callback?code=xxx → App
                            ↓
                   Token Exchange (VIA PROXY)
                            ↓
App → mitmproxy:8888 → keycloak.local:3081/token → Keycloak
      ✅ CAPTURED!
                            ↓
                   Return JWT token
                            ↓
mitmproxy → App
✅ CAPTURED!
                            ↓
App → Validate token → Done
```

---

## What You Can See in mitmproxy

### Token Exchange Request

```http
POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

### Token Exchange Response

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI...",
  "not-before-policy": 0,
  "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "scope": "openid profile email"
}
```

You can:
- Copy the JWT tokens
- Decode them at jwt.io
- Inspect claims
- Verify signatures
- Debug token issues

---

## Summary

### The Problem
1. Reactor Netty bypasses proxy for `localhost` and `127.*` (hardcoded)
2. Colima isolates Docker network IPs from host

### The Solution
1. Use `keycloak.local` hostname (not `localhost` or `127.*`)
2. Point it to container IP `172.20.0.10` (static)
3. Access via port mapping `3081:8080`
4. Configure WebClient with proxy

### The Result
- ✅ OAuth2 traffic flows through mitmproxy
- ✅ Can inspect JWT tokens
- ✅ Can debug authentication issues
- ✅ Works reliably with Colima on macOS

### Key Insight

The hostname check happens **before** DNS resolution:
```
"keycloak.local" → Check patterns → No match → Use proxy → Resolve DNS → 172.20.0.10
```

Not:
```
"localhost" → Check patterns → Match! → Bypass proxy ❌
```

That's why `keycloak.local` works! 🎯

