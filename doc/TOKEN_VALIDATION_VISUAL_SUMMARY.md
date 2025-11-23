# Token Validation Visual Summary

## 🎯 The Big Picture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     YOUR SPRING SECURITY APP                        │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 1. User Login → Keycloak                                  │    │
│  │    - Redirect to Keycloak authorization endpoint          │    │
│  │    - User authenticates                                    │    │
│  │    - Keycloak redirects back with authorization code      │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 2. CustomOAuth2TokenExchangeService                       │    │
│  │    ✅ YOU CONTROL THIS                                    │    │
│  │    - Exchange code for tokens                             │    │
│  │    - Log request/response                                 │    │
│  │    - Add custom parameters                                │    │
│  │    - Store tokens in database                             │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 3. CustomOAuth2AuthenticationManager.decodeIdToken()      │    │
│  │    ⭐ TOKEN VALIDATION HAPPENS HERE                       │    │
│  │                                                            │    │
│  │    NimbusJwtDecoder.decode(idToken)                       │    │
│  │    ├─ ✅ Validate Signature (JWK Set)                    │    │
│  │    ├─ ✅ Validate Expiration (exp)                       │    │
│  │    ├─ ✅ Validate Issued At (iat)                        │    │
│  │    ├─ ✅ Validate Not Before (nbf)                       │    │
│  │    ├─ ✅ Validate Issuer (iss)                           │    │
│  │    └─ ⚠️  Validate Audience (aud) - partial             │    │
│  │                                                            │    │
│  │    ✅ YOU CAN ADD MORE VALIDATORS                         │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 4. Custom Validations (Optional)                          │    │
│  │    ✅ YOU CONTROL THIS                                    │    │
│  │    - Validate email_verified                              │    │
│  │    - Validate organization                                │    │
│  │    - Validate custom claims                               │    │
│  │    - Check user in database                               │    │
│  │    - Check user is enabled                                │    │
│  │    - Call external services                               │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 5. extractAuthorities()                                   │    │
│  │    ✅ YOU CONTROL THIS                                    │    │
│  │    - Extract realm_access.roles                           │    │
│  │    - Extract resource_access.roles                        │    │
│  │    - Map to GrantedAuthority                              │    │
│  │    - Add roles from database                              │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 6. buildAuthenticatedUser()                               │    │
│  │    ✅ YOU CONTROL THIS                                    │    │
│  │    - Create OidcUser                                      │    │
│  │    - Create OAuth2LoginAuthenticationToken                │    │
│  │    - Sync with database                                   │    │
│  │    - Log authentication event                             │    │
│  └───────────────────────────────────────────────────────────┘    │
│                            ↓                                        │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ 7. User Authenticated ✅                                  │    │
│  │    - Stored in SecurityContext                            │    │
│  │    - Session created (if using sessions)                  │    │
│  └───────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Token Validation Deep Dive

