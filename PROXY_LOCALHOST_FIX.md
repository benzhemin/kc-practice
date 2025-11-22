# Proxy Localhost Fix - Complete Solution

## Problem Summary

When running the application with proxy enabled, only the `.well-known/openid-configuration` endpoint was being captured by the proxy (mitmproxy on port 8888). The critical OAuth2 endpoints were going **directly** to Keycloak:

- ❌ `/protocol/openid-connect/token` - NOT captured
- ❌ `/protocol/openid-connect/certs` - NOT captured  
- ❌ `/protocol/openid-connect/userinfo` - NOT captured
- ✅ `/.well-known/openid-configuration` - Captured (sometimes)

### Evidence from Logs

```
r.netty.http.client.HttpClientConnect : [634bda26-1, L:/127.0.0.1:51322 - R:localhost/127.0.0.1:3081]
                                                                                                  ^^^^
                                                                                          Direct to Keycloak (port 3081)
                                                                                          Should be: port 8888 (proxy)
```

The connection shows `R:localhost/127.0.0.1:3081` which means it's connecting directly to Keycloak, not through the proxy at port 8888.

---

## Root Cause Analysis

### Issue 1: JVM's Default `nonProxyHosts`

By default, the JVM excludes certain hosts from proxying via the `http.nonProxyHosts` system property:

```
Default value: localhost|127.*|[::1]|*.local|169.254/16
```

This means:
- `localhost` → NOT proxied
- `127.0.0.1` → NOT proxied
- `127.0.0.2` → NOT proxied
- `[::1]` (IPv6 localhost) → NOT proxied

### Issue 2: Reactor Netty Respects `nonProxyHosts`

Spring WebFlux uses **Reactor Netty** as its HTTP client. Reactor Netty:

1. Checks JVM system property `http.nonProxyHosts`
2. If the target host matches any pattern in `nonProxyHosts`, it **bypasses the proxy**
3. This happens even if you explicitly configure a proxy in the `HttpClient`

### Issue 3: Setting System Properties Doesn't Work

Simply setting system properties like this **DOES NOT WORK**:

```java
System.setProperty("http.nonProxyHosts", "");  // ❌ Doesn't work!
```

Why? Because:
- Reactor Netty caches the proxy configuration
- The system property is read at initialization time
- Setting it to empty string doesn't clear the default value

---

## The Solution

We need to **explicitly configure** Reactor Netty's proxy to exclude nothing.

### Fix 1: Clear JVM Properties (Partial Fix)

In `ProxyConfig.java`:

```java
@PostConstruct
public void configureGlobalProxy() {
    if (proxyEnabled) {
        // Clear the nonProxyHosts properties
        System.clearProperty("http.nonProxyHosts");
        System.clearProperty("https.nonProxyHosts");
        
        // Set proxy properties
        System.setProperty("http.proxyHost", proxyHost);
        System.setProperty("http.proxyPort", String.valueOf(proxyPort));
        System.setProperty("https.proxyHost", proxyHost);
        System.setProperty("https.proxyPort", String.valueOf(proxyPort));
    }
}
```

**Note:** This helps but is not sufficient alone because Reactor Netty needs explicit configuration.

### Fix 2: Configure WebClient with Empty `nonProxyHosts` (Complete Fix)

In `WebClientProxyCustomizer.java`:

```java
@Bean
public WebClient webClient(
        ReactiveClientRegistrationRepository clientRegistrations,
        ServerOAuth2AuthorizedClientRepository authorizedClients) {
    
    if (proxyEnabled) {
        Consumer<ProxyProvider.TypeSpec> proxySpec = proxy -> {
            proxy.type(getProxyType(proxyType))
                 .host(proxyHost)
                 .port(proxyPort)
                 // ⚠️ CRITICAL: Pass empty string to allow ALL hosts through proxy
                 .nonProxyHosts("");  // Empty string = no exclusions
        };
        
        HttpClient httpClient = HttpClient.create()
                .proxy(proxySpec)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000);

        ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                        clientRegistrations, authorizedClients);

        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .filter(oauth2)
                .build();
    }
    
    // ... non-proxy configuration
}
```

### Key Points

1. **`.nonProxyHosts("")`** - This is the critical line!
   - Passing an empty string tells Reactor Netty: "Don't exclude any hosts"
   - Without this, Reactor Netty uses JVM's default exclusion list

2. **Bean name `webClient`** - By naming the bean `webClient`, Spring Security's OAuth2 client automatically uses it

3. **`ServerOAuth2AuthorizedClientExchangeFilterFunction`** - This filter is required for OAuth2 authentication to work

---

## How to Test

### 1. Start mitmproxy

```bash
./mitm-proxy.sh
```

Or manually:

```bash
mitmproxy --listen-host 0.0.0.0 --listen-port 8888 --ssl-insecure
```

### 2. Start the application with proxy profile

```bash
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### 3. Access the application

```bash
open http://localhost:8080/login
```

### 4. Check mitmproxy

You should now see **ALL** OAuth2 requests in mitmproxy:

```
✅ GET  http://localhost:3081/realms/dev-realm/.well-known/openid-configuration
✅ POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
✅ GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/certs
✅ GET  http://localhost:3081/realms/dev-realm/protocol/openid-connect/userinfo
```

### 5. Check application logs

Look for these log messages:

```
═══════════════════════════════════════════════════════════
🔧 CONFIGURING GLOBAL PROXY
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════
✅ Global proxy configured via JVM system properties
⚠️  Note: Reactor Netty requires explicit WebClient proxy config

