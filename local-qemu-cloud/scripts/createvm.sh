#!/bin/bash

#############################################################
#   Author:     Karim MANAOUIL                              #
#   Email:      fk_manaouil@esi.dz                          #
#   License:    MIT                                         #
#############################################################
 
# @params (baseimage, output, keys)

VMS=$PWD

baseimage=$1
out=$2
keys=$3
size=$4

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
qemu-img resize $VMS/cluster/instances/$out.qcow2 $size"G"

# cloud-init conf iso
echo "local-hostname: $2" > $VMS/ci-conf/$keys/meta-data
genisoimage -output $VMS/cluster/instances/$out-cidata.iso\
    -volid cidata -joliet -rock $VMS/ci-conf/$keys/user-data $VMS/ci-conf/$keys/meta-data

echo "Finished"
