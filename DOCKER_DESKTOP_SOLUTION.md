# Docker Desktop Solution for Keycloak + Proxy

## Current Status

✅ **Keycloak is running** on Docker Desktop
✅ **localhost:3081 works** (I verified the connection)
❌ **keycloak.local:3081 doesn't work** (DNS issue)

## The Problem

Your `/etc/hosts` has:
```
172.20.0.10     keycloak.local
```

But `172.20.0.10` is **not accessible** from your Mac, even with Docker Desktop!

```bash
ping 172.20.0.10
# 100% packet loss ❌
```

## The Solution

Change `/etc/hosts` to point `keycloak.local` to `127.0.0.1` instead:

```bash
127.0.0.1     keycloak.local
```

This works because:
1. Port mapping makes Keycloak accessible at `localhost:3081`
2. `keycloak.local` → `127.0.0.1:3081` → Same as `localhost:3081`
3. Reactor Netty sees hostname `"keycloak.local"` (not "localhost") → Uses proxy ✅

---

## Quick Fix (Manual)

```bash
# 1. Edit /etc/hosts
sudo nano /etc/hosts

# 2. Change this line:
172.20.0.10     keycloak.local

# 3. To this:
127.0.0.1       keycloak.local

# 4. Save and exit (Ctrl+X, Y, Enter)

# 5. Test
curl http://keycloak.local:3081
# Should work! ✅
```

---

## Automated Fix

Run the setup script:

```bash
./setup-docker-desktop.sh
```

This script will:
1. Stop and restart Keycloak
2. Update `/etc/hosts` to use `127.0.0.1`
3. Verify everything works

---

## Why This Works

### The Network Flow

```
Application request: http://keycloak.local:3081/token
         ↓
    [Reactor Netty]
    Check hostname: "keycloak.local"
    - Not "localhost" ✅
    - Not "127.*" ✅
    → Use proxy!
         ↓
    [mitmproxy:8888]
    ✅ Request captured!
    Forward to: keycloak.local:3081
         ↓
    [DNS Resolution]
    /etc/hosts: keycloak.local → 127.0.0.1
         ↓
    [OS Network Stack]
    Connect to: 127.0.0.1:3081
         ↓
    [Docker Port Mapping]
    3081 → container:8080
         ↓
    [Keycloak Container]
    Receive request ✅
```

### Key Insight

**Reactor Netty checks the HOSTNAME STRING before DNS resolution!**

```java
// Reactor Netty's check
if (hostname.equals("localhost") || hostname.startsWith("127.")) {
    bypassProxy();  // ❌
}
```

When you use `keycloak.local`:
- Reactor Netty sees: `"keycloak.local"` → Not localhost → Use proxy ✅
- Then DNS resolves: `keycloak.local` → `127.0.0.1`
- Connection goes to: `127.0.0.1:3081` (which works via port mapping)

---

## Verification

### Test 1: Check /etc/hosts

```bash
cat /etc/hosts | grep keycloak
# Should show: 127.0.0.1       keycloak.local
```

### Test 2: Test DNS Resolution

```bash
getent hosts keycloak.local
# Should show: 127.0.0.1       keycloak.local
```

### Test 3: Test Connectivity

```bash
# Test localhost
curl http://localhost:3081
# HTTP/1.1 302 Found ✅

# Test keycloak.local
curl http://keycloak.local:3081
# HTTP/1.1 302 Found ✅
```

### Test 4: Open in Browser

```bash
open http://keycloak.local:3081
# Should open Keycloak admin console ✅
```

---

## Configuration Files

### docker-compose.yml (Keep as is)

```yaml
services:
  keycloak:
    ports:
      - "3081:8080"  # This is what makes it accessible
    environment:
      KC_HOSTNAME: keycloak.local  # Keycloak expects this hostname
```

### /etc/hosts (Update this)

```
127.0.0.1       localhost
127.0.0.1       keycloak.local  # ← Add this line
```

### application-proxy.yml (Keep as is)

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://keycloak.local:3081/realms/dev-realm
            # Use keycloak.local (not localhost) to bypass Reactor Netty's proxy exclusion

proxy:
  enabled: true
  host: localhost
  port: 8888
```

---

## Complete Setup Steps

### 1. Start Keycloak

```bash
docker compose up -d keycloak
```

### 2. Update /etc/hosts

```bash
# Remove old entry
sudo sed -i.bak '/keycloak.local/d' /etc/hosts

# Add new entry
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
```

### 3. Verify

```bash
curl http://keycloak.local:3081
# Should work! ✅
```

### 4. Configure Keycloak

```bash
# Open admin console
open http://keycloak.local:3081/admin

# Login: admin / admin

