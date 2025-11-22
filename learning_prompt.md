
### Goal Master OAuth2/OIDC implementation with Keycloak through hands-on engineering. Build production-ready authentication system aligned with `keycloak_full_flow.mmd`


Teaching Style:****
Break down into small, manageable steps
For each step: give me a clear task to complete
Wait for me to show you my work
Validate my implementation and explain what's correct/incorrect
Provide insights about why we're doing things a certain way
Ask me to implement key decision points so I learn by doing

Technical Scope:

Architecture:
Spring Cloud Gateway (entry point with OAuth2)
Keycloak (authorization server)
Downstream resource microservices
Docker-based Keycloak setup


## PHASE 0: ENVIRONMENT SETUP (Est: 1 hour)
     **Goal**: Docker Keycloak + baseline Spring projects ready

### Tasks (30 min each)
    1. **T0.1 - Keycloak Setup**:
         - Create docker-compose.yml with Keycloak
         - Configure admin user, expose ports
         - Start and verify admin console access
         - **Validation**: Access http://localhost:8080, login to admin console
     2. **T0.2 - Realm & Client Configuration**: 
         - Create realm: `spring-microservices`
         - Create clients: `gateway-client`, `user-service-client`, `service-account-client`
         - Configure redirect URIs, client secrets, valid flows
         - Create test users with roles
         - **Validation**: Export realm JSON, show client configurations
  
