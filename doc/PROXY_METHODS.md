# All Methods to Configure Proxy in Spring Boot

This document shows **6 different ways** to configure HTTP/HTTPS proxy for your Spring Boot application to capture OAuth2 token exchanges.

## Quick Comparison

| Method | Difficulty | Flexibility | Dynamic | Best For |
|--------|-----------|-------------|---------|----------|
| 1. application.yml | ⭐ Easy | Medium | No | Development |
| 2. Environment Variables | ⭐ Easy | Low | No | Docker/K8s |
| 3. JVM System Properties | ⭐⭐ Medium | Low | No | Quick testing |
| 4. ProxyConfig Bean | ⭐⭐ Medium | High | Yes | Production |
| 5. Custom HttpClient | ⭐⭐⭐ Hard | Very High | Yes | Advanced |
| 6. Spring Profiles | ⭐⭐ Medium | Medium | No | Multi-env |

---

## Method 1: application.yml Configuration (RECOMMENDED)

### ✅ Pros
- Simple and declarative
- Easy to understand
- Version controlled
- Works with Spring profiles

### ❌ Cons
- Requires restart to change
- Not dynamic

### Configuration

**File:** `src/main/resources/application.yml`

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP  # Options: HTTP, SOCKS4, SOCKS5
```

**File:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`

```java
@Configuration
public class ProxyConfig {
    @Value("${proxy.enabled:false}")
    private boolean proxyEnabled;

    @Value("${proxy.host:localhost}")
    private String proxyHost;

    @Value("${proxy.port:8888}")
    private int proxyPort;

    @Bean
    public WebClient webClient(...) {
        HttpClient httpClient;
        
        if (proxyEnabled) {
            httpClient = HttpClient.create()
                .proxy(proxy -> proxy
                    .type(ProxyProvider.Proxy.HTTP)
                    .host(proxyHost)
                    .port(proxyPort));
        } else {
            httpClient = HttpClient.create();
        }
        
        return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .build();
    }
}
```

### Usage

```bash
# Enable proxy in application.yml
# proxy.enabled: true

./gradlew bootRun
```

---

## Method 2: Environment Variables

### ✅ Pros
- Works across all Java applications
- Good for containerized environments
- No code changes needed

### ❌ Cons
- Less flexible
- Global for all HTTP connections
- Can interfere with other services

### Configuration

**Set environment variables:**

```bash
# For HTTP proxy
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888

# Alternative uppercase versions
export HTTP_PROXY=http://localhost:8888
export HTTPS_PROXY=http://localhost:8888

# Exclude certain hosts from proxy
export no_proxy=localhost,127.0.0.1
export NO_PROXY=localhost,127.0.0.1
```

### Usage

```bash
# Set environment variables
export http_proxy=http://localhost:8888
export https_proxy=http://localhost:8888

# Run application
./gradlew bootRun

# Or with inline env vars
http_proxy=http://localhost:8888 https_proxy=http://localhost:8888 ./gradlew bootRun
```

### Docker Example

```dockerfile
FROM openjdk:21-slim
ENV http_proxy=http://proxy.example.com:8888
ENV https_proxy=http://proxy.example.com:8888
COPY build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## Method 3: JVM System Properties

### ✅ Pros
- Works for all Java HTTP clients
- No code changes needed
- Can be set via command line

### ❌ Cons
- Global for entire JVM
- Verbose command line
- Not application-specific

### Configuration

**Via command line:**

```bash
java \
  -Dhttp.proxyHost=localhost \
  -Dhttp.proxyPort=8888 \
  -Dhttps.proxyHost=localhost \
  -Dhttps.proxyPort=8888 \
  -Dhttp.nonProxyHosts="localhost|127.0.0.1" \
  -jar build/libs/api-gateway-keycloak-0.0.1-SNAPSHOT.jar
```

**Via Gradle:**

```bash
./gradlew bootRun \
  -Dhttp.proxyHost=localhost \
  -Dhttp.proxyPort=8888 \
  -Dhttps.proxyHost=localhost \
  -Dhttps.proxyPort=8888