```
┌─────────────────────────────────────────────────────────────────────┐
│                    NimbusJwtDecoder.decode()                        │
│                                                                     │
│  Input: ID Token (JWT)                                             │
│  ───────────────────────────────────────────────────────────       │
│  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkw...  │
│                                                                     │
│  Step 1: Parse JWT                                                 │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ Header:                                                  │      │
│  │   {                                                      │      │
│  │     "alg": "RS256",                                      │      │
│  │     "typ": "JWT",                                        │      │
│  │     "kid": "abc123"  ← Key ID                           │      │
│  │   }                                                      │      │
│  │                                                          │      │
│  │ Payload:                                                 │      │
│  │   {                                                      │      │
│  │     "sub": "user-id",                                    │      │
│  │     "iss": "http://keycloak.local:3081/realms/dev-realm"│      │
│  │     "aud": "app-client",                                 │      │
│  │     "exp": 1700000000,  ← Expiration                    │      │
│  │     "iat": 1699999000,  ← Issued At                     │      │
│  │     "email": "user@example.com",                         │      │
│  │     "email_verified": true,                              │      │
│  │     "preferred_username": "john",                        │      │
│  │     "realm_access": {                                    │      │
│  │       "roles": ["user", "admin"]                         │      │
│  │     }                                                     │      │
│  │   }                                                      │      │
│  │                                                          │      │
│  │ Signature:                                               │      │
│  │   [encrypted signature]                                  │      │
│  └─────────────────────────────────────────────────────────┘      │
│                            ↓                                        │
│  Step 2: Get Public Key from JWK Set                              │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ GET http://keycloak.local:3081/realms/dev-realm/        │      │
│  │     protocol/openid-connect/certs                        │      │
│  │                                                          │      │
│  │ Response:                                                │      │
│  │ {                                                        │      │
│  │   "keys": [                                              │      │
│  │     {                                                    │      │
│  │       "kid": "abc123",  ← Matches header.kid            │      │
│  │       "kty": "RSA",                                      │      │
│  │       "alg": "RS256",                                    │      │
│  │       "use": "sig",                                      │      │
│  │       "n": "...",  ← Public key modulus                 │      │
│  │       "e": "AQAB"  ← Public key exponent                │      │
│  │     }                                                    │      │
│  │   ]                                                      │      │
│  │ }                                                        │      │
│  │                                                          │      │
│  │ ✅ Public key cached for future use                     │      │
│  └─────────────────────────────────────────────────────────┘      │
│                            ↓                                        │
│  Step 3: Validate Signature                                       │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ Verify signature using public key                       │      │
│  │                                                          │      │
│  │ signature_valid = verify(                               │      │
│  │   header + "." + payload,                               │      │
│  │   signature,                                             │      │
│  │   public_key                                             │      │
│  │ )                                                        │      │
│  │                                                          │      │
│  │ ✅ Signature valid → Token signed by Keycloak           │      │
│  │ ❌ Signature invalid → Throw JwtException               │      │
│  └─────────────────────────────────────────────────────────┘      │
│                            ↓                                        │
│  Step 4: Validate Claims                                          │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ ✅ Expiration (exp):                                    │      │
│  │    current_time < exp                                    │      │
│  │    1699999500 < 1700000000 ✅                           │      │
│  │                                                          │      │
│  │ ✅ Issued At (iat):                                     │      │
│  │    iat <= current_time                                   │      │
│  │    1699999000 <= 1699999500 ✅                          │      │
│  │                                                          │      │
│  │ ✅ Not Before (nbf):                                    │      │
│  │    current_time >= nbf (if present)                      │      │
│  │                                                          │      │
│  │ ✅ Issuer (iss):                                        │      │
│  │    iss == expected_issuer                                │      │
│  │    "http://keycloak.local:3081/realms/dev-realm" ✅     │      │
│  │                                                          │      │
│  │ ⚠️  Audience (aud):                                     │      │
│  │    Partially validated (can add custom validator)       │      │
│  └─────────────────────────────────────────────────────────┘      │
│                            ↓                                        │
│  Step 5: Return Validated JWT                                     │
│  ┌─────────────────────────────────────────────────────────┐      │
│  │ Jwt {                                                    │      │
│  │   tokenValue: "eyJhbGci...",                             │      │
│  │   issuedAt: 1699999000,                                  │      │
│  │   expiresAt: 1700000000,                                 │      │
│  │   claims: { ... }                                        │      │
│  │ }                                                        │      │
│  │                                                          │      │
│  │ ✅ Token is valid and trusted                           │      │
│  └─────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎨 Customization Points Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                    YOUR CUSTOMIZATION OPTIONS                       │
└─────────────────────────────────────────────────────────────────────┘

1️⃣  Token Exchange
    ┌──────────────────────────────────────────────────────────┐
    │ CustomOAuth2TokenExchangeService.exchangeCodeForTokens() │
    │                                                          │
    │ ✅ Control HTTP request to Keycloak                     │
    │ ✅ Add custom parameters                                │
    │ ✅ Log request/response                                 │
    │ ✅ Store tokens in database                             │
    │ ✅ Call external APIs                                   │
    └──────────────────────────────────────────────────────────┘

2️⃣  JWT Decoder
    ┌──────────────────────────────────────────────────────────┐
    │ @Bean JwtDecoder customJwtDecoder()                      │
    │                                                          │
    │ ✅ Add audience validator                               │
    │ ✅ Add custom claim validators                          │
    │ ✅ Add time skew tolerance                              │
    │ ✅ Configure JWK Set cache                              │
    └──────────────────────────────────────────────────────────┘

3️⃣  Token Validation
    ┌──────────────────────────────────────────────────────────┐
    │ CustomOAuth2AuthenticationManager.decodeIdToken()        │
    │                                                          │
    │ ✅ Use custom JWT decoder                               │
    │ ✅ Add pre-validation logic                             │
    │ ✅ Add post-validation logic                            │
    │ ✅ Handle validation errors                             │
    └──────────────────────────────────────────────────────────┘

4️⃣  Custom Claims Validation
    ┌──────────────────────────────────────────────────────────┐
    │ CustomOAuth2AuthenticationManager.buildAuthenticatedUser()│
    │                                                          │
    │ ✅ Validate email_verified                              │
    │ ✅ Validate organization                                │
    │ ✅ Validate custom claims                               │
    │ ✅ Validate user attributes                             │
    └──────────────────────────────────────────────────────────┘

5️⃣  Token Introspection
    ┌──────────────────────────────────────────────────────────┐
    │ TokenIntrospectionService.introspectToken()              │
    │                                                          │
    │ ✅ Validate with Keycloak                               │
    │ ✅ Check if token is revoked                            │
    │ ✅ Get additional token metadata                        │
    │ ✅ Validate on each request                             │
    └──────────────────────────────────────────────────────────┘

6️⃣  Database User Validation
    ┌──────────────────────────────────────────────────────────┐
    │ UserValidationService.validateAndSyncUser()              │
    │                                                          │
    │ ✅ Check user exists in database                        │
    │ ✅ Create new users on first login                      │
    │ ✅ Update user information                              │
    │ ✅ Check if user is enabled                             │
    │ ✅ Track last login time                                │
    └──────────────────────────────────────────────────────────┘

7️⃣  Authority Extraction
    ┌──────────────────────────────────────────────────────────┐
    │ CustomOAuth2AuthenticationManager.extractAuthorities()   │
    │                                                          │
    │ ✅ Extract realm roles                                  │
    │ ✅ Extract client roles                                 │
    │ ✅ Map to GrantedAuthority                              │
    │ ✅ Add roles from database                              │
    │ ✅ Add dynamic roles                                    │
    └──────────────────────────────────────────────────────────┘

8️⃣  Authentication Success/Failure
    ┌──────────────────────────────────────────────────────────┐
    │ SecurityConfig.securityWebFilterChain()                  │
    │                                                          │
    │ ✅ Custom success handler                               │
    │ ✅ Custom failure handler                               │
    │ ✅ Custom redirect logic                                │
    │ ✅ Log authentication events                            │
    └──────────────────────────────────────────────────────────┘
```

