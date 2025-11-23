# Spring Security Token Validation Process

## Overview

This document explains how Spring Security validates OAuth2/OIDC tokens after the authorization code is exchanged, and shows you all the customization points in your application.

---

## 🔄 The Complete OAuth2 Flow in Your App

```
1. User clicks login
   ↓
2. Redirect to Keycloak authorization endpoint
   ↓
3. User authenticates at Keycloak
   ↓
4. Keycloak redirects back with authorization code
   ↓
5. ⭐ CustomOAuth2TokenExchangeService.exchangeCodeForTokens()
   - Exchanges code for tokens (access_token, id_token, refresh_token)
   ↓
6. ⭐ CustomOAuth2AuthenticationManager.decodeIdToken()
   - Validates ID token signature using JWK Set
   - Validates token claims (exp, iat, iss, aud)
   ↓
7. ⭐ CustomOAuth2AuthenticationManager.extractAuthorities()
   - Extracts roles from token claims
   ↓
8. Creates authenticated user (OidcUser)
   ↓
9. Stores authentication in SecurityContext
   ↓
10. User is authenticated ✅
```

---

## 🔐 Token Validation Process (Step 6 in Detail)

### Where It Happens

In your `CustomOAuth2AuthenticationManager.java`, the `decodeIdToken()` method:

```java
private Mono<OidcIdToken> decodeIdToken(
        String idTokenValue,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {
    
    // 1. Get JWK Set URI from Keycloak
    String jwkSetUri = authCodeToken.getClientRegistration()
            .getProviderDetails()
            .getJwkSetUri();
    // Example: http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs
    
    // 2. Create JWT decoder with JWK Set URI
    JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    
    // 3. Decode and validate the JWT
    Jwt jwt = jwtDecoder.decode(idTokenValue);
    
    // 4. Convert to OidcIdToken
    OidcIdToken idToken = new OidcIdToken(
            jwt.getTokenValue(),
            jwt.getIssuedAt(),
            jwt.getExpiresAt(),
            jwt.getClaims()
    );
    
    return Mono.just(idToken);
}
```

### What Gets Validated Automatically

When you call `jwtDecoder.decode(idTokenValue)`, Spring Security automatically validates:

#### 1. **Signature Validation** ✅
- Downloads public keys from Keycloak's JWK Set endpoint
- Verifies the token was signed by Keycloak using RS256 algorithm
- Caches the JWK Set for performance

#### 2. **Expiration Time (`exp`)** ✅
- Checks if current time < expiration time
- Throws `JwtException` if token is expired

#### 3. **Issued At (`iat`)** ✅
- Validates the token was issued in the past
- Prevents tokens with future timestamps

#### 4. **Not Before (`nbf`)** ✅
- If present, checks if current time >= nbf
- Prevents using tokens before they're valid

#### 5. **Issuer (`iss`)** ✅
- Validates the token was issued by the expected issuer
- Expected: `http://keycloak.local:3081/realms/dev-realm`

#### 6. **Audience (`aud`)** ⚠️
- Can be configured to validate audience claim
- By default, not strictly enforced for ID tokens

---

## 🎯 Your Current Customization Points

### 1. Custom Token Exchange (`CustomOAuth2TokenExchangeService`)

**Location:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2TokenExchangeService.java`

**What You Can Customize:**
```java
public Mono<OAuth2AccessTokenResponse> exchangeCodeForTokens(...) {
    // ✅ You control the entire HTTP request to Keycloak
    // ✅ You can add custom parameters
    // ✅ You can log the request/response
    // ✅ You can store tokens in database
    // ✅ You can call external APIs
    
    MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
    formData.add("grant_type", "authorization_code");
    formData.add("code", code);
    // ... add custom parameters here
    
    return webClient.post()
        .uri(tokenUri)
        .bodyValue(formData)
        .retrieve()
        .bodyToMono(Map.class)
        .doOnNext(response -> {
            // ✅ Custom logic after receiving tokens
            // - Store in database
            // - Log to external system
            // - Validate custom claims
        });
}
```

### 2. Custom Authentication Manager (`CustomOAuth2AuthenticationManager`)

**Location:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

**What You Can Customize:**
```java
@Override
public Mono<Authentication> authenticate(Authentication authentication) {
    // ✅ You control the entire authentication process
    // ✅ You can add custom validation logic
    // ✅ You can modify user attributes
    // ✅ You can call external services
    
    return tokenExchangeService.exchangeCodeForTokens(...)
        .flatMap(tokenResponse -> {
            // ✅ Custom logic before building user
            return buildAuthenticatedUser(tokenResponse, authCodeToken);
        })
        .map(auth -> {
            // ✅ Custom logic after authentication
            // - Store user in database
            // - Update last login time
            // - Sync user roles
            // - Log authentication event
            return auth;
        });
}
```

### 3. Custom Authority Extraction (`extractAuthorities()`)

**What You Can Customize:**
```java
private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
    Set<GrantedAuthority> authorities = new HashSet<>();
    
    // ✅ Extract realm roles from Keycloak
    // realm_access.roles -> ROLE_USER, ROLE_ADMIN
    
    // ✅ Extract client roles from Keycloak
    // resource_access.app-client.roles -> ROLE_APP-CLIENT_MANAGER
    
    // ✅ You can add custom logic:
    // - Fetch roles from database
    // - Map Keycloak roles to application roles
    // - Add dynamic roles based on user attributes
    // - Call external authorization service
    
    return authorities;
}
```

---

## 🔧 Advanced Customization Options

### Option 1: Custom JWT Decoder with Additional Validations

Create a custom JWT decoder with additional validators:

```java
@Bean
public JwtDecoder customJwtDecoder() {
    String jwkSetUri = "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs";
    
    NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    
    // Add custom validators
    OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator("app-client");
    OAuth2TokenValidator<Jwt> issuerValidator = new JwtIssuerValidator("http://keycloak.local:3081/realms/dev-realm");
    OAuth2TokenValidator<Jwt> customValidator = new CustomClaimValidator();
    
    OAuth2TokenValidator<Jwt> validators = new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),
        audienceValidator,
        issuerValidator,
        customValidator
    );
    
    jwtDecoder.setJwtValidator(validators);
    
    return jwtDecoder;
}

