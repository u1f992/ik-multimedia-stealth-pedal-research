import re
import subprocess
import sys

monitor = subprocess.Popen(
    ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--property"],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
)

event = {}
for line in monitor.stdout:
    line = line.rstrip("\n")
    if line == "":
        if event.get("DEVTYPE") == "usb_device" and event.get("ACTION") in ("add", "remove"):
            m = re.search(r"/(0000:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9])/usb(\d+)/", event.get("DEVPATH", ""))
            controller = m.group(1) if m else "?"
            bus = m.group(2) if m else "?"
            vendor = event.get("ID_VENDOR_FROM_DATABASE") or event.get("ID_VENDOR") or ""
            model = event.get("ID_MODEL_FROM_DATABASE") or event.get("ID_MODEL") or ""
            ids = event.get("ID_VENDOR_ID", "?") + ":" + event.get("ID_MODEL_ID", "?")
            leaf = event.get("DEVPATH", "").split("/")[-1]
            print(event["ACTION"], "controller=" + controller, "bus=" + bus, "devpath=" + leaf, "id=" + ids, vendor, model, flush=True)
        event = {}
        continue
    if "=" in line and not line.startswith("UDEV"):
        key, value = line.split("=", 1)
        event[key] = value
sys.exit(monitor.wait())
