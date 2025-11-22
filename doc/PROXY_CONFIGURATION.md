# Proxy Configuration for Capturing OAuth2 Token Exchange

This guide shows how to capture the token exchange between Spring Boot and Keycloak using various proxy tools.

## Table of Contents
1. [Using mitmproxy (Recommended)](#1-using-mitmproxy-recommended)
2. [Using Charles Proxy](#2-using-charles-proxy)
3. [Using Spring Boot RestClient Interceptor](#3-using-spring-boot-restclient-interceptor)
4. [Using Wireshark](#4-using-wireshark)

---

## 1. Using mitmproxy (Recommended)

### Installation
```bash
# macOS
brew install mitmproxy

# Or using pip
pip install mitmproxy
```

### Step 1: Start mitmproxy
```bash
# Start mitmproxy on port 8888 (default)
mitmproxy

# Or use mitmweb for a web interface
mitmweb --web-port 8081
```

### Step 2: Configure Spring Boot to Use Proxy

Add these JVM arguments when starting your Spring Boot app:

```bash
# Method 1: Using gradle bootRun
./gradlew bootRun \
  -Dhttp.proxyHost=localhost \
  -Dhttp.proxyPort=8888 \
  -Dhttps.proxyHost=localhost \
  -Dhttps.proxyPort=8888 \
  -Djavax.net.ssl.trustStore=/path/to/mitmproxy-ca-cert.jks \
  -Djavax.net.ssl.trustStorePassword=changeit

# Method 2: Using java -jar
java -Dhttp.proxyHost=localhost \
     -Dhttp.proxyPort=8888 \
     -Dhttps.proxyHost=localhost \
     -Dhttps.proxyPort=8888 \
     -jar build/libs/api-gateway-keycloak-0.0.1-SNAPSHOT.jar
```

### Step 3: Trust mitmproxy Certificate (for HTTPS)

Since Keycloak uses HTTP in your setup (localhost:3081), you don't need this. But for production HTTPS:

```bash
# Export mitmproxy CA certificate
cd ~/.mitmproxy
openssl x509 -in mitmproxy-ca-cert.pem -out mitmproxy-ca-cert.crt

# Import into Java keystore
keytool -import -alias mitmproxy \
  -file ~/.mitmproxy/mitmproxy-ca-cert.crt \
  -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit
```

### Step 4: What You'll See

When you trigger the OAuth2 flow, mitmproxy will capture:

1. **Authorization Request** (Browser → Keycloak)
   ```
   GET http://localhost:3081/realms/dev-realm/protocol/openid-connect/auth
   ```

2. **Token Exchange** (Spring → Keycloak) ⭐ **THIS IS THE KEY ONE**
   ```
   POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=authorization_code
   &code=eyJhbGciOiJSUzI1NiIsInR5cCI...
   &redirect_uri=http://localhost:8080/login/oauth2/code/gateway
   &client_id=app-client
   &client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
   ```

3. **Token Response** (Keycloak → Spring)
   ```json
   {
     "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
     "expires_in": 300,
     "refresh_expires_in": 1800,
     "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
     "token_type": "Bearer",
     "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
     "not-before-policy": 0,
     "session_state": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
     "scope": "openid profile email"
   }
   ```

---

## 2. Using Charles Proxy

### Installation
Download from: https://www.charlesproxy.com/

### Configuration
1. Start Charles Proxy (default port: 8888)
2. Enable SSL Proxying: `Proxy → SSL Proxying Settings → Enable SSL Proxying`
3. Add location: Host: `localhost`, Port: `3081`
4. Configure Spring Boot (same as mitmproxy above)

---

## 3. Using Spring Boot RestClient Interceptor

This approach logs the token exchange directly in your application without external tools.

### Create a Custom WebClient Configuration

Create this file: `src/main/java/com/zz/gateway/auth/config/WebClientConfig.java`

```java
package com.zz.gateway.auth.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.client.registration.ReactiveClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.reactive.function.client.ServerOAuth2AuthorizedClientExchangeFilterFunction;
import org.springframework.security.oauth2.client.web.server.ServerOAuth2AuthorizedClientRepository;
import org.springframework.web.reactive.function.client.ExchangeFilterFunction;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Configuration
public class WebClientConfig {

    @Bean
    public WebClient webClient(
            ReactiveClientRegistrationRepository clientRegistrations,
            ServerOAuth2AuthorizedClientRepository authorizedClients) {
        
        ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                        clientRegistrations, authorizedClients);
        
        return WebClient.builder()
                .filter(oauth2)
                .filter(logRequest())
                .filter(logResponse())
                .build();
    }

    private ExchangeFilterFunction logRequest() {
        return ExchangeFilterFunction.ofRequestProcessor(clientRequest -> {
            System.out.println("═══════════════════════════════════════");
            System.out.println("🔵 REQUEST: " + clientRequest.method() + " " + clientRequest.url());
            System.out.println("Headers: " + clientRequest.headers());
            System.out.println("═══════════════════════════════════════");
            return Mono.just(clientRequest);
        });
    }

    private ExchangeFilterFunction logResponse() {
        return ExchangeFilterFunction.ofResponseProcessor(clientResponse -> {
            System.out.println("═══════════════════════════════════════");
            System.out.println("🟢 RESPONSE: " + clientResponse.statusCode());
            System.out.println("Headers: " + clientResponse.headers().asHttpHeaders());
            System.out.println("═══════════════════════════════════════");
            return Mono.just(clientResponse);
        });
    }
}
```

### Enable Detailed OAuth2 Logging

Add to `application.yml`:

```yaml
logging:
  level:
    org.springframework.security: TRACE
    org.springframework.security.oauth2: TRACE
    org.springframework.web.reactive.function.client: TRACE
    reactor.netty.http.client: DEBUG
```

This will log:
- All HTTP requests/responses
- OAuth2 token exchange details
- Authorization code flow steps

---

## 4. Using Wireshark

### Installation
```bash
brew install --cask wireshark
```

### Capture Steps
1. Start Wireshark
2. Select "Loopback: lo0" interface
3. Apply filter: `http.request.uri contains "token" or http.request.uri contains "auth"`
4. Start capture
5. Trigger OAuth2 login
6. Look for POST to `/protocol/openid-connect/token`

---

## Quick Start: Recommended Approach

For this project, I recommend **Option 3** (Spring Boot Interceptor) because:
- No external tools needed
- Works with localhost HTTP (no SSL certificate issues)
- Logs directly in your application console
- Easy to enable/disable

### Implementation Steps:

1. Create the `WebClientConfig.java` file (shown above)
2. Update `application.yml` logging levels
3. Restart your Spring Boot app
4. Trigger login at `http://localhost:8080/login`
5. Watch the console for detailed OAuth2 flow logs

---

## What to Look For in the Token Exchange

The critical request is:

```http
POST http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<AUTHORIZATION_CODE>
&redirect_uri=http://localhost:8080/login/oauth2/code/gateway
&client_id=app-client
&client_secret=mEFz9aF5WBb6OAYRPVYm3rlTn3ylCBeF
```

Response:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "Bearer",
  "expires_in": 300,
  "refresh_token": "eyJhbGci...",
  "id_token": "eyJhbGci...",
  "scope": "openid profile email"
}
```

This exchange happens **server-side** (Spring → Keycloak), not in the browser!

---

## Testing the Setup

```bash
# 1. Start your Spring Boot app with proxy settings
./gradlew bootRun

# 2. In another terminal, trigger the OAuth2 flow
curl -v http://localhost:8080/

# 3. Follow the redirect to login
# 4. Check your proxy/logs for the token exchange
```

