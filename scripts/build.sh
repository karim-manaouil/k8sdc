#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################

if [[ $# -ne 3 ]]; then 
    echo "./rebuild name nat br"
    exit 1
fi

if $(sudo virsh net-list --all | grep -q $2); then 
   sudo virsh net-define ../net/$2.xml
   [[ $? -ne 0 ]] && echo "error creating $2" && exit 1
   sudo pkill dnsmasq # This happens only on my Debian
   sudo virsh net-start $2
fi


sleep 1 # gives few secs for $2

./scripts/createvm.sh ubuntu $1 $1
./scripts/installvms.sh $1 $2 $3

virsh list
