#!/bin/bash

virsh shutdown $1
sleep 1
virsh undefine $1

./scripts/createvm.sh ubuntu $1 $1
./scripts/installvms.sh $1 default

virsh list
