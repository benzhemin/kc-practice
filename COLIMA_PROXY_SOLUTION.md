# Keycloak Proxy Setup with Colima - Complete Solution

## The Problem

When running Keycloak in Docker via Colima on macOS, there are **two networking challenges**:

### Challenge 1: Reactor Netty Proxy Bypass
Reactor Netty (used by Spring WebFlux) has **hardcoded logic** that bypasses proxy for:
- `localhost`
- `127.*` (any IP starting with 127)
- `[::1]` (IPv6 localhost)

**Result:** OAuth2 token exchanges go directly to Keycloak, bypassing mitmproxy.

### Challenge 2: Colima Network Isolation
Custom Docker network IPs (like `172.20.0.10`) are **not directly accessible** from the macOS host:
- Docker runs inside a Linux VM managed by Colima
- Custom network IPs only exist inside that VM
- Host machine cannot route to these IPs directly

**Result:** Even if you assign a custom IP to avoid `127.*`, you can't access it.

---

## The Solution

Use **`keycloak.local`** hostname that resolves to the **Docker container IP** (not 127.*):

```
keycloak.local → 172.20.0.10 (Docker container IP)
```

This works because:
1. ✅ It's not `localhost` → Reactor Netty won't bypass proxy
2. ✅ It's not `127.*` → Reactor Netty won't bypass proxy
3. ✅ Resolves to container IP → Accessible from host via port mapping
4. ✅ Container IP is routable → Works with Colima's networking

---

## Setup Steps

### Step 1: Configure Docker Compose

Your `docker-compose.yml` should have:

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
      KC_HOSTNAME: keycloak.local  # ← Important!
    command:
      - start-dev
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10  # Custom IP (not 127.*)
    ports:
      - "3081:8080"  # Port mapping for host access

networks:
  keycloak-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

**Key points:**
- `ipv4_address: 172.20.0.10` - Assigns non-127.* IP to container
- `ports: "3081:8080"` - Maps container port to host port
- `KC_HOSTNAME: keycloak.local` - Keycloak expects this hostname

### Step 2: Setup Hostname Resolution

Run the setup script:

```bash
chmod +x setup-keycloak-hostname.sh
./setup-keycloak-hostname.sh
```

This script will:
1. Start Keycloak container
2. Get the container's IP address (172.20.0.10)
3. Add entry to `/etc/hosts`: `172.20.0.10 keycloak.local`
4. Verify DNS resolution and connectivity

**Manual alternative:**

```bash
# Start Keycloak
docker-compose up -d keycloak

# Get container IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keycloak
# Output: 172.20.0.10

# Add to /etc/hosts (requires sudo)
echo "172.20.0.10 keycloak.local" | sudo tee -a /etc/hosts

# Verify
ping -c 1 keycloak.local
curl http://keycloak.local:3081
```

### Step 3: Update Application Configuration

Your `application-proxy.yml` should use `keycloak.local`:

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

proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

### Step 4: Configure Keycloak

1. Access Keycloak admin console: http://keycloak.local:3081
2. Login with `admin` / `admin`
3. Update client settings:
   - Home URL: `http://localhost:8080`
   - Valid redirect URIs: `http://localhost:8080/login/oauth2/code/*`
   - Post logout redirect URIs: `http://localhost:8080`

**Important:** The redirect URIs use `localhost:8080` because they're used by the **browser**, not the application. The browser can access `localhost:8080` directly.

### Step 5: Start Everything

```bash
# Terminal 1: Start mitmproxy
./mitm-proxy.sh

# Terminal 2: Start application with proxy profile
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Terminal 3: Test the flow
open http://localhost:8080/login
```

---

## How It Works