### PHASE 1: AUTHORIZATION CODE FLOW (Est: 3.5 hours)
  **Reference**: keycloak_full_flow.mmd steps 1-17  
  **Goal**: User login → authorization code → access token flow

  ### Tasks
  1. **T1.1 - Gateway OAuth2 Client (45 min)**:
    - Create Spring Cloud Gateway project
    - Add OAuth2 client dependencies
    - Configure `application.yml` for Keycloak provider
    - Implement login redirect flow
    - **Validation**: `/login` redirects to Keycloak, login redirects back

  2. **T1.2 - Token Exchange Implementation (45 min)**:
    - Configure authorization code to token exchange
    - Implement token storage strategy (session vs cookie)
    - Add logging to inspect tokens (access_token, refresh_token, id_token)
    - **Validation**: After login, log decoded JWT claims, show token structure

  3. **T1.3 - Protected Routes (30 min)**:
    - Create route configuration for `/api/**`
    - Add authentication requirement
    - Implement 401 redirect to login
    - **Validation**: Unauthenticated request → login → successful API call

  4. **T1.4 - Frontend Simulation (30 min)**:
    - Create simple REST controller simulating frontend callback
    - Show authorization code in callback
    - Display token exchange process
    - **Validation**: Full flow from authorization request to token receipt

  ---

  ## PHASE 2: TOKEN VALIDATION & MICROSERVICE INTEGRATION (Est: 4 hours)
  **Reference**: keycloak_full_flow.mmd steps 18-47  
  **Goal**: Gateway validates token → forwards to microservice → microservice validates independently

  ### Tasks
  1. **T2.1 - Gateway Token Validation (45 min)**:
    - Configure JWT decoder with Keycloak JWKS endpoint
    - Implement signature verification
    - Validate claims (exp, iss, aud, nbf)
    - Extract roles from token
    - **Validation**: Invalid token rejected, expired token rejected, log validation steps

  2. **T2.2 - Gateway Filters & Headers (45 min)**:
    - Create GatewayFilter to add custom headers (X-Auth-User-Id, X-Auth-User-Roles)
    - Implement request/response logging
    - Add correlation ID propagation
    - **Validation**: Log shows headers added, downstream receives headers

  3. **T2.3 - Resource Microservice Setup (45 min)**:
    - Create user-service Spring Boot app
    - Add OAuth2 Resource Server dependencies
    - Configure JWT validation with Keycloak
    - Create `/users/profile` endpoint
    - **Validation**: Direct call fails without token, works with valid JWT

  4. **T2.4 - Method-Level Security (30 min)**:
    - Enable @PreAuthorize, @PostAuthorize
    - Create endpoints with role-based access (`ROLE_USER`, `ROLE_ADMIN`)
    - Implement custom security expressions
    - **Validation**: ADMIN endpoint rejects USER token, vice versa

  5. **T2.5 - Gateway Routing & Integration (45 min)**:
    - Configure gateway routes to user-service
    - Implement token forwarding
    - Test end-to-end: User login → gateway → microservice
    - **Validation**: Full request trace from browser to microservice with logs

  ---

  ## PHASE 3: TOKEN REFRESH & SESSION MANAGEMENT (Est: 2 hours)
  **Reference**: keycloak_full_flow.mmd steps 48-55  
  **Goal**: Handle token expiry gracefully without re-authentication

  ### Tasks
  1. **T3.1 - Refresh Token Configuration (30 min)**:
    - Configure token lifetimes in Keycloak (access: 5min, refresh: 30min)
    - Enable refresh token rotation
    - Configure gateway to receive refresh tokens
    - **Validation**: Token response includes refresh_token, show expiry times

  2. **T3.2 - Automatic Token Refresh (60 min)**:
    - Implement token refresh filter in gateway
    - Detect access token expiry
    - Call Keycloak token endpoint with refresh_token grant
    - Update session with new tokens
    - **Validation**: Wait for expiry, next request auto-refreshes, logs show refresh flow

  3. **T3.3 - Frontend Refresh Strategy (30 min)**:
    - Create REST endpoint demonstrating refresh flow for frontend
    - Show proactive refresh (before expiry) vs reactive
    - Handle refresh token expiry (force re-login)
    - **Validation**: Simulate expired refresh token, verify re-login required

  ---

  ## PHASE 4: LOGOUT & TOKEN REVOCATION (Est: 2 hours)
  **Reference**: keycloak_full_flow.mmd steps 56-67  
  **Goal**: Secure logout with token invalidation and blacklisting

  ### Tasks
  1. **T4.1 - Keycloak Logout Integration (30 min)**:
    - Implement logout endpoint calling Keycloak `/logout`
    - Clear gateway session
    - Implement post-logout redirect
    - **Validation**: Logout invalidates Keycloak session, old token rejected

  2. **T4.2 - Token Blacklisting Strategy (60 min)**:
    - Design token blacklist approach (Redis, in-memory, database)
    - Implement blacklist check in gateway filter
    - Add blacklist check in microservice
    - Handle race conditions
    - **Validation**: Revoked token rejected even before expiry

  3. **T4.3 - Distributed Logout Events (30 min)**:
    - Implement event publishing on logout (Redis pub/sub or webhook)
    - Subscribe in gateway and microservices
    - Update blacklist across all instances
    - **Validation**: Logout propagates to all services, revoked token fails everywhere

  ---

  ## PHASE 5: SERVICE-TO-SERVICE (CLIENT CREDENTIALS) (Est: 2.5 hours)
  **Reference**: keycloak_full_flow.mmd steps 68-72  
  **Goal**: Backend services authenticate without user context

  ### Tasks
  1. **T5.1 - Service Account Configuration (30 min)**:
    - Create service account client in Keycloak
    - Configure client credentials grant
    - Assign service roles
    - **Validation**: Manual curl to get service token, inspect claims

  2. **T5.2 - Service Client Implementation (60 min)**:
    - Create second microservice (e.g., `order-service`)
    - Implement OAuth2 client credentials flow
    - Create RestTemplate/WebClient with automatic token acquisition
    - Call user-service from order-service
    - **Validation**: Service-to-service call succeeds with service token

  3. **T5.3 - Token Caching & Reuse (30 min)**:
    - Implement service token caching (don't request every call)
    - Handle token expiry and refresh
    - Add token reuse strategy
    - **Validation**: Multiple calls reuse same token, auto-refresh on expiry

  4. **T5.4 - User vs Service Token Context (30 min)**:
    - Implement endpoint that accepts both user and service tokens
    - Extract different claims from each
    - Show when to use which flow
    - **Validation**: Same endpoint handles both token types correctly

  ---

  ## PHASE 6: PRODUCTION HARDENING (Est: 2 hours)
  **Goal**: Security best practices, error handling, monitoring

  ### Tasks
  1. **T6.1 - Security Headers & CORS (30 min)**:
    - Implement security headers (CSP, X-Frame-Options, etc.)
    - Configure CORS properly
    - Add rate limiting
    - **Validation**: Security scan shows proper headers

  2. **T6.2 - Error Handling (45 min)**:
    - Custom error responses (don't leak stack traces)
      - Handle all OAuth2 error scenarios
      - Implement retry logic for Keycloak calls
      - **Validation**: Kill Keycloak, verify graceful degradation

    3. **T6.3 - Logging & Monitoring (45 min)**:
       - Structured logging (JSON format)
       - Log authentication events and audit trails
       - Add metrics (token validation time, refresh count)
       - Implement health checks and readiness/liveness probes
       - **Validation**: Demonstrate audit trail for security events

    ---

    ## TOTAL ESTIMATED TIME: 15-17 hours
    - Phase 0: 1 hour
    - Phase 1: 3.5 hours
    - Phase 2: 4 hours
    - Phase 3: 2 hours
    - Phase 4: 2 hours
    - Phase 5: 2.5 hours
    - Phase 6: 2 hours

    ## Session Progress Tracker
    - [ ] Phase 0: Environment Setup
    - [ ] Phase 1: Authorization Code Flow
    - [ ] Phase 2: Token Validation & Microservices
    - [ ] Phase 3: Token Refresh
    - [ ] Phase 4: Logout & Revocation
    - [ ] Phase 5: Service-to-Service
    - [ ] Phase 6: Production Hardening



OAuth2 Flows to Cover:
Authorization Code flow
Client Credentials flow
Token exchange patterns
Refresh token handling

Key Learning Areas:
Keycloak realm/client/user configuration
Gateway token validation
Token forwarding to downstream services
Resource server JWT validation
Production security best practices

Technology Stack:
Spring Boot 3.2+
Java 17 or 21
Spring Cloud Gateway
Spring Security OAuth2 Resource Server
Keycloak (latest stable)
Docker Compose

Expected Timeline: 3.5-5 hours total (can split into 2-3 sessions)

Current Progress: [UPDATE THIS EACH SESSION]
Session 1: Not started / Completed Step X / etc.

How to Teach:
Give me one step at a time
Tell me exactly what to create/configure
Wait for me to share my implementation
Validate and explain before moving to next step
For key design decisions, ask me to implement solutions with guidance