# mitmproxy Commands Reference

## Understanding the Ports

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Spring Boot App                                            │
│  (localhost:8080)                                           │
│                                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Sends HTTP requests through proxy
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  mitmproxy Proxy Port                                       │
│  (localhost:8888) ◄── Your app sends requests here         │
│                                                             │
│  Captures traffic and forwards to actual destination        │
│                                                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Forwards to actual target
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Keycloak                                                   │
│  (localhost:3081)                                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Optional: mitmweb Web UI (localhost:8081) for viewing captured traffic
```

---

## mitmproxy CLI Commands

### Basic Usage

```bash
# Default: Listen on port 8888
mitmproxy

# Explicit port
mitmproxy --listen-port 8888

# Listen on all interfaces (not just localhost)
mitmproxy --listen-host 0.0.0.0 --listen-port 8888

# Bind to specific interface
mitmproxy --listen-host 127.0.0.1 --listen-port 8888
```

### With Filtering

```bash
# Only show requests to Keycloak
mitmproxy --listen-port 8888 -f "~d localhost:3081"

# Only show POST requests
mitmproxy --listen-port 8888 -f "~m POST"

# Only show requests with "token" in URL
mitmproxy --listen-port 8888 -f "~u token"

# Combine filters (POST to Keycloak)
mitmproxy --listen-port 8888 -f "~m POST & ~d localhost:3081"
```

### Keyboard Shortcuts (in mitmproxy)

```
Arrow keys    - Navigate requests
Enter         - View request/response details
Tab           - Switch between request/response/detail
q             - Back to list
Q             - Quit mitmproxy
/             - Search
?             - Help
e             - Edit request/response
r             - Replay request
z             - Clear flow list
```

---

## mitmdump Commands

`mitmdump` is the non-interactive version that outputs to console.

### Basic Usage

```bash
# Simple console output
mitmdump --listen-port 8888

# Verbose output (shows headers)
mitmdump --listen-port 8888 -v

# Very verbose (shows everything)
mitmdump --listen-port 8888 -vv
```

### Save to File

```bash
# Save captured traffic to file
mitmdump --listen-port 8888 -w capture.mitm

# Read from saved file
mitmdump -r capture.mitm

# Save and display
mitmdump --listen-port 8888 -w capture.mitm -v
```

### Filtering

```bash
# Only capture POST requests
mitmdump --listen-port 8888 -f "~m POST"

# Only capture requests to /token endpoint
mitmdump --listen-port 8888 -f "~u token"

# Only capture requests to Keycloak
mitmdump --listen-port 8888 -f "~d localhost:3081"

# Capture OAuth2 token exchange specifically
mitmdump --listen-port 8888 -f "~m POST & ~u openid-connect/token"
```

### Custom Output Format

```bash
# Show only URLs
mitmdump --listen-port 8888 --flow-detail 0

# Show request method and URL
mitmdump --listen-port 8888 -v | grep -E "(POST|GET)"

# Save as JSON
mitmdump --listen-port 8888 -w - | jq '.'
```

---

## mitmweb Commands

`mitmweb` provides a web interface for viewing captured traffic.

### Basic Usage

```bash
# Default: Proxy on 8888, Web UI on 8081
mitmweb

# Explicit ports
mitmweb --listen-port 8888 --web-port 8081

# Different web UI port
mitmweb --web-port 9000

# Bind web UI to all interfaces
mitmweb --web-host 0.0.0.0 --web-port 8081
```

### With Options

```bash
# Don't open browser automatically
mitmweb --no-web-open-browser

# Custom web UI port
mitmweb --web-port 9090

# Save captured traffic
mitmweb --save-stream-file capture.mitm
```

---

## Complete Workflow Examples

### Example 1: Using mitmproxy CLI

```bash
# Terminal 1: Start mitmproxy
mitmproxy --listen-port 8888

# Terminal 2: Start Spring Boot
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Terminal 3: Trigger OAuth2
curl -v http://localhost:8080/user

# In Terminal 1 (mitmproxy):
# - Use arrow keys to find POST to /openid-connect/token
# - Press Enter to view details
# - Press Tab to switch between Request/Response
# - Look for access_token, refresh_token, id_token
```

### Example 2: Using mitmdump with Filtering

```bash
# Terminal 1: Start mitmdump with filter for token endpoint
mitmdump --listen-port 8888 -v -f "~u token"

# Terminal 2: Start Spring Boot
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Terminal 3: Trigger OAuth2
open http://localhost:8080/user

