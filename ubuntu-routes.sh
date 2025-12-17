#!/bin/bash
# Add static routes on Ubuntu desktop to reach all SSH-managed devices

sudo ip route add 10.0.1.0/30 via 192.168.122.254  # Reach R3 via R1
sudo ip route add 10.0.2.0/30 via 192.168.122.254  # Reach R2 via R1
sudo ip route add 10.2.0.0/24 via 192.168.122.254  # Reach S1 via R1->R2
sudo ip route add 10.3.0.0/24 via 192.168.122.254  # Reach S2 via R1->R3

echo "Routes added. Verifying:"
ip route show
