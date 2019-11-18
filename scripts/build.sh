#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################

# $1: VM name (in virsh)
# $2: Cloud-Init key (master or worker ?)
# $3: Virsh NAT interface
# $4: A bridge to connect all VMs

if [[ $# -ne 4 ]]; then 
    echo "./rebuild name key nat br"
    exit 1
fi

sudo virsh net-list --all | grep -q $3
nat_exists=$?

if [[ $nat_exists -ne 0 ]]; then 
   sudo virsh net-define net/$3.xml
   [[ $? -ne 0 ]] && echo "error creating $3" && exit 1
   echo "created NAT network $3"
   sudo pkill dnsmasq # This happens only on my Debian
   sudo virsh net-autostart $3
   sudo virsh net-start $3
   echo "Waiting 3s for net ..."
   sleep 3 # gives few secs for $3
fi

sudo virsh net-list
echo
./scripts/createvm.sh ubuntu $1 $2
./scripts/installvms.sh $1 $3 $4

sudo virsh list --all
