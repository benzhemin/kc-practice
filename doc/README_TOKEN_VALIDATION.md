# Token Validation Documentation

## 📚 Overview

This directory contains comprehensive documentation about how Spring Security validates OAuth2/OIDC tokens in your application and how you can customize the validation process.

---

## 🎯 Quick Start

**Want a quick answer?** → Read [`TOKEN_VALIDATION_QUICK_REFERENCE.md`](TOKEN_VALIDATION_QUICK_REFERENCE.md)

**Want to understand deeply?** → Read [`TOKEN_VALIDATION_EXPLAINED.md`](TOKEN_VALIDATION_EXPLAINED.md)

**Want to see visual diagrams?** → Read [`TOKEN_VALIDATION_VISUAL_SUMMARY.md`](TOKEN_VALIDATION_VISUAL_SUMMARY.md)

**Want to implement custom validation?** → Read [`HANDS_ON_CUSTOM_VALIDATION.md`](HANDS_ON_CUSTOM_VALIDATION.md)

**Want code examples?** → Read [`CUSTOMIZATION_EXAMPLES.md`](../src/main/java/com/zz/gateway/auth/oauth2/CUSTOMIZATION_EXAMPLES.md)

---

## 📖 Documentation Files

### 1. TOKEN_VALIDATION_QUICK_REFERENCE.md
**Purpose:** Quick answers and reference guide

**Contents:**
- Quick answer to "How does Spring Security validate tokens?"
- Where validation happens in your code
- What gets validated automatically
- Customization points summary
- Quick decision tree
- Common questions

**Read this when:** You need a quick answer or reference

---

### 2. TOKEN_VALIDATION_EXPLAINED.md
**Purpose:** Comprehensive detailed explanation

**Contents:**
- Complete OAuth2 flow in your app
- Detailed token validation process
- What gets validated automatically (signature, exp, iat, nbf, iss)
- Your current customization points
- Advanced customization options
- Token validation on subsequent requests
- Flow diagrams and examples

**Read this when:** You want to understand the entire process deeply

---

### 3. TOKEN_VALIDATION_VISUAL_SUMMARY.md
**Purpose:** Visual diagrams and summaries

**Contents:**
- Big picture diagram
- Token validation deep dive diagram
- Customization points map
- Validation checklist
- Session vs stateless comparison
- Quick decision tree
- File structure

**Read this when:** You prefer visual learning or want to see the flow

---

### 4. HANDS_ON_CUSTOM_VALIDATION.md
**Purpose:** Step-by-step implementation guide

**Contents:**
- Step 1: Add email verification check
- Step 2: Add organization validation
- Step 3: Add better error handling
- Step 4: Add logging and monitoring
- Step 5: Test your validations
- Complete code examples
- Testing instructions

**Read this when:** You want to implement custom validation right now

---

### 5. CUSTOMIZATION_EXAMPLES.md
**Purpose:** Reusable code examples

**Contents:**
- Example 1: Custom JWT decoder with audience validation
- Example 2: Token introspection service
- Example 3: Database user validation and sync
- Example 4: Enhanced authentication manager
- Example 5: Stateless JWT validation on each request
- Usage guide
- Testing examples

**Read this when:** You want to copy/paste code for specific features

---

### 6. token_validation_flow.mmd
**Purpose:** Mermaid flow diagram

**Contents:**
- Visual flow diagram of the entire token validation process
- Can be viewed in Mermaid-compatible viewers

**Read this when:** You want to visualize the flow in a diagram tool

---

## 🔑 Key Concepts

### What is Token Validation?

Token validation is the process of verifying that a JWT (JSON Web Token) is:
1. **Authentic** - Signed by the expected issuer (Keycloak)
2. **Valid** - Not expired, issued in the past, etc.
3. **Authorized** - Contains the required claims and permissions

### Where Does Validation Happen?

In your app, token validation happens in:
```
CustomOAuth2AuthenticationManager.decodeIdToken()
    ↓
NimbusJwtDecoder.decode(idToken)
    ↓
Validates: signature, exp, iat, nbf, iss
```