// Custom validator example
public class CustomClaimValidator implements OAuth2TokenValidator<Jwt> {
    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        // Validate custom claims
        String emailVerified = jwt.getClaim("email_verified");
        if (!"true".equals(emailVerified)) {
            return OAuth2TokenValidatorResult.failure(
                new OAuth2Error("invalid_token", "Email not verified", null)
            );
        }
        return OAuth2TokenValidatorResult.success();
    }
}
```

### Option 2: Custom Token Introspection

Instead of validating JWT locally, you can validate with Keycloak's introspection endpoint:

```java
@Service
public class TokenIntrospectionService {
    
    private final WebClient webClient;
    
    public Mono<Boolean> introspectToken(String token, ClientRegistration clientRegistration) {
        String introspectionUri = "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token/introspect";
        
        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("token", token);
        formData.add("client_id", clientRegistration.getClientId());
        formData.add("client_secret", clientRegistration.getClientSecret());
        
        return webClient.post()
            .uri(introspectionUri)
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .bodyValue(formData)
            .retrieve()
            .bodyToMono(Map.class)
            .map(response -> {
                Boolean active = (Boolean) response.get("active");
                System.out.println("Token active: " + active);
                return active != null && active;
            });
    }
}
```

### Option 3: Custom Claims Validation

Add custom validation logic in your authentication manager:

```java
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            // ✅ Custom validation logic
            Map<String, Object> claims = idToken.getClaims();
            
            // Validate email is verified
            Boolean emailVerified = (Boolean) claims.get("email_verified");
            if (emailVerified == null || !emailVerified) {
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("email_not_verified", "Email must be verified", null)
                ));
            }
            
            // Validate user has required role
            Set<GrantedAuthority> authorities = extractAuthorities(claims);
            boolean hasRequiredRole = authorities.stream()
                .anyMatch(auth -> auth.getAuthority().equals("ROLE_USER"));
            
            if (!hasRequiredRole) {
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("insufficient_permissions", "User lacks required role", null)
                ));
            }
            
            // Validate custom claim
            String organization = (String) claims.get("organization");
            if (organization == null || !organization.equals("my-company")) {
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("invalid_organization", "User not from allowed organization", null)
                ));
            }
            
            // All validations passed
            return Mono.just(createOidcUser(idToken, authorities));
        });
}
```

### Option 4: Database-Based User Validation

Validate user exists in your database:

```java
@Service
public class UserValidationService {
    
    @Autowired
    private UserRepository userRepository;
    
    public Mono<User> validateAndSyncUser(OidcIdToken idToken) {
        String keycloakId = idToken.getSubject();
        String email = idToken.getEmail();
        String username = idToken.getPreferredUsername();
        
        return userRepository.findByKeycloakId(keycloakId)
            .switchIfEmpty(
                // User doesn't exist, create new user
                Mono.defer(() -> {
                    User newUser = new User();
                    newUser.setKeycloakId(keycloakId);
                    newUser.setEmail(email);
                    newUser.setUsername(username);
                    newUser.setCreatedAt(Instant.now());
                    return userRepository.save(newUser);
                })
            )
            .flatMap(user -> {
                // Update user information
                user.setEmail(email);
                user.setUsername(username);
                user.setLastLoginAt(Instant.now());
                return userRepository.save(user);
            })
            .doOnNext(user -> {
                System.out.println("User validated and synced: " + user.getUsername());
            });
    }
}

