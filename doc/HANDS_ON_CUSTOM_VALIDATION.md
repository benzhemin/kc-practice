# Hands-On: Implementing Custom Token Validation

This guide shows you how to implement custom token validation step-by-step.

---

## 🎯 Goal

Add custom validation to your authentication flow to:
1. Validate email is verified
2. Validate user belongs to allowed organization
3. Sync user with database
4. Add custom error messages

---

## 📝 Step 1: Add Email Verification Check

### Edit: `CustomOAuth2AuthenticationManager.java`

Find the `buildAuthenticatedUser()` method and add validation:

```java
private Mono<Authentication> buildAuthenticatedUser(
        OAuth2AccessTokenResponse tokenResponse,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

    String idTokenValue = (String) tokenResponse.getAdditionalParameters().get(OidcParameterNames.ID_TOKEN);

    if (idTokenValue == null) {
        System.err.println("No ID token found in response");
        return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("missing_id_token", "ID token is required", null)));
    }

    return decodeIdToken(idTokenValue, authCodeToken)
            .flatMap(idToken -> {
                Map<String, Object> claims = idToken.getClaims();
                
                // ⭐ ADD THIS: Validate email is verified
                Boolean emailVerified = (Boolean) claims.get("email_verified");
                if (emailVerified == null || !emailVerified) {
                    System.err.println("❌ Email not verified for user: " + claims.get("email"));
                    return Mono.error(new OAuth2AuthenticationException(
                        new OAuth2Error(
                            "email_not_verified",
                            "Please verify your email address before logging in",
                            null
                        )
                    ));
                }
                System.out.println("✅ Email verified: " + claims.get("email"));
                
                // Continue with existing code
                String username = (String) claims.get("preferred_username");
                String email = (String) claims.get("email");
                String name = (String) claims.get("name");

                System.out.println("User Details:");
                System.out.println("   Username: " + username);
                System.out.println("   Email: " + email);
                System.out.println("   Name: " + name);

                Set<GrantedAuthority> authorities = extractAuthorities(claims);
                System.out.println("   Authorities: " + authorities);

                OidcUser oidcUser = new DefaultOidcUser(
                        authorities,
                        idToken,
                        "preferred_username"
                );

                OAuth2LoginAuthenticationToken authenticationToken = new OAuth2LoginAuthenticationToken(
                        authCodeToken.getClientRegistration(),
                        authCodeToken.getAuthorizationExchange(),
                        oidcUser,
                        authorities,
                        tokenResponse.getAccessToken(),
                        tokenResponse.getRefreshToken()
                );

                return Mono.just(authenticationToken);
            });
}
```

### Test It

1. Build and run:
```bash
./gradlew bootRun
```

2. Try to login with a user that has unverified email
3. You should see the error message: "Please verify your email address before logging in"

---

## 📝 Step 2: Add Organization Validation

### Edit: `CustomOAuth2AuthenticationManager.java`

Add organization validation after email verification:

```java
private Mono<Authentication> buildAuthenticatedUser(
        OAuth2AccessTokenResponse tokenResponse,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

    String idTokenValue = (String) tokenResponse.getAdditionalParameters().get(OidcParameterNames.ID_TOKEN);

    if (idTokenValue == null) {
        return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("missing_id_token", "ID token is required", null)));
    }

    return decodeIdToken(idTokenValue, authCodeToken)
            .flatMap(idToken -> {
                Map<String, Object> claims = idToken.getClaims();
                
                // Validate email is verified
                Boolean emailVerified = (Boolean) claims.get("email_verified");
                if (emailVerified == null || !emailVerified) {
                    System.err.println("❌ Email not verified for user: " + claims.get("email"));
                    return Mono.error(new OAuth2AuthenticationException(
                        new OAuth2Error(
                            "email_not_verified",
                            "Please verify your email address before logging in",
                            null
                        )
                    ));
                }
                System.out.println("✅ Email verified: " + claims.get("email"));
                
                // ⭐ ADD THIS: Validate organization
                String organization = (String) claims.get("organization");
                List<String> allowedOrganizations = List.of("my-company", "partner-company");
                
                if (organization == null || !allowedOrganizations.contains(organization)) {
                    System.err.println("❌ Invalid organization: " + organization);
                    return Mono.error(new OAuth2AuthenticationException(
                        new OAuth2Error(
                            "invalid_organization",
                            "Your organization is not allowed to access this application",
                            null
                        )
                    ));
                }
                System.out.println("✅ Organization validated: " + organization);
                
                // Continue with existing code
                String username = (String) claims.get("preferred_username");
                String email = (String) claims.get("email");
                String name = (String) claims.get("name");

                System.out.println("User Details:");
                System.out.println("   Username: " + username);
                System.out.println("   Email: " + email);
                System.out.println("   Name: " + name);
                System.out.println("   Organization: " + organization);

                Set<GrantedAuthority> authorities = extractAuthorities(claims);
                System.out.println("   Authorities: " + authorities);

                OidcUser oidcUser = new DefaultOidcUser(
                        authorities,
                        idToken,
                        "preferred_username"
                );

                OAuth2LoginAuthenticationToken authenticationToken = new OAuth2LoginAuthenticationToken(
                        authCodeToken.getClientRegistration(),
                        authCodeToken.getAuthorizationExchange(),
                        oidcUser,
                        authorities,
                        tokenResponse.getAccessToken(),
                        tokenResponse.getRefreshToken()
                );

                return Mono.just(authenticationToken);
            });
}
```