### What Gets Validated Automatically?

Spring Security's `NimbusJwtDecoder` automatically validates:
- ✅ **Signature** - Using Keycloak's public keys from JWK Set
- ✅ **Expiration (exp)** - Token must not be expired
- ✅ **Issued At (iat)** - Token must be issued in the past
- ✅ **Not Before (nbf)** - Token must be valid now (if nbf present)
- ✅ **Issuer (iss)** - Token must be from expected issuer

### Can This Be Customized?

**YES!** You have full control through:
1. **Custom JWT Decoder** - Add more validators
2. **Custom Claims Validation** - Validate email_verified, organization, etc.
3. **Token Introspection** - Validate with Keycloak
4. **Database User Validation** - Check user exists and is enabled
5. **Custom Authority Extraction** - Control how roles are mapped

---

## 🎓 Learning Path

### Beginner
1. Read `TOKEN_VALIDATION_QUICK_REFERENCE.md`
2. Understand where validation happens in your code
3. Look at the automatic validations

### Intermediate
1. Read `TOKEN_VALIDATION_EXPLAINED.md`
2. Understand the complete OAuth2 flow
3. Learn about customization points
4. Read `TOKEN_VALIDATION_VISUAL_SUMMARY.md`

### Advanced
1. Read `HANDS_ON_CUSTOM_VALIDATION.md`
2. Implement custom validations
3. Read `CUSTOMIZATION_EXAMPLES.md`
4. Implement advanced features (introspection, database sync, etc.)

---

## 🔍 Common Use Cases

### Use Case 1: Validate Email is Verified
**Solution:** Add custom validation in `buildAuthenticatedUser()`
**Guide:** `HANDS_ON_CUSTOM_VALIDATION.md` - Step 1
**Code:** Check if `email_verified` claim is true

### Use Case 2: Validate User Organization
**Solution:** Add custom validation for organization claim
**Guide:** `HANDS_ON_CUSTOM_VALIDATION.md` - Step 2
**Code:** Check if `organization` claim is in allowed list

### Use Case 3: Check if Token is Revoked
**Solution:** Use token introspection
**Guide:** `CUSTOMIZATION_EXAMPLES.md` - Example 2
**Code:** Call Keycloak's introspection endpoint

### Use Case 4: Sync User with Database
**Solution:** Add database user validation
**Guide:** `CUSTOMIZATION_EXAMPLES.md` - Example 3
**Code:** Create/update user in database during authentication

### Use Case 5: Validate Token on Every Request
**Solution:** Configure resource server
**Guide:** `CUSTOMIZATION_EXAMPLES.md` - Example 5
**Code:** Add `oauth2ResourceServer()` configuration

### Use Case 6: Add Custom Audience Validation
**Solution:** Create custom JWT decoder
**Guide:** `CUSTOMIZATION_EXAMPLES.md` - Example 1
**Code:** Add `AudienceValidator` to JWT decoder

---

## 📁 Related Files in Your Project

### Configuration Files
- `src/main/java/com/zz/gateway/auth/config/SecurityConfig.java`
  - Main security configuration
  - Registers custom authentication manager
  - Configures OAuth2 login

### OAuth2 Implementation Files
- `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2AuthenticationManager.java`
  - **⭐ Token validation happens here**
  - Controls entire authentication process
  - Decodes and validates ID token
  - Extracts authorities from token

- `src/main/java/com/zz/gateway/auth/oauth2/CustomOAuth2TokenExchangeService.java`
  - Exchanges authorization code for tokens
  - Calls Keycloak's token endpoint
  - Logs token exchange details

### Configuration
- `src/main/resources/application.yml`
  - OAuth2 client configuration
  - Keycloak issuer URI
  - JWK Set URI

---

## 🚀 Quick Implementation Guide

### Add Email Verification Check (5 minutes)