// In CustomOAuth2AuthenticationManager
private Mono<Authentication> buildAuthenticatedUser(...) {
    return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {
            // Validate user in database
            return userValidationService.validateAndSyncUser(idToken)
                .map(user -> {
                    // Create authenticated user
                    Set<GrantedAuthority> authorities = extractAuthorities(idToken.getClaims());
                    OidcUser oidcUser = new DefaultOidcUser(authorities, idToken, "preferred_username");
                    return new OAuth2LoginAuthenticationToken(...);
                });
        });
}
```

---

## 🛡️ Token Validation on Subsequent Requests

After initial authentication, Spring Security validates tokens on each request:

### For Session-Based Authentication (Default)

```java
// Spring Security stores the authentication in session
// On each request:
1. Reads JSESSIONID cookie
2. Retrieves authentication from session
3. Checks if session is valid
4. Checks if token is expired (if stored in session)
```

### For Stateless JWT Authentication (Resource Server)

If you want to validate tokens on each request without sessions:

```java
@Bean
public SecurityWebFilterChain resourceServerSecurityChain(ServerHttpSecurity http) {
    http
        .authorizeExchange(exchanges -> exchanges
            .anyExchange().authenticated()
        )
        .oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt
                .jwtDecoder(customJwtDecoder()) // Validates JWT on each request
            )
        );
    
    return http.build();
}
```

This configuration:
- Validates JWT signature on each request
- Validates expiration time
- Validates issuer
- Extracts authorities from JWT claims

---

## 📊 Token Validation Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Token Exchange                                           │
│    CustomOAuth2TokenExchangeService                         │
│    ↓                                                         │
│    POST /token (code → tokens)                              │
│    ↓                                                         │
│    Returns: access_token, id_token, refresh_token           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Token Validation                                         │
│    CustomOAuth2AuthenticationManager.decodeIdToken()        │
│    ↓                                                         │
│    NimbusJwtDecoder.decode(idToken)                         │
│    ↓                                                         │
│    ┌─────────────────────────────────────────┐             │
│    │ Automatic Validations:                  │             │
│    │ ✅ Signature (using JWK Set)            │             │
│    │ ✅ Expiration (exp claim)               │             │
│    │ ✅ Issued At (iat claim)                │             │
│    │ ✅ Not Before (nbf claim)               │             │
│    │ ✅ Issuer (iss claim)                   │             │
│    └─────────────────────────────────────────┘             │
│    ↓                                                         │
│    Returns: Jwt object with validated claims                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Custom Validations (Your Code)                          │
│    ↓                                                         │
│    extractAuthorities(claims)                               │
│    - Extract realm_access.roles                             │
│    - Extract resource_access.roles                          │
│    - Map to GrantedAuthority                                │
│    ↓                                                         │
│    buildAuthenticatedUser()                                 │
│    - Create OidcUser                                        │
│    - Create OAuth2LoginAuthenticationToken                  │
│    ↓                                                         │
│    Optional: validateAndSyncUser()                          │
│    - Check user in database                                 │
│    - Update user information                                │
│    - Add custom authorities                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Authentication Complete                                  │
│    - User is authenticated                                  │
│    - SecurityContext is populated                           │
│    - Session is created (if using sessions)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎓 Key Takeaways

### What Spring Security Does Automatically
1. ✅ **Signature validation** using JWK Set from Keycloak
2. ✅ **Expiration validation** (exp claim)
3. ✅ **Issued at validation** (iat claim)
4. ✅ **Not before validation** (nbf claim)
5. ✅ **Issuer validation** (iss claim)

### What You Can Customize
1. ✅ **Token exchange process** (CustomOAuth2TokenExchangeService)
2. ✅ **Authentication flow** (CustomOAuth2AuthenticationManager)
3. ✅ **Authority extraction** (extractAuthorities method)
4. ✅ **Custom claim validation** (add your own validators)
5. ✅ **User database sync** (validateAndSyncUser)
6. ✅ **Token introspection** (call Keycloak's introspect endpoint)
7. ✅ **Audience validation** (custom JWT decoder)
8. ✅ **Custom error handling** (authentication failure handler)

### Where Validation Happens
- **Initial login**: `CustomOAuth2AuthenticationManager.decodeIdToken()`
- **Subsequent requests (session-based)**: Session validation only
- **Subsequent requests (stateless)**: JWT validation on each request (if using resource server)

---

## 🚀 Next Steps

1. **Add custom claim validation** - Validate email_verified, organization, etc.
2. **Add database user sync** - Store/update users in your database
3. **Add token introspection** - Validate tokens with Keycloak on each request
4. **Add custom authorities** - Fetch roles from database instead of token
5. **Add audit logging** - Log all authentication events
6. **Add rate limiting** - Prevent brute force attacks
7. **Add MFA validation** - Require additional authentication factors

---

## 📚 Related Files

- `SecurityConfig.java` - Main security configuration
- `CustomOAuth2AuthenticationManager.java` - Custom authentication logic
- `CustomOAuth2TokenExchangeService.java` - Custom token exchange
- `application.yml` - OAuth2 client configuration

---

## 🔗 References

- [Spring Security OAuth2 Client](https://docs.spring.io/spring-security/reference/servlet/oauth2/client/index.html)
- [Spring Security JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [Nimbus JWT Decoder](https://connect2id.com/products/nimbus-jose-jwt)
- [Keycloak Token Endpoint](https://www.keycloak.org/docs/latest/securing_apps/#_token-exchange)

