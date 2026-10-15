import fcntl
import glob
import os
import select
import sys
import time

HIDIOCGINPUT_25 = (3 << 30) | (25 << 16) | (ord("H") << 8) | 0x0A
started = time.time()


def log(message):
    print("%8.3f %s" % (time.time() - started, message), flush=True)


def find_hidraw(vendor=0x1963, product=0x0003):
    wanted = "HID_ID=0003:%08X:%08X" % (vendor, product)
    for uevent in sorted(glob.glob("/sys/class/hidraw/hidraw*/device/uevent")):
        if wanted in open(uevent).read():
            return "/dev/" + uevent.split("/")[4]
    return None


def get_report(fd):
    buf = bytearray(25)
    fcntl.ioctl(fd, HIDIOCGINPUT_25, buf, True)
    return bytes(buf[1:])


def read_reports(fd, seconds):
    reports = []
    deadline = time.time() + seconds
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            return reports
        ready, _, _ = select.select([fd], [], [], min(remaining, 0.5))
        if ready:
            reports.append(os.read(fd, 64))


def summarize(reports):
    lengths = {}
    for r in reports:
        lengths[len(r)] = lengths.get(len(r), 0) + 1
    ten = [r for r in reports if len(r) == 10]
    detail = " first=%s last=%s" % (ten[0].hex(" "), ten[-1].hex(" ")) if ten else ""
    others = [r.hex(" ") for r in reports if len(r) != 10][:5]
    return "%d reports, lengths=%s%s others=%s" % (len(reports), lengths, detail, others)


experiment = sys.argv[1]
path = find_hidraw()
log("hidraw: %s" % path)
fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)

if experiment == "read-only":
    log("GET_REPORT: %s" % get_report(fd).hex(" "))
    log("read without command: %s" % summarize(read_reports(fd, float(sys.argv[2]) if len(sys.argv) > 2 else 3.0)))

elif experiment == "enable":
    os.write(fd, b"\x00" + bytes.fromhex("00 04 01"))
    log("sent 00 04 01; read: %s" % summarize(read_reports(fd, 3.0)))
    log("GET_REPORT: %s" % get_report(fd).hex(" "))

elif experiment == "command":
    log("before: GET_REPORT %s" % get_report(fd).hex(" "))
    log("before: %s" % summarize(read_reports(fd, 1.0)))
    for arg in sys.argv[2:]:
        command = bytes.fromhex(arg)
        os.write(fd, b"\x00" + command)
        log("sent %s; read: %s" % (command.hex(" "), summarize(read_reports(fd, 2.0))))
        log("after %s: GET_REPORT %s" % (command.hex(" "), get_report(fd).hex(" ")))

elif experiment == "getreport":
    for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 3):
        log("GET_REPORT: %s" % get_report(fd).hex(" "))
        time.sleep(0.5)

elif experiment == "watch":
    for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 20):
        ten = [r for r in read_reports(fd, 0.5) if len(r) == 10]
        log("report %s GET_REPORT %s" % (ten[-1].hex(" ") if ten else "-", get_report(fd).hex(" ")))

os.close(fd)
