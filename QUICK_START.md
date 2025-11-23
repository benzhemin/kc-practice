# Quick Start - Custom OAuth2 Implementation

## 🚀 Get Started in 3 Steps

### Step 1: Start Keycloak
```bash
docker-compose up -d
```

Wait for Keycloak to be ready (check with `docker-compose logs -f keycloak`)

### Step 2: Start the Application
```bash
./mvnw spring-boot:run
```

### Step 3: Test the Flow
Open your browser and go to:
```
http://localhost:8080/api/users
```

You'll be redirected to Keycloak login. After logging in, watch your console for detailed logs!

## 📋 What to Expect

### Console Output
You should see logs like this:

```
🔐 ========================================
🔐 CUSTOM AUTHENTICATION MANAGER INVOKED
🔐 ========================================
📋 Registration ID: gateway
📋 Authorization Code: urn:ietf:params:oauth:grant-type:jwt-bearer...

🔄 ========================================
🔄 CUSTOM TOKEN EXCHANGE STARTED
🔄 ========================================
📍 Token URI: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
📤 Sending token request to Keycloak...

✅ ========================================
✅ TOKEN EXCHANGE SUCCESSFUL
✅ ========================================
🎫 Access Token: eyJhbGciOi...xyz
🎫 ID Token: eyJhbGciOi...abc
🎫 Refresh Token: eyJhbGciOi...def

👤 User Details:
   Username: john.doe
   Email: john.doe@example.com

✅ ========================================
✅ AUTHENTICATION SUCCESSFUL
✅ ========================================
```

## 🧪 Test Endpoints

### 1. Home (authenticated)
```bash
curl -b cookies.txt http://localhost:8080/
```
Response: `"Hello, World! You are authenticated!"`

### 2. User Info
```bash
curl -b cookies.txt http://localhost:8080/user
```
Response: JSON with user details, claims, and roles

### 3. Protected API
```bash
curl -b cookies.txt http://localhost:8080/api/users
```
Response: JSON with authenticated user info

## 🎯 Key Files

| File | Purpose |
|------|---------|
| `CustomOAuth2TokenExchangeService.java` | Handles token exchange with Keycloak |
| `CustomOAuth2AuthenticationManager.java` | Integrates with Spring Security |
| `SecurityConfig.java` | Configures custom authentication manager |

## 📚 Documentation

- **Detailed Guide**: See `CUSTOM_OAUTH2_IMPLEMENTATION.md`
- **Technical Docs**: See `src/main/java/com/zz/gateway/auth/oauth2/README.md`
- **Flow Diagram**: See `doc/custom_oauth2_flow.mmd`

## 🔧 Customization Points

Want to customize? Here are the key places:

### Store Tokens in Database
Edit `CustomOAuth2TokenExchangeService.java` line 67-83 (in `.doOnNext()`)

### Add Custom Token Parameters
Edit `CustomOAuth2TokenExchangeService.java` line 53-56 (in `formData`)

### Validate Users Before Auth
Edit `CustomOAuth2AuthenticationManager.java` line 109-140 (in `buildAuthenticatedUser()`)

### Add Custom Authorities
Edit `CustomOAuth2AuthenticationManager.java` line 215-250 (in `extractAuthorities()`)

## 🆘 Troubleshooting

### Keycloak not accessible?
Check `/etc/hosts` has: `127.0.0.1 keycloak.local`

### No logs appearing?
Check `application.yml` has:
```yaml
logging:
  level:
    com.zz.gateway.auth.oauth2: DEBUG
```

### Authentication failing?
1. Check Keycloak is running: `docker-compose ps`
2. Check client secret matches in `application.yml`
3. Check console for error messages

## 🎉 Success!

If you see the detailed logs and can access `/api/users`, congratulations! You now have full control over your OAuth2 flow.

**Next**: Read `CUSTOM_OAUTH2_IMPLEMENTATION.md` for customization examples.
