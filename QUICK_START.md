# 🚀 Quick Start Guide - Capture OAuth2 Token Exchange

## Fastest Method (3 Commands)

```bash
# 1. Start mitmproxy
mitmweb --web-port 8081

# 2. Start app with proxy profile
./start-with-proxy-profile.sh

# 3. Trigger OAuth2 and view
open http://localhost:8080/user
open http://localhost:8081
```

---

## All Available Methods

### Method 1: Using Proxy Profile (RECOMMENDED)

```bash
# Uses application-proxy.yml (proxy pre-enabled)
./gradlew bootRun --args='--spring.profiles.active=proxy'

# Or use the script
./start-with-proxy-profile.sh
```

### Method 2: Using application.yml

```bash
# Edit src/main/resources/application.yml
# Change: proxy.enabled: true

./gradlew bootRun
```

### Method 3: Command Line Override

```bash
# No file changes needed
./gradlew bootRun --args='--proxy.enabled=true --proxy.host=localhost --proxy.port=8888'
```

### Method 4: Using Scripts

```bash
# Config-based proxy
./run-with-config-proxy.sh

# JVM properties proxy
./run-with-proxy.sh
```

---

## What You'll See

### Console Output

```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
<<<<<<<<<<<< OUTGOING REQUEST (via proxy) >>>>>>>>>>>>>>
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
>>>>>>>>>>>> INCOMING RESPONSE <<<<<<<<<<<<
Status: 200 OK
═══════════════════════════════════════════════════════════
```

### mitmproxy (http://localhost:8081)

```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token

Request:
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

## File Structure

```
keycloak-practice/
├── src/main/
│   ├── java/.../config/
│   │   ├── ProxyConfig.java          # Main proxy configuration
│   │   └── SecurityConfig.java       # OAuth2 security config
│   └── resources/
│       ├── application.yml           # Default config (proxy disabled)
│       └── application-proxy.yml     # Proxy profile (proxy enabled)
│
├── doc/
│   ├── USING_PROXY_PROFILE.md       # How to use profiles
│   ├── PROXY_METHODS.md             # All 6 methods
│   ├── PROXY_EXAMPLES.md            # Real-world examples
│   └── PROXY_QUICK_REFERENCE.md     # Cheat sheet
│
├── start-with-proxy-profile.sh     # Quick start script
├── run-with-config-proxy.sh        # Config-based proxy
├── run-with-proxy.sh               # JVM properties proxy
└── QUICK_START.md                  # This file
```

---

## Comparison

| Method | Command | Pros | Best For |
|--------|---------|------|----------|
| **Proxy Profile** | `--spring.profiles.active=proxy` | Clean, reusable | Daily use |
| **application.yml** | Edit file | Simple | Always-on |
| **Command line** | `--proxy.enabled=true` | No edits | Quick test |
| **Script** | `./start-with-proxy-profile.sh` | Easiest | Beginners |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Proxy not working | Check mitmproxy is running: `nc -zv localhost 8888` |
| Profile not loading | Check spelling: `--spring.profiles.active=proxy` |
| No token exchange | Access protected endpoint: `/user` not `/` |
| Connection timeout | Check proxy host/port in config |

---

## Documentation

- **Quick Start:** `QUICK_START.md` (this file)
- **Using Profiles:** `doc/USING_PROXY_PROFILE.md`
- **All Methods:** `doc/PROXY_METHODS.md`
- **Examples:** `doc/PROXY_EXAMPLES.md`
- **Cheat Sheet:** `doc/PROXY_QUICK_REFERENCE.md`
- **Complete Guide:** `PROXY_CONFIGURATION_SUMMARY.md`

---

## Commands Cheat Sheet

```bash
# Install mitmproxy (one time)
brew install mitmproxy

# Start mitmproxy
mitmweb --web-port 8081

# Start app (choose one)
./start-with-proxy-profile.sh                                    # Easiest
./gradlew bootRun --args='--spring.profiles.active=proxy'        # Profile
./gradlew bootRun --args='--proxy.enabled=true'                  # Override
./run-with-config-proxy.sh                                       # Script

# Test OAuth2 flow
open http://localhost:8080/user

# View captured traffic
open http://localhost:8081

# Check if proxy is running
nc -zv localhost 8888

# Check logs for proxy
./gradlew bootRun --args='--spring.profiles.active=proxy' | grep -i proxy
```

---

## Next Steps

1. ✅ Choose your preferred method
2. ✅ Start mitmproxy
3. ✅ Start app with proxy
4. ✅ Trigger OAuth2 login
5. ✅ Inspect token exchange
6. ✅ Decode JWT tokens at https://jwt.io

Happy debugging! 🎉

