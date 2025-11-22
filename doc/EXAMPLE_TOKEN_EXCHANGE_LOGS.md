# Example: OAuth2 Token Exchange Logs

This document shows what you'll see in the logs when capturing the OAuth2 token exchange between Spring Boot and Keycloak.

## Complete OAuth2 Flow with Logs

### 1. User Visits Protected Resource

```
User Browser → Spring Boot
GET http://localhost:8080/user
```

**Spring Boot Log:**
```
2024-11-22 10:30:15.123 DEBUG [reactor-http-nio-2] o.s.s.w.s.a.AuthorizationWebFilter : 
  Authorization required for /user
2024-11-22 10:30:15.125 DEBUG [reactor-http-nio-2] o.s.s.w.s.a.RedirectServerAuthenticationEntryPoint : 
  Redirecting to: /oauth2/authorization/keycloak
```

---

### 2. Spring Redirects to Keycloak Authorization Endpoint

```
Spring Boot → User Browser (302 Redirect)
Location: http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth?
  response_type=code
  &client_id=app-client
  &scope=openid%20profile%20email
  &state=abc123xyz
  &redirect_uri=http://localhost:8080/login/oauth2/code/gateway
  &nonce=def456uvw
```

**Spring Boot Log:**
```
2024-11-22 10:30:15.130 TRACE [reactor-http-nio-2] o.s.s.o.c.w.s.OAuth2AuthorizationRequestRedirectWebFilter : 
  Creating authorization request for client: keycloak
2024-11-22 10:30:15.132 TRACE [reactor-http-nio-2] o.s.s.o.c.w.s.OAuth2AuthorizationRequestRedirectWebFilter : 
  Authorization Request: OAuth2AuthorizationRequest{
    authorizationUri='http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth',
    clientId='app-client',
    redirectUri='http://localhost:8080/login/oauth2/code/gateway',
    scopes=[openid, profile, email],
    state='abc123xyz',
    additionalParameters={nonce=def456uvw}
  }
```

---

### 3. User Logs In at Keycloak

```
User Browser → Keycloak
POST http://localhost:3081/realms/dev-realm/login-actions/authenticate
```

(This happens in the browser, not logged by Spring)

---

### 4. Keycloak Redirects Back with Authorization Code

```
Keycloak → User Browser (302 Redirect)
Location: http://localhost:8080/login/oauth2/code/gateway?
  code=eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..vXYZ123...
  &state=abc123xyz
```

**Spring Boot Log:**
```
2024-11-22 10:30:25.200 DEBUG [reactor-http-nio-3] o.s.s.w.s.a.AuthenticationWebFilter : 
  Processing authentication for /login/oauth2/code/gateway
2024-11-22 10:30:25.202 TRACE [reactor-http-nio-3] o.s.s.o.c.w.s.a.OAuth2LoginAuthenticationWebFilter : 
  Received authorization code: eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..vXYZ123...
```

---

### 5. 🔥 **THE KEY STEP** 🔥 Spring Exchanges Code for Tokens

This is the **server-to-server** request that happens **behind the scenes**:

```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded
Authorization: Basic YXBwLWNsaWVudDptRUZ6OWFGNVdCYjZPQVlSUFZZbTNybFRuM3lsQ0JlRg==

grant_type=authorization_code
&code=eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..vXYZ123...
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

**Spring Boot Log (with TRACE logging enabled):**
```
2024-11-22 10:30:25.205 TRACE [reactor-http-nio-3] o.s.s.o.c.e.WebClientReactiveAuthorizationCodeTokenResponseClient : 
  Exchanging authorization code for access token
  
═══════════════════════════════════════════════════════════
🔵 OUTGOING REQUEST
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Headers:
  Content-Type: application/x-www-form-urlencoded;charset=UTF-8
  Authorization: Bearer ***MASKED***
  Accept: application/json
  User-Agent: ReactorNetty/1.1.13
═══════════════════════════════════════════════════════════

