#!/bin/bash

swapoff -a    # will turn off the swap 
kubeadm reset
systemctl daemon-reload
systemctl restart kubelet
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
