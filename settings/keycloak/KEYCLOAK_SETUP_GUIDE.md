# Keycloak Setup Guide - Step by Step

**Project:** Spring Cloud Gateway with Keycloak OAuth2/OIDC
**Purpose:** Complete tutorial for configuring Keycloak from scratch
**Author:** Setup Guide for dev-realm project

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Keycloak Installation (Docker)](#2-keycloak-installation-docker)
3. [Access Keycloak Admin Console](#3-access-keycloak-admin-console)
4. [Create Realm](#4-create-realm)
5. [Create Client](#5-create-client)
6. [Create Roles](#6-create-roles)
7. [Create Users](#7-create-users)
8. [Assign Roles to Users](#8-assign-roles-to-users)
9. [Verify Configuration](#9-verify-configuration)
10. [Export Realm Configuration](#10-export-realm-configuration-optional)

---

## 1. Prerequisites

### Required Software
- Docker and Docker Compose installed
- Text editor
- Web browser
- Terminal/Command line

### Ports to Be Used
- `3081` - Keycloak server
- `8080` - Spring Cloud Gateway (your application)

---

## 2. Keycloak Installation (Docker)

### Step 2.1: Create docker-compose.yml

Create a file named `docker-compose.yml` in your project root:

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

**Configuration Explanation:**
- `image`: Official Keycloak image from Quay.io
- `KEYCLOAK_ADMIN`: Admin username (set to "admin")
- `KEYCLOAK_ADMIN_PASSWORD`: Admin password (set to "admin")
- `ports`: Map host port 3081 to container port 8080
- `command: start-dev`: Run in development mode (not for production!)

### Step 2.2: Start Keycloak

```bash
# Start Keycloak in detached mode
docker-compose up -d

# Check if container is running
docker-compose ps

# View logs (wait until you see "Keycloak started")
docker-compose logs -f keycloak
```

**Expected Output:**
```
keycloak  | ...
keycloak  | Keycloak 23.0.x (or later)
keycloak  | Running the server in development mode...
keycloak  | Listening on: http://0.0.0.0:8080
```

### Step 2.3: Verify Keycloak is Running

Open browser and navigate to: **http://localhost:3081**

You should see the Keycloak welcome page.

---

## 3. Access Keycloak Admin Console

### Step 3.1: Open Admin Console

1. Go to: **http://localhost:3081**
2. Click **"Administration Console"** button
3. You'll be redirected to: http://localhost:3081/admin

### Step 3.2: Login

**Credentials:**
- Username: `admin`
- Password: `admin`

### Step 3.3: Verify Access

After login, you should see:
- Keycloak Admin Console dashboard
- Left sidebar with menu items:
  - Realm Settings
  - Clients
  - Client scopes
  - Realm roles
  - Users
  - Groups
  - Sessions
  - Events
- Top-left shows current realm: **"master"**

⚠️ **Important:** The "master" realm is for Keycloak administration only. Never use it for your applications!

---

## 4. Create Realm

A **Realm** is an isolated namespace that manages a set of users, credentials, roles, and groups.

### Step 4.1: Open Realm Creation

1. **Hover** over the **"master"** dropdown in the top-left corner
2. Click the **dropdown arrow**
3. Click **"Create Realm"** button

### Step 4.2: Configure Realm

Fill in the form:

| Field | Value | Description |
|-------|-------|-------------|
| **Realm name** | `dev-realm` | Unique identifier for your realm |
| **Enabled** | ✅ ON | Realm is active |

### Step 4.3: Create

Click **"Create"** button at the bottom.

### Step 4.4: Verify Realm Creation

- You should be automatically switched to the new realm
- Top-left dropdown should now show **"dev-realm"**
- Left sidebar shows the same menu items, but now for dev-realm

**Realm URL Pattern:**
```
http://localhost:3081/realms/{realm-name}
http://localhost:3081/realms/dev-realm  ← Your realm
```

---

## 5. Create Client

A **Client** represents an application that uses Keycloak for authentication.

### Step 5.1: Navigate to Clients

1. Ensure you're in **"dev-realm"** (check top-left)
2. Click **"Clients"** in the left sidebar
3. You'll see a list of default clients (account, admin-cli, etc.)

### Step 5.2: Create New Client

Click **"Create client"** button (top-right)

### Step 5.3: General Settings (Page 1)

Fill in the form:

| Field | Value | Description |
|-------|-------|-------------|
| **Client type** | `OpenID Connect` | OAuth2/OIDC protocol |
| **Client ID** | `app-client` | Unique client identifier |
| **Name** | `Spring Cloud Gateway Client` | Display name (optional) |
| **Description** | `OAuth2 client for gateway` | Optional description |
| **Always display in UI** | ❌ OFF | Don't show in account console |

Click **"Next"**

### Step 5.4: Capability Config (Page 2)

Configure authentication and flows:

| Field | Value | Why? |
|-------|-------|------|
| **Client authentication** | ✅ **ON** | Makes it a confidential client (has secret) |
| **Authorization** | ❌ OFF | Don't need fine-grained authorization |
| **Authentication flow** | | |
| - Standard flow | ✅ **ON** | Enable Authorization Code flow |
| - Direct access grants | ✅ **ON** | For testing with Postman/curl |
| - Implicit flow | ❌ OFF | Deprecated, insecure |
| - Service accounts roles | ❌ OFF | Not needed for user login |
| - OAuth 2.0 Device Authorization Grant | ❌ OFF | Not needed |

Click **"Next"**

### Step 5.5: Login Settings (Page 3)

Configure redirect URIs and origins:

| Field | Value | Description |
|-------|-------|-------------|
| **Root URL** | (leave empty) | Optional base URL |
| **Home URL** | (leave empty) | Optional home page |
| **Valid redirect URIs** | `http://localhost:8080/login/oauth2/code` | Where Keycloak redirects after login |
| | `http://localhost:8080/login/oauth2/code/*` | Wildcard variant (optional) |
| **Valid post logout redirect URIs** | `http://localhost:8080/` | Where to redirect after logout |
| **Web origins** | `http://localhost:8080` | CORS - allowed origins |
| **Admin URL** | (leave empty) | Optional admin endpoint |

**Important Notes:**
- **Redirect URI** must EXACTLY match what Spring Security expects
- Use `*` wildcard if you have multiple OAuth2 providers
- Multiple URIs can be added (click the "+" icon)

Click **"Save"**

### Step 5.6: Get Client Secret

After saving, you'll see the client details page.

1. Click the **"Credentials"** tab (top tabs)
2. You'll see:
   - **Client Authenticator:** "Client Id and Secret"
   - **Client Secret:** `••••••••••••••••••••••••••••` (masked)

3. **Copy the secret:**
   - Click the **eye icon** (👁️) to reveal the secret
   - Click the **copy icon** (📋) to copy to clipboard
   - **Save this secret!** You'll need it in Spring configuration

Example secret: `mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF`

### Step 5.7: Verify Client Settings

Go back to **"Settings"** tab and verify:

**Capability Config Section:**
```
Client authentication: ON
Authorization: OFF
Standard flow: Enabled
Direct access grants: Enabled
```

**Access Settings Section:**
```
Valid redirect URIs: http://localhost:8080/login/oauth2/code
Valid post logout redirect URIs: http://localhost:8080/
Web origins: http://localhost:8080
```

---

## 6. Create Roles

**Roles** define permissions and are included in JWT tokens.

### Step 6.1: Understanding Role Types

| Role Type | Scope | When to Use |
|-----------|-------|-------------|
| **Realm Roles** | Global (all clients) | Shared roles across multiple applications |
| **Client Roles** | Specific to one client | Roles specific to one application |

For this project, we'll create **Client Roles** (app-client specific).

### Step 6.2: Navigate to Client Roles

1. Click **"Clients"** in left sidebar
2. Click on **"app-client"** in the list
3. Click the **"Roles"** tab (top tabs)

### Step 6.3: Create ROLE_USER

1. Click **"Create role"** button
2. Fill in the form:

| Field | Value |
|-------|-------|
| **Role name** | `ROLE_USER` |
| **Description** | `Standard user role` |

3. Click **"Save"**

**Why "ROLE_" prefix?**
- Spring Security expects roles to start with `ROLE_` by default
- Without it, you need custom configuration
- Standard convention in Spring ecosystem

### Step 6.4: Create ROLE_ADMIN

1. Click **"Create role"** button again
2. Fill in the form:

| Field | Value |
|-------|-------|
| **Role name** | `ROLE_ADMIN` |
| **Description** | `Administrator role` |

3. Click **"Save"**

### Step 6.5: Verify Roles

You should now see both roles in the list:

| Role name | Description | Composite |
|-----------|-------------|-----------|
| ROLE_ADMIN | Administrator role | False |
| ROLE_USER | Standard user role | False |

---

## 7. Create Users

**Users** are entities that can authenticate and get tokens.

### Step 7.1: Navigate to Users

1. Ensure you're in **"dev-realm"**
2. Click **"Users"** in the left sidebar
3. You'll see an empty users list (or default users)

### Step 7.2: Create User "john"

#### 7.2.1: Create User

1. Click **"Create new user"** button (or "Add user")
2. Fill in the form:

| Field | Value | Required? |
|-------|-------|-----------|
| **Username** | `john` | ✅ Yes |
| **Email** | `john@test.com` | No |
| **Email verified** | ✅ ON | No (but recommended for testing) |
| **First name** | `John` | No |
| **Last name** | `Doe` | No |
| **Enabled** | ✅ ON | Yes (user can login) |

3. Click **"Create"**

#### 7.2.2: Set Password

After creating the user, you'll be on the user details page.

1. Click the **"Credentials"** tab
2. Click **"Set password"** button
3. Fill in the form:

| Field | Value | Important! |
|-------|-------|------------|
| **Password** | `john123` | |
| **Password confirmation** | `john123` | Must match |
| **Temporary** | ❌ **OFF** | If ON, user must change password on first login |

4. Click **"Save"**
5. Confirm in the popup dialog

**Verify:**
- You should see "Password set" message
- Credentials tab shows password was set

### Step 7.3: Create User "admin"

Repeat the same process for admin user:

#### 7.3.1: Create User

1. Go back to Users list (click "Users" in left sidebar)
2. Click **"Create new user"**
3. Fill in:

| Field | Value |
|-------|-------|
| **Username** | `admin` |
| **Email** | `admin@test.com` |
| **Email verified** | ✅ ON |
| **First name** | `Admin` |
| **Last name** | `User` |
| **Enabled** | ✅ ON |

4. Click **"Create"**

#### 7.3.2: Set Password

1. Click **"Credentials"** tab
2. Click **"Set password"**
3. Fill in:

| Field | Value |
|-------|-------|
| **Password** | `admin123` |
| **Password confirmation** | `admin123` |
| **Temporary** | ❌ OFF |

4. Click **"Save"** and confirm

### Step 7.4: Verify Users

Go to **Users** in left sidebar. You should see:

| Username | Email | Email Verified | Enabled |
|----------|-------|----------------|---------|
| john | john@test.com | ✅ | ✅ |
| admin | admin@test.com | ✅ | ✅ |

---

## 8. Assign Roles to Users

Now we assign the roles we created to each user.

### Step 8.1: Assign Role to "john"

#### 8.1.1: Open User

1. Click **"Users"** in left sidebar
2. Click on **"john"** in the users list

#### 8.1.2: Open Role Mapping

1. Click the **"Role mapping"** tab (top tabs)
2. You'll see a list of available roles

#### 8.1.3: Assign ROLE_USER

1. Click **"Assign role"** button
2. In the dialog, you'll see various roles
3. **Filter by client roles:**
   - Look for a **filter dropdown** (might say "Filter by realm roles")
   - Change it to **"Filter by clients"**
   - Select **"app-client"**
4. You should now see:
   - `ROLE_USER`
   - `ROLE_ADMIN`
5. **Check the box** next to `ROLE_USER`
6. Click **"Assign"** button

#### 8.1.4: Verify Assignment

The "Role mapping" tab should now show:

**Assigned roles:**
| Name | Inherited | Description |
|------|-----------|-------------|
| app-client ROLE_USER | False | Standard user role |

Plus some inherited default roles (manage-account, view-profile, etc.)

### Step 8.2: Assign Roles to "admin"

#### 8.2.1: Open User

1. Go back to **Users** list
2. Click on **"admin"**

#### 8.2.2: Assign Both Roles

1. Click **"Role mapping"** tab
2. Click **"Assign role"** button
3. Filter by clients → **"app-client"**
4. **Check BOTH boxes:**
   - ✅ `ROLE_USER`
   - ✅ `ROLE_ADMIN`
5. Click **"Assign"**

#### 8.2.3: Verify Assignment

The "Role mapping" tab should now show:

**Assigned roles:**
| Name | Inherited | Description |
|------|-----------|-------------|
| app-client ROLE_USER | False | Standard user role |
| app-client ROLE_ADMIN | False | Administrator role |

---

## 9. Verify Configuration

### Step 9.1: Verify Realm

1. Click realm dropdown (top-left)
2. Select **"dev-realm"**
3. Click **"Realm settings"** in left sidebar
4. Verify **"Enabled"** is ON

### Step 9.2: Verify Client

1. Click **"Clients"** → **"app-client"**
2. **Settings tab:**
   - Client ID: `app-client`
   - Client authentication: ON
   - Standard flow: Enabled
3. **Credentials tab:**
   - Client secret exists (copy it!)
4. **Roles tab:**
   - `ROLE_USER` exists
   - `ROLE_ADMIN` exists

### Step 9.3: Verify Users

1. Click **"Users"**
2. Search for "john" → Check roles (ROLE_USER)
3. Search for "admin" → Check roles (ROLE_USER, ROLE_ADMIN)

### Step 9.4: Test OIDC Discovery Endpoint

```bash
curl http://localhost:3081/realms/dev-realm/.well-known/openid-configuration | jq
```

**Expected:** JSON with OIDC configuration including:
- `issuer`
- `authorization_endpoint`
- `token_endpoint`
- `jwks_uri`
- etc.

### Step 9.5: Test JWKS Endpoint

```bash
curl http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs | jq
```

**Expected:** JSON with public keys for JWT signature verification.

---

## 10. Export Realm Configuration (Optional)

### Why Export?

- Backup your configuration
- Version control
- Share with team members
- Recreate realm on another environment

### Step 10.1: Export via Admin Console

1. Click **"Realm settings"**
2. Click **"Action"** dropdown (top-right)
3. Select **"Partial export"**
4. Check options:
   - ✅ Export clients
   - ✅ Export groups and roles
   - ✅ Export users
5. Click **"Export"**
6. Save the JSON file

### Step 10.2: Export via CLI (Advanced)

```bash
# Export realm to file
docker exec -it keycloak /opt/keycloak/bin/kc.sh export \
  --realm dev-realm \
  --file /tmp/dev-realm-export.json

# Copy file from container
docker cp keycloak:/tmp/dev-realm-export.json ./dev-realm-export.json
```

### Step 10.3: Import Realm (Future Use)

To import on another Keycloak instance:

1. Admin Console → Create Realm
2. Click **"Browse"** and select JSON file
3. Click **"Create"**

---

## 11. Configuration Summary Table

### Complete Configuration Checklist

| Component | Name/Value | Status |
|-----------|------------|--------|
| **Keycloak Server** | http://localhost:3081 | ✅ |
| **Admin User** | admin / admin | ✅ |
| **Realm** | dev-realm | ✅ |
| **Client** | app-client | ✅ |
| **Client Secret** | mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF | ✅ |
| **Redirect URI** | http://localhost:8080/login/oauth2/code | ✅ |
| **Client Roles** | ROLE_USER, ROLE_ADMIN | ✅ |
| **User: john** | john / john123 | ✅ |
| **User: admin** | admin / admin123 | ✅ |
| **john roles** | ROLE_USER | ✅ |
| **admin roles** | ROLE_USER, ROLE_ADMIN | ✅ |

---

## 12. Common Issues & Troubleshooting

### Issue 1: Can't Access Keycloak

**Symptoms:** http://localhost:3081 doesn't load

**Solutions:**
```bash
# Check if container is running
docker-compose ps

# Check logs
docker-compose logs -f keycloak

# Restart
docker-compose restart keycloak
```

### Issue 2: Wrong Redirect URI Error

**Symptoms:** "Invalid redirect_uri" error during login

**Solution:**
1. Check client settings: Clients → app-client → Settings
2. Verify "Valid redirect URIs" matches exactly
3. No trailing slashes
4. Correct port number

### Issue 3: Roles Not Appearing in Token

**Symptoms:** JWT token doesn't contain roles

**Solution:**
1. Verify user has roles assigned
2. Check role mapping: Users → {username} → Role mapping
3. Ensure roles are from correct client (app-client)
4. Restart Spring application

### Issue 4: Invalid Client Secret

**Symptoms:** "Invalid client credentials" error

**Solution:**
1. Go to: Clients → app-client → Credentials
2. Copy the secret (click eye icon, then copy)
3. Update Spring `application.yml`
4. Restart application

### Issue 5: User Can't Login

**Symptoms:** "Invalid username or password"

**Checklist:**
- [ ] User is enabled (Users → {username} → Details)
- [ ] User is in correct realm (dev-realm)
- [ ] Password is set (Credentials tab)
- [ ] Password is not temporary
- [ ] Email verified (if required)

---

## 13. Next Steps

After completing this Keycloak setup:

1. ✅ Configure Spring Security OAuth2 Client
2. ✅ Add client-id and client-secret to `application.yml`
3. ✅ Create SecurityConfig.java
4. ✅ Test OAuth2 login flow
5. ✅ Inspect JWT tokens
6. ✅ Implement role-based authorization

---

## 14. Reference Links

### Keycloak Endpoints

```
Base: http://localhost:3081/realms/dev-realm

OIDC Discovery:  /.well-known/openid-configuration
Authorization:   /protocol/openid-connect/auth
Token:           /protocol/openid-connect/token
UserInfo:        /protocol/openid-connect/userinfo
JWKS:            /protocol/openid-connect/certs
Logout:          /protocol/openid-connect/logout
```

### Admin Console Paths

```
Admin Console:   http://localhost:3081/admin
Realm Settings:  /admin/master/console/#/dev-realm/realm-settings
Clients:         /admin/master/console/#/dev-realm/clients
Users:           /admin/master/console/#/dev-realm/users
Roles:           /admin/master/console/#/dev-realm/roles
```

### Documentation

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [OAuth 2.0 Spec](https://oauth.net/2/)
- [OpenID Connect Spec](https://openid.net/connect/)

---

## 15. Quick Commands Reference

### Docker Commands

```bash
# Start Keycloak
docker-compose up -d

# Stop Keycloak
docker-compose down

# View logs
docker-compose logs -f keycloak

# Restart
docker-compose restart keycloak

# Access container shell
docker exec -it keycloak bash
```

### Testing Commands

```bash
# Test OIDC discovery
curl http://localhost:3081/realms/dev-realm/.well-known/openid-configuration

# Test JWKS endpoint
curl http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs

# Get token (direct access grant)
curl -X POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=app-client" \
  -d "client_secret=YOUR_SECRET" \
  -d "grant_type=password" \
  -d "username=john" \
  -d "password=john123"
```

---

**End of Keycloak Setup Guide**

This guide covers the complete setup of Keycloak for OAuth2/OIDC integration with Spring Cloud Gateway. Follow each step carefully, and verify at each checkpoint.
