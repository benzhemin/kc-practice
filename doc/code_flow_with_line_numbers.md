# Token Validation Code Flow with Line Numbers

This document shows exactly where token validation happens in your code, with line numbers.

---

## 🎯 The Complete Flow

```
User Login
    ↓
SecurityConfig.java (Line 21-65)
    ↓
CustomOAuth2AuthenticationManager.java (Line 42-102)
    ↓
CustomOAuth2TokenExchangeService.java (Line 37-98)
    ↓
CustomOAuth2AuthenticationManager.java (Line 169-206)
    ⭐ TOKEN VALIDATION HAPPENS HERE
    ↓
CustomOAuth2AuthenticationManager.java (Line 209-253)
    ↓
User Authenticated ✅
```

---

## 📍 Step-by-Step Code Flow

### Step 1: Security Configuration Registers Custom Auth Manager

**File:** `src/main/java/com/zz/gateway/auth/config/SecurityConfig.java`

```java
// Lines 21-34
@Bean
public SecurityWebFilterChain securityWebFilterChain(
    ServerHttpSecurity http,
    CustomOAuth2AuthenticationManager customAuthenticationManager) {
  http
      .authorizeExchange(exchanges -> exchanges
          .pathMatchers("/actuator/**").permitAll()
          .pathMatchers("/login/**", "/oauth2/**").permitAll()
          .anyExchange().authenticated()
      )
      .oauth2Login(oauth2 -> oauth2
          // ⭐ Line 34: Register custom authentication manager
          .authenticationManager(customAuthenticationManager)
          // ...
```

**What happens:**
- Spring Security is configured to use your custom authentication manager
- All OAuth2 login requests will go through `CustomOAuth2AuthenticationManager`

---