═══════════════════════════════════════════════════════════
🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2
Proxy: localhost:8888 (HTTP)
═══════════════════════════════════════════════════════════
🔧 Proxy configured: localhost:8888
📌 nonProxyHosts set to empty - ALL traffic (including localhost) will go through proxy
✅ WebClient created with proxy - OAuth2 will use this
📌 Proxy will intercept: /token, /certs, /userinfo, /.well-known
═══════════════════════════════════════════════════════════
```

### 6. Verify connection in logs

Look for Reactor Netty connection logs:

**Before fix (WRONG):**
```
[634bda26-1, L:/127.0.0.1:51322 - R:localhost/127.0.0.1:3081]
                                                          ^^^^
                                                  Direct to Keycloak!
```

**After fix (CORRECT):**
```
[634bda26-1, L:/127.0.0.1:51322 - R:localhost/127.0.0.1:8888]
                                                          ^^^^
                                                  Through proxy!
```

---

## OAuth2 Flow with Proxy

Here's what happens during the OAuth2 Authorization Code flow:

### 1. Browser Redirect to Keycloak (NOT proxied)

```
Browser → http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth
```

This is a **browser redirect**, so it doesn't go through the application's proxy.

### 2. Token Exchange (PROXIED ✅)

```
Application → Proxy (8888) → Keycloak (3081)
POST /realms/dev-realm/protocol/openid-connect/token
```

This is a **server-to-server** request made by Spring Security's OAuth2 client using our configured `WebClient`.

### 3. JWK Retrieval (PROXIED ✅)

```
Application → Proxy (8888) → Keycloak (3081)
GET /realms/dev-realm/protocol/openid-connect/certs
```

Used to validate the JWT token signature.

### 4. UserInfo Request (PROXIED ✅)

```
Application → Proxy (8888) → Keycloak (3081)
GET /realms/dev-realm/protocol/openid-connect/userinfo
```

Retrieves additional user information.

### 5. OIDC Discovery (PROXIED ✅)

```
Application → Proxy (8888) → Keycloak (3081)
GET /realms/dev-realm/.well-known/openid-configuration
```

Discovers OAuth2/OIDC endpoints.

---

## Configuration Files

### `application-proxy.yml`

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP

logging:
  level:
    org.springframework.security: TRACE
    org.springframework.security.oauth2: TRACE
    org.springframework.web.reactive.function.client: TRACE
    reactor.netty.http.client: DEBUG
```

### `ProxyConfig.java`

- Clears JVM's `nonProxyHosts` properties
- Sets global proxy system properties
- Runs before Spring Security initialization

### `WebClientProxyCustomizer.java`

- Creates `WebClient` bean with proxy configuration
- Explicitly sets `.nonProxyHosts("")` to allow localhost
- Used by Spring Security OAuth2 client

---

## Common Issues and Troubleshooting

### Issue: Still seeing direct connections

**Symptoms:**
```
[L:/127.0.0.1:51322 - R:localhost/127.0.0.1:3081]
```

**Solutions:**
1. Verify proxy is running: `curl -x http://localhost:8888 http://example.com`
2. Check `proxy.enabled=true` in `application-proxy.yml`
3. Ensure you're using the `proxy` profile: `--spring.profiles.active=proxy`
4. Check for multiple `WebClient` beans (only one should exist)

### Issue: Connection refused to proxy

**Symptoms:**
```
Connection refused: localhost/127.0.0.1:8888
```

**Solutions:**
1. Start mitmproxy: `./mitm-proxy.sh`
2. Check mitmproxy is listening on correct port: `lsof -i :8888`
3. Verify firewall isn't blocking port 8888

### Issue: SSL/TLS errors

**Symptoms:**
```
SSLHandshakeException: unable to find valid certification path
```

**Solutions:**
1. Use `--ssl-insecure` flag with mitmproxy
2. Or install mitmproxy's CA certificate
3. Or disable SSL verification (development only!)

---

## Why This Matters

Understanding proxy configuration is critical for:

1. **Debugging OAuth2 flows** - See token exchanges, inspect JWTs
2. **Security testing** - Intercept and modify requests
3. **Performance analysis** - Measure request/response times
4. **Corporate environments** - Many companies require proxy for external traffic
5. **Development** - Test how your app behaves behind a proxy

---

## References

- [Reactor Netty Proxy Documentation](https://projectreactor.io/docs/netty/release/reference/index.html#_proxy_support)
- [Spring Security OAuth2 Client](https://docs.spring.io/spring-security/reference/servlet/oauth2/client/index.html)
- [Java Networking Properties](https://docs.oracle.com/javase/8/docs/technotes/guides/net/proxies.html)
- [mitmproxy Documentation](https://docs.mitmproxy.org/)

---

## Summary

The fix requires **two changes**:

1. **Clear JVM properties** in `ProxyConfig.java`:
   ```java
   System.clearProperty("http.nonProxyHosts");
   System.clearProperty("https.nonProxyHosts");
   ```

2. **Configure WebClient** in `WebClientProxyCustomizer.java`:
   ```java
   proxy.type(ProxyProvider.Proxy.HTTP)
        .host(proxyHost)
        .port(proxyPort)
        .nonProxyHosts("");  // ⚠️ This is the critical line!
   ```

Without these changes, Reactor Netty will bypass the proxy for `localhost`, `127.*`, and `[::1]`, causing OAuth2 token exchanges to go directly to Keycloak instead of through your proxy.

**Result:** All OAuth2 traffic now flows through the proxy, allowing you to inspect tokens, debug issues, and understand the complete authentication flow! 🎉

