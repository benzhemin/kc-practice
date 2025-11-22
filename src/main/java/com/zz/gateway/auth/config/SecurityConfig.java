package com.zz.gateway.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.security.web.server.authentication.RedirectServerAuthenticationSuccessHandler;
import org.springframework.security.web.server.authentication.logout.RedirectServerLogoutSuccessHandler;
import org.springframework.security.web.server.authentication.logout.ServerLogoutSuccessHandler;
import reactor.core.publisher.Mono;

import java.net.URI;

@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

  @Bean
  public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
    http
        .authorizeExchange(exchanges -> exchanges
            .pathMatchers("/actuator/**").permitAll() // Allow health checks
            .pathMatchers("/login/**", "/oauth2/**").permitAll() // Allow OAuth2 endpoints
            .anyExchange().authenticated() // All other requests require authentication
        )
        .oauth2Login(oauth2 -> oauth2
            // 1. AUTHENTICATION SUCCESS HANDLER
            // Called after successful OAuth2 login
            .authenticationSuccessHandler(
                new RedirectServerAuthenticationSuccessHandler("/")
            )
            
            // 2. AUTHENTICATION FAILURE HANDLER
            // Called when OAuth2 login fails
            .authenticationFailureHandler((exchange, exception) -> {
              System.err.println("OAuth2 login failed: " + exception.getMessage());
              return Mono.fromRunnable(() -> 
                  exchange.getExchange().getResponse().setStatusCode(
                      org.springframework.http.HttpStatus.UNAUTHORIZED
                  )
              );
            })
            
            // 3. CUSTOM AUTHORIZATION REQUEST CUSTOMIZER (Advanced)
            // Modify the OAuth2 authorization request before redirecting to Keycloak
            // .authorizationRequestResolver(customAuthorizationRequestResolver())
        )
        .logout(logout -> logout
            // Configure logout
            .logoutUrl("/logout")
            .logoutSuccessHandler(oidcLogoutSuccessHandler())
        )
        .csrf(ServerHttpSecurity.CsrfSpec::disable); // Disable CSRF for now (enable in production!)

    return http.build();
  }

  /**
   * Custom logout handler that redirects to Keycloak logout endpoint
   * This ensures the user is logged out from both the app AND Keycloak
   */
  @Bean
  public ServerLogoutSuccessHandler oidcLogoutSuccessHandler() {
    RedirectServerLogoutSuccessHandler handler = new RedirectServerLogoutSuccessHandler();
    // Redirect to Keycloak logout, then back to our app, it's due to keycloak session is on user's browser, so we need to redirect to logout from keycloak.
    handler.setLogoutSuccessUrl(URI.create(
        "http://localhost:3081/realms/dev-realm/protocol/openid-connect/logout?redirect_uri=http://localhost:8080"
    ));
    return handler;
  }
}