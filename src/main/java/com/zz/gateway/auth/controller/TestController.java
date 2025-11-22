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
    return Mono.just("Hello, World!");
  }

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
} 
