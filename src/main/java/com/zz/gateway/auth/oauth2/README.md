# Custom OAuth2 Token Exchange Implementation

This package contains a custom implementation that gives you **full control** over the OAuth2 authorization code flow and token exchange process.

## 📁 Files Overview

### 1. `CustomOAuth2TokenExchangeService.java`
**Purpose**: Handles the actual token exchange with Keycloak.

**What it does**:
- Takes the authorization code from the callback URL
- Makes a POST request to Keycloak's token endpoint
- Exchanges the code for `access_token`, `id_token`, and `refresh_token`
- Logs detailed information about the token exchange
- Allows you to add custom logic (store tokens, validate, etc.)

**Key Methods**:
```java
// Main method - exchanges code for tokens
Mono<OAuth2AccessTokenResponse> exchangeCodeForTokens(
    String code,
    String redirectUri,
    ClientRegistration clientRegistration)

// Advanced method - add custom parameters to token request
Mono<OAuth2AccessTokenResponse> exchangeCodeForTokensWithCustomParams(
    String code,
    String redirectUri,
    ClientRegistration clientRegistration,
    Map<String, String> customParams)
```

### 2. `CustomOAuth2AuthenticationManager.java`
**Purpose**: Intercepts the OAuth2 authentication flow in Spring Security.

**What it does**:
- Receives the `OAuth2AuthorizationCodeAuthenticationToken` from Spring Security
- Extracts the authorization code
- Calls `CustomOAuth2TokenExchangeService` to exchange code for tokens
- Decodes the ID token to extract user information
- Extracts roles/authorities from Keycloak token claims
- Creates the final `OAuth2AuthenticationToken` with user details

**Key Methods**:
```java
// Main authentication method - called by Spring Security
Mono<Authentication> authenticate(Authentication authentication)

// Build authenticated user from token response
Mono<Authentication> buildAuthenticatedUser(
    OAuth2AccessTokenResponse tokenResponse,
    OAuth2AuthorizationCodeAuthenticationToken authCodeToken)

// Decode and validate ID token
Mono<OidcIdToken> decodeIdToken(
    String idTokenValue,
    OAuth2AuthorizationCodeAuthenticationToken authCodeToken)

// Extract Keycloak roles as Spring Security authorities
Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims)
```

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. User tries to access protected resource                         │
│    GET http://localhost:8080/api/users                              │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. Spring Security detects unauthenticated request                 │
│    Redirects to Keycloak authorization endpoint                     │
│    GET http://keycloak.local:3081/realms/dev-realm/protocol/       │
│        openid-connect/auth?client_id=...&redirect_uri=...           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3. User logs in at Keycloak                                         │
│    Enters username/password                                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 4. Keycloak redirects back with authorization code                  │
│    GET http://localhost:8080/login/oauth2/code/gateway?code=ABC123 │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 5. ⭐ CustomOAuth2AuthenticationManager.authenticate() CALLED       │
│    - Extracts authorization code: ABC123                            │
│    - Logs: "🔐 CUSTOM AUTHENTICATION MANAGER INVOKED"               │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 6. ⭐ CustomOAuth2TokenExchangeService.exchangeCodeForTokens()      │
│    - Builds token request parameters                                │
│    - POST http://keycloak.local:3081/realms/dev-realm/protocol/    │
│           openid-connect/token                                      │
│    - Body: grant_type=authorization_code&code=ABC123&...            │
│    - Logs: "🔄 CUSTOM TOKEN EXCHANGE STARTED"                       │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 7. Keycloak responds with tokens                                    │
│    {                                                                │
│      "access_token": "eyJhbGci...",                                 │
│      "id_token": "eyJhbGci...",                                     │
│      "refresh_token": "eyJhbGci...",                                │
│      "expires_in": 300,                                             │
│      "token_type": "Bearer"                                         │
│    }                                                                │
│    - Logs: "✅ TOKEN EXCHANGE SUCCESSFUL"                           │
│    - Logs: "🎫 Access Token: eyJhbGci...xyz"                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 8. ⭐ CustomOAuth2AuthenticationManager.buildAuthenticatedUser()    │
│    - Decodes ID token using JWK Set from Keycloak                  │
│    - Extracts user info: username, email, name                      │
│    - Extracts roles from realm_access and resource_access           │
│    - Creates OAuth2AuthenticationToken                              │
│    - Logs: "✅ AUTHENTICATION SUCCESSFUL"                           │
│    - Logs: "👤 User: john.doe"                                      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 9. Spring Security stores authentication in SecurityContext        │
│    User is now authenticated                                        │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 10. AuthenticationSuccessHandler redirects to "/"                   │
│     User lands on home page, fully authenticated                    │
└─────────────────────────────────────────────────────────────────────┘
```

## 🎯 What You Can Customize

### In `CustomOAuth2TokenExchangeService`:

1. **Add custom parameters to token request**:
```java
// Add custom parameters like audience, resource, etc.
formData.add("audience", "my-api");
formData.add("custom_claim", "custom_value");
```

2. **Store tokens in database**:
```java
.doOnNext(response -> {
    // Store tokens for later use
    tokenRepository.save(new TokenEntity(
        userId,
        response.get("access_token"),
        response.get("refresh_token")
    ));
})
```

3. **Log to external system**:
```java
.doOnNext(response -> {
    auditService.logTokenExchange(userId, timestamp);
})
```

4. **Validate tokens before accepting**:
```java
.doOnNext(response -> {
    String accessToken = (String) response.get("access_token");
    if (!customValidator.isValid(accessToken)) {
        throw new OAuth2AuthenticationException("Invalid token");
    }
})
```

### In `CustomOAuth2AuthenticationManager`:

1. **Sync user data with database**:
```java
.map(idToken -> {
    String username = (String) idToken.getClaims().get("preferred_username");
    userRepository.updateLastLogin(username, Instant.now());
    return idToken;
})
```

2. **Add custom authorities**:
```java
private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
    Set<GrantedAuthority> authorities = new HashSet<>();
    
    // Add custom business logic
    if (isAdmin(claims)) {
        authorities.add(new SimpleGrantedAuthority("ROLE_ADMIN"));
    }
    
    return authorities;
}
```

3. **Validate user eligibility**:
```java
.flatMap(idToken -> {
    String email = (String) idToken.getClaims().get("email");
    if (!email.endsWith("@mycompany.com")) {
        return Mono.error(new OAuth2AuthenticationException(
            new OAuth2Error("unauthorized_domain")
        ));
    }
    return Mono.just(idToken);
})
```

## 🧪 Testing the Implementation

### 1. Start the application:
```bash
./mvnw spring-boot:run
```

### 2. Navigate to a protected endpoint:
```
http://localhost:8080/api/users
```

### 3. Watch the console logs:
You should see detailed logs like:
```
🔐 ========================================
🔐 CUSTOM AUTHENTICATION MANAGER INVOKED
🔐 ========================================
📋 Registration ID: gateway
📋 Authorization Code: abc123xyz...
📋 Redirect URI: http://localhost:8080/login/oauth2/code/gateway

