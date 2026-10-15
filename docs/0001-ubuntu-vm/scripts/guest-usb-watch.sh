#!/bin/bash
set -u

here=$(dirname "$0")
domain=${GUEST_DOMAIN:-stealthpedal-ubuntu}
uri=${LIBVIRT_URI:-qemu:///system}
interval=${1:-5}

list_devices='for d in /sys/bus/usb/devices/[34]-*; do case "$d" in *:*) continue;; esac; [ -e "$d/idVendor" ] || continue; echo "$(basename $d) $(cat $d/idVendor):$(cat $d/idProduct) $(cat $d/manufacturer 2>/dev/null) $(cat $d/product 2>/dev/null) speed=$(cat $d/speed)M"; done'

previous="(none)"
echo "watching guest bus 3/4 (Renesas controller passed through to $domain)"
while true; do
  state=$(virsh -c "$uri" domstate "$domain" 2>&1)
  if [ "$state" != "running" ]; then
    echo "VM state changed: $state"
    exit 1
  fi
  current=$("$here/guest-exec.sh" "$list_devices" 2>/dev/null) || current="(agent unavailable)"
  [ -n "$current" ] || current="(none)"
  if [ "$current" != "$previous" ]; then
    echo "GUEST USB bus 3/4: $current"
    previous=$current
  fi
  sleep "$interval"
done
