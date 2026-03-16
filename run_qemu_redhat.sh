#!/bin/bash

set -e

IMAGE="./images/openSUSE-Leap-15.0-JeOS.x86_64-15.0.1-kvm-and-xen-Current.qcow2"

echo "== Disable cloud-init =="
virt-customize -a "$IMAGE" --run-command "touch /etc/cloud/cloud-init.disabled"

echo "== Set root password =="
virt-customize -a "$IMAGE" --root-password password:root

echo "== Start QEMU =="

qemu-system-x86_64 \
-enable-kvm \
-cpu host \
-smp 2 \
-m 2048 \
-drive file="$IMAGE",format=qcow2,if=virtio \
-netdev user,id=net0,hostfwd=tcp::2222-:22 \
-device virtio-net-pci,netdev=net0 \
-nographic \
-display none \
-serial mon:stdio
