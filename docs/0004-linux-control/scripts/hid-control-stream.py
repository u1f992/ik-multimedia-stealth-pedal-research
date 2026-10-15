import os
import select
import sys
import time

device = os.environ.get("HIDRAW", "/dev/hidraw1")
seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 5.0
commands = [bytes.fromhex(arg) for arg in sys.argv[2:]] or [bytes.fromhex("00 04 01")]

fd = os.open(device, os.O_RDWR | os.O_NONBLOCK)
started = time.time()
for command in commands:
    written = os.write(fd, b"\x00" + command)
    print("%8.3f write %s (%d bytes incl. report id)" % (time.time() - started, command.hex(" "), written), flush=True)
    time.sleep(0.005)

count = 0
previous = None
while time.time() - started < seconds:
    ready, _, _ = select.select([fd], [], [], 0.5)
    if not ready:
        continue
    report = os.read(fd, 64)
    count += 1
    key = bytes(report[i] for i in range(len(report)) if i not in (3, 4)) if len(report) == 10 else report
    if key != previous or count <= 3:
        print("%8.3f report #%d len=%d %s" % (time.time() - started, count, len(report), report.hex(" ")), flush=True)
        previous = key
print("%8.3f end: %d reports" % (time.time() - started, count), flush=True)
