#!/bin/bash

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io

wget https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz

sudo tar -C /usr/local -xzf go1.13.7.linux-amd64.tar.gz

echo "export GOPATH=/home/go" >> ~/.bashrc
echo "export GOBIN=$GOPATH/bin" >> ~/.bashrc
echo "export PATH=$PATH:/usr/local/go/bin:$GOBIN" >> ~/.bashrc
echo "export GO11MODULE=on" >> ~/.bashrc

echo "DONE"
