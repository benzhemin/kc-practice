package com.zz.gateway.auth.oauth2;

import org.springframework.security.authentication.ReactiveAuthenticationManager;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.client.authentication.OAuth2AuthorizationCodeAuthenticationToken;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.endpoint.OAuth2AccessTokenResponse;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest;
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationResponse;
import org.springframework.security.oauth2.core.oidc.OidcIdToken;
import org.springframework.security.oauth2.core.oidc.endpoint.OidcParameterNames;
import org.springframework.security.oauth2.core.oidc.user.DefaultOidcUser;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.client.authentication.OAuth2LoginAuthenticationToken;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Custom Authentication Manager that intercepts OAuth2 authorization code authentication.
 * This gives you full control over the authentication process.
 */
@Component
public class CustomOAuth2AuthenticationManager implements ReactiveAuthenticationManager {

    private final CustomOAuth2TokenExchangeService tokenExchangeService;

    public CustomOAuth2AuthenticationManager(
            CustomOAuth2TokenExchangeService tokenExchangeService) {
        this.tokenExchangeService = tokenExchangeService;
    }

    @Override
    public Mono<Authentication> authenticate(Authentication authentication) {
        System.out.println("========================================");
        System.out.println("CUSTOM AUTHENTICATION MANAGER INVOKED");
        System.out.println("========================================");

        // Only handle OAuth2 authorization code authentication
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

        String code = authorizationResponse.getCode();
        String registrationId = authCodeToken.getClientRegistration().getRegistrationId();

        System.out.println("Registration ID: " + registrationId);
        System.out.println("Authorization Code: " + code);
        System.out.println("Redirect URI: " + authorizationRequest.getRedirectUri());
        System.out.println("State: " + authorizationRequest.getState());

        // Exchange authorization code for tokens using our custom service
        return tokenExchangeService.exchangeCodeForTokens(
                        code,
                        authorizationRequest.getRedirectUri(),
                        authCodeToken.getClientRegistration())
                .flatMap(tokenResponse -> {
                    System.out.println("Building authenticated user from token response...");
                    return buildAuthenticatedUser(tokenResponse, authCodeToken);
                })
                .doOnNext(auth -> {
                    System.out.println("========================================");
                    System.out.println("AUTHENTICATION SUCCESSFUL");
                    System.out.println("========================================");
                    System.out.println("User: " + auth.getName());
                    System.out.println("Authorities: " + auth.getAuthorities());
                })
                .doOnError(error -> {
                    System.err.println("========================================");
                    System.err.println("AUTHENTICATION FAILED");
                    System.err.println("========================================");
                    System.err.println("Error: " + error.getMessage());
                })
                .onErrorMap(throwable -> {
                    if (throwable instanceof OAuth2AuthenticationException) {
                        return throwable;
                    }
                    OAuth2Error oauth2Error = new OAuth2Error(
                            "authentication_failure",
                            "Failed to authenticate: " + throwable.getMessage(),
                            null
                    );
                    return new OAuth2AuthenticationException(oauth2Error, throwable);
                });
    }

    /**
     * Build the authenticated user from the token response
     */
    private Mono<Authentication> buildAuthenticatedUser(
            OAuth2AccessTokenResponse tokenResponse,
            OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

        // Extract ID token (for OIDC)
        String idTokenValue = (String) tokenResponse.getAdditionalParameters().get(OidcParameterNames.ID_TOKEN);

        if (idTokenValue == null) {
            System.err.println("No ID token found in response");
            return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error("missing_id_token", "ID token is required", null)));
        }

        // Decode the ID token to get user information
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

                    // Create OIDC user
                    OidcUser oidcUser = new DefaultOidcUser(
                            authorities,
                            idToken,
                            "preferred_username" // Name attribute key
                    );

                    // Create OAuth2LoginAuthenticationToken (not OAuth2AuthenticationToken)
                    // This is what Spring Security's OAuth2LoginAuthenticationWebFilter expects
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
    }

    /**
     * Decode and validate the ID token
     */
    private Mono<OidcIdToken> decodeIdToken(
            String idTokenValue,
            OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

        try {
            // Get JWK Set URI from client registration
            String jwkSetUri = authCodeToken.getClientRegistration()
                    .getProviderDetails()
                    .getJwkSetUri();

            System.out.println("🔍 Decoding ID token using JWK Set URI: " + jwkSetUri);

            // Create JWT decoder
            JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();

            // Decode the JWT
            Jwt jwt = jwtDecoder.decode(idTokenValue);

            // Convert to OidcIdToken
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

    /**
     * Extract authorities (roles) from ID token claims
     */
    @SuppressWarnings("unchecked")
    private Set<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
        Set<GrantedAuthority> authorities = new HashSet<>();

        // Extract realm roles from Keycloak
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

        // Extract resource/client roles from Keycloak
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

        // Add default authority if none found
        if (authorities.isEmpty()) {
            authorities.add(new SimpleGrantedAuthority("ROLE_USER"));
        }

        return authorities;
    }
}