```

**Programmatically (in main method):**

```java
@SpringBootApplication
public class ApiGatewayKeycloakApplication {
    public static void main(String[] args) {
        // Set proxy before Spring Boot starts
        System.setProperty("http.proxyHost", "localhost");
        System.setProperty("http.proxyPort", "8888");
        System.setProperty("https.proxyHost", "localhost");
        System.setProperty("https.proxyPort", "8888");
        
        SpringApplication.run(ApiGatewayKeycloakApplication.class, args);
    }
}
```

### Available Properties

```properties
# HTTP Proxy
http.proxyHost=localhost
http.proxyPort=8888
http.nonProxyHosts=localhost|127.0.0.1

# HTTPS Proxy
https.proxyHost=localhost
https.proxyPort=8888

# SOCKS Proxy
socksProxyHost=localhost
socksProxyPort=1080
socksProxyVersion=5

# Proxy Authentication
http.proxyUser=username
http.proxyPassword=password
https.proxyUser=username
https.proxyPassword=password
```

---

## Method 4: ProxyConfig Bean (RECOMMENDED for Production)

### ✅ Pros
- Full control over proxy behavior
- Can be toggled at runtime
- Application-specific
- Works with OAuth2 client

### ❌ Cons
- Requires custom code
- More complex setup

### Configuration

This is already implemented in `ProxyConfig.java`!

**Features:**
- ✅ Toggle proxy on/off via config
- ✅ Support for HTTP, SOCKS4, SOCKS5
- ✅ Proxy authentication support
- ✅ Non-proxy hosts configuration
- ✅ Request/response logging
- ✅ Works with OAuth2 token exchange

### Usage

```yaml
# application.yml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

```bash
./gradlew bootRun
```

**Or override via command line:**

```bash
./gradlew bootRun --args='--proxy.enabled=true --proxy.host=localhost --proxy.port=8888'
```

---

## Method 5: Custom HttpClient with Advanced Proxy

### ✅ Pros
- Maximum flexibility
- Can customize per-request
- Support for proxy authentication
- Can add custom headers

### ❌ Cons
- Most complex
- Requires deep understanding of Netty

### Configuration

**Example: Proxy with Authentication**

```java
@Bean
public WebClient webClientWithProxyAuth() {
    HttpClient httpClient = HttpClient.create()
        .proxy(proxy -> proxy
            .type(ProxyProvider.Proxy.HTTP)
            .host("proxy.example.com")
            .port(8888)
            .username("proxy-user")
            .password(s -> "proxy-password")
            .nonProxyHosts("localhost|127.0.0.1|*.internal.com")
        );
    
    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .build();
}
```

**Example: Conditional Proxy (per-host)**

```java
@Bean
public WebClient webClientWithConditionalProxy() {
    HttpClient httpClient = HttpClient.create()
        .proxy(proxy -> {
            // Only proxy requests to Keycloak
            proxy.type(ProxyProvider.Proxy.HTTP)
                 .host("localhost")
                 .port(8888)
                 .nonProxyHosts("localhost|127.0.0.1");
        });
    
    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .build();
}
```

**Example: Dynamic Proxy Selection**

```java
@Bean
public WebClient webClientWithDynamicProxy() {
    // Choose proxy based on target URL
    HttpClient httpClient = HttpClient.create()
        .doOnRequest((request, connection) -> {
            String host = request.uri().getHost();
            if (host.contains("keycloak") || host.contains("3081")) {
                // Use proxy for Keycloak
                InetSocketAddress proxyAddr = new InetSocketAddress("localhost", 8888);
                HttpProxyHandler proxyHandler = new HttpProxyHandler(proxyAddr);
                connection.addHandlerFirst(proxyHandler);
            }
        });
    
    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .build();
}
```

---

## Method 6: Spring Profiles (Multi-Environment)

### ✅ Pros
- Different proxy per environment
- Clean separation
- Easy to manage

### ❌ Cons
- Requires multiple config files
- Not dynamic

### Configuration

**File:** `application.yml` (default - no proxy)

```yaml
proxy:
  enabled: false
```

**File:** `application-dev.yml` (development with proxy)

```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
  type: HTTP
```

**File:** `application-prod.yml` (production with corporate proxy)

