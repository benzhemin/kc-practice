package com.zz.gateway.auth.oauth2;

import org.springframework.http.MediaType;
import org.springframework.security.oauth2.client.registration.ClientRegistration;
import org.springframework.security.oauth2.core.OAuth2AccessToken;
import org.springframework.security.oauth2.core.endpoint.OAuth2AccessTokenResponse;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;
import java.util.Set;

/**
 * Custom service to handle OAuth2 token exchange.
 * This gives you full control over the token exchange process.
 */
@Service
public class CustomOAuth2TokenExchangeService {

    private final WebClient webClient;

    public CustomOAuth2TokenExchangeService(WebClient webClient) {
        this.webClient = webClient;
    }

    /**
     * Exchange authorization code for tokens
     * 
     * @param code The authorization code from Keycloak
     * @param redirectUri The redirect URI used in the authorization request
     * @param clientRegistration The OAuth2 client registration
     * @return OAuth2AccessTokenResponse containing access_token, id_token, refresh_token
     */
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

        // Build the token request parameters
        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("grant_type", "authorization_code");
        formData.add("code", code);
        formData.add("redirect_uri", redirectUri);
        formData.add("client_id", clientRegistration.getClientId());
        formData.add("client_secret", clientRegistration.getClientSecret());

        System.out.println("Sending token request to Keycloak...");

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
                    System.out.println(" Expires In: " + tokenMap.get("expires_in") + " seconds");
                    System.out.println("Token Type: " + tokenMap.get("token_type"));
                    System.out.println("Scope: " + tokenMap.get("scope"));
                    
                    // You can add custom logic here:
                    // - Store tokens in database
                    // - Log to external system
                    // - Validate tokens
                    // - Add custom claims
                })
                .doOnError(error -> {
                    System.err.println("========================================");
                    System.err.println("TOKEN EXCHANGE FAILED");
                    System.err.println("========================================");
                    System.err.println("Error: " + error.getMessage());
                    error.printStackTrace();
                })
                .map(response -> {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> tokenMap = (Map<String, Object>) response;
                    return buildTokenResponse(tokenMap, clientRegistration);
                });
    }

    /**
     * Build OAuth2AccessTokenResponse from the token endpoint response
     */
    private OAuth2AccessTokenResponse buildTokenResponse(
            Map<String, Object> tokenResponse,
            ClientRegistration clientRegistration) {

        String accessToken = (String) tokenResponse.get("access_token");
        long expiresIn = ((Number) tokenResponse.get("expires_in")).longValue();
        String refreshToken = (String) tokenResponse.get("refresh_token");
        String scope = (String) tokenResponse.get("scope");

        Set<String> scopes = Set.of(scope != null ? scope.split(" ") : new String[0]);

        OAuth2AccessTokenResponse.Builder builder = OAuth2AccessTokenResponse
                .withToken(accessToken)
                .tokenType(OAuth2AccessToken.TokenType.BEARER)
                .expiresIn(expiresIn)
                .scopes(scopes);

        if (refreshToken != null) {
            builder.refreshToken(refreshToken);
        }

        // Add ID token as additional parameter (important for OIDC)
        if (tokenResponse.containsKey("id_token")) {
            builder.additionalParameters(Map.of("id_token", tokenResponse.get("id_token")));
        }

        return builder.build();
    }

    /**
     * Mask token for logging (show first and last 10 characters)
     */
    private String maskToken(String token) {
        if (token == null || token.length() < 20) {
            return "***";
        }
        return token.substring(0, 10) + "..." + token.substring(token.length() - 10);
    }

    /**
     * Optional: Custom method to add extra parameters to token request
     * For example, you might want to add custom claims or parameters
     */
    public Mono<OAuth2AccessTokenResponse> exchangeCodeForTokensWithCustomParams(
            String code,
            String redirectUri,
            ClientRegistration clientRegistration,
            Map<String, String> customParams) {

        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("grant_type", "authorization_code");
        formData.add("code", code);
        formData.add("redirect_uri", redirectUri);
        formData.add("client_id", clientRegistration.getClientId());
        formData.add("client_secret", clientRegistration.getClientSecret());

        // Add custom parameters
        customParams.forEach(formData::add);

        System.out.println("🔧 Custom parameters added: " + customParams);

        return webClient
                .post()
                .uri(clientRegistration.getProviderDetails().getTokenUri())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .bodyValue(formData)
                .retrieve()
                .bodyToMono(Map.class)
                .cast(Map.class)
                .map(response -> {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> tokenMap = (Map<String, Object>) response;
                    return buildTokenResponse(tokenMap, clientRegistration);
                });
    }
}

