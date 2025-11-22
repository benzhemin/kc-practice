# Proxy Configuration Quick Reference

One-page reference for all proxy configuration methods.

## 🚀 Fastest Method (30 seconds)

```bash
# 1. Edit application.yml - change one line:
#    proxy.enabled: true

# 2. Start proxy
mitmweb --web-port 8081

# 3. Run app
./gradlew bootRun

# 4. Test
open http://localhost:8080/user

# 5. View
open http://localhost:8081
```

---

## 📋 All Methods at a Glance

### Method 1: application.yml
```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
```
```bash
./gradlew bootRun
```

### Method 2: Command Line
```bash
./gradlew bootRun --args='--proxy.enabled=true --proxy.host=localhost --proxy.port=8888'
```

### Method 3: Spring Profile
```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### Method 4: Script (Config)
```bash
./run-with-config-proxy.sh localhost 8888
```

### Method 5: Script (JVM)
```bash
./run-with-proxy.sh localhost 8888
```

### Method 6: Environment Variables
```bash
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888
./gradlew bootRun
```

---

## 🎯 What You're Looking For

### In Console Logs
```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════

🔵 OUTGOING REQUEST (via proxy)
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
```

### In mitmproxy
```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token

Request Body:
grant_type=authorization_code
&code=eyJhbGci...
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF

Response:
{
  "access_token": "eyJhbGci...",
  "refresh_token": "eyJhbGci...",
  "id_token": "eyJhbGci..."
}
```

---

## 🔧 Configuration Files

### ProxyConfig.java
```
src/main/java/com/zz/gateway/auth/config/ProxyConfig.java
```
- Main proxy configuration bean
- Handles HTTP, SOCKS4, SOCKS5
- Supports authentication
- Logs all requests/responses

### application.yml
```
src/main/resources/application.yml
```
```yaml
proxy:
  enabled: false  # Change to true
  host: localhost
  port: 8888
  type: HTTP
```

### application-proxy.yml
```
src/main/resources/application-proxy.yml
```
Pre-configured profile with proxy enabled

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Proxy not working | Check `proxy.enabled: true` in application.yml |
| Connection timeout | Check proxy is running: `nc -zv localhost 8888` |
| Not seeing logs | Check logging level: `TRACE` for oauth2 |
| Token not captured | Make sure to access protected endpoint: `/user` |

---

## 📊 Quick Comparison

| Method | Setup Time | Flexibility | Best For |
|--------|-----------|-------------|----------|
| application.yml | 10 sec | ⭐⭐⭐ | Development |
| Command line | 5 sec | ⭐⭐ | Quick test |
| Spring profile | 15 sec | ⭐⭐⭐ | Multi-env |
| Config script | 5 sec | ⭐⭐ | Daily use |
| JVM properties | 5 sec | ⭐ | Legacy |
| Env variables | 10 sec | ⭐⭐ | Docker |

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| PROXY_CONFIGURATION_SUMMARY.md | Complete overview |
| doc/README_PROXY.md | Getting started |
| doc/QUICK_START_PROXY.md | 30-second guide |
| doc/PROXY_METHODS.md | All 6 methods detailed |
| doc/PROXY_EXAMPLES.md | Real-world examples |
| doc/PROXY_CONFIGURATION.md | Detailed setup |

---

## 🎓 Common Use Cases

### Capture OAuth2 Token Exchange
```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
```

### Corporate Proxy with Auth
```yaml
proxy:
  enabled: true
  host: corporate-proxy.com
  port: 3128
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}
```

### SOCKS5 Proxy (SSH Tunnel)
```yaml
proxy:
  enabled: true
  host: localhost
  port: 1080
  type: SOCKS5
```

### Docker Environment
```yaml
# docker-compose.yml
environment:
  - http_proxy=http://proxy:8888
  - https_proxy=http://proxy:8888
```

---

## ⚡ Commands Cheat Sheet

```bash
# Install mitmproxy
brew install mitmproxy

# Start mitmproxy (CLI)
mitmproxy

# Start mitmproxy (Web UI)
mitmweb --web-port 8081

# Test proxy connectivity
nc -zv localhost 8888
curl -x http://localhost:8888 http://example.com

# Run app with proxy (various methods)
./gradlew bootRun                                    # Uses application.yml
./run-with-config-proxy.sh                           # Config-based
./run-with-proxy.sh                                  # JVM properties
./gradlew bootRun --args='--spring.profiles.active=proxy'  # Profile

# Test OAuth2 flow
curl -v http://localhost:8080/user
open http://localhost:8080/user

# View mitmproxy web UI
open http://localhost:8081

# Check logs for proxy
./gradlew bootRun | grep -i proxy

# Decode JWT token
# Copy token from logs and paste at: https://jwt.io
```

---

## 🔑 Key Points

1. **Token exchange is server-to-server** (Spring ↔ Keycloak)
2. **Not visible in browser** (only authorization code is)
3. **Client secret is transmitted** in the request
4. **Three tokens returned**: access_token, refresh_token, id_token
5. **Proxy captures everything** including the token exchange
6. **Multiple methods available** - choose what works best

---

## 📞 Need Help?

1. **Start with:** `doc/README_PROXY.md`
2. **Quick test:** `doc/QUICK_START_PROXY.md`
3. **All methods:** `doc/PROXY_METHODS.md`
4. **Examples:** `doc/PROXY_EXAMPLES.md`
5. **Troubleshooting:** `doc/PROXY_CONFIGURATION.md`

---

## ✅ Checklist

- [ ] Proxy tool installed (mitmproxy/Charles)
- [ ] Proxy tool running (port 8888)
- [ ] Proxy enabled in application.yml
- [ ] App running (`./gradlew bootRun`)
- [ ] OAuth2 flow triggered (`/user` endpoint)
- [ ] Console shows "PROXY ENABLED"
- [ ] Console shows "OUTGOING REQUEST (via proxy)"
- [ ] mitmproxy shows POST to `/token` endpoint
- [ ] Token response visible in mitmproxy

---

**Last Updated:** 2024-11-22
**Project:** keycloak-practice
**Author:** AI Assistant

