#!/bin/bash
set -eu

here=$(cd "$(dirname "$0")" && pwd)
windows_host=${WINDOWS_HOST:-192.168.0.5}
scratch=${SCRATCH_DIR:-/tmp/usbpcap-probe}
device_marker=${DEVICE_MARKER:-63 19 03 00}
mkdir -p "$scratch"

for index in 1 2 3 4 5 6 7 8; do
  result=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "$windows_host" powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\IK\scripts\usbpcap-capture.ps1' -Index "$index" -Out "C:\\IK\\probe$index.pcap" -Seconds 1 2>/dev/null | tr -d '\r')
  if printf '%s' "$result" | grep -q "Couldn't open device"; then
    continue
  fi
  scp -q -o BatchMode=yes "$windows_host:C:/IK/probe$index.pcap" "$scratch/probe$index.pcap" 2>/dev/null || continue
  if python3 -I "$here/pcap-summary.py" "$scratch/probe$index.pcap" 24 2>/dev/null | grep -q "$device_marker"; then
    echo "$index"
    exit 0
  fi
done
echo "no USBPcap control device shows a device matching '$device_marker'" >&2
exit 1
