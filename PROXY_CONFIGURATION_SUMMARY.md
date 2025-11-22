# ✅ Proxy Configuration Complete - Summary

## What Was Implemented

I've added **multiple programmatic ways** to configure HTTP/HTTPS proxy for your Spring Boot application to capture OAuth2 token exchanges with Keycloak.

---

## 📦 New Files Created

### 1. **ProxyConfig.java** (Main Configuration)
**Location:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`

**Features:**
- ✅ Programmatic proxy configuration using Reactor Netty
- ✅ Toggle proxy on/off via `application.yml`
- ✅ Support for HTTP, SOCKS4, SOCKS5 proxies
- ✅ Proxy authentication support (commented out, easy to enable)
- ✅ Non-proxy hosts configuration
- ✅ Request/response logging with proxy indicator
- ✅ Works seamlessly with OAuth2 client
- ✅ Captures token exchange between Spring and Keycloak

### 2. **application.yml** (Updated)
**Location:** `src/main/resources/application.yml`

**Added:**
```yaml
proxy:
  enabled: false  # Set to true to enable proxy
  host: localhost
  port: 8888
  type: HTTP  # Options: HTTP, SOCKS4, SOCKS5
```

### 3. **application-proxy.yml** (New Profile)
**Location:** `src/main/resources/application-proxy.yml`

**Purpose:** Pre-configured profile with proxy enabled for quick testing

**Usage:**
```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### 4. **Scripts**

**run-with-config-proxy.sh** - Uses ProxyConfig.java approach
```bash
./run-with-config-proxy.sh [host] [port]
```

**run-with-proxy.sh** - Uses JVM system properties approach
```bash
./run-with-proxy.sh [host] [port]
```

### 5. **Documentation**

**doc/PROXY_METHODS.md** - Complete guide to 6 different proxy configuration methods
**doc/PROXY_EXAMPLES.md** - Real-world examples for various scenarios
**doc/PROXY_CONFIGURATION.md** - Detailed setup guide
**doc/QUICK_START_PROXY.md** - 30-second quick start

---

## 🚀 How to Use (6 Methods)

### Method 1: application.yml (EASIEST - RECOMMENDED)

**Edit:** `src/main/resources/application.yml`
```yaml
proxy:
  enabled: true  # Change this to true
  host: localhost
  port: 8888
```

**Run:**
```bash
./gradlew bootRun
```

---

### Method 2: Command Line Override

**No file changes needed!**

```bash
./gradlew bootRun --args='--proxy.enabled=true --proxy.host=localhost --proxy.port=8888'
```

---

### Method 3: Spring Profile

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

---

### Method 4: Script (Config-based)

```bash
./run-with-config-proxy.sh localhost 8888
```

---

### Method 5: Script (JVM Properties)

```bash
./run-with-proxy.sh localhost 8888
```

---

### Method 6: Environment Variables

```bash
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888
./gradlew bootRun
```

---

## 🎯 Complete Example: Capturing Token Exchange

### Step 1: Start mitmproxy

```bash
# Install (one time)
brew install mitmproxy

# Start with web interface
mitmweb --web-port 8081
```

### Step 2: Enable Proxy in Your App

**Choose ONE method:**

**Option A: Edit application.yml**
```yaml
proxy:
  enabled: true
```
Then run: `./gradlew bootRun`

**Option B: Use command line**
```bash
./gradlew bootRun --args='--proxy.enabled=true'
```

**Option C: Use profile**
```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

**Option D: Use script**
```bash
./run-with-config-proxy.sh
```

### Step 3: Trigger OAuth2 Flow

```bash
open http://localhost:8080/user
```

### Step 4: View Captured Traffic

**In Console:** Look for these logs
```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
🔵 OUTGOING REQUEST (via proxy)
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
═══════════════════════════════════════════════════════════
```

**In mitmproxy:** Open `http://localhost:8081`
- Look for POST to `/protocol/openid-connect/token`
- Click to see full request/response with tokens

---

## 🔍 What You'll Capture

### The Token Exchange Request
```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=eyJhbGciOiJkaXIi...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

### The Token Response
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "scope": "openid profile email"
}
```

---

