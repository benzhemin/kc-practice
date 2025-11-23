# Custom OAuth2 Implementation - Complete Guide

## 🎯 What Was Implemented

You now have **full control** over the OAuth2 authorization code flow and token exchange process. Spring Security no longer hides the token exchange - you can see it, customize it, and extend it.

## 📦 New Components

### 1. **CustomOAuth2TokenExchangeService** 
`src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2TokenExchangeService.java`

**Responsibility**: Handles the actual HTTP token exchange with Keycloak.

**Key Features**:
- ✅ Intercepts authorization code
- ✅ Makes POST request to Keycloak token endpoint
- ✅ Logs detailed token information (masked for security)
- ✅ Returns `OAuth2AccessTokenResponse` with all tokens
- ✅ Supports custom parameters in token request

### 2. **CustomOAuth2AuthenticationManager**
`src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

**Responsibility**: Integrates with Spring Security's authentication flow.

**Key Features**:
- ✅ Receives `OAuth2AuthorizationCodeAuthenticationToken` from Spring Security
- ✅ Calls `CustomOAuth2TokenExchangeService` for token exchange
- ✅ Decodes ID token using Keycloak's JWK Set
- ✅ Extracts user information (username, email, name)
- ✅ Extracts Keycloak roles and converts to Spring Security authorities
- ✅ Creates final `OAuth2AuthenticationToken`

### 3. **Updated SecurityConfig**
`src/main/java/com/zz/gateway/auth/config/SecurityConfig.java`

**Changes**:
- ✅ Injects `CustomOAuth2AuthenticationManager`
- ✅ Configures `.oauth2Login()` to use custom authentication manager
- ✅ All other security features remain intact

## 🔄 Complete Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                    USER AUTHENTICATION FLOW                          │
└──────────────────────────────────────────────────────────────────────┘

1. User accesses protected endpoint
   GET http://localhost:8080/api/users
   
   ↓

2. Spring Security detects unauthenticated request
   Redirects to Keycloak login
   
   ↓

3. User logs in at Keycloak
   Keycloak redirects back with authorization code
   GET http://localhost:8080/login/oauth2/code/gateway?code=ABC123
   
   ↓

4. ⭐ CustomOAuth2AuthenticationManager.authenticate()
   📋 Extracts code: ABC123
   📋 Logs: "🔐 CUSTOM AUTHENTICATION MANAGER INVOKED"
   
   ↓

5. ⭐ CustomOAuth2TokenExchangeService.exchangeCodeForTokens()
   📤 POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
   📤 Body: grant_type=authorization_code&code=ABC123&...
   📋 Logs: "🔄 CUSTOM TOKEN EXCHANGE STARTED"
   
   ↓

6. Keycloak responds with tokens
   {
     "access_token": "eyJhbGci...",
     "id_token": "eyJhbGci...",
     "refresh_token": "eyJhbGci...",
     "expires_in": 300
   }
   📋 Logs: "✅ TOKEN EXCHANGE SUCCESSFUL"
   📋 Logs: "🎫 Access Token: eyJhbGci...xyz"
   
   ↓

7. ⭐ CustomOAuth2AuthenticationManager.buildAuthenticatedUser()
   🔍 Decodes ID token
   👤 Extracts user: john.doe
   🔑 Extracts roles: [ROLE_USER, ROLE_ADMIN]
   📋 Logs: "✅ AUTHENTICATION SUCCESSFUL"
   
   ↓

8. Spring Security stores authentication
   User is now authenticated
   
   ↓

9. AuthenticationSuccessHandler redirects to "/"
   User lands on home page
```

## 🚀 How to Test

### Step 1: Start Keycloak (if not already running)
```bash
docker-compose up -d
```

### Step 2: Start the application
```bash
./mvnw spring-boot:run
```

### Step 3: Access a protected endpoint
Open your browser and navigate to:
```
http://localhost:8080/api/users
```

### Step 4: Watch the console logs
You should see detailed logs showing the entire flow:

```
🔐 ========================================
🔐 CUSTOM AUTHENTICATION MANAGER INVOKED
🔐 ========================================
📋 Registration ID: gateway
📋 Authorization Code: urn:ietf:params:oauth:grant-type:jwt-bearer...
📋 Redirect URI: http://localhost:8080/login/oauth2/code/gateway
📋 State: xyz123

🔄 ========================================
🔄 CUSTOM TOKEN EXCHANGE STARTED
🔄 ========================================
📍 Authorization Code: urn:ietf:params:oauth:grant-type:jwt-bearer...
📍 Redirect URI: http://localhost:8080/login/oauth2/code/gateway
📍 Client ID: app-client
📍 Token URI: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token
📤 Sending token request to Keycloak...

✅ ========================================
✅ TOKEN EXCHANGE SUCCESSFUL
✅ ========================================
🎫 Access Token: eyJhbGciOi...nKWvHxyz
🎫 ID Token: eyJhbGciOi...mQabcdef
🎫 Refresh Token: eyJhbGciOi...pQrstuvw
⏱️  Expires In: 300 seconds
🔑 Token Type: Bearer
📋 Scope: openid profile email

🎯 Building authenticated user from token response...
🔍 Decoding ID token using JWK Set URI: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
✅ ID token decoded successfully
   Subject: 12345678-1234-1234-1234-123456789abc
   Issued At: 2025-11-23T10:30:00Z
   Expires At: 2025-11-23T10:35:00Z

👤 User Details:
   Username: john.doe
   Email: john.doe@example.com
   Name: John Doe
   Authorities: [ROLE_USER, ROLE_ADMIN]

✅ ========================================
✅ AUTHENTICATION SUCCESSFUL
✅ ========================================
👤 User: john.doe
🔑 Authorities: [ROLE_USER, ROLE_ADMIN]
```

### Step 5: Test the endpoints

**Home endpoint** (authenticated):
```bash
curl http://localhost:8080/
# Response: "Hello, World! You are authenticated!"
```

**User info endpoint**:
```bash
curl http://localhost:8080/user
# Response: JSON with user details, claims, and roles
```

**Protected API endpoint**:
```bash
curl http://localhost:8080/api/users
# Response: JSON with message and authenticated user info
```

## 🎨 Customization Examples

### Example 1: Store Tokens in Database

In `CustomOAuth2TokenExchangeService.java`, add:

```java
@Autowired
private TokenRepository tokenRepository;

public Mono<OAuth2AccessTokenResponse> exchangeCodeForTokens(...) {
    return webClient
        .post()
        // ... existing code ...
        .doOnNext(response -> {
            // Store tokens
            @SuppressWarnings("unchecked")
            Map<String, Object> tokenMap = (Map<String, Object>) response;
            
            TokenEntity token = new TokenEntity();
            token.setAccessToken((String) tokenMap.get("access_token"));
            token.setRefreshToken((String) tokenMap.get("refresh_token"));
            token.setExpiresAt(Instant.now().plusSeconds(
                ((Number) tokenMap.get("expires_in")).longValue()
            ));
            
            tokenRepository.save(token).subscribe();
            
            System.out.println("💾 Tokens stored in database");
        })
        // ... rest of code ...
}
```

### Example 2: Add Custom Token Parameters

In `CustomOAuth2TokenExchangeService.java`:

```java
public Mono<OAuth2AccessTokenResponse> exchangeCodeForTokens(...) {
    MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
    formData.add("grant_type", "authorization_code");
    formData.add("code", code);
    formData.add("redirect_uri", redirectUri);
    formData.add("client_id", clientRegistration.getClientId());
    formData.add("client_secret", clientRegistration.getClientSecret());
    
    // Add custom parameters
    formData.add("audience", "my-custom-api");
    formData.add("resource", "my-resource-server");
    
    System.out.println("🔧 Added custom parameters: audience, resource");
    
    // ... rest of code ...
}
```

### Example 3: Validate User Before Authentication

In `CustomOAuth2AuthenticationManager.java`:

```java
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            Map<String, Object> claims = idToken.getClaims();
            String email = (String) claims.get("email");
            
            // Validate email domain
            if (!email.endsWith("@mycompany.com")) {
                System.err.println("❌ Unauthorized email domain: " + email);
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error(
                        "unauthorized_domain",
                        "Only @mycompany.com emails are allowed",
                        null
                    )
                ));
            }
            
            System.out.println("✅ Email domain validated: " + email);
            return Mono.just(idToken);
        })
        .map(idToken -> {
            // ... rest of authentication logic ...
        });
}
```

### Example 4: Add Custom Authorities Based on Business Logic

In `CustomOAuth2AuthenticationManager.java`:

```java
private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
    Set<GrantedAuthority> authorities = new HashSet<>();
    
    // Extract Keycloak roles (existing code)
    // ...
    
    // Add custom business logic
    String email = (String) claims.get("email");
    if (email != null && email.endsWith("@admin.mycompany.com")) {
        authorities.add(new SimpleGrantedAuthority("ROLE_SUPER_ADMIN"));
        System.out.println("🔑 Added ROLE_SUPER_ADMIN based on email domain");
    }
    
    // Check custom claim
    Object department = claims.get("department");
    if ("engineering".equals(department)) {
        authorities.add(new SimpleGrantedAuthority("ROLE_ENGINEER"));
        System.out.println("🔑 Added ROLE_ENGINEER based on department claim");
    }
    
    return authorities;
}
```

## 🔍 Debugging

### Enable Detailed Logging

In `application.yml`:
```yaml
logging:
  level:
    com.zz.gateway.auth.oauth2: DEBUG
    org.springframework.security: TRACE
    org.springframework.security.oauth2: TRACE
```

### Add Breakpoints

Set breakpoints in your IDE at:
1. `CustomOAuth2AuthenticationManager.authenticate()` - Line 48
2. `CustomOAuth2TokenExchangeService.exchangeCodeForTokens()` - Line 60
3. `CustomOAuth2AuthenticationManager.buildAuthenticatedUser()` - Line 109

### Decode Tokens

Copy the access token or ID token from the logs and paste it into https://jwt.io to see the claims.

## 📊 Comparison: Before vs After

### Before (Default Spring Security)
```
❌ Token exchange is hidden
❌ Can't see what's happening
❌ Can't customize token request
❌ Can't add custom validation
❌ Can't store tokens easily
```

### After (Custom Implementation)
```
✅ Full visibility into token exchange
✅ Detailed logs at every step
✅ Can add custom parameters to token request
✅ Can validate users before authentication
✅ Can store tokens in database
✅ Can add custom authorities
✅ Can integrate with external systems
```

## 🎓 Key Takeaways

1. **You now control the OAuth2 flow** - Spring Security delegates to your custom manager
2. **Token exchange is visible** - You can see exactly what's being sent to Keycloak
3. **Fully customizable** - Add parameters, validate users, store tokens, etc.
4. **Still uses Spring Security** - All other security features work normally
5. **Production-ready** - Includes error handling, logging, and proper token validation

## 📚 Next Steps

1. **Test the flow** - Try logging in and watch the console logs
2. **Customize it** - Add your own business logic to the token exchange
3. **Store tokens** - Implement token storage if needed
4. **Add refresh token logic** - Implement token refresh when access token expires
5. **Integrate with your systems** - Add calls to your user service, audit logs, etc.

## 🆘 Troubleshooting

### Issue: "No ID token found in response"
**Solution**: Make sure `scope: openid` is in your `application.yml`

### Issue: "Failed to decode ID token"
**Solution**: Check that Keycloak JWK Set URI is accessible from your app

### Issue: "Authentication failed"
**Solution**: Check the console logs for detailed error messages

### Issue: Tokens not showing in logs
**Solution**: Ensure logging level is set to DEBUG for `com.zz.gateway.auth.oauth2`

## 📞 Support

For more information, see:
- `src/main/java/com/zz/gateway/auth/oauth2/README.md` - Detailed technical documentation
- Spring Security OAuth2 docs: https://docs.spring.io/spring-security/reference/servlet/oauth2/client/
- Keycloak docs: https://www.keycloak.org/docs/latest/securing_apps/

---

**Congratulations! You now have full control over your OAuth2 authentication flow! 🎉**