### Step 2: Custom Auth Manager Receives Authorization Code

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 42-68
@Override
public Mono<Authentication> authenticate(Authentication authentication) {
    System.out.println("========================================");
    System.out.println("CUSTOM AUTHENTICATION MANAGER INVOKED");
    System.out.println("========================================");

    // Line 48: Check if this is OAuth2 authorization code authentication
    if (!(authentication instanceof OAuth2AuthorizationCodeAuthenticationToken)) {
        System.out.println("Not an OAuth2 authorization code token, skipping...");
        return Mono.just(authentication);
    }

    OAuth2AuthorizationCodeAuthenticationToken authCodeToken =
            (OAuth2AuthorizationCodeAuthenticationToken) authentication;

    OAuth2AuthorizationRequest authorizationRequest =
            authCodeToken.getAuthorizationExchange().getAuthorizationRequest();
    OAuth2AuthorizationResponse authorizationResponse =
            authCodeToken.getAuthorizationExchange().getAuthorizationResponse();

    // Line 61: Extract authorization code
    String code = authorizationResponse.getCode();
    String registrationId = authCodeToken.getClientRegistration().getRegistrationId();

    System.out.println("Registration ID: " + registrationId);
    System.out.println("Authorization Code: " + code);
    // ...
```

**What happens:**
- Keycloak redirects back with authorization code
- Spring Security calls your custom authentication manager
- You extract the authorization code

---

### Step 3: Exchange Authorization Code for Tokens

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 69-77
// Exchange authorization code for tokens using our custom service
return tokenExchangeService.exchangeCodeForTokens(
                code,
                authorizationRequest.getRedirectUri(),
                authCodeToken.getClientRegistration())
        .flatMap(tokenResponse -> {
            System.out.println("Building authenticated user from token response...");
            return buildAuthenticatedUser(tokenResponse, authCodeToken);
        })
        // ...
```

**What happens:**
- Calls `CustomOAuth2TokenExchangeService.exchangeCodeForTokens()`
- Exchanges code for access_token, id_token, refresh_token

---

### Step 4: Token Exchange Service Calls Keycloak

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2TokenExchangeService.java`

```java
// Lines 37-98
public Mono<OAuth2AccessTokenResponse> exchangeCodeForTokens(
        String code,
        String redirectUri,
        ClientRegistration clientRegistration) {

    System.out.println("========================================");
    System.out.println("CUSTOM TOKEN EXCHANGE STARTED");
    System.out.println("========================================");
    System.out.println("Authorization Code: " + code);
    System.out.println("Redirect URI: " + redirectUri);
    System.out.println("Client ID: " + clientRegistration.getClientId());
    System.out.println("Token URI: " + clientRegistration.getProviderDetails().getTokenUri());

    // Lines 50-56: Build token request
    MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
    formData.add("grant_type", "authorization_code");
    formData.add("code", code);
    formData.add("redirect_uri", redirectUri);
    formData.add("client_id", clientRegistration.getClientId());
    formData.add("client_secret", clientRegistration.getClientSecret());

    System.out.println("Sending token request to Keycloak...");

    // Lines 60-98: Send request to Keycloak
    return webClient
            .post()
            .uri(clientRegistration.getProviderDetails().getTokenUri())
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .bodyValue(formData)
            .retrieve()
            .bodyToMono(Map.class)
            .cast(Map.class)
            .doOnNext(response -> {
                @SuppressWarnings("unchecked")
                Map<String, Object> tokenMap = (Map<String, Object>) response;
                System.out.println("========================================");
                System.out.println("TOKEN EXCHANGE SUCCESSFUL");
                System.out.println("========================================");
                System.out.println("Access Token: " + maskToken((String) tokenMap.get("access_token")));
                System.out.println("ID Token: " + maskToken((String) tokenMap.get("id_token")));
                System.out.println("Refresh Token: " + maskToken((String) tokenMap.get("refresh_token")));
                // ...
            })
            .map(response -> {
                @SuppressWarnings("unchecked")
                Map<String, Object> tokenMap = (Map<String, Object>) response;
                return buildTokenResponse(tokenMap, clientRegistration);
            });
}
```

**What happens:**
- Builds HTTP POST request to Keycloak's token endpoint
- Sends authorization code, client_id, client_secret
- Receives access_token, id_token, refresh_token
- Logs the response

---

### Step 5: Build Authenticated User (Extract ID Token)

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 107-118
private Mono<Authentication> buildAuthenticatedUser(
        OAuth2AccessTokenResponse tokenResponse,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

    // Line 112: Extract ID token from response
    String idTokenValue = (String) tokenResponse.getAdditionalParameters().get(OidcParameterNames.ID_TOKEN);

    if (idTokenValue == null) {
        System.err.println("No ID token found in response");
        return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("missing_id_token", "ID token is required", null)));
    }

    // Line 121: Decode and validate ID token
    return decodeIdToken(idTokenValue, authCodeToken)
            .map(idToken -> {
                // Extract user attributes from ID token
                Map<String, Object> claims = idToken.getClaims();
                // ...
```

**What happens:**
- Extracts ID token from token response
- Calls `decodeIdToken()` to validate it

---

### Step 6: ⭐ TOKEN VALIDATION HAPPENS HERE

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 169-206
private Mono<OidcIdToken> decodeIdToken(
        String idTokenValue,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

    try {
        // Line 174-177: Get JWK Set URI from client registration
        String jwkSetUri = authCodeToken.getClientRegistration()
                .getProviderDetails()
                .getJwkSetUri();

        System.out.println("🔍 Decoding ID token using JWK Set URI: " + jwkSetUri);

        // Line 182: Create JWT decoder
        // This will download Keycloak's public keys from JWK Set endpoint
        JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();

        // ⭐⭐⭐ Line 185: THIS IS WHERE VALIDATION HAPPENS ⭐⭐⭐
        // This single line validates:
        // ✅ Signature (using Keycloak's public key)
        // ✅ Expiration (exp claim)
        // ✅ Issued At (iat claim)
        // ✅ Not Before (nbf claim)
        // ✅ Issuer (iss claim)
        Jwt jwt = jwtDecoder.decode(idTokenValue);

        // Lines 188-193: Convert JWT to OidcIdToken
        OidcIdToken idToken = new OidcIdToken(
                jwt.getTokenValue(),
                jwt.getIssuedAt(),
                jwt.getExpiresAt(),
                jwt.getClaims()
        );

        System.out.println("ID token decoded successfully");
        System.out.println("   Subject: " + jwt.getSubject());
        System.out.println("   Issued At: " + jwt.getIssuedAt());
        System.out.println("   Expires At: " + jwt.getExpiresAt());

        return Mono.just(idToken);

    } catch (Exception e) {
        System.err.println("Failed to decode ID token: " + e.getMessage());
        return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("invalid_id_token", "Failed to decode ID token", null), e));
    }
}
```

**What happens:**
1. **Line 174-177:** Gets JWK Set URI from configuration
   - Example: `http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs`

2. **Line 182:** Creates `NimbusJwtDecoder` with JWK Set URI
   - This will download Keycloak's public keys

3. **⭐ Line 185:** `jwtDecoder.decode(idTokenValue)` - **THIS IS THE KEY LINE**
   - Downloads public keys from Keycloak (if not cached)
   - Parses JWT header, payload, signature
   - Validates signature using public key
   - Validates expiration time (exp)
   - Validates issued at time (iat)
   - Validates not before time (nbf)
   - Validates issuer (iss)
   - Throws `JwtException` if any validation fails

4. **Lines 188-193:** Converts validated JWT to `OidcIdToken`

5. **Lines 195-198:** Logs success

6. **Lines 202-205:** Catches and handles validation errors

---

### Step 7: Extract Authorities from Token

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 209-253
private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
    Set<GrantedAuthority> authorities = new HashSet<>();

    // Lines 216-227: Extract realm roles from Keycloak
    Object realmAccessObj = claims.get("realm_access");
    if (realmAccessObj instanceof Map) {
        Map<String, Object> realmAccess = (Map<String, Object>) realmAccessObj;
        Object rolesObj = realmAccess.get("roles");
        if (rolesObj instanceof List) {
            List<String> roles = (List<String>) rolesObj;
            authorities.addAll(roles.stream()
                    .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                    .collect(Collectors.toSet()));
        }
    }

    // Lines 229-245: Extract resource/client roles from Keycloak
    Object resourceAccessObj = claims.get("resource_access");
    if (resourceAccessObj instanceof Map) {
        Map<String, Object> resourceAccess = (Map<String, Object>) resourceAccessObj;
        resourceAccess.forEach((client, access) -> {
            if (access instanceof Map) {
                Map<String, Object> clientAccess = (Map<String, Object>) access;
                Object rolesObj = clientAccess.get("roles");
                if (rolesObj instanceof List) {
                    List<String> roles = (List<String>) rolesObj;
                    authorities.addAll(roles.stream()
                            .map(role -> new SimpleGrantedAuthority("ROLE_" + client.toUpperCase() + "_" + role.toUpperCase()))
                            .collect(Collectors.toSet()));
                }
            }
        });
    }

    // Lines 247-250: Add default authority if none found
    if (authorities.isEmpty()) {
        authorities.add(new SimpleGrantedAuthority("ROLE_USER"));
    }

    return authorities;
}
```

