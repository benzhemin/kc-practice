package com.zz.gateway.auth.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import reactor.core.publisher.Mono;

@RestController
public class TestController {
  @GetMapping("/")
  public Mono<String> home() {
    return Mono.just("Hello, World! You are authenticated!");
  }

  /**
   * Get current authenticated user information
   * This demonstrates how to access the user after custom authentication
   */
  @GetMapping("/user")
  public Mono<Map<String, Object>> user(@AuthenticationPrincipal OidcUser principal) {
    Map<String, Object> user = new HashMap<>();
    user.put("name", principal.getName());
    user.put("email", principal.getEmail());
    user.put("sub", principal.getSubject());
    user.put("claims", principal.getClaims());
    user.put("roles", principal.getAuthorities());
    return Mono.just(user);
  }

  /**
   * Protected API endpoint - requires authentication
   * This will trigger the custom OAuth2 flow if user is not authenticated
   */
  @GetMapping("/api/users")
  public Mono<Map<String, Object>> getUsers(@AuthenticationPrincipal OidcUser principal) {
    Map<String, Object> response = new HashMap<>();
    response.put("message", "This is a protected endpoint");
    response.put("authenticated_user", principal.getName());
    response.put("user_roles", principal.getAuthorities());
    return Mono.just(response);
  }
} 
