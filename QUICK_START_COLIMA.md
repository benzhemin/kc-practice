# Quick Start - Keycloak with Proxy on Colima

## TL;DR

```bash
# 1. Setup hostname (one-time)
./setup-keycloak-hostname.sh

# 2. Start proxy
./mitm-proxy.sh

# 3. Start app
./gradlew bootRun --args='--spring.profiles.active=proxy'

# 4. Test
open http://localhost:8080/login
```

Check mitmproxy - you should see OAuth2 token exchanges! 🎉

---

## Why This Works

### The Problem
- **Reactor Netty** (Spring WebFlux HTTP client) has hardcoded logic that **bypasses proxy** for:
  - `localhost`
  - `127.*` (any IP starting with 127)
  - `[::1]` (IPv6 localhost)

- **Colima** (Docker on macOS) runs containers in a VM:
  - Custom network IPs like `172.20.0.10` are not directly accessible from host
  - Need port mapping to access containers

### The Solution
Use `keycloak.local` hostname that resolves to the **Docker container IP** (not 127.*):

```
Browser/App → keycloak.local → 172.20.0.10:3081 → Container:8080
```

This works because:
1. ✅ Not `localhost` → Reactor Netty won't bypass proxy
2. ✅ Not `127.*` → Reactor Netty won't bypass proxy  
3. ✅ Container IP is accessible via port mapping
4. ✅ Static IP in docker-compose ensures consistency

---

## What the Setup Script Does

`./setup-keycloak-hostname.sh`:

1. Starts Keycloak container
2. Gets container IP: `172.20.0.10`
3. Adds to `/etc/hosts`: `172.20.0.10 keycloak.local`
4. Verifies DNS resolution and connectivity

**Manual alternative:**

```bash
docker-compose up -d keycloak
echo "172.20.0.10 keycloak.local" | sudo tee -a /etc/hosts
```

---

## Configuration

### docker-compose.yml

```yaml
services:
  keycloak:
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10  # Static IP (not 127.*)
    ports:
      - "3081:8080"  # Port mapping for host access
    environment:
      KC_HOSTNAME: keycloak.local  # Match hostname
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

proxy:
  enabled: true
  host: localhost
  port: 8888
```

---

## Verification

### 1. Check DNS Resolution

```bash
getent hosts keycloak.local
# Should show: 172.20.0.10 keycloak.local
# NOT: 127.0.0.1 keycloak.local
```

### 2. Check Container

```bash
docker ps | grep keycloak
docker inspect keycloak | grep IPAddress
# Should show: "IPAddress": "172.20.0.10"
```

### 3. Check Connectivity

```bash
curl http://keycloak.local:3081/realms/dev-realm/.well-known/openid-configuration
# Should return JSON configuration
```

### 4. Check Proxy Capture

After logging in, check mitmproxy for:

```
✅ POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

### 5. Check Application Logs

Look for:

```
🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2
Proxy: localhost:8888 (HTTP)
```

And Reactor Netty connection to proxy port:

```
[L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:8888]
                                              ^^^^
                                         Proxy port (GOOD!)
```

**NOT:**

```
[L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:3081]
                                              ^^^^
                                         Direct to Keycloak (BAD!)
```

---

## Troubleshooting

### "keycloak.local not found"

```bash
# Check /etc/hosts
cat /etc/hosts | grep keycloak.local

# If missing, run setup again
./setup-keycloak-hostname.sh
```

### "Connection refused"

```bash
# Check container is running
docker ps | grep keycloak

# Check logs
docker logs keycloak

# Restart if needed
docker-compose restart keycloak
```

### "Still bypassing proxy"

```bash
# Verify DNS resolution is NOT 127.*
getent hosts keycloak.local
# Must show: 172.20.0.10

# Check proxy is running
lsof -i :8888

# Check correct profile
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### "Invalid redirect_uri"

Update Keycloak client at http://keycloak.local:3081/admin:
- Valid redirect URIs: `http://localhost:8080/login/oauth2/code/*`

**Note:** Use `localhost:8080` (not `keycloak.local`) for redirects - they're handled by the browser.

---

## Access URLs

| Service | URL | Used By | Proxied? |
|---------|-----|---------|----------|
| Application | http://localhost:8080 | Browser | No |
| Keycloak (browser) | http://keycloak.local:3081 | Browser | No |
| Keycloak (app) | http://keycloak.local:3081 | Application | **Yes!** ✅ |
| Keycloak Admin | http://keycloak.local:3081/admin | Browser | No |
| mitmproxy | http://localhost:8888 | Proxy | N/A |

---

## Network Flow

```
Login Flow:
1. Browser → http://localhost:8080/login
2. App redirects → http://keycloak.local:3081/auth (browser direct)
3. User logs in (browser direct)
4. Keycloak redirects → http://localhost:8080/login/oauth2/code/gateway?code=...
5. App exchanges code for token:
   App → mitmproxy (8888) → keycloak.local (3081) → Container (8080)
   ✅ CAPTURED IN MITMPROXY!
```

---

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Static IP + port mapping |
| `/etc/hosts` | DNS: keycloak.local → 172.20.0.10 |
| `application-proxy.yml` | Use keycloak.local + enable proxy |
| `setup-keycloak-hostname.sh` | Automated setup |
| `COLIMA_PROXY_SOLUTION.md` | Detailed explanation |

---

## Why Not...?

| Approach | Why Not? |
|----------|----------|
| Use `localhost` | Reactor Netty bypasses proxy (hardcoded) |
| Use `127.0.0.1` | Reactor Netty bypasses proxy (hardcoded) |
| Use container IP directly | Less readable, might change, hostname mismatch |
| Use `host.docker.internal` | Only works inside containers, might resolve to 127.* |
| Use custom ProxyProvider | Too complex, requires deep Reactor Netty customization |

**✅ Use `keycloak.local`** - Simple, reliable, works with Colima!

---

## Summary

**Problem:** Can't proxy OAuth2 traffic to Keycloak on Colima because:
- Reactor Netty bypasses proxy for `localhost` and `127.*`
- Docker network IPs not accessible from host

**Solution:** Use `keycloak.local` hostname:
- Resolves to container IP `172.20.0.10` (not 127.*)
- Accessible via port mapping `3081:8080`
- Reactor Netty doesn't bypass proxy

**Result:** All OAuth2 token exchanges captured in mitmproxy! 🎉

---

For detailed explanation, see: `COLIMA_PROXY_SOLUTION.md`

