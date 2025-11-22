# DNS Resolution vs KC_HOSTNAME - What Does What?

## TL;DR

| Component | Purpose | Resolves DNS? |
|-----------|---------|---------------|
| `/etc/hosts` entry | Maps `keycloak.local` → `172.20.0.10` | **YES** ✅ |
| `KC_HOSTNAME` | Tells Keycloak what hostname to expect | **NO** ❌ |
| `ipv4_address: 172.20.0.10` | Assigns static IP to container | **NO** ❌ |
| `ports: 3081:8080` | Maps host port to container port | **NO** ❌ |

**Only `/etc/hosts` resolves DNS!**

---

## How DNS Resolution Works

### Step-by-Step Flow

```
1. Application makes request: http://keycloak.local:3081/token
                                    ↓
2. OS needs to resolve "keycloak.local" to an IP address
                                    ↓
3. OS checks /etc/hosts first:
   
   /etc/hosts:
   172.20.0.10 keycloak.local  ← Found it!
                                    ↓
4. OS returns: 172.20.0.10
                                    ↓
5. Application connects to: 172.20.0.10:3081
                                    ↓
6. Port mapping forwards: 3081 → container:8080
                                    ↓
7. Request reaches Keycloak container
```

### Without /etc/hosts Entry

```
1. Application makes request: http://keycloak.local:3081/token
                                    ↓
2. OS needs to resolve "keycloak.local"
                                    ↓
3. OS checks /etc/hosts: Not found
                                    ↓
4. OS queries DNS servers: Not found
                                    ↓
5. ERROR: UnknownHostException: keycloak.local ❌
```

---

## What Each Component Does

### 1. /etc/hosts Entry

**File:** `/etc/hosts`

**Content:**
```
172.20.0.10 keycloak.local
```

**Purpose:** DNS resolution (hostname → IP address)

**What it does:**
- Maps the hostname `keycloak.local` to IP `172.20.0.10`
- OS checks this file BEFORE querying DNS servers
- Works for ALL applications on the host

**Test it:**
```bash
# This uses /etc/hosts
getent hosts keycloak.local
# Output: 172.20.0.10 keycloak.local

# This also uses /etc/hosts
ping keycloak.local
# PING keycloak.local (172.20.0.10): 56 data bytes

# This also uses /etc/hosts
curl http://keycloak.local:3081
# Connects to 172.20.0.10:3081
```

### 2. KC_HOSTNAME Environment Variable

**File:** `docker-compose.yml`

**Content:**
```yaml
environment:
  KC_HOSTNAME: keycloak.local
```

**Purpose:** Keycloak's hostname validation and URL generation

**What it does:**
- Tells Keycloak: "Expect requests with Host header: keycloak.local"
- Keycloak uses this to generate URLs in responses
- Keycloak validates incoming Host headers against this

**Does NOT affect DNS resolution!**

#### Example: Hostname Validation

When a request comes in:

```http
GET /realms/dev-realm/.well-known/openid-configuration HTTP/1.1
Host: keycloak.local:3081
```

Keycloak checks:
```java
// Pseudo-code inside Keycloak
String requestHost = request.getHeader("Host"); // "keycloak.local:3081"
String expectedHost = System.getenv("KC_HOSTNAME"); // "keycloak.local"

if (KC_HOSTNAME_STRICT && !requestHost.startsWith(expectedHost)) {
    throw new HostnameMismatchException();
}
```

#### Example: URL Generation

When Keycloak generates OIDC discovery document:

```yaml
# With KC_HOSTNAME: keycloak.local
environment:
  KC_HOSTNAME: keycloak.local
```

Response:
```json
{
  "issuer": "http://keycloak.local:3081/realms/dev-realm",
  "authorization_endpoint": "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/auth",
  "token_endpoint": "http://keycloak.local:3081/realms/dev-realm/protocol/openid-connect/token"
}
```

```yaml
# With KC_HOSTNAME: localhost
environment:
  KC_HOSTNAME: localhost
```

Response:
```json
{
  "issuer": "http://localhost:3081/realms/dev-realm",
  "authorization_endpoint": "http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth",
  "token_endpoint": "http://localhost:3081/realms/dev-realm/protocol/openid-connect/token"
}
```

**Notice:** The URLs change based on `KC_HOSTNAME`!

### 3. Static IP Address

**File:** `docker-compose.yml`

**Content:**
```yaml
networks:
  keycloak-net:
    ipv4_address: 172.20.0.10
```

**Purpose:** Assign a specific IP to the container

