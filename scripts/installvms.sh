#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################

# @params(instance_name, nat_net, vr_bridge)

if [[ $# -ne 2 ]]; then
    echo Nothing provided
	exit 1
fi

path=$1
net=$2
br=$3

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
--import --network network=$net --network bridge=$br --noautoconsole

