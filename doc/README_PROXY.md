# Capturing OAuth2 Token Exchange - Complete Guide

This directory contains comprehensive documentation for capturing and understanding the OAuth2 token exchange between Spring Boot and Keycloak.

## 📁 Documentation Files

### Quick Start
- **[QUICK_START_PROXY.md](QUICK_START_PROXY.md)** - Start here! Fastest way to capture token exchange

### Detailed Guides
- **[PROXY_CONFIGURATION.md](PROXY_CONFIGURATION.md)** - Complete guide with 4 different methods
- **[EXAMPLE_TOKEN_EXCHANGE_LOGS.md](EXAMPLE_TOKEN_EXCHANGE_LOGS.md)** - Real examples of what you'll see
- **[token_exchange_flow.mmd](token_exchange_flow.mmd)** - Visual sequence diagram (view in Mermaid viewer)

## 🎯 What You'll Learn

1. **Where** the token exchange happens (server-to-server, not in browser)
2. **How** to capture it (4 different methods)
3. **What** the request/response looks like
4. **Why** it's important for security and debugging

## 🚀 Quick Start (30 seconds)

```bash
# 1. Your app is already configured! Just run it:
./gradlew bootRun

# 2. Open browser and login:
open http://localhost:8080/user

# 3. Check console for logs like:
#    🔵 OUTGOING REQUEST
#    Method: POST
#    URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
```

## 🔧 What Was Configured

### 1. WebClientConfig.java (NEW)
```
src/main/java/com/zz/gateway/auth/config/WebClientConfig.java
```
- Intercepts all HTTP requests/responses
- Logs OAuth2 token exchanges
- Masks sensitive data (Authorization headers)

### 2. Enhanced Logging (UPDATED)
```
src/main/resources/application.yml
```
- TRACE level logging for OAuth2
- Shows token exchange details
- Captures HTTP client activity

### 3. Proxy Script (NEW)
```
run-with-proxy.sh
```
- Run app with external proxy (mitmproxy/Charles)
- Captures all HTTP traffic
- Useful for detailed inspection

## 📊 The Token Exchange Request

This is what you're capturing:

```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded
Authorization: Basic YXBwLWNsaWVudDptRUZ6OWFGNVdCYjZPQVlSUFZZbTNybFRuM3lsQ0JlRg==

grant_type=authorization_code
&code=eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

Response:
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

## 🎓 Why This Matters

### Security
- See exactly what credentials are transmitted
- Verify client_secret is sent securely
- Understand token lifetime and refresh flow

### Debugging
- Troubleshoot authentication issues
- Verify OAuth2 configuration
- Inspect token claims and scopes

### Learning
- Understand OAuth2 Authorization Code flow
- See the difference between authorization code and tokens
- Learn about JWT structure

## 🛠️ Four Methods to Capture

| Method | Difficulty | Detail Level | Setup Time |
|--------|-----------|--------------|------------|
| **WebClientConfig** | ⭐ Easy | Medium | 0 min (done!) |
| **TRACE Logging** | ⭐ Easy | High | 0 min (done!) |
| **mitmproxy** | ⭐⭐ Medium | Very High | 2 min |
| **Charles Proxy** | ⭐⭐ Medium | Very High | 5 min |

### Recommendation
Start with **WebClientConfig** (already configured). If you need more detail, try **mitmproxy**.

## 📖 Related Documentation

In the parent directories:
- `../settings/keycloak/KEYCLOAK_CONFIG_SUMMARY.md` - Full Keycloak setup
- `../settings/keycloak/spring-keycloak-config.md` - Spring Security config
- `../keycloak_full_flow.mmd` - Complete OAuth2 flow diagram

## 🔗 External Resources

- [OAuth 2.0 RFC](https://datatracker.ietf.org/doc/html/rfc6749)
- [JWT.io](https://jwt.io) - Decode JWT tokens
- [mitmproxy docs](https://docs.mitmproxy.org/)
- [Spring Security OAuth2 docs](https://docs.spring.io/spring-security/reference/servlet/oauth2/login/core.html)

## 💡 Tips

1. **Use TRACE logging** for development, DEBUG for production
2. **Never log tokens** in production (WebClientConfig masks them)
3. **mitmproxy** is great for learning, but not needed for daily development
4. **JWT tokens are not encrypted**, only signed (anyone can decode them)
5. **Authorization code is single-use** and expires quickly (usually 60 seconds)

## 🐛 Troubleshooting

### Not seeing token exchange logs?
```bash
# Check if logging is enabled
grep -A 5 "logging:" src/main/resources/application.yml

# Should show TRACE level for oauth2
```

### mitmproxy not capturing?
```bash
# Make sure you're using the proxy script
./run-with-proxy.sh

# Not just: ./gradlew bootRun
```

### Still stuck?
Check the detailed guides:
1. [PROXY_CONFIGURATION.md](PROXY_CONFIGURATION.md) - Step-by-step setup
2. [EXAMPLE_TOKEN_EXCHANGE_LOGS.md](EXAMPLE_TOKEN_EXCHANGE_LOGS.md) - What to expect

## 📝 Testing Checklist

- [ ] Start app: `./gradlew bootRun`
- [ ] Open browser: `http://localhost:8080/user`
- [ ] See login page
- [ ] Click Keycloak link
- [ ] Enter credentials
- [ ] Check console for token exchange logs
- [ ] See user info displayed

## 🎉 Success!

If you see logs like this, you're capturing the token exchange:

```
═══════════════════════════════════════════════════════════
🔵 OUTGOING REQUEST
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
🟢 INCOMING RESPONSE
Status: 200 OK
═══════════════════════════════════════════════════════════
```

Congratulations! You're now capturing and understanding the OAuth2 token exchange. 🎊

---

**Questions?** Check the detailed guides or review the sequence diagram in `token_exchange_flow.mmd`.

