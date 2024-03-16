#!/bin/bash
set -e

MACHINE_NAME=$1

if [ -z "$MACHINE_NAME" ]; then
    echo "please provide a machine name"
    exit 1
fi

echo "Check we have tools"
butane --version || brew install butane yq
coreos-installer --version || cargo install coreos-installer

echo "Transpile machine specific butane machine config to ignition"
op inject --in-file ./butane/$MACHINE_NAME.bu.tmpl --out-file machine-config.bu -f
butane --files-dir ./ --pretty --strict machine-config.bu > machine-config.ign

echo "Transpile base butane config to ignition. Merging in the machine specific config"
op inject --in-file ./butane/_shared-config.bu.tmpl --out-file shared-config.bu -f
butane --files-dir ./ --pretty --strict ./shared-config.bu > config.ign

if [ ! -f "fedora-coreos.qcow2" ]; then
    echo "Get the latest Fedora CoreOS image"
    coreos-installer download -s "stable" -p qemu -f qcow2.xz --decompress -C .
    mv *qcow2 fedora-coreos.qcow2

    # Give the vm some more space for var (things like docker images)
    echo "Expanding image by 40G"
    qemu-img resize ./fedora-coreos.qcow2 +40G
fi

# Cleanup any previous output
echo "Cleanup previous output"
rm -rf output/$MACHINE_NAME 

# Make an output dir for the machines ignition and image files
echo "Create output dir"
mkdir ./output/$MACHINE_NAME
cp fedora-coreos.qcow2 ./output/$MACHINE_NAME/$MACHINE_NAME-coreos.qcow2
mv config.ign ./output/$MACHINE_NAME/$MACHINE_NAME-config.ign

if [ "$(hostname)" = "libvirt" ]; then
    echo "On libvirt, creating VM for real!"
    sudo cp ./output/$MACHINE_NAME/* /mnt/nvme/libvirt/images

    virt-install --name=$MACHINE_NAME --ram=2048 --vcpus=1 --import \
        --disk size=50,path=/mnt/nvme/libvirt/images/$MACHINE_NAME-coreos.qcow2 \
        --sysinfo type=fwcfg,entry0.name=opt/com.coreos/config,entry0.file=/mnt/nvme/libvirt/images/$MACHINE_NAME-config.ign \
        --os-variant=fedora-coreos-stable --graphics=none \
        --noreboot # Don't start the VM until we have the iSCSI disk attached
else
    echo "creating a vm from ./build-$MACHINE_NAME/ for testing"
    sudo rm -rf /var/lib/libvirt/images/uctest
    sudo mkdir /var/lib/libvirt/images/uctest
    sudo cp ./output/$MACHINE_NAME/* /var/lib/libvirt/images/uctest/

    virsh destroy uctest || true
    virsh undefine --nvram uctest || true
    virt-install --name=uctest --ram=2048 --vcpus=1 --import \
        --disk size=50,path=/var/lib/libvirt/images/uctest/$MACHINE_NAME-coreos.qcow2 \
        --disk size=10,path=/var/lib/libvirt/images/uctest/take-iscsi.qcow2 \
        --sysinfo type=fwcfg,entry0.name=opt/com.coreos/config,entry0.file=/var/lib/libvirt/images/uctest/$MACHINE_NAME-config.ign \
        --os-variant=fedora-coreos-stable --graphics=none 
fi

