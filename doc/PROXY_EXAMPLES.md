# Proxy Configuration Examples

This document provides real-world examples of different proxy configurations for various scenarios.

## Table of Contents
1. [Development: mitmproxy](#1-development-mitmproxy)
2. [Corporate Proxy with Authentication](#2-corporate-proxy-with-authentication)
3. [Docker Environment](#3-docker-environment)
4. [Kubernetes Environment](#4-kubernetes-environment)
5. [Conditional Proxy (Only for Keycloak)](#5-conditional-proxy-only-for-keycloak)
6. [SOCKS5 Proxy](#6-socks5-proxy)
7. [Multiple Environments](#7-multiple-environments)

---

## 1. Development: mitmproxy

**Scenario:** Capture OAuth2 token exchange during local development

### Setup

```bash
# Terminal 1: Start mitmproxy
brew install mitmproxy
mitmweb --web-port 8081
```

### Method A: Using application.yml

**File:** `src/main/resources/application.yml`
```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

```bash
# Terminal 2: Run app
./gradlew bootRun

# Terminal 3: Trigger OAuth2
open http://localhost:8080/user

# View captured traffic
open http://localhost:8081
```

### Method B: Using Spring Profile

```bash
# Run with proxy profile
./gradlew bootRun --args='--spring.profiles.active=proxy'
```

### Method C: Using Script

```bash
# Using config-based proxy
./run-with-config-proxy.sh

# Or using JVM properties
./run-with-proxy.sh
```

---

## 2. Corporate Proxy with Authentication

**Scenario:** Your company requires authenticated proxy for all external connections

### Configuration

**File:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`

```java
@Configuration
public class ProxyConfig {
    
    @Value("${proxy.enabled:false}")
    private boolean proxyEnabled;
    
    @Value("${proxy.host}")
    private String proxyHost;
    
    @Value("${proxy.port}")
    private int proxyPort;
    
    @Value("${proxy.username:}")
    private String proxyUsername;
    
    @Value("${proxy.password:}")
    private String proxyPassword;

    @Bean
    public WebClient webClient(
            ReactiveClientRegistrationRepository clientRegistrations,
            ServerOAuth2AuthorizedClientRepository authorizedClients) {

        ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                        clientRegistrations, authorizedClients);

        HttpClient httpClient;
        
        if (proxyEnabled) {
            httpClient = HttpClient.create()
                .proxy(proxy -> {
                    ProxyProvider.Proxy proxySpec = proxy
                        .type(ProxyProvider.Proxy.HTTP)
                        .host(proxyHost)
                        .port(proxyPort);
                    
                    // Add authentication if credentials provided
                    if (!proxyUsername.isEmpty()) {
                        proxySpec.username(proxyUsername)
                                 .password(s -> proxyPassword);
                    }
                    
                    // Don't proxy internal services
                    proxySpec.nonProxyHosts("localhost|127.0.0.1|*.internal.company.com");
                });
        } else {
            httpClient = HttpClient.create();
        }

        return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .filter(oauth2)
            .build();
    }
}
```

**File:** `src/main/resources/application.yml`

```yaml
proxy:
  enabled: true
  host: corporate-proxy.company.com
  port: 3128
  type: HTTP
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}
```

**Usage:**

```bash
# Set credentials via environment variables
export PROXY_USERNAME=john.doe
export PROXY_PASSWORD=secret123

./gradlew bootRun
```

---

## 3. Docker Environment

**Scenario:** Running in Docker with proxy for external connections

### docker-compose.yml

```yaml
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    ports:
      - "3081:8080"
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    command: start-dev

  spring-app:
    build: .
    ports:
      - "8080:8080"
    environment:
      # Method 1: Using environment variables
      - http_proxy=http://proxy.company.com:8888
      - https_proxy=http://proxy.company.com:8888
      - no_proxy=localhost,127.0.0.1,keycloak
      
      # Method 2: Using Spring properties
      - PROXY_ENABLED=true
      - PROXY_HOST=proxy.company.com
      - PROXY_PORT=8888
    depends_on:
      - keycloak
```

### Dockerfile

```dockerfile
FROM gradle:8.5-jdk21 AS build
WORKDIR /app
COPY . .
RUN gradle build -x test

FROM openjdk:21-slim
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

# Optional: Set proxy via JVM properties
ENV JAVA_OPTS="-Dhttp.proxyHost=proxy.company.com -Dhttp.proxyPort=8888"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

---

## 4. Kubernetes Environment

**Scenario:** Running in Kubernetes with ConfigMap and Secrets

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  application.yml: |
    proxy:
      enabled: true
      host: corporate-proxy.company.svc.cluster.local
      port: 3128
      type: HTTP
```

### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: proxy-credentials
type: Opaque
stringData:
  username: john.doe
  password: secret123
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app
        image: your-registry/spring-app:latest
        ports:
        - containerPort: 8080
        env:
        # Method 1: Direct environment variables
        - name: PROXY_ENABLED
          value: "true"
        - name: PROXY_HOST
          value: "corporate-proxy.company.svc.cluster.local"
        - name: PROXY_PORT
          value: "3128"
        
        # Method 2: From Secret
        - name: PROXY_USERNAME
          valueFrom:
            secretKeyRef:
              name: proxy-credentials
              key: username
        - name: PROXY_PASSWORD
          valueFrom:
            secretKeyRef:
              name: proxy-credentials
              key: password
        
        volumeMounts:
        - name: config
          mountPath: /app/config
      
      volumes:
      - name: config
        configMap:
          name: app-config
```

---

## 5. Conditional Proxy (Only for Keycloak)

**Scenario:** Only proxy requests to Keycloak, direct connection for everything else

### Configuration

```java
@Configuration
public class ConditionalProxyConfig {

    @Value("${keycloak.proxy.enabled:false}")
    private boolean keycloakProxyEnabled;
    
    @Value("${keycloak.proxy.host:localhost}")
    private String proxyHost;
    
    @Value("${keycloak.proxy.port:8888}")
    private int proxyPort;

    @Bean
    public WebClient webClient(
            ReactiveClientRegistrationRepository clientRegistrations,
            ServerOAuth2AuthorizedClientRepository authorizedClients) {

        ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                        clientRegistrations, authorizedClients);

        // Add filter to conditionally add proxy
        ExchangeFilterFunction conditionalProxyFilter = 
            ExchangeFilterFunction.ofRequestProcessor(request -> {
                String host = request.url().getHost();
                
                // Only proxy Keycloak requests
                if (keycloakProxyEnabled && 
                    (host.contains("keycloak") || host.contains("3081"))) {
                    
                    System.out.println("🔵 Routing through proxy: " + request.url());
                    
                    // Note: This is a simplified example
                    // In practice, you'd configure HttpClient with proxy
                    // and use different clients for different targets
                }
                
                return Mono.just(request);
            });

        return WebClient.builder()
            .filter(oauth2)
            .filter(conditionalProxyFilter)
            .build();
    }
}
```

**Better approach using multiple WebClient beans:**

```java
@Configuration
public class MultiClientConfig {

    @Bean
    @Qualifier("keycloakClient")
    public WebClient keycloakWebClient() {
        // Proxy for Keycloak
        HttpClient httpClient = HttpClient.create()
            .proxy(proxy -> proxy
                .type(ProxyProvider.Proxy.HTTP)
                .host("localhost")
                .port(8888));
        
        return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .build();
    }

    @Bean
    @Qualifier("directClient")
    public WebClient directWebClient() {
        // Direct connection for other services
        return WebClient.builder().build();
    }
}
```

---

## 6. SOCKS5 Proxy

**Scenario:** Using SOCKS5 proxy (e.g., SSH tunnel)

### Setup SSH Tunnel

```bash
# Create SOCKS5 proxy via SSH
ssh -D 1080 -N user@remote-server.com
```

### Configuration

**File:** `application.yml`

```yaml
proxy:
  enabled: true
  host: localhost
  port: 1080
  type: SOCKS5  # Not HTTP!
```

### Alternative: JVM Properties

```bash
java \
  -DsocksProxyHost=localhost \
  -DsocksProxyPort=1080 \
  -DsocksProxyVersion=5 \
  -jar app.jar
```

---

## 7. Multiple Environments

**Scenario:** Different proxy settings for dev, staging, production

### application.yml (default - no proxy)

```yaml
proxy:
  enabled: false
```

### application-dev.yml (local development with mitmproxy)

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP

logging:
  level:
    org.springframework.security.oauth2: TRACE
```

### application-staging.yml (staging with corporate proxy)

```yaml
proxy:
  enabled: true
  host: staging-proxy.company.com
  port: 3128
  type: HTTP
  username: ${PROXY_USERNAME}
  password: ${PROXY_PASSWORD}

logging:
  level:
    org.springframework.security.oauth2: DEBUG
```

### application-prod.yml (production - no proxy)

```yaml
proxy:
  enabled: false

logging:
  level:
    org.springframework.security.oauth2: WARN
```

### Usage

```bash
# Development
./gradlew bootRun --args='--spring.profiles.active=dev'

# Staging
java -jar app.jar --spring.profiles.active=staging

# Production
java -jar app.jar --spring.profiles.active=prod
```

---

## Testing Your Configuration

### 1. Test Proxy Connectivity

```bash
# Test if proxy is reachable
nc -zv localhost 8888

# Test HTTP through proxy
curl -x http://localhost:8888 http://example.com
```

### 2. Test Spring Boot App

```bash
# Start mitmproxy
mitmweb --web-port 8081

# Run app with proxy
./run-with-config-proxy.sh

# Trigger OAuth2 flow
curl -v http://localhost:8080/user

# Check mitmproxy UI
open http://localhost:8081
```

### 3. Verify Proxy is Being Used

Look for these logs:

```
═══════════════════════════════════════════════════════════
🔧 PROXY ENABLED
Proxy Type: HTTP
Proxy Host: localhost
Proxy Port: 8888
═══════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════
🔵 OUTGOING REQUEST (via proxy)
Method: POST
URL: http://localhost:3081/realms/dev-realm/protocol/openid-connect/token
═══════════════════════════════════════════════════════════
```

---

## Troubleshooting

### Proxy not working?

```bash
# Check if proxy is enabled
grep "proxy.enabled" src/main/resources/application.yml

# Check logs for proxy initialization
./gradlew bootRun | grep -i proxy
```

### Connection timeout?

```bash
# Increase timeout in ProxyConfig.java
.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 30000)  # 30 seconds
```

### Proxy authentication failing?

```bash
# Verify credentials
echo -n "username:password" | base64

# Check proxy logs
tail -f /var/log/proxy.log
```

### SSL/TLS issues?

```bash
# Disable SSL verification (DEVELOPMENT ONLY!)
HttpClient httpClient = HttpClient.create()
    .secure(spec -> spec.sslContext(
        SslContextBuilder.forClient()
            .trustManager(InsecureTrustManagerFactory.INSTANCE)
            .build()
    ));
```

---

## Summary

### Quick Reference

| Scenario | Method | Config File |
|----------|--------|-------------|
| Local dev | application.yml | `proxy.enabled=true` |
| Docker | Environment vars | `http_proxy=...` |
| Kubernetes | ConfigMap | `PROXY_HOST=...` |
| Corporate | Auth proxy | `proxy.username=...` |
| Conditional | Multiple beans | `@Qualifier` |
| SOCKS5 | JVM properties | `-DsocksProxyHost=...` |

### Best Practices

1. ✅ **Use environment variables** for credentials
2. ✅ **Use Spring profiles** for different environments
3. ✅ **Log proxy usage** for debugging
4. ✅ **Configure non-proxy hosts** for internal services
5. ✅ **Test proxy connectivity** before running app
6. ❌ **Never hardcode credentials** in code
7. ❌ **Don't use proxy in production** unless required
8. ❌ **Don't disable SSL verification** in production

---

## Next Steps

1. Choose the configuration method that fits your scenario
2. Update `application.yml` or create profile-specific configs
3. Test proxy connectivity
4. Run application and verify proxy is being used
5. Capture and inspect OAuth2 token exchange

For more details, see:
- [PROXY_METHODS.md](PROXY_METHODS.md) - All configuration methods
- [PROXY_CONFIGURATION.md](PROXY_CONFIGURATION.md) - Detailed setup guide
- [QUICK_START_PROXY.md](QUICK_START_PROXY.md) - Quick start guide