### Configure Organization Claim in Keycloak

1. Go to Keycloak Admin Console: http://keycloak.local:3081
2. Select your realm: `dev-realm`
3. Go to **Client Scopes** → **profile**
4. Go to **Mappers** tab
5. Click **Add mapper** → **By configuration** → **User Attribute**
6. Configure:
   - Name: `organization`
   - User Attribute: `organization`
   - Token Claim Name: `organization`
   - Claim JSON Type: `String`
   - Add to ID token: `ON`
   - Add to access token: `ON`
   - Add to userinfo: `ON`
7. Click **Save**

8. Add organization attribute to a user:
   - Go to **Users** → Select a user
   - Go to **Attributes** tab
   - Add attribute:
     - Key: `organization`
     - Value: `my-company`
   - Click **Save**

### Test It

1. Restart your app
2. Try to login with a user that has `organization = "my-company"` → Should succeed
3. Try to login with a user without organization attribute → Should fail

---

## 📝 Step 3: Add Better Error Handling

### Edit: `SecurityConfig.java`

Update the authentication failure handler:

```java
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
            .authenticationManager(customAuthenticationManager)
            .authenticationSuccessHandler(
                new RedirectServerAuthenticationSuccessHandler("/")
            )
            // ⭐ UPDATE THIS: Better error handling
            .authenticationFailureHandler((exchange, exception) -> {
                System.err.println("========================================");
                System.err.println("OAUTH2 LOGIN FAILED");
                System.err.println("========================================");
                System.err.println("Error: " + exception.getMessage());
                
                // Get the OAuth2 error
                String errorCode = "authentication_failed";
                String errorMessage = "Authentication failed";
                
                if (exception instanceof OAuth2AuthenticationException) {
                    OAuth2AuthenticationException oauth2Exception = 
                        (OAuth2AuthenticationException) exception;
                    errorCode = oauth2Exception.getError().getErrorCode();
                    errorMessage = oauth2Exception.getError().getDescription();
                }
                
                System.err.println("Error Code: " + errorCode);
                System.err.println("Error Message: " + errorMessage);
                
                // Redirect to error page with error details
                String redirectUrl = String.format(
                    "/login?error=true&error_code=%s&error_message=%s",
                    errorCode,
                    java.net.URLEncoder.encode(errorMessage, java.nio.charset.StandardCharsets.UTF_8)
                );
                
                return exchange.getExchange().getResponse()
                    .setComplete()
                    .then(Mono.fromRunnable(() -> {
                        exchange.getExchange().getResponse().setStatusCode(
                            org.springframework.http.HttpStatus.FOUND
                        );
                        exchange.getExchange().getResponse().getHeaders()
                            .setLocation(java.net.URI.create(redirectUrl));
                    }));
            })
        )
        .logout(logout -> logout
            .logoutUrl("/logout")
            .logoutSuccessHandler(oidcLogoutSuccessHandler())
        )
        .csrf(ServerHttpSecurity.CsrfSpec::disable);

    return http.build();
}
```

### Create Error Page

