# Keycloak Configuration Summary

**Project:** API Gateway with Keycloak OAuth2/OIDC Integration
**Last Updated:** Session 1
**Status:** Phase 0 Complete - Ready for Phase 1 Testing

---

## Table of Contents
- [Keycloak Server Setup](#1-keycloak-server-docker)
- [Realm Configuration](#2-keycloak-realm-configuration)
- [Client Configuration](#3-keycloak-client-configuration)
- [Roles Configuration](#4-keycloak-roles)
- [Users Configuration](#5-keycloak-users)
- [Spring Application Configuration](#6-spring-application-configuration)
- [Keycloak Endpoints](#7-key-keycloak-endpoints)
- [Configuration Mapping](#8-configuration-mapping)
- [Next Steps](#9-next-steps)

---

## 1. Keycloak Server (Docker)

### Docker Compose Configuration

**File:** `docker-compose.yml`

```yaml
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    ports:
      - "3081:8080"
    command: start-dev
```

### Access Information

| Item | Value |
|------|-------|
| **Keycloak URL** | http://localhost:3081 |
| **Admin Console** | http://localhost:3081/admin |
| **Admin Username** | admin |
| **Admin Password** | admin |
| **Database** | H2 in-memory (dev mode) |

### Docker Commands

```bash
# Start Keycloak
docker-compose up -d

# View logs
docker-compose logs -f keycloak

# Stop Keycloak
docker-compose down

# Restart Keycloak (data will be lost with H2)
docker-compose restart keycloak
```

---

## 2. Keycloak Realm Configuration

### Realm Details

| Setting | Value |
|---------|-------|
| **Realm Name** | `dev-realm` |
| **Display Name** | dev-realm |
| **Enabled** | Yes |
| **Endpoints Base** | http://localhost:3081/realms/dev-realm |

### How to Access
1. Login to Keycloak Admin Console
2. Click realm dropdown (top-left)
3. Select `dev-realm`

---

## 3. Keycloak Client Configuration

### Client: `app-client`

**Purpose:** OAuth2 client for Spring Cloud Gateway (Authorization Code flow)

#### General Settings

| Setting | Value |
|---------|-------|
| **Client ID** | `app-client` |
| **Name** | app-client |
| **Description** | for dev purpose |
| **Client Type** | OpenID Connect |
| **Enabled** | Yes |

#### Capability Configuration

| Setting | Value |
|---------|-------|
| **Client Authentication** | ON (Confidential Client) ✅ |
| **Authorization** | OFF |
| **Standard Flow** | Enabled ✅ (Authorization Code) |
| **Direct Access Grants** | Enabled ✅ (for testing) |
| **Implicit Flow** | Disabled ❌ (deprecated) |

#### Access Settings

| Setting | Value |
|---------|-------|
| **Root URL** | (empty) |
| **Home URL** | (empty) |
| **Valid Redirect URIs** | `http://localhost:8080/login/oauth2/code` |
| **Valid Post Logout Redirect URIs** | `http://localhost:8080/` |
| **Web Origins** | `http://localhost:8080` |

#### Credentials

| Setting | Value |
|---------|-------|
| **Client Authenticator** | Client Id and Secret |
| **Client Secret** | `mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF` |

⚠️ **Security Note:** In production, store this secret in environment variables or a secrets manager, never in code!

---

## 4. Keycloak Roles

### Client Roles (app-client)

Created under: **Clients → app-client → Roles**

| Role Name | Description | Composite |
|-----------|-------------|-----------|
| `ROLE_USER` | Standard user role | False |
| `ROLE_ADMIN` | Administrator role | False |

### Role Usage

These roles will appear in JWT tokens under:
```json
{
  "resource_access": {
    "app-client": {
      "roles": ["ROLE_USER", "ROLE_ADMIN"]
    }
  }
}
```

### Spring Security Integration

Spring Security will use these roles for authorization:
```java
@PreAuthorize("hasRole('USER')")
@PreAuthorize("hasRole('ADMIN')")
```

---

## 5. Keycloak Users

### Test Users

Created under: **Users → Create new user**

#### User 1: john (Standard User)

| Setting | Value |
|---------|-------|
| **Username** | `john` |
| **Email** | john@test.com |
| **First Name** | John |
| **Last Name** | Doe |
| **Email Verified** | Yes |
| **Enabled** | Yes |
| **Password** | `john123` |
| **Temporary Password** | No |
| **Roles** | `ROLE_USER` (app-client) |

#### User 2: admin (Administrator)

| Setting | Value |
|---------|-------|
| **Username** | `admin` |
| **Email** | admin@test.com |
| **First Name** | Admin |
| **Last Name** | User |
| **Email Verified** | Yes |
| **Enabled** | Yes |
| **Password** | `admin123` |
| **Temporary Password** | No |
| **Roles** | `ROLE_USER`, `ROLE_ADMIN` (app-client) |

### User Testing Matrix

| Username | Password | Roles | Use Case |
|----------|----------|-------|----------|
| john | john123 | ROLE_USER | Test user-level access |
| admin | admin123 | ROLE_USER, ROLE_ADMIN | Test admin-level access |

---

## 6. Spring Application Configuration

### Build Configuration

**File:** `build.gradle`

```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '4.0.0'
    id 'io.spring.dependency-management' version '1.1.7'
}

ext {
    springCloudVersion = '2024.0.0'
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter'
    implementation 'org.springframework.cloud:spring-cloud-starter-gateway'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-client'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}
```

### Application Configuration

**File:** `src/main/resources/application.yml`

```yaml
spring:
  application:
    name: api-gateway-keycloak

  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: app-client
            client-secret: mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
            scope: openid,profile,email
            authorization-grant-type: authorization_code
            redirect-uri: "{baseUrl}/login/oauth2/code"

        provider:
          keycloak:
            issuer-uri: http://localhost:3081/realms/dev-realm
            user-name-attribute: preferred_username

      resourceserver:
        jwt:
          issuer-uri: http://localhost:3081/realms/dev-realm
          jwk-set-uri: http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs

server:
  port: 8080

logging:
  level:
    org.springframework.security: DEBUG
    org.springframework.security.oauth2: DEBUG
    com.zz.gateway: DEBUG
```

### Configuration Explanation

#### OAuth2 Client Registration
- **client-id**: Matches Keycloak client ID
- **client-secret**: From Keycloak Credentials tab
- **scope**: OIDC scopes (openid is required)
- **authorization-grant-type**: Authorization Code flow for user login
- **redirect-uri**: Where Keycloak redirects after login

#### OAuth2 Provider
- **issuer-uri**: Base URL for OIDC discovery (auto-discovers all endpoints)
- **user-name-attribute**: JWT claim to use as username

#### Resource Server
- **jwt.issuer-uri**: Validates the `iss` claim in JWT
- **jwt.jwk-set-uri**: Public keys for JWT signature verification

---

## 7. Key Keycloak Endpoints

### Base URL
```
http://localhost:3081/realms/dev-realm
```

### OIDC Endpoints (Auto-Discovered)

| Endpoint | Path |
|----------|------|
| **OIDC Discovery** | `/.well-known/openid-configuration` |
| **Authorization** | `/protocol/openid-connect/auth` |
| **Token** | `/protocol/openid-connect/token` |
| **UserInfo** | `/protocol/openid-connect/userinfo` |
| **JWKS (Public Keys)** | `/protocol/openid-connect/certs` |
| **Logout** | `/protocol/openid-connect/logout` |
| **Token Introspection** | `/protocol/openid-connect/token/introspect` |
| **Token Revocation** | `/protocol/openid-connect/revoke` |

### Testing Endpoints

```bash
# Get OIDC configuration
curl http://localhost:3081/realms/dev-realm/.well-known/openid-configuration

# Get public keys (JWKS)
curl http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
```

---

## 8. Configuration Mapping

### Keycloak ↔ Spring Mapping

| Configuration Item | Keycloak Value | Spring Config | Location in Spring |
|-------------------|----------------|---------------|-------------------|
| **Realm** | `dev-realm` | In `issuer-uri` path | `application.yml` |
| **Client ID** | `app-client` | `client-id` | `registration.keycloak.client-id` |
| **Client Secret** | `mEFz9aF5WBb6...` | `client-secret` | `registration.keycloak.client-secret` |
| **Redirect URI** | `http://localhost:8080/login/oauth2/code` | `redirect-uri` | `registration.keycloak.redirect-uri` |
| **Keycloak Base URL** | `http://localhost:3081` | In `issuer-uri` | `provider.keycloak.issuer-uri` |
| **OIDC Scopes** | N/A | `openid,profile,email` | `registration.keycloak.scope` |
| **User Roles** | `ROLE_USER`, `ROLE_ADMIN` | In JWT token | Extracted by Spring Security |

### Port Mapping

| Service | Port | URL |
|---------|------|-----|
| **Keycloak** | 3081 | http://localhost:3081 |
| **Spring Gateway** | 8080 | http://localhost:8080 |
| **Backend Services** | 9090+ | (To be created) |

---

## 9. Next Steps

### ✅ Completed (Phase 0)

- [x] Keycloak Docker setup
- [x] Realm creation (`dev-realm`)
- [x] Client configuration (`app-client`)
- [x] Roles creation (`ROLE_USER`, `ROLE_ADMIN`)
- [x] Users creation (`john`, `admin`)
- [x] Spring Cloud Gateway project setup
- [x] OAuth2 client configuration in `application.yml`

### ⏸️ To Do (Phase 1)

- [ ] Create Spring Security configuration (`SecurityConfig.java`)
- [ ] Start Spring Boot application
- [ ] Test OAuth2 login flow
  - [ ] Access protected endpoint
  - [ ] Redirect to Keycloak login
  - [ ] Login with `john` / `john123`
  - [ ] Verify successful redirect back
  - [ ] Inspect JWT token
- [ ] Create test endpoints
- [ ] Validate role-based access

### 🔜 Future Phases

- **Phase 2:** Token validation, microservice integration
- **Phase 3:** Token refresh implementation
- **Phase 4:** Logout and token revocation
- **Phase 5:** Service-to-service (Client Credentials)
- **Phase 6:** Production hardening

---

## 10. Troubleshooting

### Common Issues

#### Issue: Keycloak not starting
```bash
# Check logs
docker-compose logs -f keycloak

# Verify container is running
docker-compose ps
```

#### Issue: Port 3081 already in use
- Change port in `docker-compose.yml`: `"3082:8080"`
- Update `issuer-uri` in `application.yml` accordingly

#### Issue: Invalid redirect URI error
- Verify Keycloak client settings match Spring config
- Check: http://localhost:8080/login/oauth2/code
- Must be exact match (no trailing slash, correct port)

#### Issue: Client secret mismatch
- Copy secret from: Keycloak → Clients → app-client → Credentials
- Paste into: `application.yml` → `client-secret`

### Verification Checklist

Before testing OAuth2 flow:

- [ ] Keycloak is running (`docker-compose ps`)
- [ ] Can access http://localhost:3081/admin
- [ ] Realm `dev-realm` exists and is enabled
- [ ] Client `app-client` exists with correct redirect URI
- [ ] Users `john` and `admin` exist with passwords set
- [ ] Roles are assigned to users
- [ ] Spring `application.yml` has correct `client-secret`
- [ ] Ports 3081 (Keycloak) and 8080 (Gateway) are available

---

## 11. Quick Reference Commands

### Docker
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View Keycloak logs
docker-compose logs -f keycloak

# Restart Keycloak
docker-compose restart keycloak
```

### Gradle
```bash
# Build project
./gradlew build

# Run Spring Boot app
./gradlew bootRun

# Clean build
./gradlew clean build
```

### Testing
```bash
# Check OIDC configuration
curl http://localhost:3081/realms/dev-realm/.well-known/openid-configuration | jq

# Check if gateway is running
curl http://localhost:8080/actuator/health

# Test protected endpoint (should redirect to Keycloak)
curl -v http://localhost:8080/
```

---

## 12. References

### Documentation
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Spring Security OAuth2 Client](https://docs.spring.io/spring-security/reference/servlet/oauth2/client/index.html)
- [Spring Cloud Gateway](https://docs.spring.io/spring-cloud-gateway/docs/current/reference/html/)

### Project Files
- `docker-compose.yml` - Keycloak container configuration
- `build.gradle` - Project dependencies
- `application.yml` - Spring OAuth2 configuration
- `PROGRESS.md` - Learning progress tracker
- `keycloak_full_flow.mmd` - OAuth2 flow diagram
- `learning_prompt.md` - Full curriculum

---

**Last Updated:** Phase 0 Complete
**Next Session:** Create Security Configuration and test OAuth2 login flow
