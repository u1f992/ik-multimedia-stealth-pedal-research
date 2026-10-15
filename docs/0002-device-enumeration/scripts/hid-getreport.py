import fcntl
import os

IOC_WRITE, IOC_READ = 1, 2


def ioc(direction, type_char, number, size):
    return (direction << 30) | (size << 16) | (ord(type_char) << 8) | number


def hidiocginput(size):
    return ioc(IOC_WRITE | IOC_READ, "H", 0x0A, size)


def hidiocgfeature(size):
    return ioc(IOC_WRITE | IOC_READ, "H", 0x07, size)


fd = os.open("/dev/hidraw1", os.O_RDWR | os.O_NONBLOCK)
for name, request, size in (("GINPUT", hidiocginput, 25), ("GINPUT", hidiocginput, 24), ("GFEATURE", hidiocgfeature, 25)):
    buf = bytearray(size)
    try:
        ret = fcntl.ioctl(fd, request(size), buf, True)
        print(name, size, "ok ret=%d data=%s" % (ret, buf.hex()))
    except OSError as e:
        print(name, size, "err", e)
try:
    print("nonblocking read:", os.read(fd, 64).hex())
except OSError as e:
    print("nonblocking read err:", e)