---

## 📊 Validation Checklist

### Automatic Validations (by NimbusJwtDecoder)

- [x] **Signature** - Verified using Keycloak's public key from JWK Set
- [x] **Expiration (exp)** - Current time must be before expiration
- [x] **Issued At (iat)** - Token must be issued in the past
- [x] **Not Before (nbf)** - Current time must be after nbf (if present)
- [x] **Issuer (iss)** - Must match expected issuer

### Optional Validations (you can add)

- [ ] **Audience (aud)** - Add custom validator
- [ ] **Email Verified** - Check email_verified claim
- [ ] **Organization** - Check organization claim
- [ ] **User in Database** - Check user exists and is enabled
- [ ] **Token Revocation** - Use introspection endpoint
- [ ] **Custom Claims** - Validate any custom claims
- [ ] **IP Whitelist** - Check request IP
- [ ] **Time-based Access** - Check if user can access at this time
- [ ] **MFA** - Require additional authentication

---

## 🔄 Session vs Stateless Validation

### Session-Based (Default in Your App)

```
┌─────────────────────────────────────────────────────────────┐
│ First Request (Login)                                       │
│                                                             │
│ 1. User logs in                                             │
│ 2. Token validated (NimbusJwtDecoder.decode())              │
│ 3. Authentication stored in session                         │
│ 4. JSESSIONID cookie sent to browser                        │
│                                                             │
│ Subsequent Requests                                         │
│                                                             │
│ 1. Browser sends JSESSIONID cookie                          │
│ 2. Spring Security reads authentication from session        │
│ 3. No token validation (just session check)                 │
│ 4. ✅ Fast (no JWT decoding/validation)                    │
│ 5. ⚠️  Token revocation not detected until session expires │
└─────────────────────────────────────────────────────────────┘
```

