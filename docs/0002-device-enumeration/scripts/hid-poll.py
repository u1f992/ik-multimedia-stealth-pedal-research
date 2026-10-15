import fcntl
import os
import time

HIDIOCGINPUT_25 = (3 << 30) | (25 << 16) | (ord("H") << 8) | 0x0A

fd = os.open("/dev/hidraw1", os.O_RDWR)
log = open("/tmp/hid-poll.log", "a", buffering=1)
previous = None
polls = 0
started = time.time()
log.write("start %.3f\n" % started)
while True:
    buf = bytearray(25)
    fcntl.ioctl(fd, HIDIOCGINPUT_25, buf, True)
    report = bytes(buf[1:])
    polls += 1
    if report != previous:
        log.write("%8.3f %s\n" % (time.time() - started, report.hex(" ")))
        previous = report
    if polls % 500 == 0:
        log.write("alive %8.3f polls=%d\n" % (time.time() - started, polls))
    time.sleep(0.02)
