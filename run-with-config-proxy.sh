#!/bin/bash

# Script to run Spring Boot app with proxy enabled via application.yml configuration
# This uses the ProxyConfig.java bean approach

PROXY_HOST=${1:-localhost}
PROXY_PORT=${2:-8888}

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Starting Spring Boot with Config-Based Proxy"
echo "═══════════════════════════════════════════════════════════"
echo "Method: ProxyConfig.java Bean (application.yml)"
echo "Proxy Host: $PROXY_HOST"
echo "Proxy Port: $PROXY_PORT"
echo ""
echo "This uses the programmatic proxy configuration in ProxyConfig.java"
echo "Make sure your proxy tool is running on $PROXY_HOST:$PROXY_PORT"
echo ""
echo "Recommended proxy tools:"
echo "  - mitmproxy: brew install mitmproxy && mitmproxy"
echo "  - mitmweb: mitmweb --web-port 8081"
echo "  - Charles Proxy: https://www.charlesproxy.com/"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Run with proxy enabled via command-line arguments
./gradlew bootRun --args="--proxy.enabled=true --proxy.host=$PROXY_HOST --proxy.port=$PROXY_PORT"

