# Token Validation Cheatsheet

Quick reference for Spring Security token validation in your app.

---

## 🎯 Quick Answer

**Q: How does Spring Security validate tokens after auth code exchange?**

**A:** In `CustomOAuth2AuthenticationManager.java` line 185:
```java
Jwt jwt = jwtDecoder.decode(idTokenValue);
```

This validates: signature ✅, expiration ✅, issued-at ✅, not-before ✅, issuer ✅

---

## 📍 Where Validation Happens

```
CustomOAuth2AuthenticationManager.java
    ↓
Line 169: decodeIdToken() method
    ↓
Line 182: Create NimbusJwtDecoder
    ↓
Line 185: jwtDecoder.decode(idTokenValue)  ⭐ VALIDATION HERE
    ↓
Line 188: Convert to OidcIdToken
```

---

## ✅ Automatic Validations

| Validation | Status | How |
|------------|--------|-----|
| Signature | ✅ Auto | Using Keycloak's public key from JWK Set |
| Expiration (exp) | ✅ Auto | Current time < exp |
| Issued At (iat) | ✅ Auto | iat <= current time |
| Not Before (nbf) | ✅ Auto | current time >= nbf (if present) |
| Issuer (iss) | ✅ Auto | iss == expected issuer |
| Audience (aud) | ⚠️ Partial | Can add custom validator |

---

## 🔧 Customization Points

### 1. Custom JWT Decoder
**When:** Need additional validators (audience, custom claims)
**Where:** Create new `@Bean JwtDecoder`
**Code:**
```java
@Bean
public JwtDecoder jwtDecoder() {
    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withJwkSetUri(jwkSetUri).build();
    decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),
        new AudienceValidator("app-client")
    ));
    return decoder;
}
```

### 2. Custom Claims Validation
**When:** Need to validate email_verified, organization, etc.
**Where:** `CustomOAuth2AuthenticationManager.buildAuthenticatedUser()` after line 124
**Code:**
```java
.flatMap(idToken -> {
    Map<String, Object> claims = idToken.getClaims();
    
    // Validate email verified
    Boolean emailVerified = (Boolean) claims.get("email_verified");
    if (!emailVerified) {
        return Mono.error(new OAuth2AuthenticationException(...));
    }
    
    // Continue...
})
```

### 3. Token Introspection
**When:** Need to check if token is revoked
**Where:** Create `TokenIntrospectionService`
**Code:**
```java
public Mono<Boolean> introspectToken(String token) {
    return webClient.post()
        .uri(keycloakIntrospectUri)
        .bodyValue(Map.of("token", token, "client_id", clientId))
        .retrieve()
        .bodyToMono(Map.class)
        .map(r -> (Boolean) r.get("active"));
}
```

### 4. Database User Sync
**When:** Need to sync user with database
**Where:** Create `UserValidationService`
**Code:**
```java
public Mono<User> validateAndSyncUser(OidcIdToken idToken) {
    return userRepository.findByKeycloakId(idToken.getSubject())
        .switchIfEmpty(createNewUser(idToken))
        .flatMap(user -> updateAndSave(user, idToken));
}
```

---

## 🚀 Quick Implementation

### Add Email Verification (2 min)
```java
// In buildAuthenticatedUser() after line 124
Boolean emailVerified = (Boolean) claims.get("email_verified");
if (emailVerified == null || !emailVerified) {
    return Mono.error(new OAuth2AuthenticationException(
        new OAuth2Error("email_not_verified", "Email not verified", null)
    ));
}
```

### Add Organization Check (2 min)
```java
// In buildAuthenticatedUser() after email check
String org = (String) claims.get("organization");
if (!"my-company".equals(org)) {
    return Mono.error(new OAuth2AuthenticationException(
        new OAuth2Error("invalid_organization", "Invalid org", null)
    ));
}
```

### Add Audience Validator (5 min)
```java
@Bean
public JwtDecoder jwtDecoder() {
    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withJwkSetUri("http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs")
        .build();
    decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),
        jwt -> jwt.getAudience().contains("app-client") 
            ? OAuth2TokenValidatorResult.success() 
            : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_aud"))
    ));
    return decoder;
}
```

---

## 🔄 Session vs Stateless

### Session-Based (Your Current Setup)
- ✅ Token validated once during login
- ✅ Session used for subsequent requests
- ✅ Fast (no JWT validation on each request)
- ⚠️ Token revocation not detected until session expires

### Stateless (Resource Server)
- ✅ Token validated on every request
- ✅ Token revocation detected immediately
- ✅ No server-side session
- ⚠️ Slower (JWT validation on each request)

**To enable stateless:**
```java
http.oauth2ResourceServer(oauth2 -> oauth2
    .jwt(jwt -> jwt.jwtDecoder(customJwtDecoder()))
);
```

---

## 🧪 Testing

### Test Valid User
```bash
curl -v http://localhost:8080/
# Expected: Login succeeds
```

### Test Invalid Token
```bash
curl -H "Authorization: Bearer invalid_token" http://localhost:8080/api/test
# Expected: 401 Unauthorized
```

### Check Logs
```bash
./gradlew bootRun
# Look for:
# ✅ ID token decoded successfully
# ✅ Authentication successful
# ❌ Failed to decode ID token
```

---

## 📁 Key Files

| File | Purpose | Key Lines |
|------|---------|-----------|
| `CustomOAuth2AuthenticationManager.java` | Token validation | 169-206 (decodeIdToken) |
| `CustomOAuth2TokenExchangeService.java` | Token exchange | 37-98 (exchangeCodeForTokens) |
| `SecurityConfig.java` | Security config | 21-65 (securityWebFilterChain) |
| `application.yml` | OAuth2 config | 6-24 (oauth2 client) |

---

## ❓ Common Questions

**Q: When is token validated?**
A: During initial login (line 185 in CustomOAuth2AuthenticationManager)

**Q: Is it validated on every request?**
A: No (with sessions). Yes (with resource server config).

**Q: Can I add custom validation?**
A: Yes! Add logic in buildAuthenticatedUser() or create custom JWT decoder.

**Q: Where are public keys cached?**
A: NimbusJwtDecoder caches JWK Set automatically.

**Q: What if validation fails?**
A: OAuth2AuthenticationException is thrown, user not authenticated.

---

## 🎯 Decision Tree

```
Need to validate tokens?
│
├─ During login only? → Use current setup (CustomOAuth2AuthenticationManager)
│
├─ On every request? → Add oauth2ResourceServer() config
│
├─ Custom claims? → Add validation in buildAuthenticatedUser()
│
├─ Check revocation? → Use token introspection
│
└─ Sync with DB? → Create UserValidationService
```

---

## 📚 Documentation

- **Quick Reference:** `TOKEN_VALIDATION_QUICK_REFERENCE.md`
- **Full Guide:** `TOKEN_VALIDATION_EXPLAINED.md`
- **Visual Diagrams:** `TOKEN_VALIDATION_VISUAL_SUMMARY.md`
- **Hands-On Guide:** `HANDS_ON_CUSTOM_VALIDATION.md`
- **Code Examples:** `CUSTOMIZATION_EXAMPLES.md`
- **Code Flow:** `code_flow_with_line_numbers.md`

---

## 🔗 Useful Links

- Spring Security OAuth2: https://docs.spring.io/spring-security/reference/servlet/oauth2/client/
- JWT Decoder: https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html
- Keycloak Docs: https://www.keycloak.org/docs/latest/securing_apps/

---

**Print this page for quick reference! 📄**