**What it does:**
- Docker assigns `172.20.0.10` to the container
- IP stays the same across container restarts
- Makes `/etc/hosts` entry stable

**Does NOT affect DNS resolution!**

Without static IP:
```yaml
networks:
  - keycloak-net  # Docker assigns random IP
```

- First start: `172.20.0.5`
- Restart: `172.20.0.8`
- Restart again: `172.20.0.3`

Your `/etc/hosts` entry would become invalid!

### 4. Port Mapping

**File:** `docker-compose.yml`

**Content:**
```yaml
ports:
  - "3081:8080"
```

**Purpose:** Forward host port to container port

**What it does:**
- Listens on host port `3081`
- Forwards traffic to container port `8080`
- Allows host to access container service

**Does NOT affect DNS resolution!**

Flow:
```
Request to: keycloak.local:3081
            ↓
DNS resolves: 172.20.0.10:3081
            ↓
Port mapping: 3081 → container:8080
            ↓
Keycloak receives on: :8080
```

---

## Why We Need Both /etc/hosts AND KC_HOSTNAME

### Scenario 1: Only /etc/hosts, No KC_HOSTNAME Match

```bash
# /etc/hosts
172.20.0.10 keycloak.local
```

```yaml
# docker-compose.yml
environment:
  KC_HOSTNAME: localhost  # ❌ Mismatch!
```

**What happens:**

1. DNS works fine:
   ```bash
   curl http://keycloak.local:3081
   # Resolves to 172.20.0.10 ✅
   ```

2. But Keycloak might complain:
   ```
   Request Host: keycloak.local
   Expected Host: localhost
   ⚠️ Hostname mismatch warning
   ```

3. Keycloak generates wrong URLs:
   ```json
   {
     "issuer": "http://localhost:3081/realms/dev-realm"
   }
   ```
   
   But your app expects:
   ```yaml
   issuer-uri: http://keycloak.local:3081/realms/dev-realm
   ```
   
   **Result:** Token validation might fail! ❌

### Scenario 2: KC_HOSTNAME Set, No /etc/hosts

```yaml
# docker-compose.yml
environment:
  KC_HOSTNAME: keycloak.local  # ✅ Set correctly
```

```bash
# /etc/hosts
# (no entry for keycloak.local) ❌
```

**What happens:**

1. DNS fails:
   ```bash
   curl http://keycloak.local:3081
   # UnknownHostException: keycloak.local ❌
   ```

2. Application can't connect:
   ```
   java.net.UnknownHostException: keycloak.local
   ```

3. Keycloak's KC_HOSTNAME setting doesn't help because requests never reach it!

### Scenario 3: Both Configured Correctly ✅

```bash
# /etc/hosts
172.20.0.10 keycloak.local
```

```yaml
# docker-compose.yml
environment:
  KC_HOSTNAME: keycloak.local
```

**What happens:**

1. DNS works:
   ```bash
   curl http://keycloak.local:3081
   # Resolves to 172.20.0.10 ✅
   ```

2. Keycloak accepts request:
   ```
   Request Host: keycloak.local
   Expected Host: keycloak.local
   ✅ Match!
   ```

3. Keycloak generates correct URLs:
   ```json
   {
     "issuer": "http://keycloak.local:3081/realms/dev-realm"
   }
   ```
   
   Matches your app config:
   ```yaml
   issuer-uri: http://keycloak.local:3081/realms/dev-realm
   ```
   
   **Result:** Everything works! ✅

---

## Real-World Example

### Complete Configuration

```yaml
# docker-compose.yml
services:
  keycloak:
    environment:
      KC_HOSTNAME: keycloak.local        # ← Keycloak's expected hostname
      KC_HOSTNAME_STRICT: false          # ← Allow some flexibility
    networks:
      keycloak-net:
        ipv4_address: 172.20.0.10        # ← Static IP
    ports:
      - "3081:8080"                      # ← Port mapping
```

```bash
# /etc/hosts
172.20.0.10 keycloak.local               # ← DNS resolution
```

```yaml
# application-proxy.yml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: http://keycloak.local:3081/realms/dev-realm
```

### Request Flow