**What happens:**
- Extracts roles from `realm_access.roles` claim
- Extracts roles from `resource_access.<client>.roles` claim
- Maps roles to Spring Security `GrantedAuthority`
- Adds default `ROLE_USER` if no roles found

---

### Step 8: Create Authenticated User

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 121-163 (continuation of buildAuthenticatedUser)
return decodeIdToken(idTokenValue, authCodeToken)
        .map(idToken -> {
            // Extract user attributes from ID token
            Map<String, Object> claims = idToken.getClaims();
            String username = (String) claims.get("preferred_username");
            String email = (String) claims.get("email");
            String name = (String) claims.get("name");

            System.out.println("User Details:");
            System.out.println("   Username: " + username);
            System.out.println("   Email: " + email);
            System.out.println("   Name: " + name);

            // Extract roles/authorities
            Set<GrantedAuthority> authorities = extractAuthorities(claims);
            System.out.println("   Authorities: " + authorities);

            // Line 139-143: Create OIDC user
            OidcUser oidcUser = new DefaultOidcUser(
                    authorities,
                    idToken,
                    "preferred_username" // Name attribute key
            );

            // Lines 147-154: Create OAuth2LoginAuthenticationToken
            OAuth2LoginAuthenticationToken authenticationToken = new OAuth2LoginAuthenticationToken(
                    authCodeToken.getClientRegistration(),
                    authCodeToken.getAuthorizationExchange(),
                    oidcUser,
                    authorities,
                    tokenResponse.getAccessToken(),
                    tokenResponse.getRefreshToken()
            );

            // You can add custom logic here:
            // - Store user in database
            // - Update last login time
            // - Sync user roles
            // - Log authentication event

            return authenticationToken;
        });
