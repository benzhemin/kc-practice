package com.zz.gateway.auth.config;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

/**
 * Proxy Configuration for Spring Boot WebFlux/Reactive applications
 * 
 * This configuration provides multiple ways to set up HTTP/HTTPS proxy:
 * 1. Using Reactor Netty's built-in proxy support (RECOMMENDED)
 * 2. Using application.yml properties
 * 3. Using environment variables
 * 4. Using JVM system properties
 */
@Configuration
public class ProxyConfig {

    @Value("${proxy.enabled:false}")
    private boolean proxyEnabled;

    @Value("${proxy.host:localhost}")
    private String proxyHost;

    @Value("${proxy.port:8888}")
    private int proxyPort;

    @Value("${proxy.type:HTTP}")
    private String proxyType;

    /**
     * Configure global HTTP client proxy settings
     * This runs BEFORE Spring Security OAuth2 client is initialized
     */
    @PostConstruct
    public void configureGlobalProxy() {
        if (proxyEnabled) {
            System.out.println("═══════════════════════════════════════════════════════════");
            System.out.println("🔧 CONFIGURING GLOBAL PROXY");
            System.out.println("Proxy Type: " + proxyType);
            System.out.println("Proxy Host: " + proxyHost);
            System.out.println("Proxy Port: " + proxyPort);
            System.out.println("═══════════════════════════════════════════════════════════");

            // ⚠️ IMPORTANT: JVM system properties DON'T work reliably for Reactor Netty
            // We're setting them anyway for compatibility with other HTTP clients
            System.setProperty("http.proxyHost", proxyHost);
            System.setProperty("http.proxyPort", String.valueOf(proxyPort));
            System.setProperty("https.proxyHost", proxyHost);
            System.setProperty("https.proxyPort", String.valueOf(proxyPort));
            
            // ⚠️ CRITICAL: Clear nonProxyHosts to allow localhost through proxy
            // By default, JVM excludes localhost|127.*|[::1] from proxy
            // We need to clear this to capture localhost traffic
            System.clearProperty("http.nonProxyHosts");
            System.clearProperty("https.nonProxyHosts");
            
            System.out.println("✅ Global proxy configured via JVM system properties");
            System.out.println("⚠️  Note: Reactor Netty requires explicit WebClient proxy config");
        } else {
            System.out.println("ℹ️  Proxy disabled - using direct connection");
        }
    }

    /**
     * NOTE: WebClient bean is in WebClientProxyCustomizer.java
     * This ensures OAuth2 client uses the proxy configuration.
     * 
     * See: WebClientProxyCustomizer.java for the WebClient bean with proxy support.
     */
}