🔄 ========================================
🔄 CUSTOM TOKEN EXCHANGE STARTED
🔄 ========================================
📍 Authorization Code: abc123xyz...
📤 Sending token request to Keycloak...

✅ ========================================
✅ TOKEN EXCHANGE SUCCESSFUL
✅ ========================================
🎫 Access Token: eyJhbGci...xyz
🎫 ID Token: eyJhbGci...abc
🎫 Refresh Token: eyJhbGci...def

👤 User Details:
   Username: john.doe
   Email: john.doe@example.com
   Name: John Doe
   Authorities: [ROLE_USER, ROLE_ADMIN]

✅ ========================================
✅ AUTHENTICATION SUCCESSFUL
✅ ========================================
```

## 🔍 Debugging Tips

### Enable detailed Spring Security logs:
In `application.yml`:
```yaml
logging:
  level:
    org.springframework.security: TRACE
    org.springframework.security.oauth2: TRACE
    com.zz.gateway.auth.oauth2: DEBUG
```

### Add breakpoints:
- `CustomOAuth2AuthenticationManager.authenticate()` - line 48
- `CustomOAuth2TokenExchangeService.exchangeCodeForTokens()` - line 60
- `CustomOAuth2AuthenticationManager.buildAuthenticatedUser()` - line 109

### Check token contents:
Use https://jwt.io to decode the ID token and access token to see the claims.

## 🚀 Advanced Use Cases

### 1. Token Refresh
Add a method to refresh tokens:
```java
public Mono<OAuth2AccessTokenResponse> refreshToken(String refreshToken) {
    // Implement token refresh logic
}
```

### 2. Token Introspection
Validate tokens with Keycloak:
```java
public Mono<Boolean> introspectToken(String token) {
    // Call Keycloak introspection endpoint
}
```

### 3. Custom Token Claims
Add custom claims to the authentication:
```java
Map<String, Object> additionalClaims = new HashMap<>();
additionalClaims.put("tenant_id", extractTenantId(claims));
```

## 📚 Related Documentation

- [Spring Security OAuth2 Client](https://docs.spring.io/spring-security/reference/servlet/oauth2/client/index.html)
- [Keycloak Token Exchange](https://www.keycloak.org/docs/latest/securing_apps/#_token-exchange)
- [OAuth 2.0 Authorization Code Flow](https://oauth.net/2/grant-types/authorization-code/)

## ❓ FAQ

**Q: Why use custom authentication manager instead of default?**
A: To have full visibility and control over the token exchange process, add custom validation, store tokens, or integrate with external systems.

**Q: Does this break Spring Security's OAuth2 support?**
A: No! We're just customizing the authentication manager. All other Spring Security features (session management, CSRF, etc.) work normally.

**Q: Can I still use the default flow?**
A: Yes! Simply remove the `.authenticationManager(customAuthenticationManager)` line from SecurityConfig.

**Q: How do I access tokens in my controllers?**
A: Inject `OAuth2AuthenticationToken` or use `@AuthenticationPrincipal`:
```java
@GetMapping("/me")
public Mono<Map<String, Object>> getCurrentUser(
    @AuthenticationPrincipal OidcUser user) {
    return Mono.just(user.getClaims());
}
```

