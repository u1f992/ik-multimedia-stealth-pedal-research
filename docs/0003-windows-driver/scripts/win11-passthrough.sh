#!/bin/bash
set -eu

here=$(cd "$(dirname "$0")" && pwd)
uri=${LIBVIRT_URI:-qemu:///system}
ubuntu=${GUEST_DOMAIN:-stealthpedal-ubuntu}
windows=${WINDOWS_DOMAIN:-win11}
windows_host=${WINDOWS_HOST:-192.168.0.5}

if [ "$(virsh -c "$uri" domstate "$ubuntu")" = "running" ]; then
  virsh -c "$uri" shutdown "$ubuntu"
  virsh -c "$uri" event --domain "$ubuntu" --event lifecycle --timeout 120
  virsh -c "$uri" event --domain "$ubuntu" --event lifecycle --timeout 60 || true
fi
virsh -c "$uri" domstate "$ubuntu"
lspci -k -s 06:00.0 | grep 'Kernel driver'

if ! virsh -c "$uri" dumpxml "$windows" --inactive | grep -q "bus='0x06' slot='0x00' function='0x0'"; then
  virsh -c "$uri" attach-device "$windows" "$here/../win11-hostdev-0600.xml" --config
fi
virsh -c "$uri" dumpxml "$windows" --inactive | grep -A4 '<hostdev'

virsh -c "$uri" start "$windows"
for _ in $(seq 1 36); do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$windows_host" 'echo ok' 2>/dev/null | grep -q ok; then
    echo "ssh reachable: $windows_host"
    break
  fi
  sleep 5
done
lspci -k -s 06:00.0 | grep 'Kernel driver'
