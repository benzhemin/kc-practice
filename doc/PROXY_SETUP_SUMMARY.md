# ✅ Proxy Configuration Complete

## What Was Done

I've configured your Spring Boot application to capture the OAuth2 token exchange between Spring and Keycloak. Here's what was added/modified:

## 📝 Files Changed

### 1. NEW: WebClientConfig.java
**Location:** `src/main/java/com/zz/gateway/auth/config/WebClientConfig.java`

**Purpose:** Automatically logs all HTTP requests/responses, including the token exchange

**Features:**
- 🔵 Logs outgoing requests (Spring → Keycloak)
- 🟢 Logs incoming responses (Keycloak → Spring)
- 🔒 Masks sensitive headers (Authorization)
- 🎯 Captures the critical token exchange

### 2. UPDATED: application.yml
**Location:** `src/main/resources/application.yml`

**Changes:** Enhanced logging levels
```yaml
logging:
  level:
    org.springframework.security: TRACE
    org.springframework.security.oauth2: TRACE
    org.springframework.web.reactive.function.client: TRACE
    reactor.netty.http.client: DEBUG
    org.springframework.security.oauth2.client.endpoint: TRACE  # ⭐ Token exchange
    org.springframework.security.oauth2.client.web: TRACE
```

### 3. NEW: run-with-proxy.sh
**Location:** `run-with-proxy.sh`

**Purpose:** Run app with external proxy (mitmproxy/Charles)

**Usage:**
```bash
./run-with-proxy.sh [proxy_host] [proxy_port]
# Default: localhost:8888
```

### 4. NEW: Documentation
**Location:** `doc/` directory

Created comprehensive guides:
- `README_PROXY.md` - Overview and quick start
- `QUICK_START_PROXY.md` - 30-second guide
- `PROXY_CONFIGURATION.md` - Detailed setup (4 methods)
- `EXAMPLE_TOKEN_EXCHANGE_LOGS.md` - Real log examples
- `token_exchange_flow.mmd` - Visual sequence diagram

---

## 🚀 How to Use (Easiest Method)

### Step 1: Start Your App
```bash
./gradlew bootRun
```

### Step 2: Trigger OAuth2 Login
Open browser: http://localhost:8080/user

### Step 3: Watch Console
You'll see logs like:
```
═══════════════════════════════════════════════════════════
🔵 OUTGOING REQUEST
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Headers:
  Content-Type: application/x-www-form-urlencoded;charset=UTF-8
  Authorization: Bearer ***MASKED***
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
🟢 INCOMING RESPONSE
Status: 200 OK
Headers:
  Content-Type: application/json
═══════════════════════════════════════════════════════════
```

**That's the token exchange!** 🎉

---

## 🔍 What You're Capturing

### The Request (Spring → Keycloak)
```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=eyJhbGciOiJkaXIi...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

### The Response (Keycloak → Spring)
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

## 🎯 Key Points About `/login`

Based on your original question about `http://localhost:8080/login`:

### Where is `/login` configured?
**Answer:** It's **auto-generated** by Spring Security's `oauth2Login()` feature. You don't see it in your code because it's built into Spring Security.

### How does it work?
1. **SecurityConfig.java** enables `oauth2Login()`
2. Spring Security automatically creates `/login` endpoint
3. It reads your OAuth2 configuration from `application.yml`
4. It generates HTML with a link to Keycloak

### The HTML you saw:
```html
<h2>Login with OAuth 2.0</h2>
<a href="/oauth2/authorization/keycloak">
  http://localhost:3081/realms/dev-realm
</a>
```

### Where does the link text come from?
From your `application.yml`:
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://localhost:3081/realms/dev-realm  # ⬅️ This!
```

---

## 📊 Complete OAuth2 Flow

```
1. User visits: /user
   ↓
2. Spring redirects to: /login (auto-generated)
   ↓
3. User clicks: /oauth2/authorization/keycloak
   ↓
4. Spring redirects to: Keycloak authorization endpoint
   ↓
5. User logs in at Keycloak
   ↓
6. Keycloak redirects back with code: /login/oauth2/code/gateway?code=...
   ↓
7. 🔥 TOKEN EXCHANGE (What you're capturing!)
   Spring → Keycloak: POST /protocol/openid-connect/token
   Keycloak → Spring: {access_token, refresh_token, id_token}
   ↓
8. Spring validates tokens and creates session
   ↓
9. User is redirected to: / (success handler)
   ↓
10. User can access: /user (authenticated)
```

---

## 🛠️ Alternative Methods

If you want even more detail, try:

### Method 1: mitmproxy (Web Interface)
```bash
# Install
brew install mitmproxy

# Start
mitmweb --web-port 8081

# Run app with proxy
./run-with-proxy.sh

# View at: http://localhost:8081
```

### Method 2: Charles Proxy
1. Download: https://www.charlesproxy.com/
2. Start Charles (port 8888)
3. Enable SSL Proxying for localhost:3081
4. Run: `./run-with-proxy.sh`

---

## 📚 Documentation

All documentation is in the `doc/` folder:

```
doc/
├── README_PROXY.md                    # Start here
├── QUICK_START_PROXY.md               # 30-second guide
├── PROXY_CONFIGURATION.md             # Detailed setup
├── EXAMPLE_TOKEN_EXCHANGE_LOGS.md     # Real examples
└── token_exchange_flow.mmd            # Visual diagram
```

---

## ✨ What You Learned

1. **`/login` is auto-generated** by Spring Security (not in your code)
2. **Token exchange is server-to-server** (Spring ↔ Keycloak)
3. **Authorization code is exchanged for tokens** (access, refresh, ID)
4. **Client secret is transmitted** in the token exchange
5. **Multiple ways to capture** the exchange (WebClient, proxy, logging)

---

## 🎓 Next Steps

1. **Test it:** Run `./gradlew bootRun` and visit `http://localhost:8080/user`
2. **Decode tokens:** Copy a token from logs and paste at https://jwt.io
3. **Explore:** Read the documentation in `doc/README_PROXY.md`
4. **Experiment:** Try mitmproxy for even more detail

---

## 🐛 Troubleshooting

### Not seeing logs?
```bash
# Verify logging config
cat src/main/resources/application.yml | grep -A 10 "logging:"
```

### WebClientConfig not working?
```bash
# Verify file exists
ls -la src/main/java/com/zz/gateway/auth/config/WebClientConfig.java
```

### Need help?
Check `doc/PROXY_CONFIGURATION.md` for detailed troubleshooting.

---

## 📞 Summary

You asked: **"How is `/login` configured and how does it represent Keycloak?"**

**Answer:**
- `/login` is **auto-generated** by Spring Security's `oauth2Login()`
- The link text comes from `issuer-uri` in `application.yml`
- The token exchange happens **server-side** after the user logs in
- You can now **capture and inspect** this exchange using the tools I've set up

**Files to review:**
1. `doc/README_PROXY.md` - Complete overview
2. `doc/QUICK_START_PROXY.md` - Quick start guide
3. `src/main/java/com/zz/gateway/auth/config/WebClientConfig.java` - The interceptor

**Test command:**
```bash
./gradlew bootRun
# Then visit: http://localhost:8080/user
```

Enjoy exploring OAuth2! 🚀

