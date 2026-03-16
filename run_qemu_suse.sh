#!/bin/bash

set -e
IMAGE=$1

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image.qcow2>"
    exit 1
fi

echo "== Đang tinh chỉnh Image openSUSE (với sudo) =="

sudo virt-customize -a "$IMAGE" \
  --run-command "touch /etc/cloud/cloud-init.disabled || true" \
  --root-password password:root \
  --run-command "grep -q ttyS0 /etc/securetty || echo ttyS0 >> /etc/securetty" \
  --run-command "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || true" \
  --run-command "sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true" \
  --run-command "mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d" \
  --run-command "printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %%I 115200 linux\n' > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" \
  --run-command "systemctl enable sshd || true" \
  --run-command "sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"console=ttyS0,115200n8\"/' /etc/default/grub" \
  --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg || true"

echo "== Khởi chạy QEMU =="

qemu-system-x86_64 \
-enable-kvm \
-cpu host \
-smp 2 \
-m 2048 \
-drive file="$IMAGE",format=qcow2,if=virtio \
-netdev user,id=net0,hostfwd=tcp::2222-:22 \
-device virtio-net-pci,netdev=net0 \
-nographic \
-serial mon:stdio