### Network Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ macOS Host                                                   │
│                                                              │
│  Browser                     Spring Boot App                │
│    │                              │                          │
│    │ 1. http://localhost:8080    │                          │
│    │─────────────────────────────>│                          │
│    │                              │                          │
│    │ 2. Redirect to Keycloak     │                          │
│    │<─────────────────────────────│                          │
│    │                              │                          │
│    │ 3. http://keycloak.local:3081/auth                     │
│    │─────────────────────────────────────────┐              │
│    │                              │           │              │
│    │                              │           ↓              │
│    │                              │    ┌──────────────┐      │
│    │                              │    │ /etc/hosts   │      │
│    │                              │    │ 172.20.0.10  │      │
│    │                              │    │ keycloak.local│     │
│    │                              │    └──────────────┘      │
│    │                              │           │              │
│    │ 4. Login form               │           │              │
│    │<─────────────────────────────────────────┘             │
│    │                              │                          │
│    │ 5. Submit credentials       │                          │
│    │──────────────────────────────────────────>             │
│    │                              │                          │
│    │ 6. Redirect with code       │                          │
│    │<─────────────────────────────────────────              │
│    │                              │                          │
│    │ 7. http://localhost:8080/login/oauth2/code/gateway?code=...
│    │─────────────────────────────>│                          │
│    │                              │                          │
│    │                              │ 8. Token Exchange        │
│    │                              │    http://keycloak.local:3081/token
│    │                              │                          │
│    │                              ↓                          │
│    │                       ┌─────────────┐                   │
│    │                       │ mitmproxy   │                   │
│    │                       │ :8888       │                   │
│    │                       └─────────────┘                   │
│    │                              │                          │
│    │                              ↓                          │
│    │                       Port Mapping                      │
│    │                       3081 → 8080                       │
│    │                              │                          │
└────┼──────────────────────────────┼──────────────────────────┘
     │                              │
     │                              ↓
┌────┼──────────────────────────────┼──────────────────────────┐
│    │      Colima VM               │                          │
│    │                              │                          │
│    │                       ┌──────────────┐                  │
│    └──────────────────────>│  Keycloak    │                  │
│                            │  172.20.0.10 │                  │
│                            │  :8080       │                  │
│                            └──────────────┘                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Why This Works

