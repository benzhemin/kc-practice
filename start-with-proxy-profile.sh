#!/bin/bash

# Script to start Spring Boot app using the application-proxy.yml profile
# This profile has proxy pre-configured and enabled

echo "═══════════════════════════════════════════════════════════"
echo "🚀 Starting Spring Boot with Proxy Profile"
echo "═══════════════════════════════════════════════════════════"
echo "Profile: proxy (application-proxy.yml)"
echo ""
echo "IMPORTANT: Make sure mitmproxy is running first!"
echo ""
echo "  mitmweb --web-port 8081"
echo ""
echo "This will:"
echo "  - Listen for proxy traffic on: localhost:8888"
echo "  - Provide web interface at: http://localhost:8081"
echo ""
echo "Your app will send requests to port 8888 (proxy port)"
echo "You view captured traffic at port 8081 (web UI)"
echo ""
echo "After app starts, trigger OAuth2 by visiting:"
echo "  http://localhost:8080/user"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Run with proxy profile
./gradlew bootRun --args='--spring.profiles.active=proxy'

