
What Spring Auto-Discovers from issuer-uri:

  When you set issuer-uri=http://localhost:3081/realms/dev-realm, Spring Security automatically fetches:

  Endpoint: http://localhost:3081/realms/dev-realm/.well-known/openid-configuration

USER:
provider:
            keycloak:
              issuer-uri: http://localhost:3081/realms/dev-realm
              authorization-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth
              token-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
              user-info-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo
              jwk-set-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
              user-name-attribute: preferred_username

Explain in detail

AGENT:
I'll explain the Keycloak OAuth2/OIDC configuration you've provided in detail.

## Overview

The configuration snippet shows how to set up a Spring Boot application to use Keycloak as an OAuth2/OIDC provider. This enables your application to delegate authentication to Keycloak and use JWT tokens for authorization.

## Configuration Breakdown

```yaml
provider:
  keycloak:
    issuer-uri: http://localhost:3081/realms/dev-realm
    authorization-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth
    token-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
    user-info-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo
    jwk-set-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
    user-name-attribute: preferred_username
```
### Key Components

**1. Issuer URI**
- `issuer-uri: http://localhost:3081/realms/dev-realm`
- This is the root Keycloak realm endpoint
- Spring Boot uses this to automatically discover all other endpoints (via OpenID Connect Discovery)
- All tokens issued will have `iss` claim set to this value
- Spring Boot validates that incoming tokens have this exact issuer

**2. Authorization URI**
- `authorization-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth`
- Where users are redirected to log in
- Used in the OAuth2 Authorization Code Flow (step 1)
- Example redirect: `http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth?client_id=...&redirect_uri=...&response_type=code&scope=openid`

**3. Token URI**
- `token-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token`
- Backend-to-backend endpoint (never exposed to browser)
- Spring Boot exchanges the authorization code for tokens here
- Also used for refresh token grants
- Requires `client_id` and `client_secret` for authentication

**4. User Info URI**
- `user-info-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo`
- Optional endpoint that returns authenticated user's information
- Spring Boot calls this with the access token to get user details
- Less commonly used since ID tokens already contain user info
- Useful for fetching additional user attributes not in the JWT

**5. JWKS URI**
- `jwk-set-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs`
- Returns Keycloak's public keys in JWKS (JSON Web Key Set) format
- Spring Boot uses these keys to verify JWT signatures
- Cached locally to avoid repeated network calls
- Critical for security: proves tokens came from Keycloak

**6. User Name Attribute**
- `user-name-attribute: preferred_username`
- Tells Spring Boot which JWT claim to use as the user's principal name
- Other options: `sub` (subject), `email`, `name`
- `preferred_username` is Keycloak's standard username claim
- This becomes the `name` in Spring's `Authentication` object

## Complete Authentication Flow

1. **User initiates login** → Browser redirected to `authorization-uri`
2. **User enters credentials** → Keycloak validates and generates `authorization_code`
3. **Redirect back to app** → Browser sent to your app's callback URL with code
4. **Exchange code for tokens** → Your app calls `token-uri` (backend-to-backend) with:
   - `code` (from step 2)
   - `client_id` and `client_secret`
   - Gets back `access_token`, `refresh_token`, `id_token`
5. **Validate tokens** → Spring Boot:
   - Fetches public keys from `jwk-set-uri`
   - Verifies JWT signature
   - Validates claims (issuer, audience, expiration)
6. **Extract user info** → Optionally calls `user-info-uri` or uses ID token claims
7. **Create SecurityContext** → User authenticated, `preferred_username` becomes principal

## Minimal Required Additional Configuration

For this to work, your `application.yml` also needs:

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: your-client-id
            client-secret: your-client-secret
            authorization-grant-type: authorization_code
            redirect-uri: "http://localhost:8080/login/oauth2/code/keycloak"
            scope: openid,profile,email
        provider:
          keycloak:
            # Your configuration from above
```
## Security Implications

- **State parameter**: Automatically generated by Spring Boot to prevent CSRF attacks
- **Client secret**: Must be kept server-side, never exposed to frontend
- **JWT signature validation**: Ensures tokens weren't tampered with
- **Issuer validation**: Confirms tokens came from your Keycloak instance
- **Expiration checking**: Access tokens expire (~5 min), refresh tokens can get new ones (~30 min)

## Token Lifecycle

1. **Access token** (short-lived, ~5 min)
   - Used to call protected APIs
   - In `Authorization: Bearer <token>` header
   
2. **Refresh token** (longer-lived, ~30 min)
   - Used to get new access tokens when expired
   - Spring Boot handles this automatically
   
3. **ID token** (for authentication)
   - Contains user info (username, email, etc.)
   - Spring Boot extracts user details from this

The configuration you provided is a standard, secure setup for delegating authentication to Keycloak while maintaining JWT-based stateless authorization.