### Stateless (Resource Server)

```
┌─────────────────────────────────────────────────────────────┐
│ Every Request                                               │
│                                                             │
│ 1. Client sends: Authorization: Bearer <access_token>       │
│ 2. Token validated on EVERY request                         │
│    - Signature validation                                   │
│    - Expiration check                                       │
│    - Issuer check                                           │
│ 3. Authentication created from token                        │
│ 4. ✅ Token revocation detected immediately                │
│ 5. ⚠️  Slower (JWT validation on every request)           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Quick Decision Tree

```
Do you need to validate tokens?
│
├─ During initial login only?
│  └─ ✅ Use your current setup (CustomOAuth2AuthenticationManager)
│     - Token validated once during login
│     - Session used for subsequent requests
│     - Fast and efficient
│
├─ On every request?
│  └─ ✅ Add Resource Server configuration
│     - Configure oauth2ResourceServer()
│     - Token validated on every request
│     - Stateless (no sessions)
│
├─ With custom claims?
│  └─ ✅ Add custom validation in buildAuthenticatedUser()
│     - Validate email_verified
│     - Validate organization
│     - Validate custom claims
│
├─ Check if token is revoked?
│  └─ ✅ Use Token Introspection
│     - Call Keycloak's introspect endpoint
│     - Check if token is still active
│     - Can be done on every request or periodically
│
└─ Sync with database?
   └─ ✅ Add UserValidationService
      - Check user exists
      - Create/update user
      - Check if user is enabled
```

---

## 📁 File Structure

```
src/main/java/com/zz/gateway/auth/
├── config/
│   ├── SecurityConfig.java                    ← Main security config
│   ├── JwtDecoderConfig.java                  ← Custom JWT decoder (optional)
│   └── ResourceServerConfig.java              ← Stateless validation (optional)
│
├── oauth2/
│   ├── CustomOAuth2AuthenticationManager.java ← ⭐ Token validation here
│   ├── CustomOAuth2TokenExchangeService.java  ← Token exchange
│   └── TokenIntrospectionService.java         ← Token introspection (optional)
│
└── service/
    └── UserValidationService.java             ← Database sync (optional)

doc/
├── TOKEN_VALIDATION_EXPLAINED.md              ← Full detailed guide
├── TOKEN_VALIDATION_QUICK_REFERENCE.md        ← Quick reference
├── TOKEN_VALIDATION_VISUAL_SUMMARY.md         ← This file
├── CUSTOMIZATION_EXAMPLES.md                  ← Code examples
└── token_validation_flow.mmd                  ← Flow diagram
```

---

## 🚀 Next Steps

1. **Understand the basics** ✅
   - You now know how token validation works
   - You know where it happens in your code

2. **Add custom validations**
   - Start with email verification check
   - Add organization validation
   - Add database user sync

3. **Test your validations**
   - Try logging in with unverified email
   - Try logging in with wrong organization
   - Check logs to see validation in action

4. **Consider advanced features**
   - Token introspection for revocation checking
   - Stateless validation for API endpoints
   - Custom JWT decoder with additional validators

---

## 📚 Documentation Files

| File | Purpose | When to Read |
|------|---------|--------------|
| `TOKEN_VALIDATION_QUICK_REFERENCE.md` | Quick answers | When you need a quick answer |
| `TOKEN_VALIDATION_EXPLAINED.md` | Detailed explanation | When you want to understand deeply |
| `TOKEN_VALIDATION_VISUAL_SUMMARY.md` | Visual diagrams | When you want to see the flow |
| `CUSTOMIZATION_EXAMPLES.md` | Code examples | When you want to implement |
| `token_validation_flow.mmd` | Flow diagram | When you want to visualize |

---

**You now have complete understanding of token validation in your Spring Security app! 🎉**

