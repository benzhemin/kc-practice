# Using application-proxy.yml Profile

This guide shows how to use the `application-proxy.yml` Spring profile for capturing OAuth2 token exchanges.

## What is application-proxy.yml?

`application-proxy.yml` is a **Spring profile** that has proxy configuration pre-enabled. It's a complete copy of your main configuration with one key difference:

```yaml
proxy:
  enabled: true  # ⬅️ Pre-enabled!
  host: localhost
  port: 8888
  type: HTTP
```

## Why Use a Profile?

### ✅ Advantages
- No need to edit `application.yml`
- Easy to switch between proxy/no-proxy
- Can have different settings per environment
- Clean separation of concerns

### 📋 Use Cases
- Development with proxy capture
- Testing OAuth2 flows
- Debugging authentication issues
- Learning how OAuth2 works

---

## Quick Start (3 Steps)

### Step 1: Start mitmproxy

```bash
# Install (one time)
brew install mitmproxy

# Start with web interface
mitmweb --web-port 8081
```

### Step 2: Run App with Proxy Profile

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

**Or use the script:**

```bash
./start-with-proxy-profile.sh
```

### Step 3: Trigger OAuth2 Flow

```bash
open http://localhost:8080/user
```

**View captured traffic:**

```bash
open http://localhost:8081
```

---

## All Methods to Use the Profile

### Method 1: Gradle Command Line (Recommended)

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### Method 2: Using the Script

```bash
./start-with-proxy-profile.sh
```

### Method 3: Environment Variable

```bash
export SPRING_PROFILES_ACTIVE=proxy
./gradlew bootRun
```

### Method 4: Java JAR

```bash
# Build first
./gradlew build

# Run with profile
java -jar build/libs/api-gateway-keycloak-0.0.1-SNAPSHOT.jar \
  --spring.profiles.active=proxy
```

### Method 5: IDE Configuration

**IntelliJ IDEA:**
1. Edit Run Configuration
2. Add to "Program arguments": `--spring.profiles.active=proxy`
3. Run

**VS Code:**
Add to `launch.json`:
```json
{
  "type": "java",
  "name": "Spring Boot with Proxy",
  "request": "launch",
  "mainClass": "com.zz.gateway.auth.ApiGatewayKeycloakApplication",
  "args": "--spring.profiles.active=proxy"
}
```

---

## Customizing the Proxy Profile

### Change Proxy Host/Port

**Edit:** `src/main/resources/application-proxy.yml`

```yaml
proxy:
  enabled: true
  host: my-proxy.example.com  # Change this
  port: 3128                   # Change this
  type: HTTP
```

### Add Proxy Authentication

**Edit:** `src/main/resources/application-proxy.yml`

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}
```

Then run:

```bash
export PROXY_USERNAME=myuser
export PROXY_PASSWORD=mypass
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### Use SOCKS5 Proxy

**Edit:** `src/main/resources/application-proxy.yml`

```yaml
proxy:
  enabled: true
  host: localhost
  port: 1080
  type: SOCKS5  # Change from HTTP to SOCKS5
```

---

## Multiple Profiles

You can combine multiple profiles:

### Example: Proxy + Development

**Create:** `src/main/resources/application-dev.yml`

```yaml
# Development-specific settings
logging:
  level:
    root: DEBUG

server:
  port: 8080
```

**Run with both:**

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy,dev'
```

### Example: Proxy + Production

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy,prod'
```

---

## Verifying the Profile is Active

### Check Console Output

When you start the app, look for:

```
The following 1 profile is active: "proxy"
```

Or:

```
The following 2 profiles are active: "proxy", "dev"
```

### Check Proxy Configuration

Look for:

```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════
```

### Check Request Logs

Look for:

```
═══════════════════════════════════════════════════════════
<<<<<<<<<<<< OUTGOING REQUEST (via proxy) >>>>>>>>>>>>>>
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
═══════════════════════════════════════════════════════════
```

---

## Switching Between Profiles

### No Proxy (Default)

```bash
./gradlew bootRun
# Uses: application.yml (proxy.enabled: false)
```

### With Proxy

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
# Uses: application-proxy.yml (proxy.enabled: true)
```

---

## Complete Example Workflow

### 1. Start Keycloak (if not running)

```bash
docker-compose up -d
```

### 2. Start mitmproxy

```bash
mitmweb --web-port 8081
```

### 3. Start Spring Boot with Proxy Profile

```bash
./start-with-proxy-profile.sh
```

**Or:**

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### 4. Wait for App to Start

Look for:

```
Started ApiGatewayKeycloakApplication in X.XXX seconds
```

### 5. Trigger OAuth2 Login

**Option A: Browser**

```bash
open http://localhost:8080/user
```

**Option B: curl**

```bash
curl -v http://localhost:8080/user
# Follow the redirect chain manually
```

### 6. View Captured Traffic

**mitmproxy Web UI:**

```bash
open http://localhost:8081
```

Look for:
- POST to `/realms/dev-realm/protocol/openid-connect/token`
- Request body with `grant_type=authorization_code`
- Response with `access_token`, `refresh_token`, `id_token`

**Console Logs:**

Look for:

```
═══════════════════════════════════════════════════════════
<<<<<<<<<<<< OUTGOING REQUEST (via proxy) >>>>>>>>>>>>>>
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Headers:
  Content-Type: application/x-www-form-urlencoded;charset=UTF-8
  Authorization: ***MASKED***
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
>>>>>>>>>>>> INCOMING RESPONSE <<<<<<<<<<<<
Status: 200 OK
Headers:
  Content-Type: application/json
