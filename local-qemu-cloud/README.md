# k8sdc
Configurable Build of a k8s virtual infrastructure

## The project tree 
The master tree contains all necessary configuration files and scripts to bootstrap 
the infrastructure except some folders that are excpected to hold the images.

The tree view below shows the real directory structure one should have to be able to
run the scripts. The missing folders are *cloud-images* and *cluster*. 

*cloud-images* is not very significant and just stands as an OS image store.
*cluster* subtree is important and should be created. *cluster/base* should 
at least have an image that will be used to build the virtual machines. The 
image should be named `$OS_NAME.qcow2.`

**NB: currently, the image name is fixed to ubuntu in buildvms.sh**

The Ubuntu Bionic cloud image, used below, can be download online from http://www.ubuntu.com.

*cluster/instances* will hold the VMs disk images created by the scripts.

```bash
mkdir -p cluster/base cluster/instances
mv cloud-images/ubuntu-18.04-server-cloudimg-amd64.img cluster/base/ubuntu.qcow2
```

Real directory structure that should be created on your machine:
```
.
├── ci-conf
│   ├── ci-steps
│   ├── master
│   │   ├── meta-data
│   │   └── user-data
│   └── worker
│       ├── meta-data
│       └── user-data
├── cloud-images
│   ├── Fedora-Cloud-Base-30-1.2.x86_64.raw.xz
│   └── ubuntu-18.04-server-cloudimg-amd64.img
├── cluster
│   ├── base
│   │   └── ubuntu.qcow2
│   └── instances
│       ├── master-cidata.iso
│       ├── master.qcow2
│       ├── worker-1-cidata.iso
│       └── worker-1.qcow2
├── LICENSE
├── net
│   ├── default.xml
│   ├── intnat.xml
│   └── tap
├── README.md
└── scripts
    ├── build.sh
    ├── createvm.sh
    ├── enable_router.sh
    ├── helper
    │   ├── installk8s.sh
    │   └── reset-kube.sh
    ├── installvms.sh
    ├── k8sdc.sh
    └── tapvmsup.sh

10 directories, 26 files
```

## Usage
To create a virtual machine to be used as a master, one can issue the following command.
Spec: 512MB RAM, 5GB disk size, 2 vcpus, uses virsh default NAT networking.

```
./scripts/k8sdc.sh \
--name master \
--ci-key master \
--nat default \
--ram 512 \
--disk 5 \
--vcpus 2
```

In case you need help with the scripts, reach me at fk_manaouil@esi.dz