```
1. App makes request: http://keycloak.local:3081/token
                                    ↓
2. OS checks /etc/hosts:
   keycloak.local → 172.20.0.10 ✅
                                    ↓
3. App connects to: 172.20.0.10:3081
                                    ↓
4. Port mapping: 3081 → container:8080
                                    ↓
5. Request reaches Keycloak with header:
   Host: keycloak.local:3081
                                    ↓
6. Keycloak checks KC_HOSTNAME:
   "keycloak.local" == "keycloak.local" ✅
                                    ↓
7. Keycloak processes request
                                    ↓
8. Keycloak generates response with URLs:
   "issuer": "http://keycloak.local:3081/realms/dev-realm"
                                    ↓
9. App validates issuer:
   Expected: http://keycloak.local:3081/realms/dev-realm
   Got:      http://keycloak.local:3081/realms/dev-realm
   ✅ Match!
```

---

## Common Misconceptions

### ❌ "KC_HOSTNAME resolves DNS"

**Wrong!** `KC_HOSTNAME` is a Keycloak configuration, not a DNS setting.

DNS resolution is handled by:
- `/etc/hosts` (local)
- DNS servers (network)
- Not by application environment variables!

### ❌ "Static IP makes hostname accessible"

**Wrong!** Static IP just ensures the container always gets the same IP.

You still need:
- `/etc/hosts` to map hostname → IP
- Port mapping to access from host

### ❌ "Port mapping affects DNS"

**Wrong!** Port mapping only forwards traffic between ports.

DNS resolution happens before port mapping:
```
DNS: keycloak.local → 172.20.0.10
Then: Connect to 172.20.0.10:3081
Then: Port mapping forwards to container:8080
```

---

## Testing Each Component

### Test DNS Resolution (/etc/hosts)

```bash
# Test 1: Check /etc/hosts entry
cat /etc/hosts | grep keycloak.local
# Expected: 172.20.0.10 keycloak.local

# Test 2: Resolve hostname
getent hosts keycloak.local
# Expected: 172.20.0.10 keycloak.local

# Test 3: Ping (uses DNS)
ping -c 1 keycloak.local
# Expected: PING keycloak.local (172.20.0.10)

# Test 4: DNS lookup
nslookup keycloak.local
# Expected: Address: 172.20.0.10
```

### Test Static IP

```bash
# Get container IP
docker inspect keycloak | grep IPAddress
# Expected: "IPAddress": "172.20.0.10"

# Restart container
docker-compose restart keycloak

# Check IP again
docker inspect keycloak | grep IPAddress
# Expected: "IPAddress": "172.20.0.10" (same!)
```

### Test Port Mapping

```bash
# Check port mapping
docker port keycloak
# Expected: 8080/tcp -> 0.0.0.0:3081

# Test connection via mapped port
curl http://keycloak.local:3081
# Expected: HTML response from Keycloak

# Test connection via container IP (won't work from host with Colima)
curl http://172.20.0.10:8080
# Expected: Connection refused (Colima VM isolation)
```

### Test KC_HOSTNAME

```bash
# Make request with correct hostname
curl -H "Host: keycloak.local:3081" http://172.20.0.10:3081/realms/dev-realm/.well-known/openid-configuration
# Expected: JSON response with URLs using keycloak.local

# Make request with wrong hostname
curl -H "Host: wrong.local:3081" http://172.20.0.10:3081/realms/dev-realm/.well-known/openid-configuration
# Expected: Might work (KC_HOSTNAME_STRICT: false) but could show warnings in logs
```

---

## Summary

| Component | What It Does | Example |
|-----------|--------------|---------|
| `/etc/hosts` | **Resolves DNS**: hostname → IP | `keycloak.local` → `172.20.0.10` |
| `KC_HOSTNAME` | **Validates Host header** in requests | Request must have `Host: keycloak.local` |
| `KC_HOSTNAME` | **Generates URLs** in responses | `"issuer": "http://keycloak.local:3081/..."` |
| `ipv4_address` | **Assigns static IP** to container | Container always gets `172.20.0.10` |
| `ports` | **Forwards traffic** between ports | `host:3081` → `container:8080` |

**Key Insight:**

- **DNS resolution** = `/etc/hosts` (or DNS servers)
- **Hostname validation** = `KC_HOSTNAME`
- They serve **different purposes** but must **match** for everything to work!

---

## Analogy

Think of it like a restaurant:

- **`/etc/hosts`** = GPS/Map (tells you where the restaurant is located)
- **`KC_HOSTNAME`** = Restaurant's name on the door (what name they expect you to ask for)
- **`ipv4_address`** = Street address that never changes
- **`ports`** = Door number (which door to enter)

You need:
1. GPS to find the location (DNS resolution)
2. Correct restaurant name to be let in (hostname validation)
3. Stable address so GPS works (static IP)
4. Right door to enter (port mapping)

All pieces work together! 🎯

