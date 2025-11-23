# Token Validation Customization Examples

This file contains practical examples of how to customize token validation in your Spring Security application.

## Example 1: Custom JWT Decoder with Audience Validation

Create a custom JWT decoder that validates the audience claim:

```java
package com.zz.gateway.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.*;

@Configuration
public class JwtDecoderConfig {

    @Bean
    public JwtDecoder jwtDecoder() {
        String jwkSetUri = "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/certs";
        
        NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
        
        // Add custom validators
        OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator("app-client");
        OAuth2TokenValidator<Jwt> customClaimValidator = new CustomClaimValidator();
        
        OAuth2TokenValidator<Jwt> validators = new DelegatingOAuth2TokenValidator<>(
            JwtValidators.createDefault(),
            audienceValidator,
            customClaimValidator
        );
        
        jwtDecoder.setJwtValidator(validators);
        
        return jwtDecoder;
    }
}

// Audience Validator
class AudienceValidator implements OAuth2TokenValidator<Jwt> {
    private final String audience;
    
    public AudienceValidator(String audience) {
        this.audience = audience;
    }
    
    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        if (jwt.getAudience().contains(audience)) {
            return OAuth2TokenValidatorResult.success();
        }
        
        OAuth2Error error = new OAuth2Error(
            "invalid_token",
            "Token does not contain required audience: " + audience,
            null
        );
        return OAuth2TokenValidatorResult.failure(error);
    }
}

// Custom Claim Validator
class CustomClaimValidator implements OAuth2TokenValidator<Jwt> {
    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        // Validate email is verified
        Boolean emailVerified = jwt.getClaim("email_verified");
        if (emailVerified == null || !emailVerified) {
            OAuth2Error error = new OAuth2Error(
                "invalid_token",
                "Email must be verified",
                null
            );
            return OAuth2TokenValidatorResult.failure(error);
        }
        
        // Validate organization claim
        String organization = jwt.getClaim("organization");
        if (organization == null || !organization.equals("my-company")) {
            OAuth2Error error = new OAuth2Error(
                "invalid_token",
                "User not from allowed organization",
                null
            );
            return OAuth2TokenValidatorResult.failure(error);
        }
        
        return OAuth2TokenValidatorResult.success();
    }
}
```

## Example 2: Token Introspection Service

Validate tokens with Keycloak's introspection endpoint:

```java
package com.zz.gateway.auth.oauth2;

import org.springframework.http.MediaType;
import org.springframework.security.oauth2.client.registration.ClientRegistration;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;

@Service
public class TokenIntrospectionService {
    
    private final WebClient webClient;
    
    public TokenIntrospectionService(WebClient webClient) {
        this.webClient = webClient;
    }
    
    /**
     * Introspect token with Keycloak to check if it's still valid
     * This is useful for:
     * - Checking if token has been revoked
     * - Validating tokens on each request (stateless)
     * - Getting additional token metadata
     */
    public Mono<TokenIntrospectionResult> introspectToken(
            String token, 
            ClientRegistration clientRegistration) {
        
        String introspectionUri = clientRegistration.getProviderDetails().getIssuerUri() 
            + "/protocol/openid-connect/token/introspect";
        
        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("token", token);
        formData.add("client_id", clientRegistration.getClientId());
        formData.add("client_secret", clientRegistration.getClientSecret());
        
        System.out.println("Introspecting token with Keycloak...");
        
        return webClient.post()
            .uri(introspectionUri)
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .bodyValue(formData)
            .retrieve()
            .bodyToMono(Map.class)
            .map(response -> {
                @SuppressWarnings("unchecked")
                Map<String, Object> responseMap = (Map<String, Object>) response;
                
                Boolean active = (Boolean) responseMap.get("active");
                String username = (String) responseMap.get("username");
                String scope = (String) responseMap.get("scope");
                Long exp = responseMap.get("exp") != null 
                    ? ((Number) responseMap.get("exp")).longValue() 
                    : null;
                
                System.out.println("Token introspection result:");
                System.out.println("  Active: " + active);
                System.out.println("  Username: " + username);
                System.out.println("  Scope: " + scope);
                System.out.println("  Expires: " + exp);
                
                return new TokenIntrospectionResult(active, username, scope, exp, responseMap);
            })
            .doOnError(error -> {
                System.err.println("Token introspection failed: " + error.getMessage());
            });
    }
    
    public static class TokenIntrospectionResult {
        private final Boolean active;
        private final String username;
        private final String scope;
        private final Long exp;
        private final Map<String, Object> allClaims;
        
        public TokenIntrospectionResult(Boolean active, String username, String scope, 
                                       Long exp, Map<String, Object> allClaims) {
            this.active = active;
            this.username = username;
            this.scope = scope;
            this.exp = exp;
            this.allClaims = allClaims;
        }
        
        public Boolean isActive() { return active; }
        public String getUsername() { return username; }
        public String getScope() { return scope; }
        public Long getExp() { return exp; }
        public Map<String, Object> getAllClaims() { return allClaims; }
    }
}
```