# Create realm: dev-realm
# Create client: app-client
# Create users and roles
```

### 5. Start Proxy

```bash
./mitm-proxy.sh
```

### 6. Start Application

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### 7. Test

```bash
open http://localhost:8080/login
```

Check mitmproxy - you should see OAuth2 token exchanges! 🎉

---

## Why Container IP Doesn't Work

Even with Docker Desktop, the container IP `172.20.0.10` is **not directly accessible** from macOS:

```bash
# Container has IP 172.20.0.10
docker inspect keycloak | grep IPAddress
# "IPAddress": "172.20.0.10"

# But you can't reach it
ping 172.20.0.10
# 100% packet loss ❌

curl http://172.20.0.10:8080
# Timeout ❌

curl http://172.20.0.10:3081
# Timeout ❌
```

**Why?** Docker Desktop on macOS runs containers in a Linux VM (like Colima). The container network is isolated from the host.

**Solution:** Use port mapping to access via `localhost`.

---

## Comparison: What Works vs What Doesn't

### ❌ Doesn't Work

```bash
# Container IP directly
curl http://172.20.0.10:8080
# Timeout ❌

curl http://172.20.0.10:3081
# Timeout ❌

# keycloak.local pointing to container IP
# /etc/hosts: 172.20.0.10 keycloak.local
curl http://keycloak.local:3081
# Timeout ❌
```

### ✅ Works

```bash
# localhost via port mapping
curl http://localhost:3081
# Success! ✅

# keycloak.local pointing to localhost
# /etc/hosts: 127.0.0.1 keycloak.local
curl http://keycloak.local:3081
# Success! ✅
```

---

## Why This is Better Than Using localhost

### Using localhost in Config

```yaml
issuer-uri: http://localhost:3081/realms/dev-realm
```

**Problem:** Reactor Netty bypasses proxy for `localhost` ❌

```
Application → http://localhost:3081/token
         ↓
Reactor Netty: "localhost" → Bypass proxy
         ↓
Direct connection (mitmproxy doesn't see it) ❌
```

### Using keycloak.local in Config

```yaml
issuer-uri: http://keycloak.local:3081/realms/dev-realm
```

**Success:** Reactor Netty uses proxy ✅

```
Application → http://keycloak.local:3081/token
         ↓
Reactor Netty: "keycloak.local" → Use proxy ✅
         ↓
mitmproxy:8888 (captured!) ✅
         ↓
Forward to keycloak.local:3081
         ↓
DNS: 127.0.0.1:3081
         ↓
Port mapping → container ✅
```

---

## Troubleshooting

### Issue: "keycloak.local not found"

```bash
curl: (6) Could not resolve host: keycloak.local
```

**Solution:**
```bash
# Check /etc/hosts
cat /etc/hosts | grep keycloak

# Should have:
# 127.0.0.1       keycloak.local

# If not, add it:
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
```

### Issue: "Connection refused to keycloak.local:3081"

```bash
curl: (7) Failed to connect to keycloak.local port 3081: Connection refused
```

**Solution:**
```bash
# Check if Keycloak is running
docker ps | grep keycloak

# Check if port mapping exists
docker port keycloak
# Should show: 8080/tcp -> 0.0.0.0:3081

# Check if localhost:3081 works
curl http://localhost:3081
# If this works, it's a DNS issue
```

### Issue: "Keycloak redirects to wrong URL"

Keycloak redirects to `http://localhost:3081` instead of `http://keycloak.local:3081`

**Solution:**
```bash
# Check KC_HOSTNAME in docker-compose.yml
docker inspect keycloak | grep KC_HOSTNAME

# Should be: KC_HOSTNAME=keycloak.local

# If not, update docker-compose.yml and restart:
docker compose down
docker compose up -d
```

---

## Summary

### The Problem
- Container IP `172.20.0.10` is not accessible from macOS host
- Even with Docker Desktop, containers run in a VM
- Port mapping only works with `localhost`

### The Solution
- Point `keycloak.local` to `127.0.0.1` in `/etc/hosts`
- Use `keycloak.local` in application config (bypasses Reactor Netty's proxy exclusion)
- Connection goes through port mapping to container

### The Result
- ✅ `keycloak.local:3081` works (accessible via port mapping)
- ✅ Reactor Netty uses proxy (hostname is not "localhost")
- ✅ mitmproxy captures OAuth2 traffic
- ✅ Can debug token exchanges

---

## Quick Reference

```bash
# Fix /etc/hosts
echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts

# Start everything
docker compose up -d                                              # Terminal 1
./mitm-proxy.sh                                                   # Terminal 2
./gradlew bootRun --args='--spring.profiles.active=proxy'        # Terminal 3

# Test
open http://localhost:8080/login

# Verify proxy is working
# Check mitmproxy for: POST http://keycloak.local:3081/.../token
```

That's it! 🎯