Create `src/main/resources/static/error.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Login Error</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .error-box {
            background-color: #fff;
            border-left: 4px solid #d32f2f;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #d32f2f;
            margin-top: 0;
        }
        .error-code {
            font-family: monospace;
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .back-link {
            display: inline-block;
            margin-top: 20px;
            padding: 10px 20px;
            background-color: #1976d2;
            color: white;
            text-decoration: none;
            border-radius: 4px;
        }
        .back-link:hover {
            background-color: #1565c0;
        }
    </style>
</head>
<body>
    <div class="error-box">
        <h1>Authentication Failed</h1>
        <p id="error-message">An error occurred during authentication.</p>
        <div class="error-code" id="error-code"></div>
        <a href="/login" class="back-link">Try Again</a>
    </div>
    
    <script>
        // Parse URL parameters
        const params = new URLSearchParams(window.location.search);
        const errorCode = params.get('error_code');
        const errorMessage = params.get('error_message');
        
        if (errorMessage) {
            document.getElementById('error-message').textContent = errorMessage;
        }
        
        if (errorCode) {
            document.getElementById('error-code').textContent = 'Error Code: ' + errorCode;
        }
    </script>
</body>
</html>
```

---

## 📝 Step 4: Add Logging and Monitoring

### Create Validation Utility Class

Create `src/main/java/com/zz/gateway/auth/oauth2/TokenValidationUtils.java`:

```java
package com.zz.gateway.auth.oauth2;

import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.Map;

public class TokenValidationUtils {

    /**
     * Validate email is verified
     */
    public static Mono<Void> validateEmailVerified(Map<String, Object> claims) {
        Boolean emailVerified = (Boolean) claims.get("email_verified");
        String email = (String) claims.get("email");
        
        if (emailVerified == null || !emailVerified) {
            System.err.println("❌ Email verification failed");
            System.err.println("   Email: " + email);
            System.err.println("   Email Verified: " + emailVerified);
            
            return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error(
                    "email_not_verified",
                    "Please verify your email address before logging in",
                    null
                )
            ));
        }
        
        System.out.println("✅ Email verification passed");
        System.out.println("   Email: " + email);
        return Mono.empty();
    }

    /**
     * Validate organization
     */
    public static Mono<Void> validateOrganization(
            Map<String, Object> claims, 
            List<String> allowedOrganizations) {
        
        String organization = (String) claims.get("organization");
        String username = (String) claims.get("preferred_username");
        
        if (organization == null || !allowedOrganizations.contains(organization)) {
            System.err.println("❌ Organization validation failed");
            System.err.println("   Username: " + username);
            System.err.println("   Organization: " + organization);
            System.err.println("   Allowed Organizations: " + allowedOrganizations);
            
            return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error(
                    "invalid_organization",
                    "Your organization is not allowed to access this application",
                    null
                )
            ));
        }
        
        System.out.println("✅ Organization validation passed");
        System.out.println("   Username: " + username);
        System.out.println("   Organization: " + organization);
        return Mono.empty();
    }

    /**
     * Validate required claims are present
     */
    public static Mono<Void> validateRequiredClaims(
            Map<String, Object> claims, 
            List<String> requiredClaims) {
        
        for (String claim : requiredClaims) {
            if (!claims.containsKey(claim) || claims.get(claim) == null) {
                System.err.println("❌ Required claim missing: " + claim);
                
                return Mono.error(new OAuth2AuthenticationException(
                    new OAuth2Error(
                        "missing_claim",
                        "Required claim is missing: " + claim,
                        null
                    )
                ));
            }
        }
        
        System.out.println("✅ All required claims present");
        return Mono.empty();
    }

    /**
     * Log token claims for debugging
     */
    public static void logTokenClaims(Map<String, Object> claims) {
        System.out.println("========================================");
        System.out.println("TOKEN CLAIMS");
        System.out.println("========================================");
        claims.forEach((key, value) -> {
            System.out.println("   " + key + ": " + value);
        });
        System.out.println("========================================");
    }
}
```

### Use Validation Utils

Update `CustomOAuth2AuthenticationManager.java`:

```java
private Mono<Authentication> buildAuthenticatedUser(
        OAuth2AccessTokenResponse tokenResponse,
        OAuth2AuthorizationCodeAuthenticationToken authCodeToken) {

    String idTokenValue = (String) tokenResponse.getAdditionalParameters().get(OidcParameterNames.ID_TOKEN);

    if (idTokenValue == null) {
        return Mono.error(new OAuth2AuthenticationException(
                new OAuth2Error("missing_id_token", "ID token is required", null)));
    }

    return decodeIdToken(idTokenValue, authCodeToken)
            .flatMap(idToken -> {
                Map<String, Object> claims = idToken.getClaims();
                
                // ⭐ Log all claims for debugging
                TokenValidationUtils.logTokenClaims(claims);
                
                // ⭐ Validate required claims
                return TokenValidationUtils.validateRequiredClaims(
                    claims, 
                    List.of("sub", "email", "preferred_username")
                )
                // ⭐ Validate email is verified
                .then(TokenValidationUtils.validateEmailVerified(claims))
                
                // ⭐ Validate organization
                .then(TokenValidationUtils.validateOrganization(
                    claims,
                    List.of("my-company", "partner-company")
                ))
                
                // Continue with building authenticated user
                .then(Mono.fromCallable(() -> {
                    String username = (String) claims.get("preferred_username");
                    String email = (String) claims.get("email");
                    String name = (String) claims.get("name");

                    System.out.println("Building authenticated user:");
                    System.out.println("   Username: " + username);
                    System.out.println("   Email: " + email);
                    System.out.println("   Name: " + name);

                    Set<GrantedAuthority> authorities = extractAuthorities(claims);
                    System.out.println("   Authorities: " + authorities);

                    OidcUser oidcUser = new DefaultOidcUser(
                            authorities,
                            idToken,
                            "preferred_username"
                    );

                    return new OAuth2LoginAuthenticationToken(
                            authCodeToken.getClientRegistration(),
                            authCodeToken.getAuthorizationExchange(),
                            oidcUser,
                            authorities,
                            tokenResponse.getAccessToken(),
                            tokenResponse.getRefreshToken()
                    );
                }));
            });
}
```

---

## 📝 Step 5: Test Your Custom Validations

### Test Case 1: Valid User

**Setup:**
- User with verified email
- User with organization = "my-company"

**Expected:**
- ✅ Login succeeds
- User is redirected to home page

**Logs:**
```
========================================
TOKEN CLAIMS
========================================
   sub: 12345
   email: user@example.com
   email_verified: true
   preferred_username: john
   organization: my-company
   ...
========================================
✅ All required claims present
✅ Email verification passed
   Email: user@example.com
✅ Organization validation passed
   Username: john
   Organization: my-company
Building authenticated user:
   Username: john
   Email: user@example.com
   ...
========================================
AUTHENTICATION SUCCESSFUL
========================================
```

### Test Case 2: Unverified Email

**Setup:**
- User with email_verified = false

**Expected:**
- ❌ Login fails
- Error message: "Please verify your email address before logging in"

**Logs:**
```
❌ Email verification failed
   Email: user@example.com
   Email Verified: false
========================================
OAUTH2 LOGIN FAILED
========================================
Error: email_not_verified
Error Message: Please verify your email address before logging in
```

### Test Case 3: Invalid Organization

**Setup:**
- User with organization = "other-company"

**Expected:**
- ❌ Login fails
- Error message: "Your organization is not allowed to access this application"

**Logs:**
```
✅ Email verification passed
   Email: user@example.com
❌ Organization validation failed
   Username: john
   Organization: other-company
   Allowed Organizations: [my-company, partner-company]
========================================
OAUTH2 LOGIN FAILED
========================================
Error: invalid_organization
Error Message: Your organization is not allowed to access this application
```

---

## 🎉 Summary

You've successfully implemented custom token validation! Your app now:

1. ✅ Validates email is verified
2. ✅ Validates user belongs to allowed organization
3. ✅ Validates required claims are present
4. ✅ Logs detailed information for debugging
5. ✅ Shows user-friendly error messages
6. ✅ Has reusable validation utilities

---

## 🚀 Next Steps

1. **Add database user sync** - See `CUSTOMIZATION_EXAMPLES.md`
2. **Add token introspection** - Validate tokens with Keycloak
3. **Add custom authorities** - Fetch roles from database
4. **Add audit logging** - Log all authentication events
5. **Add rate limiting** - Prevent brute force attacks

---

## 📚 Related Documentation

- `TOKEN_VALIDATION_EXPLAINED.md` - Detailed explanation
- `TOKEN_VALIDATION_QUICK_REFERENCE.md` - Quick reference
- `CUSTOMIZATION_EXAMPLES.md` - More code examples
- `token_validation_flow.mmd` - Visual flow diagram