## Example 3: Database User Validation and Sync

Validate and sync users with your database:

```java
package com.zz.gateway.auth.service;

import org.springframework.security.oauth2.core.oidc.OidcIdToken;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Mono;

import java.time.Instant;

@Service
public class UserValidationService {
    
    private final UserRepository userRepository;
    
    public UserValidationService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    /**
     * Validate user exists in database and sync information
     * This is called during authentication to:
     * - Create new users on first login
     * - Update existing user information
     * - Track last login time
     * - Sync roles from Keycloak
     */
    public Mono<User> validateAndSyncUser(OidcIdToken idToken) {
        String keycloakId = idToken.getSubject();
        String email = idToken.getEmail();
        String username = idToken.getPreferredUsername();
        String name = idToken.getFullName();
        
        System.out.println("Validating and syncing user: " + username);
        
        return userRepository.findByKeycloakId(keycloakId)
            .switchIfEmpty(
                // User doesn't exist, create new user
                Mono.defer(() -> {
                    System.out.println("Creating new user: " + username);
                    
                    User newUser = new User();
                    newUser.setKeycloakId(keycloakId);
                    newUser.setEmail(email);
                    newUser.setUsername(username);
                    newUser.setName(name);
                    newUser.setCreatedAt(Instant.now());
                    newUser.setEnabled(true);
                    
                    return userRepository.save(newUser);
                })
            )
            .flatMap(user -> {
                // Update user information
                System.out.println("Updating user information: " + username);
                
                user.setEmail(email);
                user.setUsername(username);
                user.setName(name);
                user.setLastLoginAt(Instant.now());
                
                return userRepository.save(user);
            })
            .doOnNext(user -> {
                System.out.println("User validated and synced successfully: " + user.getUsername());
            })
            .doOnError(error -> {
                System.err.println("Failed to validate/sync user: " + error.getMessage());
            });
    }
    
    /**
     * Check if user is allowed to authenticate
     * This can be used to:
     * - Block disabled users
     * - Enforce organization membership
     * - Check subscription status
     */
    public Mono<Boolean> isUserAllowed(User user) {
        if (!user.isEnabled()) {
            System.err.println("User is disabled: " + user.getUsername());
            return Mono.just(false);
        }
        
        // Add more checks here
        // - Check subscription status
        // - Check organization membership
        // - Check IP whitelist
        
        return Mono.just(true);
    }
}

// User Entity (example)
class User {
    private Long id;
    private String keycloakId;
    private String username;
    private String email;
    private String name;
    private boolean enabled;
    private Instant createdAt;
    private Instant lastLoginAt;
    
    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getKeycloakId() { return keycloakId; }
    public void setKeycloakId(String keycloakId) { this.keycloakId = keycloakId; }
    
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }
    
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    
    public Instant getLastLoginAt() { return lastLoginAt; }
    public void setLastLoginAt(Instant lastLoginAt) { this.lastLoginAt = lastLoginAt; }
}

// User Repository (example)
interface UserRepository {
    Mono<User> findByKeycloakId(String keycloakId);
    Mono<User> save(User user);
}
```

## Example 4: Enhanced Authentication Manager with All Customizations

Integrate all customizations into your authentication manager:

```java
package com.zz.gateway.auth.oauth2;

import com.zz.gateway.auth.service.UserValidationService;
import org.springframework.security.authentication.ReactiveAuthenticationManager;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.client.authentication.OAuth2AuthorizationCodeAuthenticationToken;
import org.springframework.security.oauth2.client.authentication.OAuth2LoginAuthenticationToken;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.oidc.OidcIdToken;
import org.springframework.security.oauth2.core.oidc.user.DefaultOidcUser;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.Set;

@Component
public class EnhancedOAuth2AuthenticationManager implements ReactiveAuthenticationManager {

    private final CustomOAuth2TokenExchangeService tokenExchangeService;
    private final TokenIntrospectionService introspectionService;
    private final UserValidationService userValidationService;
    private final JwtDecoder jwtDecoder;

    public EnhancedOAuth2AuthenticationManager(
            CustomOAuth2TokenExchangeService tokenExchangeService,
            TokenIntrospectionService introspectionService,
            UserValidationService userValidationService,
            JwtDecoder jwtDecoder) {
        this.tokenExchangeService = tokenExchangeService;
        this.introspectionService = introspectionService;
        this.userValidationService = userValidationService;
        this.jwtDecoder = jwtDecoder;
    }

    @Override
    public Mono<Authentication> authenticate(Authentication authentication) {
        if (!(authentication instanceof OAuth2AuthorizationCodeAuthenticationToken)) {
            return Mono.just(authentication);
        }

        OAuth2AuthorizationCodeAuthenticationToken authCodeToken =
                (OAuth2AuthorizationCodeAuthenticationToken) authentication;

        // Step 1: Exchange code for tokens
        return tokenExchangeService.exchangeCodeForTokens(
                        authCodeToken.getAuthorizationExchange().getAuthorizationResponse().getCode(),
                        authCodeToken.getAuthorizationExchange().getAuthorizationRequest().getRedirectUri(),
                        authCodeToken.getClientRegistration())
                
                // Step 2: Validate and decode ID token
                .flatMap(tokenResponse -> {
                    String idTokenValue = (String) tokenResponse.getAdditionalParameters().get("id_token");
                    return validateAndDecodeToken(idTokenValue, authCodeToken)
                        .map(idToken -> Map.entry(idToken, tokenResponse));
                })
                
                // Step 3: Validate custom claims
                .flatMap(entry -> {
                    OidcIdToken idToken = entry.getKey();
                    return validateCustomClaims(idToken)
                        .thenReturn(entry);
                })
                
                // Step 4: Validate and sync user in database
                .flatMap(entry -> {
                    OidcIdToken idToken = entry.getKey();
                    return userValidationService.validateAndSyncUser(idToken)
                        .flatMap(user -> userValidationService.isUserAllowed(user)
                            .flatMap(allowed -> {
                                if (!allowed) {
                                    return Mono.error(new OAuth2AuthenticationException(
                                        new OAuth2Error("user_not_allowed", "User is not allowed to authenticate", null)
                                    ));
                                }
                                return Mono.just(entry);
                            })
                        );
                })
                
                // Step 5: Build authenticated user
                .map(entry -> {
                    OidcIdToken idToken = entry.getKey();
                    var tokenResponse = entry.getValue();
                    
                    Set<GrantedAuthority> authorities = extractAuthorities(idToken.getClaims());
                    OidcUser oidcUser = new DefaultOidcUser(authorities, idToken, "preferred_username");
                    
                    return new OAuth2LoginAuthenticationToken(
                        authCodeToken.getClientRegistration(),
                        authCodeToken.getAuthorizationExchange(),
                        oidcUser,
                        authorities,
                        tokenResponse.getAccessToken(),
                        tokenResponse.getRefreshToken()
                    );
                })
                
                // Step 6: Optional - Introspect token for additional validation
                .flatMap(authToken -> {
                    String accessToken = authToken.getAccessToken().getTokenValue();
                    return introspectionService.introspectToken(accessToken, authCodeToken.getClientRegistration())
                        .flatMap(result -> {
                            if (!result.isActive()) {
                                return Mono.error(new OAuth2AuthenticationException(
                                    new OAuth2Error("invalid_token", "Token is not active", null)
                                ));
                            }
                            return Mono.just(authToken);
                        });
                })
                
                .doOnNext(auth -> {
                    System.out.println("✅ Authentication successful: " + auth.getName());
                })
                .doOnError(error -> {
                    System.err.println("❌ Authentication failed: " + error.getMessage());
                });
    }
    
    private Mono<OidcIdToken> validateAndDecodeToken(String idTokenValue, OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {
        // Use custom JWT decoder with validators
        return Mono.fromCallable(() -> jwtDecoder.decode(idTokenValue))
            .map(jwt -> new OidcIdToken(
                jwt.getTokenValue(),
                jwt.getIssuedAt(),
                jwt.getExpiresAt(),
                jwt.getClaims()
            ))
            .onErrorMap(e -> new OAuth2AuthenticationException(
                new OAuth2Error("invalid_id_token", "Failed to validate ID token", null), e
            ));
    }
    
    private Mono<Void> validateCustomClaims(OidcIdToken idToken) {
        // Add your custom validation logic here
        Boolean emailVerified = idToken.getClaim("email_verified");
        if (emailVerified == null || !emailVerified) {
            return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("email_not_verified", "Email must be verified", null)
            ));
        }
        
        return Mono.empty();
    }
    
    private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
        // Your existing authority extraction logic
        return Set.of();
    }
}
```