1. **Browser → Keycloak (Steps 3-6)**
   - Browser resolves `keycloak.local` → `172.20.0.10`
   - Connects to port `3081` (mapped to container's `8080`)
   - **Not proxied** (browser doesn't use application's proxy)

2. **Application → Keycloak (Step 8)**
   - Application makes request to `http://keycloak.local:3081/token`
   - Reactor Netty checks: Is this `localhost` or `127.*`? **NO!**
   - Reactor Netty: "OK, use proxy"
   - Request goes through mitmproxy (`:8888`)
   - mitmproxy forwards to `keycloak.local:3081`
   - DNS resolves to `172.20.0.10`
   - Port mapping forwards to container's `:8080`
   - **✅ Captured in mitmproxy!**

---

## Verification

### Check DNS Resolution

```bash
# Should return 172.20.0.10
getent hosts keycloak.local

# Should NOT return 127.0.0.1
nslookup keycloak.local
```

### Check Container IP

```bash
# Get container IP
docker inspect keycloak | grep IPAddress

# Should show:
# "IPAddress": "172.20.0.10"
```

### Check Connectivity

```bash
# Test direct access (bypasses proxy)
curl http://keycloak.local:3081/realms/dev-realm/.well-known/openid-configuration

# Test via proxy
curl -x http://localhost:8888 http://keycloak.local:3081/realms/dev-realm/.well-known/openid-configuration
```

### Check Application Logs

When you start the application with proxy profile, you should see:

```
═══════════════════════════════════════════════════════════
🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2
Proxy: localhost:8888 (HTTP)
═══════════════════════════════════════════════════════════
```

### Check mitmproxy

After logging in, you should see in mitmproxy:

```
✅ POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

### Check Reactor Netty Logs

Look for connection logs showing proxy port (8888):

```
[L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:8888]
                                              ^^^^
                                         Proxy port!
```

**NOT:**

```
[L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:3081]
                                              ^^^^
                                         Direct connection (BAD!)
```

---

## Troubleshooting

### Issue: "keycloak.local not found"

**Symptoms:**
```
java.net.UnknownHostException: keycloak.local
```

**Solution:**
```bash
# Check /etc/hosts
cat /etc/hosts | grep keycloak.local

# Should show:
# 172.20.0.10 keycloak.local

# If not, add it:
echo "172.20.0.10 keycloak.local" | sudo tee -a /etc/hosts
```

### Issue: "Connection refused to keycloak.local:3081"

**Symptoms:**
```
Connection refused: keycloak.local/172.20.0.10:3081
```

**Solutions:**

1. Check if container is running:
   ```bash
   docker ps | grep keycloak
   ```

2. Check if port mapping is correct:
   ```bash
   docker port keycloak
   # Should show: 8080/tcp -> 0.0.0.0:3081
   ```

3. Check if Keycloak is ready:
   ```bash
   docker logs keycloak
   # Look for: "Keycloak ... started"
   ```

### Issue: "Still bypassing proxy"

**Symptoms:**
- mitmproxy shows no OAuth2 requests
- Logs show connection to `:3081` instead of `:8888`

**Solutions:**

1. Verify DNS resolution is NOT `127.*`:
   ```bash
   getent hosts keycloak.local
   # Should show: 172.20.0.10 keycloak.local
   # NOT: 127.0.0.1 keycloak.local
   ```

2. Check application is using proxy profile:
   ```bash
   ./gradlew bootRun --args='--spring.profiles.active=proxy'
   ```

3. Check proxy is running:
   ```bash
   lsof -i :8888
   # Should show mitmproxy listening
   ```

4. Check application configuration:
   ```bash
   grep -A 3 "proxy:" src/main/resources/application-proxy.yml
   # Should show: enabled: true
   ```

### Issue: "Invalid redirect_uri"

**Symptoms:**
```
error=invalid_redirect_uri
```

**Solution:**

Update Keycloak client settings:
1. Go to http://keycloak.local:3081/admin
2. Login as `admin` / `admin`
3. Select realm: `dev-realm`
4. Clients → `app-client`
5. Valid redirect URIs: `http://localhost:8080/login/oauth2/code/*`
6. Save

**Note:** Use `localhost:8080` (not `keycloak.local`) because the redirect is handled by the browser.

### Issue: "Container IP changed"

**Symptoms:**
- After restarting Docker, `keycloak.local` doesn't work
- DNS resolves to old IP

**Solution:**

Docker assigns IPs dynamically unless you specify a static IP (which we do in `docker-compose.yml`). If the IP changed:

```bash
# Get new IP
NEW_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' keycloak)

# Update /etc/hosts
sudo sed -i.bak '/keycloak.local/d' /etc/hosts
echo "$NEW_IP keycloak.local" | sudo tee -a /etc/hosts
```

Or just run the setup script again:
```bash
./setup-keycloak-hostname.sh
```

---

## Why Not Use Other Solutions?

### ❌ Using `localhost`

```yaml
issuer-uri: http://localhost:3081/realms/dev-realm
```

**Problem:** Reactor Netty bypasses proxy for `localhost` (hardcoded).

### ❌ Using `127.0.0.1`

```yaml
issuer-uri: http://127.0.0.1:3081/realms/dev-realm
```

**Problem:** Reactor Netty bypasses proxy for `127.*` (hardcoded).

### ❌ Using container IP directly

```yaml
issuer-uri: http://172.20.0.10:3081/realms/dev-realm
```

**Problems:**
1. IP might change when container restarts
2. Keycloak expects hostname to match `KC_HOSTNAME`
3. Less readable/maintainable

### ❌ Using `host.docker.internal`

```yaml
issuer-uri: http://host.docker.internal:3081/realms/dev-realm
```

**Problems:**
1. Only works from inside containers (not from host)
2. Resolves to `host-gateway` which might be `127.*`
3. Doesn't work consistently with Colima

### ✅ Using `keycloak.local` (RECOMMENDED)

```yaml
issuer-uri: http://keycloak.local:3081/realms/dev-realm
```

**Benefits:**
1. ✅ Not `localhost` → Proxy works
2. ✅ Not `127.*` → Proxy works
3. ✅ Resolves to container IP → Accessible
4. ✅ Static IP in docker-compose → Consistent
5. ✅ Readable and maintainable
6. ✅ Matches Keycloak's `KC_HOSTNAME`

---

## Summary

### The Problem
- Reactor Netty bypasses proxy for `localhost` and `127.*`
- Colima isolates Docker network IPs from host

### The Solution
- Use custom hostname `keycloak.local`
- Point it to Docker container IP (not 127.*)
- Configure static IP in docker-compose
- Access via port mapping

### The Result
- ✅ OAuth2 traffic flows through mitmproxy
- ✅ Can inspect tokens, debug auth flow
- ✅ Works reliably with Colima on macOS

### Key Files
1. `docker-compose.yml` - Static IP + hostname
2. `/etc/hosts` - DNS resolution
3. `application-proxy.yml` - Use `keycloak.local`
4. `setup-keycloak-hostname.sh` - Automated setup

---

## Quick Reference

```bash
# Setup (one time)
./setup-keycloak-hostname.sh

# Start everything
docker-compose up -d                                              # Terminal 1
./mitm-proxy.sh                                                   # Terminal 2
./gradlew bootRun --args='--spring.profiles.active=proxy'        # Terminal 3

# Test
open http://localhost:8080/login

# Verify
curl http://keycloak.local:3081/realms/dev-realm/.well-known/openid-configuration
```

That's it! 🎉

