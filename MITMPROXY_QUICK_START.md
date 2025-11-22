# mitmproxy Quick Start - Capture Port 8888

## TL;DR

```bash
# Terminal 1: Start mitmproxy (captures traffic on port 8888)
mitmproxy

# Terminal 2: Start Spring Boot with proxy
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Terminal 3: Trigger OAuth2
open http://localhost:8080/user

# Terminal 1: Use arrow keys to find POST to /token endpoint
```

---

## Understanding the Ports

**Port 8888** = Proxy port (where your app sends requests) ✅  
**Port 8081** = Web UI port (only for mitmweb, to view in browser)

```
Your App → Port 8888 (mitmproxy) → Keycloak
            ↑
            This is what you configure in application.yml
```

---

## Three Ways to Use mitmproxy

### 1. mitmproxy (CLI - Interactive)

```bash
mitmproxy
```

**Default behavior:**
- Listens on port **8888** for proxy traffic
- Shows interactive terminal UI
- Navigate with arrow keys

**What you'll see:**
```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
```

Press `Enter` to view request/response details.

---

### 2. mitmdump (Console Output)

```bash
mitmdump -v
```

**Default behavior:**
- Listens on port **8888** for proxy traffic
- Prints to console
- Non-interactive

**What you'll see:**
```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
    ← 200 OK 2.8k
```

---

### 3. mitmweb (Web UI)

```bash
mitmweb --web-port 8081
```

**Default behavior:**
- Listens on port **8888** for proxy traffic
- Provides web UI on port **8081**
- Open browser to view

**What you'll see:**
- Browser opens at `http://localhost:8081`
- Click on requests to view details

---

## Recommended for Beginners

```bash
# Use mitmweb - easiest to understand
mitmweb --web-port 8081
```

Then:
1. Start your app: `./gradlew bootRun --args='--spring.profiles.active=proxy'`
2. Trigger OAuth2: `open http://localhost:8080/user`
3. View traffic: `open http://localhost:8081`
4. Filter by: `/token`

---

## Recommended for Daily Use

```bash
# Use mitmdump with filter - quick and focused
mitmdump -v -f "~u token"
```

This will only show requests with "token" in the URL.

---

## All Commands Listen on Port 8888 by Default

```bash
mitmproxy                    # ✅ Listens on 8888
mitmdump                     # ✅ Listens on 8888
mitmweb                      # ✅ Listens on 8888 (web UI on 8081)

# Explicit (same result)
mitmproxy --listen-port 8888
mitmdump --listen-port 8888
mitmweb --listen-port 8888 --web-port 8081
```

---

## Your Configuration is Correct

```yaml
# application.yml or application-proxy.yml
proxy:
  enabled: true
  host: localhost
  port: 8888      # ✅ This matches mitmproxy's default
  type: HTTP
```

---

## Complete Example

### Terminal 1: Start mitmproxy

```bash
mitmproxy
```

### Terminal 2: Start Spring Boot

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

**Look for:**
```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════
```

### Terminal 3: Trigger OAuth2

```bash
open http://localhost:8080/user
```

### Terminal 1: View Captured Traffic

Use arrow keys to navigate to:
```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
```

Press `Enter` to view details.

Press `Tab` to switch between Request/Response.

Look for:
- **Request body:** `grant_type=authorization_code&code=...&client_secret=...`
- **Response body:** `{"access_token":"...","refresh_token":"...","id_token":"..."}`

---

## Filtering (Advanced)

### Show only token endpoint requests

```bash
mitmproxy -f "~u token"
```

### Show only POST requests

```bash
mitmproxy -f "~m POST"
```

### Show only requests to Keycloak

```bash
mitmproxy -f "~d localhost:3081"
```

### Combine filters

```bash
mitmproxy -f "~m POST & ~u token"
```

---

## Troubleshooting

### "Address already in use"

```bash
# Check what's using port 8888
lsof -i :8888

# Kill it
kill -9 <PID>

# Or use different port
mitmproxy --listen-port 9999
# Then update application.yml: proxy.port: 9999
```

### Not seeing any traffic

```bash
# 1. Check mitmproxy is running
lsof -i :8888

# 2. Check Spring Boot has proxy enabled
grep "proxy.enabled" src/main/resources/application-proxy.yml
# Should show: enabled: true

# 3. Check app is using proxy
./gradlew bootRun --args='--spring.profiles.active=proxy' | grep "PROXY ENABLED"
```

### Seeing traffic but not token exchange

```bash
# Make sure you're accessing a PROTECTED endpoint
# ✅ Good: http://localhost:8080/user
# ❌ Bad:  http://localhost:8080/

# The home page (/) is public, so no OAuth2 is triggered
```

---

## Summary

**Command to capture port 8888 proxy:**

```bash
mitmproxy
```

That's it! mitmproxy listens on port 8888 by default.

**Your app config is already correct:**
```yaml
proxy:
  port: 8888  # ✅ Matches mitmproxy default
```

**Complete workflow:**
1. `mitmproxy` (or `mitmdump -v` or `mitmweb`)
2. `./gradlew bootRun --args='--spring.profiles.active=proxy'`
3. `open http://localhost:8080/user`
4. View captured OAuth2 token exchange!

For more details, see: `doc/MITMPROXY_COMMANDS.md`