## Example 5: Stateless JWT Validation on Each Request

Configure resource server to validate JWT on each request:

```java
package com.zz.gateway.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.server.SecurityWebFilterChain;

@Configuration
@EnableWebFluxSecurity
public class ResourceServerConfig {

    /**
     * This configuration validates JWT on EVERY request (stateless)
     * Use this if you want to:
     * - Not use sessions
     * - Validate token freshness on each request
     * - Support token revocation
     */
    @Bean
    public SecurityWebFilterChain resourceServerSecurityChain(
            ServerHttpSecurity http,
            JwtDecoder jwtDecoder) {
        
        http
            .authorizeExchange(exchanges -> exchanges
                .pathMatchers("/actuator/**").permitAll()
                .pathMatchers("/public/**").permitAll()
                .anyExchange().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtDecoder(jwtDecoder) // Use custom JWT decoder with validators
                    .jwtAuthenticationConverter(jwtAuthenticationConverter()) // Convert JWT to Authentication
                )
            )
            .csrf(ServerHttpSecurity.CsrfSpec::disable);
        
        return http.build();
    }
    
    /**
     * Convert JWT to Authentication with custom authorities
     */
    private Converter<Jwt, Mono<AbstractAuthenticationToken>> jwtAuthenticationConverter() {
        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        
        // Custom authority converter
        converter.setJwtGrantedAuthoritiesConverter(jwt -> {
            Set<GrantedAuthority> authorities = new HashSet<>();
            
            // Extract realm roles
            Map<String, Object> realmAccess = jwt.getClaim("realm_access");
            if (realmAccess != null && realmAccess.get("roles") instanceof List) {
                List<String> roles = (List<String>) realmAccess.get("roles");
                roles.forEach(role -> 
                    authorities.add(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                );
            }
            
            return authorities;
        });
        
        return new ReactiveJwtAuthenticationConverterAdapter(converter);
    }
}
```

---

## Usage Guide

### To Use Custom JWT Decoder:
1. Create `JwtDecoderConfig.java` with custom validators
2. Inject `JwtDecoder` into your authentication manager
3. Use it in `decodeIdToken()` method

### To Use Token Introspection:
1. Create `TokenIntrospectionService.java`
2. Inject it into your authentication manager
3. Call `introspectToken()` after building authenticated user

### To Use Database User Sync:
1. Create `UserValidationService.java` and `UserRepository`
2. Inject it into your authentication manager
3. Call `validateAndSyncUser()` during authentication

### To Use Stateless JWT Validation:
1. Create `ResourceServerConfig.java`
2. Configure `oauth2ResourceServer()` with custom JWT decoder
3. Clients must send JWT in `Authorization: Bearer <token>` header

---

## Testing

Test your customizations:

```bash
# Test authentication flow
curl -v http://localhost:8080/

# Test with invalid token
curl -H "Authorization: Bearer invalid_token" http://localhost:8080/api/protected

# Test token introspection
curl -X POST http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token/introspect \
  -d "token=<your_token>" \
  -d "client_id=app-client" \
  -d "client_secret=<your_secret>"
```