2024-11-22 10:30:25.210 DEBUG [reactor-http-nio-3] r.n.h.c.HttpClientConnect : 
  [id:0x12345678, L:/127.0.0.1:54321 - R:localhost/127.0.0.1:3081] 
  Handler is being applied: {uri=http://localhost:3081/realms/dev-realm/protocol/openid-connect/token}

2024-11-22 10:30:25.215 DEBUG [reactor-http-nio-3] r.n.h.c.HttpClientOperations : 
  [id:0x12345678, L:/127.0.0.1:54321 - R:localhost/127.0.0.1:3081] 
  Sending request:
  POST /realms/dev-realm/protocol/openid-connect/token HTTP/1.1
  Content-Type: application/x-www-form-urlencoded;charset=UTF-8
  Authorization: Basic YXBwLWNsaWVudDptRUZ6OWFGNVdCYjZPQVlSUFZZbTNybFRuM3lsQ0JlRg==
  
  grant_type=authorization_code&code=eyJhbGciOiJkaXIi...&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
```

---

### 6. Keycloak Responds with Tokens

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxMnRFVjBfYXJ...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIzYzk5ZjE...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxMnRFVjBfYXJ...",
  "not-before-policy": 0,
  "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "scope": "openid profile email"
}
```

**Spring Boot Log:**
```
═══════════════════════════════════════════════════════════
🟢 INCOMING RESPONSE
Status: 200 OK
Headers:
  Content-Type: application/json
  Cache-Control: no-store
  Pragma: no-cache
  Content-Length: 2847
═══════════════════════════════════════════════════════════

2024-11-22 10:30:25.220 TRACE [reactor-http-nio-3] o.s.s.o.c.e.WebClientReactiveAuthorizationCodeTokenResponseClient : 
  Received token response: OAuth2AccessTokenResponse{
    accessToken=OAuth2AccessToken{
      tokenValue='eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldU...',
      issuedAt=2024-11-22T10:30:25Z,
      expiresAt=2024-11-22T10:35:25Z,
      scopes=[openid, profile, email]
    },
    refreshToken=OAuth2RefreshToken{
      tokenValue='eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldU...',
      issuedAt=2024-11-22T10:30:25Z
    },
    additionalParameters={
      id_token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldU...,
      session_state=a1b2c3d4-e5f6-7890-abcd-ef1234567890
    }
  }

2024-11-22 10:30:25.225 TRACE [reactor-http-nio-3] o.s.s.o.c.o.u.OidcUserService : 
  Retrieving user info from UserInfo Endpoint

2024-11-22 10:30:25.230 DEBUG [reactor-http-nio-3] o.s.s.o.c.o.u.OidcUserService : 
  Retrieved user info: OidcUserInfo{
    sub=12345678-1234-1234-1234-123456789abc,
    name=John Doe,
    preferred_username=johndoe,
    email=john.doe@example.com,
    email_verified=true
  }
```

---

### 7. Authentication Success

```
2024-11-22 10:30:25.235 DEBUG [reactor-http-nio-3] o.s.s.w.s.a.AuthenticationWebFilter : 
  Authentication success: OAuth2AuthenticationToken{
    principal=Name: [johndoe],
    authorities=[ROLE_USER, SCOPE_openid, SCOPE_profile, SCOPE_email],
    authenticated=true
  }

2024-11-22 10:30:25.240 DEBUG [reactor-http-nio-3] o.s.s.w.s.a.RedirectServerAuthenticationSuccessHandler : 
  Redirecting to: /

2024-11-22 10:30:25.245 INFO  [reactor-http-nio-3] c.z.g.a.c.SecurityConfig : 
  User johndoe successfully authenticated via OAuth2
```

---

## How to See These Logs

### Option 1: Using WebClientConfig (Easiest)

1. The `WebClientConfig.java` I created will show the boxed logs (🔵 and 🟢)
2. Run your app normally: `./gradlew bootRun`
3. Visit: `http://localhost:8080/user`
4. Check console for the token exchange logs

### Option 2: Using External Proxy (Most Detailed)

1. Install mitmproxy: `brew install mitmproxy`
2. Start mitmproxy: `mitmweb --web-port 8081`
3. Run app with proxy: `./run-with-proxy.sh`
4. Visit: `http://localhost:8080/user`
5. Open mitmproxy web UI: `http://localhost:8081`
6. Look for POST to `/protocol/openid-connect/token`

---

## Decoding the Tokens

You can decode the JWT tokens at https://jwt.io

### Access Token Example (decoded):

```json
{
  "exp": 1700654725,
  "iat": 1700654425,
  "jti": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "iss": "http://localhost:3081/realms/dev-realm",
  "aud": "account",
  "sub": "12345678-1234-1234-1234-123456789abc",
  "typ": "Bearer",
  "azp": "app-client",
  "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "acr": "1",
  "realm_access": {
    "roles": ["default-roles-dev-realm", "offline_access", "uma_authorization"]
  },
  "resource_access": {
    "account": {
      "roles": ["manage-account", "manage-account-links", "view-profile"]
    }
  },
  "scope": "openid profile email",
  "sid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "email_verified": true,
  "name": "John Doe",
  "preferred_username": "johndoe",
  "given_name": "John",
  "family_name": "Doe",
  "email": "john.doe@example.com"
}
```

### ID Token Example (decoded):

```json
{
  "exp": 1700654725,
  "iat": 1700654425,
  "auth_time": 1700654425,
  "jti": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
  "iss": "http://localhost:3081/realms/dev-realm",
  "aud": "app-client",
  "sub": "12345678-1234-1234-1234-123456789abc",
  "typ": "ID",
  "azp": "app-client",
  "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "at_hash": "xyz123abc456",
  "acr": "1",
  "sid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "email_verified": true,
  "name": "John Doe",
  "preferred_username": "johndoe",
  "given_name": "John",
  "family_name": "Doe",
  "email": "john.doe@example.com"
}
```

---

## Key Observations

1. **The token exchange is server-to-server**: It happens between Spring Boot and Keycloak, not in the browser
2. **Client secret is sent**: The request includes `client_secret` (or Basic Auth header)
3. **Authorization code is single-use**: After exchange, the code cannot be reused
4. **Multiple tokens returned**: access_token, refresh_token, and id_token
5. **Tokens are JWTs**: They can be decoded to see claims without validation
6. **Short-lived**: access_token typically expires in 5 minutes (300 seconds)
7. **Refresh token**: Used to get new access tokens without re-authentication

---

## Testing Commands

```bash
# 1. Start Keycloak (if not running)
docker-compose up -d

# 2. Start Spring Boot app with enhanced logging
./gradlew bootRun

# 3. In another terminal, trigger the OAuth2 flow
curl -v http://localhost:8080/user

# 4. You'll get a 302 redirect - follow it manually or use a browser
# The logs will show the token exchange automatically
```