```

**What happens:**
- Extracts user details from validated ID token
- Creates `OidcUser` with authorities
- Creates `OAuth2LoginAuthenticationToken`
- Returns authenticated user

---

### Step 9: Authentication Success

**File:** `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`

```java
// Lines 78-84
.doOnNext(auth -> {
    System.out.println("========================================");
    System.out.println("AUTHENTICATION SUCCESSFUL");
    System.out.println("========================================");
    System.out.println("User: " + auth.getName());
    System.out.println("Authorities: " + auth.getAuthorities());
})
```

**What happens:**
- Logs successful authentication
- Spring Security stores authentication in SecurityContext
- User is redirected to success URL (configured in `SecurityConfig`)

---

## 🎯 The Key Line

**The single most important line for token validation:**

```java
// Line 185 in CustomOAuth2AuthenticationManager.java
Jwt jwt = jwtDecoder.decode(idTokenValue);
```

This line:
1. Downloads Keycloak's public keys from JWK Set (if not cached)
2. Parses the JWT (header, payload, signature)
3. Validates signature using public key ✅
4. Validates expiration (exp) ✅
5. Validates issued at (iat) ✅
6. Validates not before (nbf) ✅
7. Validates issuer (iss) ✅
8. Throws exception if any validation fails ❌

---

## 🔧 Where to Add Custom Validation

### Option 1: In buildAuthenticatedUser() (After Line 124)

```java
return decodeIdToken(idTokenValue, authCodeToken)
        .flatMap(idToken -> {  // Change .map to .flatMap
            Map<String, Object> claims = idToken.getClaims();
            
            // ⭐ ADD YOUR CUSTOM VALIDATION HERE
            Boolean emailVerified = (Boolean) claims.get("email_verified");
            if (emailVerified == null || !emailVerified) {
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("email_not_verified", "Email not verified", null)
                ));
            }
            
            // Continue with existing code
            String username = (String) claims.get("preferred_username");
            // ...
```

### Option 2: Create Custom JWT Decoder (New File)

```java
@Bean
public JwtDecoder customJwtDecoder() {
    String jwkSetUri = "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs";
    
    NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
    
    // ⭐ ADD CUSTOM VALIDATORS
    OAuth2TokenValidator<Jwt> validators = new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),
        new AudienceValidator("app-client"),
        new CustomClaimValidator()
    );
    
    decoder.setJwtValidator(validators);
    return decoder;
}
```

Then use it in `decodeIdToken()`:

```java
// Line 182: Instead of creating new decoder
JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();

// Use injected custom decoder
Jwt jwt = this.customJwtDecoder.decode(idTokenValue);
```

---

## 📊 Summary

| Step | File | Lines | What Happens |
|------|------|-------|--------------|
| 1 | SecurityConfig.java | 21-34 | Register custom auth manager |
| 2 | CustomOAuth2AuthenticationManager.java | 42-68 | Receive authorization code |
| 3 | CustomOAuth2AuthenticationManager.java | 69-77 | Call token exchange service |
| 4 | CustomOAuth2TokenExchangeService.java | 37-98 | Exchange code for tokens |
| 5 | CustomOAuth2AuthenticationManager.java | 107-118 | Extract ID token |
| 6 | CustomOAuth2AuthenticationManager.java | **169-206** | **⭐ VALIDATE TOKEN** |
| 7 | CustomOAuth2AuthenticationManager.java | 209-253 | Extract authorities |
| 8 | CustomOAuth2AuthenticationManager.java | 121-163 | Create authenticated user |
| 9 | CustomOAuth2AuthenticationManager.java | 78-84 | Authentication success |

**The key validation happens at Line 185:**
```java
Jwt jwt = jwtDecoder.decode(idTokenValue);
```

---

## 🚀 Next Steps

1. **Read the code** - Open `CustomOAuth2AuthenticationManager.java` and find line 185
2. **Add logging** - Add more logging around line 185 to see validation in action
3. **Add custom validation** - Add email verification check after line 124
4. **Test** - Run the app and watch the logs

---

**Now you know exactly where token validation happens! 🎉**

