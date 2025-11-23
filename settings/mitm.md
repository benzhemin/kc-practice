1. The "MitM Proxy" Approach (Recommended)
The easiest way is to use a Man-in-the-Middle (MitM) proxy that can dump the decrypted traffic to a file, which you can then read.

Tools: mitmproxy (specifically mitmdump) or Proxyman.

Steps:

Install mitmproxy:
bash
brew install mitmproxy
Run mitmdump with a script to save flows: mitmdump allows you to inspect traffic and save it. While it doesn't create one-file-per-stream like tcpflow by default, it shows you the request/response pairs clearly.
bash
# Simply run this and configure your emulator to use the proxy at localhost:8080
mitmdump
Configure Emulator Proxy:
Android: emulator -avd <NAME> -http-proxy http://127.0.0.1:8080
iOS: Go to Settings -> Wi-Fi -> (i) -> Configure Proxy -> Manual -> Server: 127.0.0.1, Port: 8080.
Install Certificates: You must install the mitmproxy CA certificate on the emulator (visit mitm.it in the emulator's browser) for HTTPS to work.