# Terminal 1 will show:
# POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
# Request body: grant_type=authorization_code&code=...
# Response: {"access_token":"...","refresh_token":"..."}
```

### Example 3: Using mitmweb

```bash
# Terminal 1: Start mitmweb
mitmweb --listen-port 8888 --web-port 8081

# Terminal 2: Start Spring Boot
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Browser 1: Trigger OAuth2
open http://localhost:8080/user

# Browser 2: View captured traffic
open http://localhost:8081
# Filter by: /token
```

---

## Filtering Syntax

### Filter Expressions

| Filter | Description | Example |
|--------|-------------|---------|
| `~m METHOD` | Match HTTP method | `~m POST` |
| `~u REGEX` | Match URL | `~u token` |
| `~d DOMAIN` | Match domain | `~d localhost:3081` |
| `~s CODE` | Match status code | `~s 200` |
| `~h HEADER` | Match header | `~h Content-Type` |
| `~b REGEX` | Match body | `~b access_token` |
| `~q` | Match request | `~q` |
| `~s` | Match response | `~s` |

### Combining Filters

```bash
# AND operator: &
mitmproxy -f "~m POST & ~u token"

# OR operator: |
mitmproxy -f "~m POST | ~m GET"

# NOT operator: !
mitmproxy -f "!~d localhost"

# Complex example: POST to token endpoint with 200 response
mitmproxy -f "~m POST & ~u token & ~s 200"
```

---

## Recommended Commands for This Project

### For Learning (Interactive)

```bash
# Use mitmproxy CLI with filter for OAuth2 token exchange
mitmproxy --listen-port 8888 -f "~m POST & ~u openid-connect/token"
```

### For Debugging (Console Output)

```bash
# Use mitmdump with verbose output
mitmdump --listen-port 8888 -v -f "~u token"
```

### For Detailed Analysis (Web UI)

```bash
# Use mitmweb for easy viewing
mitmweb --listen-port 8888 --web-port 8081
```

---

## Configuration Summary

### Your Current Setup

```yaml
# application.yml or application-proxy.yml
proxy:
  enabled: true
  host: localhost
  port: 8888      # ◄── Spring sends requests to this port
  type: HTTP
```

### Matching mitmproxy Commands

```bash
# Any of these will work:
mitmproxy                           # Default port 8888
mitmproxy --listen-port 8888        # Explicit
mitmdump --listen-port 8888 -v      # Console output
mitmweb --listen-port 8888          # Web UI
```

---

## Troubleshooting

### Port Already in Use

```bash
# Check what's using port 8888
lsof -i :8888

# Kill the process
kill -9 <PID>

# Or use a different port
mitmproxy --listen-port 9999
# Then update application.yml: proxy.port: 9999
```

### Not Seeing Traffic

```bash
# Check mitmproxy is listening
lsof -i :8888
# Should show: mitmproxy

# Test proxy manually
curl -x http://localhost:8888 http://example.com

# Check Spring Boot is using proxy
./gradlew bootRun --args='--spring.profiles.active=proxy' | grep "PROXY ENABLED"
```

### SSL/TLS Issues

```bash
# For HTTPS targets, you may need to install mitmproxy CA cert
# Location: ~/.mitmproxy/mitmproxy-ca-cert.pem

# For this project, Keycloak uses HTTP (localhost:3081)
# So no SSL setup needed!
```

---

## Quick Reference Card

```bash
# START MITMPROXY
mitmproxy                                    # CLI (port 8888)
mitmdump --listen-port 8888 -v               # Console
mitmweb --listen-port 8888 --web-port 8081   # Web UI

# START SPRING BOOT
./gradlew bootRun --args='--spring.profiles.active=proxy'

# TRIGGER OAUTH2
open http://localhost:8080/user

# VIEW TRAFFIC
# - mitmproxy: Use arrow keys, Enter to view
# - mitmdump: Check console output
# - mitmweb: Open http://localhost:8081
```

---

## Summary

### For Your Use Case (Capturing OAuth2 Token Exchange)

**Recommended Command:**

```bash
# Option 1: Interactive (best for learning)
mitmproxy --listen-port 8888

# Option 2: Console output (best for quick checks)
mitmdump --listen-port 8888 -v -f "~u token"

# Option 3: Web UI (best for detailed analysis)
mitmweb --listen-port 8888 --web-port 8081
```

All three listen on **port 8888** for proxy traffic, which matches your configuration!

The key point: **8888 is the proxy port** (where your app sends requests), not the web UI port.

