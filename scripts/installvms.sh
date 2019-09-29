#!/bin/bash

if [[ $# -ne 2 ]]; then
	exit 1
fi

path=$1
net=$2

base=${path##*/}
parent=${path%/*}

virt-install --connect qemu:///system --virt-type kvm \
--name instance-1 \
--ram 1024 \
--vcpus=1 \
--os-type linux \
--os-variant ubuntu16.04 \
--disk path=~/vms/cluster/instances/$path qcow2,format=qcow2 \
--disk /var/lib/libvirt/images/$parent/$base-cidata.iso,device=cdrom \
--import --network network=$net
