#!/bin/bash

# Script to run Spring Boot app with proxy settings for capturing OAuth2 traffic
# Usage: ./run-with-proxy.sh [proxy_host] [proxy_port]

PROXY_HOST=${1:-localhost}
PROXY_PORT=${2:-8888}

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Starting Spring Boot with Proxy Configuration"
echo "═══════════════════════════════════════════════════════════"
echo "Proxy Host: $PROXY_HOST"
echo "Proxy Port: $PROXY_PORT"
echo ""
echo "Make sure your proxy tool is running on $PROXY_HOST:$PROXY_PORT"
echo "Recommended tools:"
echo "  - mitmproxy: brew install mitmproxy && mitmproxy"
echo "  - mitmweb: mitmweb --web-port 8081"
echo "  - Charles Proxy: https://www.charlesproxy.com/"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Build the application first
./gradlew clean build -x test

# Run with proxy settings
java \
  -Dhttp.proxyHost=$PROXY_HOST \
  -Dhttp.proxyPort=$PROXY_PORT \
  -Dhttps.proxyHost=$PROXY_HOST \
  -Dhttps.proxyPort=$PROXY_PORT \
  -Djava.net.useSystemProxies=false \
  -jar build/libs/api-gateway-keycloak-0.0.1-SNAPSHOT.jar

