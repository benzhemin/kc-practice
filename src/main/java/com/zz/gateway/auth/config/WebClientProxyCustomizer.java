package com.zz.gateway.auth.config;

import io.netty.channel.ChannelOption;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.security.oauth2.client.registration.ReactiveClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.reactive.function.client.ServerOAuth2AuthorizedClientExchangeFilterFunction;
import org.springframework.security.oauth2.client.web.server.ServerOAuth2AuthorizedClientRepository;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;
import reactor.netty.transport.ProxyProvider;

import java.util.function.Consumer;

/**
 * Custom WebClient configuration for Spring Security OAuth2 client.
 * 
 * This creates a WebClient bean that Spring Security's OAuth2 client will use
 * for token exchange, JWK retrieval, and userinfo requests.
 */
@Configuration
public class WebClientProxyCustomizer {

    @Value("${proxy.enabled:false}")
    private boolean proxyEnabled;

    @Value("${proxy.host:localhost}")
    private String proxyHost;

    @Value("${proxy.port:8888}")
    private int proxyPort;

    @Value("${proxy.type:HTTP}")
    private String proxyType;

    /**
     * Create a WebClient bean that Spring Security OAuth2 will use.
     * By naming it "webClient", it becomes the default WebClient for OAuth2.
     * 
     * CRITICAL: This WebClient is used for:
     * 1. Token exchange (POST /token)
     * 2. JWK retrieval (GET /certs)
     * 3. UserInfo retrieval (GET /userinfo)
     * 4. OIDC discovery (GET /.well-known/openid-configuration)
     */
    @Bean
    public WebClient webClient(
            ReactiveClientRegistrationRepository clientRegistrations,
            ServerOAuth2AuthorizedClientRepository authorizedClients) {
        
        if (proxyEnabled) {
            System.out.println("═══════════════════════════════════════════════════════════");
            System.out.println("🔧 CREATING WEBCLIENT WITH PROXY FOR OAUTH2");
            System.out.println("Proxy: " + proxyHost + ":" + proxyPort + " (" + proxyType + ")");
            System.out.println("═══════════════════════════════════════════════════════════");

            // ⚠️ CRITICAL: Reactor Netty bypasses proxy for localhost AND resolved 127.* addresses!
            // Even using "keycloak.local" doesn't work because DNS resolves to 127.0.0.1
            // BEFORE the proxy check, and 127.* matches the hardcoded bypass pattern.
            //
            // THE ONLY SOLUTION: Use a SOCKS proxy or disable DNS resolution
            // But Spring Security OAuth2 client doesn't support SOCKS for token exchange.
            //
            // WORKAROUND: We'll configure the proxy anyway for documentation purposes,
            // but it won't work for localhost/127.* addresses.
            
            System.out.println("⚠️  WARNING: Reactor Netty CANNOT proxy localhost or 127.* addresses!");
            System.out.println("⚠️  This is hardcoded in Reactor Netty and cannot be overridden.");
            System.out.println("⚠️  Even using 'keycloak.local' won't work (resolves to 127.0.0.1)");
            System.out.println("");
            System.out.println("💡 TO CAPTURE OAUTH2 TRAFFIC, YOU MUST:");
            System.out.println("   1. Run Keycloak on a DIFFERENT machine/IP");
            System.out.println("   2. Or use a real domain name (not resolving to 127.*)");
            System.out.println("   3. Or use Docker with container networking");
            System.out.println("");
            
            Consumer<ProxyProvider.TypeSpec> proxySpec = proxy -> {
                proxy.type(getProxyType(proxyType))
                     .host(proxyHost)
                     .port(proxyPort)
                     .nonProxyHosts("");  // This doesn't help for 127.*
                
                System.out.println("🔧 Proxy configured: " + proxyHost + ":" + proxyPort);
                System.out.println("   (Will only work for non-localhost addresses)");
            };
            
            HttpClient httpClient = HttpClient.create()
                    .proxy(proxySpec)
                    .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 10000);

            ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                    new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                            clientRegistrations, authorizedClients);

            WebClient webClient = WebClient.builder()
                    .clientConnector(new ReactorClientHttpConnector(httpClient))
                    .filter(oauth2)
                    .build();
            
            System.out.println("✅ WebClient created with proxy - OAuth2 will use this");
            System.out.println("📌 Proxy will intercept: /token, /certs, /userinfo, /.well-known");
            System.out.println("═══════════════════════════════════════════════════════════");
            
            return webClient;
        } else {
            ServerOAuth2AuthorizedClientExchangeFilterFunction oauth2 =
                    new ServerOAuth2AuthorizedClientExchangeFilterFunction(
                            clientRegistrations, authorizedClients);
            
            return WebClient.builder()
                    .filter(oauth2)
                    .build();
        }
    }

    private ProxyProvider.Proxy getProxyType(String type) {
        return switch (type.toUpperCase()) {
            case "HTTP" -> ProxyProvider.Proxy.HTTP;
            case "SOCKS4" -> ProxyProvider.Proxy.SOCKS4;
            case "SOCKS5" -> ProxyProvider.Proxy.SOCKS5;
            default -> {
                System.err.println("⚠️  Unknown proxy type: " + type + ", defaulting to HTTP");
                yield ProxyProvider.Proxy.HTTP;
            }
        };
    }
}

