#!/bin/bash

nodes="kube-master:8 kube-worker:10"

for node in $nodes; do
    name=$(echo $node | cut -d: -f1)
    n=$(echo $node | cut -d: -f2)

    echo "Launching $name..."

    ip add | grep -q "tap$n"
    if [[ $? -ne 0 ]]; then
        sudo ip tuntap add mode tap "tap$n" user afr0ck
        sudo ip link set "tap$n" up
        sudo parprouted wlp3s0 "tap$n"
        sudo iptables -A INPUT -i tap0 -j ACCEPT 
        sudo iptables -A FORWARD -i tap0 -j ACCEPT 
        sudo iptables -A FORWARD -o tap0 -j ACCEPT
        echo "Created tap$n for $name"
    fi

    kvm -m 512 -hda "nodes/$name.qcow2" -net nic,macaddr=DE:AD:BE:EF:$(($RANDOM%89+10)):$(($RANDOM%89+10)) \
        -net tap,ifname="tap$n",script=no & 
done
