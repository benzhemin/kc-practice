# Token Validation Quick Reference

## 🎯 Quick Answer

**Q: How does Spring Security validate tokens after auth code exchange?**

**A:** In your app, token validation happens in `CustomOAuth2AuthenticationManager.decodeIdToken()`:

```java
// This line does ALL the automatic validation:
Jwt jwt = jwtDecoder.decode(idTokenValue);
```

This automatically validates:
- ✅ **Signature** (using Keycloak's public keys from JWK Set)
- ✅ **Expiration** (exp claim)
- ✅ **Issued At** (iat claim)
- ✅ **Not Before** (nbf claim)
- ✅ **Issuer** (iss claim)

---

## 📍 Where Validation Happens in Your Code

### File: `CustomOAuth2AuthenticationManager.java`

```
authenticate()                           // Entry point
    ↓
exchangeCodeForTokens()                 // Get tokens from Keycloak
    ↓
decodeIdToken()                         // ⭐ VALIDATION HAPPENS HERE
    ↓
    NimbusJwtDecoder.decode()           // Validates signature, exp, iat, nbf, iss
    ↓
extractAuthorities()                    // Extract roles from token
    ↓
buildAuthenticatedUser()                // Create authenticated user
```

### The Key Code (Lines 169-206)

```java
private Mono<OidcIdToken> decodeIdToken(String idTokenValue, ...) {
    // Get JWK Set URI (Keycloak's public keys)
    String jwkSetUri = authCodeToken.getClientRegistration()
            .getProviderDetails()
            .getJwkSetUri();
    
    // Create JWT decoder
    JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    
    // ⭐ THIS LINE VALIDATES EVERYTHING
    Jwt jwt = jwtDecoder.decode(idTokenValue);
    
    // Convert to OidcIdToken
    return Mono.just(new OidcIdToken(
        jwt.getTokenValue(),
        jwt.getIssuedAt(),
        jwt.getExpiresAt(),
        jwt.getClaims()
    ));
}
```

---

## 🔧 Can This Be Customized?

**YES!** You have multiple customization points:

### 1. Custom JWT Decoder (Add More Validators)

```java
@Bean
public JwtDecoder customJwtDecoder() {
    NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    
    // Add custom validators
    OAuth2TokenValidator<Jwt> validators = new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),           // Default validators
        new AudienceValidator("app-client"),     // ✅ Validate audience
        new CustomClaimValidator()               // ✅ Validate custom claims
    );
    
    decoder.setJwtValidator(validators);
    return decoder;
}
```

### 2. Custom Claims Validation

```java
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            Map<String, Object> claims = idToken.getClaims();
            
            // ✅ Validate email is verified
            Boolean emailVerified = (Boolean) claims.get("email_verified");
            if (!emailVerified) {
                return Mono.error(new OAuth2AuthenticationException(...));
            }
            
            // ✅ Validate organization
            String org = (String) claims.get("organization");
            if (!"my-company".equals(org)) {
                return Mono.error(new OAuth2AuthenticationException(...));
            }
            
            // Continue with authentication
            return Mono.just(createOidcUser(idToken));
        });
}
```

### 3. Token Introspection (Validate with Keycloak)

```java
// Instead of local JWT validation, ask Keycloak if token is valid
public Mono<Boolean> introspectToken(String token) {
    return webClient.post()
        .uri("http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token/introspect")
        .bodyValue(Map.of(
            "token", token,
            "client_id", "app-client",
            "client_secret", "secret"
        ))
        .retrieve()
        .bodyToMono(Map.class)
        .map(response -> (Boolean) response.get("active"));
}
```

### 4. Database User Validation

```java
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            // ✅ Validate user exists in database
            return userRepository.findByKeycloakId(idToken.getSubject())
                .switchIfEmpty(Mono.error(new OAuth2AuthenticationException(...)))
                .flatMap(user -> {
                    // ✅ Check if user is enabled
                    if (!user.isEnabled()) {
                        return Mono.error(new OAuth2AuthenticationException(...));
                    }
                    return Mono.just(createOidcUser(idToken));
                });
        });
}
```

### 5. Custom Authority Extraction

```java
// Already customized in your app (lines 209-253)
private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
    // ✅ Extract realm roles: realm_access.roles
    // ✅ Extract client roles: resource_access.app-client.roles
    // ✅ Map to GrantedAuthority
    // ✅ Add custom roles from database
    return authorities;
}
```

---

## 🔄 Validation Flow Comparison

### Default Spring Security (Without Customization)

```
1. OAuth2LoginAuthenticationWebFilter intercepts callback
2. OAuth2AuthorizationCodeAuthenticationProvider handles auth
3. DefaultReactiveOAuth2AccessTokenResponseClient exchanges code for tokens
4. NimbusJwtDecoder validates ID token
5. Creates OAuth2User with authorities from token
6. Stores in SecurityContext
```

### Your Custom Implementation

```
1. OAuth2LoginAuthenticationWebFilter intercepts callback
2. ⭐ CustomOAuth2AuthenticationManager handles auth (YOUR CODE)
3. ⭐ CustomOAuth2TokenExchangeService exchanges code (YOUR CODE)
   - You control the HTTP request
   - You can log request/response
   - You can add custom parameters
4. ⭐ CustomOAuth2AuthenticationManager.decodeIdToken() validates (YOUR CODE)
   - Uses NimbusJwtDecoder (same as default)
   - You can add custom validators
5. ⭐ extractAuthorities() extracts roles (YOUR CODE)
   - You control how roles are mapped
   - You can add roles from database
6. ⭐ buildAuthenticatedUser() creates user (YOUR CODE)
   - You can sync with database
   - You can add custom attributes
7. Stores in SecurityContext
```

---

## 🎓 What Gets Validated Automatically

| Validation | Automatic? | Where | Can Customize? |
|------------|-----------|-------|----------------|
| **Signature** | ✅ Yes | `NimbusJwtDecoder.decode()` | ✅ Yes (custom decoder) |
| **Expiration (exp)** | ✅ Yes | `NimbusJwtDecoder.decode()` | ✅ Yes (custom validator) |
| **Issued At (iat)** | ✅ Yes | `NimbusJwtDecoder.decode()` | ✅ Yes (custom validator) |
| **Not Before (nbf)** | ✅ Yes | `NimbusJwtDecoder.decode()` | ✅ Yes (custom validator) |
| **Issuer (iss)** | ✅ Yes | `NimbusJwtDecoder.decode()` | ✅ Yes (custom validator) |
| **Audience (aud)** | ⚠️ Partial | `NimbusJwtDecoder.decode()` | ✅ Yes (add validator) |
| **Email Verified** | ❌ No | - | ✅ Yes (add custom logic) |
| **Organization** | ❌ No | - | ✅ Yes (add custom logic) |
| **User in Database** | ❌ No | - | ✅ Yes (add custom logic) |
| **User Enabled** | ❌ No | - | ✅ Yes (add custom logic) |
| **Custom Claims** | ❌ No | - | ✅ Yes (add custom logic) |

---

## 📚 Related Files in Your Project

| File | Purpose |
|------|---------|
| `SecurityConfig.java` | Main security configuration, registers custom auth manager |
| `CustomOAuth2AuthenticationManager.java` | **⭐ Token validation happens here** |
| `CustomOAuth2TokenExchangeService.java` | Token exchange with Keycloak |
| `application.yml` | OAuth2 client configuration (JWK Set URI) |
| `doc/TOKEN_VALIDATION_EXPLAINED.md` | Detailed explanation (this is the full guide) |
| `doc/token_validation_flow.mmd` | Visual flow diagram |
| `doc/CUSTOMIZATION_EXAMPLES.md` | Code examples for customization |

---

## 🚀 Quick Start: Add Custom Validation

### Step 1: Add Custom Claim Validation

Edit `CustomOAuth2AuthenticationManager.java`:

```java
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            // Add this validation
            Boolean emailVerified = idToken.getClaim("email_verified");
            if (emailVerified == null || !emailVerified) {
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("email_not_verified", "Email must be verified", null)
                ));
            }
            
            // Continue with existing code
            Map<String, Object> claims = idToken.getClaims();
            // ...
        });
}
```

### Step 2: Test

```bash
# Build and run
./gradlew bootRun

# Try to login
open http://localhost:8080

# Check logs for validation
```

---

## 💡 Key Takeaways

1. **Token validation happens in `decodeIdToken()` method**
   - Uses `NimbusJwtDecoder.decode()` which validates signature, exp, iat, nbf, iss

2. **You already have full control**
   - `CustomOAuth2AuthenticationManager` gives you complete control
   - You can add any custom validation logic

3. **Validation is automatic but extensible**
   - Basic validations (signature, expiration) happen automatically
   - You can add custom validators for additional checks

4. **Multiple customization points**
   - Custom JWT decoder with validators
   - Custom claims validation
   - Token introspection with Keycloak
   - Database user validation
   - Custom authority extraction

5. **Your implementation is already advanced**
   - Most apps use default Spring Security behavior
   - You have full visibility and control over the process

---

## 🔗 Next Steps

1. **Read the full guide**: `doc/TOKEN_VALIDATION_EXPLAINED.md`
2. **See code examples**: `doc/CUSTOMIZATION_EXAMPLES.md`
3. **View flow diagram**: `doc/token_validation_flow.mmd`
4. **Try customizations**: Add email verification check, database sync, etc.

---

## ❓ Common Questions

**Q: Is the token validated on every request?**
- **With sessions (default)**: No, only during initial login. Session is validated on each request.
- **Stateless (resource server)**: Yes, JWT is validated on every request.

**Q: Can I validate tokens with Keycloak instead of locally?**
- Yes! Use token introspection endpoint. See `CUSTOMIZATION_EXAMPLES.md`.

**Q: Can I add my own custom validations?**
- Yes! You have full control in `CustomOAuth2AuthenticationManager`.

**Q: Where are Keycloak's public keys cached?**
- `NimbusJwtDecoder` caches JWK Set automatically. Refreshes when needed.

**Q: What happens if token validation fails?**
- `OAuth2AuthenticationException` is thrown
- User is not authenticated
- `authenticationFailureHandler` is called (configured in `SecurityConfig`)

---

**For detailed explanations, see `TOKEN_VALIDATION_EXPLAINED.md`**

