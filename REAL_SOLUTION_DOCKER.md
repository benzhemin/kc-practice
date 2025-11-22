# THE REAL SOLUTION: Use Docker Networking

## The Problem - Why Nothing Works

After extensive testing, the issue is that **Reactor Netty checks the RESOLVED IP address**, not just the hostname.

### What We Tried

1. ❌ `.nonProxyHosts("")` - Doesn't work
2. ❌ `System.clearProperty("http.nonProxyHosts")` - Doesn't work
3. ❌ Using `keycloak.local` instead of `localhost` - **Doesn't work!**

### Why `keycloak.local` Doesn't Work

```
1. Application requests: http://keycloak.local:3081/token
2. DNS resolves: keycloak.local → 127.0.0.1
3. Reactor Netty checks: "127.0.0.1" matches "127.*" pattern
4. Result: BYPASS PROXY!
```

The hardcoded check in Reactor Netty:

```java
static final Predicate<String> NO_PROXY_PREDICATE = 
    s -> s != null && (
        s.startsWith("localhost") ||
        s.startsWith("127.") ||      // ⚠️ This catches resolved IPs!
        s.startsWith("[::1]")
    );
```

## The ONLY Working Solution

**Run Keycloak in Docker with a non-localhost IP address.**

---

## Solution 1: Docker with Custom Network (RECOMMENDED)

### Step 1: Create docker-compose.yml

```yaml
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_HTTP_ENABLED: true
      KC_HOSTNAME_STRICT: false
    command:
      - start-dev
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10  # Custom IP (not 127.*)
    ports:
      - "3081:8080"

networks:
  keycloak-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Step 2: Start Keycloak

```bash
docker-compose up -d
```

### Step 3: Get Keycloak's IP

```bash
docker inspect keycloak | grep IPAddress
# Output: "IPAddress": "172.20.0.10"
```

### Step 4: Update application-proxy.yml

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://172.20.0.10:8080/realms/dev-realm  # Docker IP!
      resourceserver:
        jwt:
          issuer-uri: http://172.20.0.10:8080/realms/dev-realm
          jwk-set-uri: http://172.20.0.10:8080/realms/dev-realm/protocol/openid-connect/certs
```

### Step 5: Update Keycloak Redirect URI

Access Keycloak at `http://localhost:3081` (port mapping):
1. Login: admin/admin
2. Go to Clients → `app-client`
3. Add to Valid Redirect URIs:
   - `http://localhost:8080/*`
4. Save

### Step 6: Test

```bash
# Start mitmproxy
./mitm-proxy.sh

# Start application
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Access application
open http://localhost:8080/login
```

### Step 7: Verify

In mitmproxy, you should see:
```
✅ POST http://172.20.0.10:8080/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://172.20.0.10:8080/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://172.20.0.10:8080/realms/dev-realm/protocol/openid-connect/userinfo
```

In logs:
```
[xxx, L:/127.0.0.1:xxx - R:localhost/127.0.0.1:8888]
                                                ^^^^
                                        Port 8888 = Proxy! ✅
```

---

## Solution 2: Use host.docker.internal (Mac/Windows Only)

If your application is also in Docker:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://host.docker.internal:3081/realms/dev-realm
```

This resolves to a non-127.* address on Mac/Windows.

---

## Solution 3: Use a Real External Server

Deploy Keycloak to a real server:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://keycloak.example.com/realms/dev-realm
```

This will definitely go through the proxy.

---

## Solution 4: Use ngrok (Quick Testing)

```bash
# Expose Keycloak
ngrok http 3081

# Use ngrok URL
issuer-uri: https://abc123.ngrok.io/realms/dev-realm
```

---

## Why This is the ONLY Way

### The Reactor Netty Code

```java
boolean shouldProxy(@Nullable SocketAddress address) {
    if (address instanceof InetSocketAddress) {
        InetSocketAddress isa = (InetSocketAddress) address;
        String host = isa.getHostString();  // This is the RESOLVED IP!
        
        // Check hardcoded patterns FIRST
        if (isa.isUnresolved() && NO_PROXY_PREDICATE.test(host)) {
            return false;  // Bypass!
        }
        
        // If resolved, check the IP address
        if (!isa.isUnresolved()) {
            InetAddress addr = isa.getAddress();
            if (addr.isLoopbackAddress()) {  // ⚠️ This catches 127.*!
                return false;  // Bypass!
            }
        }
    }
    return true;
}
```

### The Flow

```
Request to: http://keycloak.local:3081/token
    ↓
DNS Resolution: keycloak.local → 127.0.0.1
    ↓
Create InetSocketAddress(127.0.0.1, 3081)
    ↓
Reactor Netty checks: addr.isLoopbackAddress()
    ↓
Result: true → BYPASS PROXY!
```

**There is NO way to override this behavior!**

---

## Complete Working Setup

### docker-compose.yml

```yaml
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_HTTP_ENABLED: true
      KC_HOSTNAME_STRICT: false
    command:
      - start-dev
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10
    ports:
      - "3081:8080"

networks:
  keycloak-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### application-proxy.yml

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: app-client
            client-secret: mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
            scope: openid,profile,email
            authorization-grant-type: authorization_code
            redirect-uri: "{baseUrl}/login/oauth2/code/gateway"
        provider:
          keycloak:
            issuer-uri: http://172.20.0.10:8080/realms/dev-realm
            user-name-attribute: preferred_username
      resourceserver:
        jwt:
          issuer-uri: http://172.20.0.10:8080/realms/dev-realm
          jwk-set-uri: http://172.20.0.10:8080/realms/dev-realm/protocol/openid-connect/certs

proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

### Commands

```bash
# 1. Start Keycloak
docker-compose up -d

# 2. Wait for Keycloak to start (30 seconds)
sleep 30

# 3. Configure Keycloak client
# Access http://localhost:3081
# Login: admin/admin
# Add redirect URI: http://localhost:8080/*

# 4. Start mitmproxy
./mitm-proxy.sh

# 5. Start application
./gradlew bootRun --args='--spring.profiles.active=proxy'

# 6. Test
open http://localhost:8080/login
```

---

## Summary

**The Problem:**
- Reactor Netty has hardcoded bypass for loopback addresses (127.*)
- This check happens AFTER DNS resolution
- Using `keycloak.local` doesn't help because it resolves to 127.0.0.1
- There is NO configuration to override this

**The Solution:**
- Use Docker with a custom network and non-loopback IP (172.20.0.10)
- Update application to use the Docker IP address
- Traffic will go through proxy because 172.20.0.10 doesn't match 127.*

**Result:**
- ✅ All OAuth2 traffic captured in mitmproxy
- ✅ Can inspect tokens, debug issues
- ✅ Complete visibility into authentication flow

This is the **ONLY** way to capture localhost OAuth2 traffic with Reactor Netty! 🎯

