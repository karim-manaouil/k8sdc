#!/bin/bash

if [ "$UID" -ne "0" ]; then
	echo "Must be run as root"
	exit 1
fi

# ensure legacy binaries are installed
apt-get install -y iptables arptables ebtables

# switch to legacy versions
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

# Get K8s binaries
URL="https://storage.googleapis.com/kubernetes-release/release"

for tool in kubeadm kubectl kubelet; do 
	curl -LO $URL/`curl $URL/stable.txt`/bin/linux/amd64/$tool
	chmod u+x $tool
	mv $tool /usr/local/bin/
done

kubectl version --client

#sudo apt install -y etcd

kubeadm init --pod-network-cidr=10.244.0.0/16

sysctl net.bridge.bridge-nf-call-iptables=1
