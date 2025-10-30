#!/bin/bash

set -euo pipefail

QNX_HOST=$1

IFS_IMAGE=$2

QEMU_AARCH64_DEFAULT="third_party/third_party/qemu-aarch64/bin/qemu-system-aarch64"
DTB_DEFAULT="third_party/raspi/boot-files/bcm2711-rpi-4-b.dtb"

QEMU_AARCH64=$3
DTB=$4

if [[ "$IFS_IMAGE" == *"aarch64"* ]]; then
  echo "⚙️  Running QEMU for AArch64 (TCG only)"
  exec "${QEMU_AARCH64}" \
    -M raspi4b \
    -kernel "${IFS_IMAGE}" \
    -dtb "${DTB}" \
    -append "startup-bcm2711-rpi4 -vvv -D miniuart" \
    -d unimp \
    -s \
    -serial tcp::12345,server,nowait \
    -serial stdio \
    -serial tcp::12346,server,nowait \
    -pidfile /tmp/qemu.pid
else
  echo "⚙️  Running QEMU for x86_64"
  qemu-system-x86_64 \
    -smp 2 \
    -m 1024 \
    -nographic \
    -serial mon:stdio \
    -kernel "${IFS_IMAGE}" \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    -accel kvm \
    -cpu host \
    -pidfile /tmp/qemu.pid
fi
