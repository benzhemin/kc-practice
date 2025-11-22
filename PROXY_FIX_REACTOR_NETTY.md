# THE REAL FIX: Reactor Netty Proxy Configuration

## The Problem

Even after setting JVM system properties (`http.proxyHost`, etc.), the traffic is **STILL going directly** to Keycloak (port 3081) instead of through mitmproxy (port 8888).

### Evidence from Logs

```
Line 64: [b7b07dc6-1, L:/127.0.0.1:65092 - R:localhost/127.0.0.1:3081]
                                                                  ^^^^
                                                          Direct to Keycloak!
```

Should be connecting to port 8888 (proxy), not 3081 (Keycloak).

## Root Cause

**Reactor Netty does NOT respect JVM system properties for proxy!**

- Traditional Java HTTP clients (like `HttpURLConnection`) use `http.proxyHost` and `http.proxyPort`
- **Reactor Netty** (used by Spring WebFlux) ignores these properties
- Spring Security's OAuth2 client uses Reactor Netty internally
- Therefore, setting system properties has NO EFFECT

## The Solution

Created `WebClientProxyCustomizer.java` which implements `WebClientCustomizer`.

This interface is **automatically detected by Spring Boot** and applied to **ALL WebClient instances**, including the one used by Spring Security OAuth2.

### What Was Added

**File:** `src/main/java/com/zz/gateway/auth/config/WebClientProxyCustomizer.java`

```java
@Configuration
public class WebClientProxyCustomizer implements WebClientCustomizer {
    
    @Override
    public void customize(WebClient.Builder webClientBuilder) {
        if (proxyEnabled) {
            HttpClient httpClient = HttpClient.create()
                    .proxy(proxy -> proxy
                            .type(ProxyProvider.Proxy.HTTP)
                            .host(proxyHost)
                            .port(proxyPort));

            webClientBuilder.clientConnector(
                new ReactorClientHttpConnector(httpClient)
            );
        }
    }
}
```

This is applied to:
- ✅ Your custom WebClient beans
- ✅ Spring Security OAuth2 client's internal WebClient
- ✅ ANY WebClient created in the application

## How to Test

### Step 1: RESTART Your Spring Boot App

**CRITICAL:** You MUST restart for the new configuration to take effect.

```bash
# Stop current app (Ctrl+C)

# Restart
./gradlew bootRun
```

### Step 2: Look for New Log Message

```
═══════════════════════════════════════════════════════════
🔧 CUSTOMIZING WEBCLIENT WITH PROXY
Proxy: localhost:8888 (HTTP)
═══════════════════════════════════════════════════════════
✅ WebClient customized with proxy configuration
```

You should see this message **MULTIPLE TIMES** because Spring creates multiple WebClient instances.

### Step 3: Trigger OAuth2

```bash
open http://localhost:8080/user
```

### Step 4: Check Connection in Logs

Now the connection should show:

```
# Before (WRONG):
[xxx, L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:3081]
                                                  ^^^^
                                           Direct to Keycloak

# After (CORRECT):
[xxx, L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:8888]
                                                  ^^^^
                                           Through proxy!
```

### Step 5: Check mitmproxy

You should NOW see traffic in mitmproxy:

```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

## Why This Works

### Spring Boot's WebClientCustomizer

Spring Boot provides the `WebClientCustomizer` interface specifically for this purpose:

1. **Auto-detection:** Spring Boot automatically finds all `WebClientCustomizer` beans
2. **Auto-application:** Applies them to ALL `WebClient.Builder` instances
3. **Includes OAuth2:** This includes the WebClient used by Spring Security OAuth2 client

### The Flow

```
Spring Security OAuth2 Client
  ↓
Creates WebClient.Builder
  ↓
Spring Boot applies ALL WebClientCustomizer beans
  ↓
Our WebClientProxyCustomizer.customize() is called
  ↓
Proxy configuration is applied
  ↓
WebClient is built with proxy
  ↓
All requests go through proxy!
```

## Files Changed

1. **NEW:** `src/main/java/com/zz/gateway/auth/config/WebClientProxyCustomizer.java`
   - Implements `WebClientCustomizer`
   - Configures proxy for ALL WebClient instances

2. **KEEP:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`
   - Still useful for custom WebClient beans
   - Provides logging filters

## Summary

### The Issue
- JVM system properties don't work with Reactor Netty
- Spring Security OAuth2 uses Reactor Netty
- Therefore proxy was not being used

### The Fix
- Implement `WebClientCustomizer`
- Spring Boot automatically applies it to ALL WebClient instances
- Including OAuth2 client's internal WebClient

### Action Required
1. ✅ Code added: `WebClientProxyCustomizer.java`
2. ⚠️  **RESTART your Spring Boot app**
3. ✅ Trigger OAuth2 login
4. ✅ Check mitmproxy for traffic

**This WILL work!** The `WebClientCustomizer` approach is the official Spring Boot way to configure WebClient globally.

