sudo tcpdump -i lo0 -A 'tcp port 3081'


sudo tcpflow -i lo0 -c port 3081




# List your emulators
emulator -list-avds

# Start one with packet capture enabled
emulator -avd <YOUR_AVD_NAME> -tcpdump traffic.pcap
tcpflow -c -r traffic.pcap

