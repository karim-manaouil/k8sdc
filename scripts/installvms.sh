#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################

# @params(instance_name, nat_net, vr_bridge)

if [[ $# -ne 3 ]]; then
    echo Nothing provided
	exit 1
fi

base=$1
net=$2
br=$3

BRARG="--network bridge=$br"

if [[ $br =~ NONE ]]; then
	BRARG=""	
fi

virt-install --connect qemu:///system --virt-type kvm \
--name $base \
--ram 312 \
--os-type linux \
--os-variant debian9 \
--disk path=/home/afr0ck/vms/cluster/instances/"$base.qcow2",format=qcow2 \
--disk /home/afr0ck/vms/cluster/instances/$base-cidata.iso,device=cdrom \
--import --network network=$net $BRARG --noautoconsole