## 📊 Comparison: Which Method to Use?

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **application.yml** | Simple, version controlled | Requires restart | Development |
| **Command line** | No file changes | Long command | Quick testing |
| **Spring profile** | Environment-specific | Need profile file | Multi-env |
| **Config script** | Easy to use | Requires script | Daily use |
| **JVM properties** | Works everywhere | Global settings | Legacy apps |
| **Env variables** | Docker-friendly | Global for JVM | Containers |

### Recommendation

For **this project**, use **Method 1** (application.yml):
1. Simple to toggle on/off
2. Easy to understand
3. Works with ProxyConfig.java
4. Logs show proxy status clearly

---

## 🎓 Advanced Features

### Proxy Authentication

**Edit:** `ProxyConfig.java`

Uncomment these lines:
```java
.proxy(proxy -> proxy
    .type(getProxyType(proxyType))
    .host(proxyHost)
    .port(proxyPort)
    .username("proxy-user")          // Uncomment
    .password(s -> "proxy-password")  // Uncomment
)
```

**Add to:** `application.yml`
```yaml
proxy:
  enabled: true
  host: corporate-proxy.com
  port: 3128
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}
```

### Non-Proxy Hosts

**Edit:** `ProxyConfig.java`

Uncomment:
```java
.nonProxyHosts("localhost|127.0.0.1|*.internal.com")
```

This will bypass proxy for internal services.

### SOCKS5 Proxy

**Edit:** `application.yml`
```yaml
proxy:
  enabled: true
  host: localhost
  port: 1080
  type: SOCKS5  # Change from HTTP to SOCKS5
```

---

## 🐛 Troubleshooting

### Proxy not working?

**Check 1: Is proxy enabled?**
```bash
grep "proxy.enabled" src/main/resources/application.yml
# Should show: enabled: true
```

**Check 2: Is proxy running?**
```bash
nc -zv localhost 8888
# Should show: Connection to localhost port 8888 succeeded!
```

**Check 3: Check logs**
```bash
./gradlew bootRun | grep -i proxy
# Should show: 🔧 PROXY ENABLED
```

### Not seeing token exchange?

**Check 1: Trigger OAuth2 flow**
```bash
# Make sure you're accessing a protected endpoint
curl -v http://localhost:8080/user
```

**Check 2: Check logging level**
```bash
grep "org.springframework.security.oauth2" src/main/resources/application.yml
# Should show: TRACE
```

### Connection timeout?

**Edit:** `ProxyConfig.java`
```java
.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 30000)  // Increase to 30s
```

---

## 📚 Documentation Structure

```
doc/
├── README_PROXY.md              # Overview and introduction
├── QUICK_START_PROXY.md         # 30-second quick start
├── PROXY_METHODS.md             # All 6 configuration methods
├── PROXY_EXAMPLES.md            # Real-world examples
├── PROXY_CONFIGURATION.md       # Detailed setup guide
├── EXAMPLE_TOKEN_EXCHANGE_LOGS.md  # What to expect
└── token_exchange_flow.mmd      # Visual diagram
```

**Start here:** `doc/README_PROXY.md`

---

## ✨ Key Differences from Previous Setup

### Before (run-with-proxy.sh only)
- ❌ Only JVM system properties method
- ❌ Global for entire JVM
- ❌ No programmatic control
- ❌ No easy toggle

### Now (ProxyConfig.java)
- ✅ Programmatic configuration
- ✅ Application-specific
- ✅ Easy toggle via config
- ✅ Multiple methods available
- ✅ Better logging
- ✅ Proxy authentication support
- ✅ Non-proxy hosts support
- ✅ Works seamlessly with OAuth2

---

## 🎉 Summary

You now have **6 different ways** to configure proxy:

1. ⭐ **application.yml** - Easiest, recommended
2. **Command line** - No file changes
3. **Spring profile** - Environment-specific
4. **Config script** - Quick testing
5. **JVM properties** - Traditional approach
6. **Environment variables** - Docker/K8s friendly

### Quick Start (30 seconds)

```bash
# 1. Enable proxy in application.yml
# proxy.enabled: true

# 2. Start mitmproxy
mitmweb --web-port 8081

# 3. Run app
./gradlew bootRun

# 4. Trigger OAuth2
open http://localhost:8080/user

# 5. View traffic
open http://localhost:8081
```

### Files to Review

- **Main config:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`
- **Properties:** `src/main/resources/application.yml`
- **Documentation:** `doc/README_PROXY.md`

Enjoy capturing OAuth2 token exchanges! 🚀

