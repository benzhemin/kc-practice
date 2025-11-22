# Fix: Proxy Not Capturing Traffic

## The Problem

You have:
- ✅ mitmproxy running on port 8888
- ✅ Spring Boot running with `proxy.enabled=true`
- ✅ Proxy configuration shows "PROXY ENABLED"
- ❌ **BUT traffic is NOT going through the proxy!**

## Root Cause

Spring Security's OAuth2 client creates its **own internal WebClient** that doesn't use your custom `@Bean WebClient`. 

Looking at your logs (line 56):
```
[5b28cb2d-1, L:/127.0.0.1:61195 - R:localhost/127.0.0.1:3081]
```

This shows a **direct connection** to Keycloak (port 3081), not through proxy (port 8888).

## The Solution

I've added a `@PostConstruct` method that sets **JVM system properties** for the proxy. This ensures ALL HTTP clients (including OAuth2's internal client) use the proxy.

### What Was Added

```java
@PostConstruct
public void configureGlobalProxy() {
    if (proxyEnabled) {
        // Set JVM system properties
        System.setProperty("http.proxyHost", proxyHost);
        System.setProperty("http.proxyPort", String.valueOf(proxyPort));
        System.setProperty("https.proxyHost", proxyHost);
        System.setProperty("https.proxyPort", String.valueOf(proxyPort));
        System.setProperty("http.nonProxyHosts", "");
    }
}
```

## How to Test

### Step 1: Restart Your Spring Boot App

The `@PostConstruct` method runs when the app starts, so you need to restart:

```bash
# Stop the current app (Ctrl+C)

# Restart
./gradlew bootRun
```

### Step 2: Check Logs

Look for this NEW message:

```
═══════════════════════════════════════════════════════════
🔧 CONFIGURING GLOBAL PROXY
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════
✅ Global proxy configured via JVM system properties
```

### Step 3: Trigger OAuth2

```bash
open http://localhost:8080/user
```

### Step 4: Check mitmproxy

You should now see traffic in mitmproxy!

Look for:
```
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
```

### Step 5: Verify in Logs

The connection should now show proxy in the path:

```
# Before (direct):
[xxx, L:/127.0.0.1:61195 - R:localhost/127.0.0.1:3081]

# After (via proxy):
[xxx, L:/127.0.0.1:xxxxx - R:localhost/127.0.0.1:8888]
```

## If Still Not Working

### Check 1: Restart Required

Make sure you **restarted** the Spring Boot app after the code change.

### Check 2: Verify Configuration

```bash
grep "proxy.enabled" src/main/resources/application.yml
# Should show: enabled: true
```

### Check 3: Check mitmproxy

```bash
lsof -i :8888
# Should show: mitmproxy listening
```

### Check 4: Test Proxy Manually

```bash
curl -x http://localhost:8888 http://example.com
# Should work if mitmproxy is running correctly
```

## Alternative: Use JVM Properties Directly

If the `@PostConstruct` approach still doesn't work, you can set JVM properties when starting the app:

```bash
./gradlew bootRun \
  -Dhttp.proxyHost=localhost \
  -Dhttp.proxyPort=8888 \
  -Dhttps.proxyHost=localhost \
  -Dhttps.proxyPort=8888
```

Or use the script:

```bash
./run-with-proxy.sh
```

## Why This Happens

Spring Security OAuth2 creates multiple HTTP clients internally:
1. One for token exchange
2. One for JWK set retrieval  
3. One for userinfo endpoint

Your custom `@Bean WebClient` only affects clients that explicitly inject it. The OAuth2 clients don't use it.

**Solution:** Set JVM system properties so ALL HTTP clients use the proxy.

## Summary

1. ✅ Code updated with `@PostConstruct` method
2. ⚠️  **RESTART your Spring Boot app**
3. ✅ Trigger OAuth2 login
4. ✅ Check mitmproxy for traffic

The key is **restarting** the app so the `@PostConstruct` method runs!

