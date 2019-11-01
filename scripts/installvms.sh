#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo Nothing provided
	exit 1
fi

path=$1
net=$2

base=${path##*/}

if [[ $path =~ */* ]]; then
    parent=${path%/*}
else
    parent=""
fi

virt-install --connect qemu:///system --virt-type kvm \
--name $base \
--ram 512 \
--os-type linux \
--os-variant debian9 \
--disk path=/home/afr0ck/vms/cluster/instances/"$path.qcow2",format=qcow2 \
--disk /home/afr0ck/vms/cluster/instances/$parent/$base-cidata.iso,device=cdrom \
--import --network network=$net --noautoconsole