```java
// In CustomOAuth2AuthenticationManager.buildAuthenticatedUser()
Boolean emailVerified = (Boolean) claims.get("email_verified");
if (emailVerified == null || !emailVerified) {
    return Mono.error(new OAuth2AuthenticationException(
        new OAuth2Error("email_not_verified", 
            "Please verify your email", null)
    ));
}
```

### Add Organization Check (5 minutes)

```java
// In CustomOAuth2AuthenticationManager.buildAuthenticatedUser()
String org = (String) claims.get("organization");
if (!"my-company".equals(org)) {
    return Mono.error(new OAuth2AuthenticationException(
        new OAuth2Error("invalid_organization", 
            "Invalid organization", null)
    ));
}
```

### Add Custom JWT Decoder (10 minutes)

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

---

## 🧪 Testing Your Validations

### Test Valid User
```bash
# User with verified email and correct organization
# Expected: Login succeeds
curl -v http://localhost:8080/
```

### Test Invalid Email
```bash
# User with email_verified = false
# Expected: Login fails with "email_not_verified"
```

### Test Invalid Organization
```bash
# User with wrong organization
# Expected: Login fails with "invalid_organization"
```

### Check Logs
```bash
# Watch logs for validation messages
./gradlew bootRun

# Look for:
# ✅ Email verification passed
# ✅ Organization validation passed
# ❌ Email verification failed
# ❌ Organization validation failed
```

---

## ❓ FAQ

### Q: Is the token validated on every request?
**A:** Depends on your configuration:
- **With sessions (default):** No, only during initial login
- **Stateless (resource server):** Yes, on every request

### Q: Can I validate tokens with Keycloak instead of locally?
**A:** Yes! Use token introspection. See `CUSTOMIZATION_EXAMPLES.md` Example 2.

### Q: Where are Keycloak's public keys cached?
**A:** `NimbusJwtDecoder` caches JWK Set automatically and refreshes when needed.

### Q: What happens if validation fails?
**A:** `OAuth2AuthenticationException` is thrown, user is not authenticated, and `authenticationFailureHandler` is called.

### Q: Can I add my own custom validations?
**A:** Yes! You have full control in `CustomOAuth2AuthenticationManager`. See `HANDS_ON_CUSTOM_VALIDATION.md`.

### Q: How do I validate custom claims?
**A:** Add validation logic in `buildAuthenticatedUser()` method. See `HANDS_ON_CUSTOM_VALIDATION.md` Step 1-2.

### Q: How do I sync users with my database?
**A:** Create `UserValidationService` and call it during authentication. See `CUSTOMIZATION_EXAMPLES.md` Example 3.

### Q: How do I check if a token is revoked?
**A:** Use token introspection endpoint. See `CUSTOMIZATION_EXAMPLES.md` Example 2.

---

## 🎯 Summary

### What You Learned
1. ✅ How Spring Security validates tokens
2. ✅ Where validation happens in your code
3. ✅ What gets validated automatically
4. ✅ How to customize validation
5. ✅ How to implement custom validations

### Your Current Setup
- ✅ Custom authentication manager (full control)
- ✅ Custom token exchange service (full visibility)
- ✅ Automatic token validation (signature, exp, iat, nbf, iss)
- ✅ Custom authority extraction (realm and client roles)
- ✅ Comprehensive logging

### Next Steps
1. Implement email verification check
2. Implement organization validation
3. Add database user sync
4. Add token introspection
5. Add audit logging

---

## 📞 Need Help?

1. **Quick question?** → Check `TOKEN_VALIDATION_QUICK_REFERENCE.md`
2. **Want to understand?** → Read `TOKEN_VALIDATION_EXPLAINED.md`
3. **Want to implement?** → Follow `HANDS_ON_CUSTOM_VALIDATION.md`
4. **Need code examples?** → See `CUSTOMIZATION_EXAMPLES.md`
5. **Want visual diagrams?** → See `TOKEN_VALIDATION_VISUAL_SUMMARY.md`

---

## 📜 License

This documentation is part of your keycloak-practice project.

---

**Happy coding! 🚀**

