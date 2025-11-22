# Quick Start: Capture OAuth2 Token Exchange

## 🚀 Fastest Method (No External Tools)

### 1. Start Your App
```bash
cd /Users/sam/Desktop/test/keycloak-practice
./gradlew bootRun
```

### 2. Trigger OAuth2 Login
Open browser: `http://localhost:8080/user`

### 3. Watch Console Output
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
```

**That's it!** The `WebClientConfig.java` I created will automatically log all OAuth2 token exchanges.

---

## 🔍 Alternative: Using mitmproxy (More Detailed)

### 1. Install mitmproxy
```bash
brew install mitmproxy
```

### 2. Start mitmproxy Web Interface
```bash
mitmweb --web-port 8081
```

### 3. Run Spring Boot with Proxy
```bash
./run-with-proxy.sh
```

### 4. Trigger OAuth2 Login
Open browser: `http://localhost:8080/user`

### 5. View in mitmproxy
Open: `http://localhost:8081`

Look for:
- **POST** to `/realms/dev-realm/protocol/openid-connect/token`
- Request body contains: `grant_type=authorization_code&code=...`
- Response contains: `access_token`, `refresh_token`, `id_token`

---

## 📊 What You're Looking For

### The Critical Request (Spring → Keycloak):
```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=eyJhbGciOiJkaXIi...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

### The Response (Keycloak → Spring):
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

## 🛠️ Troubleshooting

### Not seeing logs?
Check `application.yml` has:
```yaml
logging:
  level:
    org.springframework.security.oauth2: TRACE
    org.springframework.web.reactive.function.client: TRACE
```

### mitmproxy not capturing traffic?
Make sure you started the app with proxy settings:
```bash
./run-with-proxy.sh
```

### Still not working?
Enable ALL logging:
```yaml
logging:
  level:
    root: DEBUG
```

---

## 📚 Related Files

- **Configuration**: `src/main/java/com/zz/gateway/auth/config/WebClientConfig.java`
- **Logging Config**: `src/main/resources/application.yml`
- **Proxy Script**: `run-with-proxy.sh`
- **Full Guide**: `doc/PROXY_CONFIGURATION.md`
- **Example Logs**: `doc/EXAMPLE_TOKEN_EXCHANGE_LOGS.md`

---

## 🎯 Key Takeaways

1. **Token exchange happens server-side** (Spring ↔ Keycloak)
2. **Not visible in browser** (only authorization code is)
3. **Client secret is transmitted** (in the token exchange request)
4. **Three tokens returned**: access_token, refresh_token, id_token
5. **Authorization code is single-use** (can't be replayed)

---

## Next Steps

After capturing the token exchange, you might want to:
1. Decode the JWT tokens at https://jwt.io
2. Validate token signatures
3. Inspect token claims and roles
4. Test token refresh flow
5. Test logout flow

See `settings/keycloak/KEYCLOAK_CONFIG_SUMMARY.md` for more details.

