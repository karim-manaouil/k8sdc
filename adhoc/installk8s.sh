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
#URL="https://storage.googleapis.com/kubernetes-release/release"
#
#for tool in kubeadm kubectl kubelet; do 
#	curl -LO $URL/`curl $URL/stable.txt`/bin/linux/amd64/$tool
#	chmod u+x $tool
#	mv $tool /usr/local/bin/
#done


sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#sudo apt install -y etcd

sysctl net.bridge.bridge-nf-call-iptables=1

kubeadm init --pod-network-cidr=10.244.0.0/16

#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