═══════════════════════════════════════════════════════════
```

---

## Troubleshooting

### Profile Not Loading?

**Check 1: Verify profile name**

```bash
ls -la src/main/resources/application-proxy.yml
# Should exist
```

**Check 2: Check spelling**

```bash
# Correct:
--spring.profiles.active=proxy

# Wrong:
--spring.profiles.active=application-proxy  # Don't include "application-"
```

**Check 3: Check console output**

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy' | grep -i profile
# Should show: "proxy" profile is active
```

### Proxy Not Working?

**Check 1: Is mitmproxy running?**

```bash
nc -zv localhost 8888
# Should show: Connection succeeded
```

**Check 2: Is proxy enabled in profile?**

```bash
grep "enabled:" src/main/resources/application-proxy.yml
# Should show: enabled: true
```

**Check 3: Check logs**

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy' | grep -i "PROXY ENABLED"
# Should show proxy configuration
```

### Not Seeing Token Exchange?

**Check 1: Trigger OAuth2 flow**

```bash
# Must access a protected endpoint
curl -v http://localhost:8080/user

# Not just the home page
# curl http://localhost:8080/  # This won't trigger OAuth2
```

**Check 2: Check logging level**

```bash
grep "org.springframework.security.oauth2" src/main/resources/application-proxy.yml
# Should show: TRACE
```

**Check 3: Look in mitmproxy**

```bash
open http://localhost:8081
# Filter by: /token
```

---

## Comparison: Profile vs Other Methods

| Method | Command | When to Use |
|--------|---------|-------------|
| **Profile** | `--spring.profiles.active=proxy` | Clean, reusable, recommended |
| **application.yml** | Edit file, change `enabled: true` | Simple, but requires file edit |
| **Command line** | `--proxy.enabled=true` | Quick override |
| **Script** | `./run-with-config-proxy.sh` | Convenience wrapper |

### Recommendation

Use **profile** (`application-proxy.yml`) when:
- ✅ You frequently switch between proxy/no-proxy
- ✅ You want clean separation
- ✅ You have multiple environments
- ✅ You don't want to edit `application.yml`

Use **application.yml** when:
- ✅ You always use proxy
- ✅ You want simplicity
- ✅ You don't need to switch often

---

## Advanced: Creating More Profiles

### application-proxy-charles.yml

For Charles Proxy (different port):

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888  # Charles default
  type: HTTP
```

Usage:

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy-charles'
```

### application-proxy-corporate.yml

For corporate proxy:

```yaml
proxy:
  enabled: true
  host: corporate-proxy.company.com
  port: 3128
  type: HTTP
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}
```

Usage:

```bash
export PROXY_USERNAME=john.doe
export PROXY_PASSWORD=secret
./gradlew bootRun --args='--spring.profiles.active=proxy-corporate'
```

### application-proxy-socks.yml

For SOCKS5 proxy:

```yaml
proxy:
  enabled: true
  host: localhost
  port: 1080
  type: SOCKS5
```

Usage:

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy-socks'
```

---

## Summary

### Quick Commands

```bash
# Start with proxy profile (easiest)
./start-with-proxy-profile.sh

# Or manually
./gradlew bootRun --args='--spring.profiles.active=proxy'

# With environment variable
export SPRING_PROFILES_ACTIVE=proxy
./gradlew bootRun

# Multiple profiles
./gradlew bootRun --args='--spring.profiles.active=proxy,dev'
```

### Key Files

- **Profile:** `src/main/resources/application-proxy.yml`
- **Script:** `start-with-proxy-profile.sh`
- **Config:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`

### What to Look For

1. Console: `"proxy" profile is active`
2. Console: `🔧 PROXY ENABLED`
3. Console: `<<<<<<<<<<<< OUTGOING REQUEST (via proxy) >>>>>>>>>>`
4. mitmproxy: POST to `/protocol/openid-connect/token`

---

**Next Steps:**
1. Start mitmproxy: `mitmweb --web-port 8081`
2. Run with profile: `./start-with-proxy-profile.sh`
3. Test: `open http://localhost:8080/user`
4. View: `open http://localhost:8081`

Happy debugging! 🚀

