#!/bin/bash
set -eu

here=$(cd "$(dirname "$0")" && pwd)
gexec=$here/../../0001-ubuntu-vm/scripts/guest-exec.sh
out=${1:-$here/../raw}
device=${USB_DEVICE:-3-1}
hid=${HID_DEVICE:-/sys/bus/usb/devices/3-1/3-1:1.3/0003:1963:0003.0002}
plug_from=${PLUG_FROM:-21:12}
plug_until=${PLUG_UNTIL:-21:13}
mkdir -p "$out"

"$gexec" 'lsusb -v -d 1963:0003 2>&1' > "$out/lsusb-v.txt"
"$gexec" 'lsusb -t; echo; lsusb' > "$out/lsusb-t.txt"
"$gexec" "cd /sys/bus/usb/devices/$device && for f in idVendor idProduct bcdDevice version speed bDeviceClass bDeviceSubClass bDeviceProtocol bMaxPacketSize0 bNumConfigurations bConfigurationValue bNumInterfaces bMaxPower bmAttributes manufacturer product serial busnum devnum devpath; do printf '%s=%s\n' \"\$f\" \"\$(cat \$f 2>/dev/null)\"; done; echo; for i in $device:1.*; do echo \"[\$i]\"; for f in bInterfaceNumber bAlternateSetting bNumEndpoints bInterfaceClass bInterfaceSubClass bInterfaceProtocol; do printf '%s=%s\n' \"\$f\" \"\$(cat \$i/\$f)\"; done; printf 'driver=%s\n' \"\$(basename \$(readlink \$i/driver) 2>/dev/null)\"; for e in \$i/ep_*; do [ -d \"\$e\" ] && printf '%s: bEndpointAddress=%s bmAttributes=%s wMaxPacketSize=%s bInterval=%s direction=%s type=%s\n' \"\$(basename \$e)\" \"\$(cat \$e/bEndpointAddress)\" \"\$(cat \$e/bmAttributes)\" \"\$(cat \$e/wMaxPacketSize)\" \"\$(cat \$e/bInterval)\" \"\$(cat \$e/direction)\" \"\$(cat \$e/type)\"; done; echo; done" > "$out/sysfs-usb-$device.txt"
"$gexec" "udevadm info -q all -p /sys/bus/usb/devices/$device; echo; udevadm info -q all -p $hid; echo; udevadm info -q all -n /dev/hidraw1" > "$out/udevadm-info.txt"
"$gexec" "journalctl -k --no-pager -S $plug_from -U $plug_until" > "$out/kernel-log-plug.txt"
"$gexec" 'echo "# /proc/asound/cards"; cat /proc/asound/cards; echo; echo "# aplay -l"; aplay -l 2>&1; echo; echo "# arecord -l"; arecord -l 2>&1; echo; echo "# amidi -l"; amidi -l 2>&1; echo; echo "# /proc/asound/card1/stream0"; cat /proc/asound/card1/stream0; echo; echo "# /proc/asound/card1/usbmixer"; cat /proc/asound/card1/usbmixer; echo; echo "# amixer -c 1 contents"; amixer -c 1 contents' > "$out/alsa.txt"
"$gexec" "H=$hid; cat \$H/uevent; echo; echo \"# report_descriptor (\$(stat -c %s \$H/report_descriptor) bytes in sysfs; od of the whole file)\"; od -An -tx1 -v \$H/report_descriptor; echo; echo '# /proc/bus/input/devices entries mentioning StealthPedal'; grep -B1 -A8 StealthPedal /proc/bus/input/devices || echo '(none)'; echo; echo '# /dev/input/by-id'; ls -la /dev/input/by-id/" > "$out/hid.txt"
ls -la "$out"
