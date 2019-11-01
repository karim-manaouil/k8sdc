#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################
 
# @params (baseimage, output, keys)

if [[ $# -ne 3 ]]; then
    echo "Missing arguments"
    exit 1
fi

VMS=$PWD
SIZE="5G"

baseimage=$1
out=$2
keys=$3


# Remove existing image
[[ -f $VMS/cluster/instances/$out.qcow2 ]] && \
    rm $VMS/cluster/instances/$out.qcow2

# Remove it's cloud-init conf
[[ -f $VMS/cluster/instances/$out-cidata.iso ]] && \
    rm $VMS/cluster/instances/$out-cidata.iso

# Create new instance
qemu-img create -f qcow2 -o \
    backing_file=$VMS/cluster/base/$baseimage.qcow2 $VMS/cluster/instances/$out.qcow2

# resize
qemu-img resize $VMS/cluster/instances/$out.qcow2 $SIZE

# cloud-init conf iso
genisoimage -output $VMS/cluster/instances/$out-cidata.iso\
    -volid cidata -joliet -rock $VMS/ci-conf/$keys/user-data $VMS/ci-conf/$keys/meta-data

echo "Finished"
