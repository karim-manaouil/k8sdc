#!/bin/bash

# This will enable IPv4 routing on the host
# And then forward traffic coming from LAN
# To Internet through wlp3s0 (Wifi in my case)

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Enable NAT for LAN devices
iptables -t nat -A POSTROUTING -o wlp3s0 -j MASQUERADE