```yaml
proxy:
  enabled: true
  host: corporate-proxy.company.com
  port: 3128
  type: HTTP
```

### Usage

```bash
# Development (with proxy)
./gradlew bootRun --args='--spring.profiles.active=dev'

# Production (with corporate proxy)
java -jar app.jar --spring.profiles.active=prod

# Default (no proxy)
./gradlew bootRun
```

---

## Comparison: Which Method to Use?

### For Development (Capturing OAuth2 Token Exchange)
**Use Method 1 or 4:** application.yml + ProxyConfig.java
- Easy to toggle on/off
- Logs all traffic
- No command-line hassle

### For Docker/Kubernetes
**Use Method 2:** Environment Variables
```yaml
# docker-compose.yml
environment:
  - http_proxy=http://proxy:8888
  - https_proxy=http://proxy:8888
```

### For Quick Testing
**Use Method 3:** JVM System Properties
```bash
./run-with-proxy.sh
```

### For Production
**Use Method 4 or 6:** ProxyConfig Bean + Spring Profiles
- Environment-specific configuration
- Full control
- Secure credential management

### For Advanced Use Cases
**Use Method 5:** Custom HttpClient
- Per-request proxy
- Dynamic proxy selection
- Custom authentication

---

## Testing Your Proxy Configuration

### 1. Start mitmproxy

```bash
brew install mitmproxy
mitmweb --web-port 8081
```

### 2. Enable Proxy in Your App

**Option A: application.yml**
```yaml
proxy:
  enabled: true
  host: localhost
  port: 8888
```

**Option B: Command line**
```bash
./gradlew bootRun --args='--proxy.enabled=true'
```

**Option C: Environment variable**
```bash
export http_proxy=http://localhost:8888
./gradlew bootRun
```

### 3. Trigger OAuth2 Flow

```bash
open http://localhost:8080/user
```

### 4. Check mitmproxy

```bash
open http://localhost:8081
```

Look for POST to `/protocol/openid-connect/token`

---

## Troubleshooting

### Proxy not working?

**Check 1: Is proxy running?**
```bash
curl -x http://localhost:8888 http://example.com
```

**Check 2: Is proxy enabled?**
```bash
# Check logs for:
# 🔧 PROXY ENABLED
# Proxy Host: localhost
# Proxy Port: 8888
```

**Check 3: Firewall blocking?**
```bash
# Test direct connection
nc -zv localhost 8888
```

### SSL/TLS issues with proxy?

If using HTTPS with proxy, you may need to trust the proxy's certificate:

```bash
# Export mitmproxy certificate
cd ~/.mitmproxy
openssl x509 -in mitmproxy-ca-cert.pem -out mitmproxy-ca-cert.crt

# Import to Java keystore
keytool -import -alias mitmproxy \
  -file mitmproxy-ca-cert.crt \
  -keystore $JAVA_HOME/lib/security/cacerts \
  -storepass changeit
```

### Proxy authentication required?

Update `ProxyConfig.java`:

```java
httpClient = HttpClient.create()
    .proxy(proxy -> proxy
        .type(ProxyProvider.Proxy.HTTP)
        .host(proxyHost)
        .port(proxyPort)
        .username("your-username")
        .password(s -> "your-password"));
```

---

## Summary

### Recommended Approach for This Project

**For capturing OAuth2 token exchange:**

1. **Use ProxyConfig.java** (already created)
2. **Toggle via application.yml**:
   ```yaml
   proxy:
     enabled: true  # Change to false to disable
   ```
3. **Start mitmproxy**: `mitmweb --web-port 8081`
4. **Run app**: `./gradlew bootRun`
5. **View traffic**: `http://localhost:8081`

### Key Files

- **Configuration:** `src/main/java/com/zz/gateway/auth/config/ProxyConfig.java`
- **Properties:** `src/main/resources/application.yml`
- **Script:** `run-with-proxy.sh` (for JVM properties method)

### Next Steps

1. Choose your preferred method
2. Configure proxy settings
3. Start proxy tool (mitmproxy/Charles)
4. Run application
5. Trigger OAuth2 login
6. Inspect token exchange

Happy debugging! 🚀

