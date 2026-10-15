import collections
import struct
import sys

path = sys.argv[1]
data = open(path, "rb").read()
offset = 24
first = None
reports = []
commands = []
while offset + 16 <= len(data):
    ts_sec, ts_usec, caplen, _ = struct.unpack("<IIII", data[offset:offset + 16])
    offset += 16
    packet = data[offset:offset + caplen]
    offset += caplen
    if len(packet) < 27:
        continue
    header_len, _, status, function, info, bus, device, endpoint, transfer, data_len = struct.unpack("<HQIHBHHBBI", packet[:27])
    ts = ts_sec + ts_usec / 1e6
    if first is None:
        first = ts
    payload = packet[header_len:header_len + data_len]
    if transfer == 1 and endpoint == 0x83 and (info & 1) and data_len > 0:
        reports.append((ts - first, payload))
    if transfer == 1 and endpoint == 0x04 and not (info & 1):
        commands.append((ts - first, payload))

print("commands written to EP 0x04:")
for t, p in commands:
    print("  %9.3f  %s" % (t, p.hex(" ")))
print("reports read from EP 0x83:", len(reports), "lengths:", dict(collections.Counter(len(p) for _, p in reports)))
ten = [(t, p) for t, p in reports if len(p) == 10]
if not ten:
    sys.exit(0)
print("report gaps longer than 0.5 s:")
for (t0, _), (t1, _) in zip(ten, ten[1:]):
    if t1 - t0 > 0.5:
        print("  %9.3f .. %9.3f  (%.1f s)" % (t0, t1, t1 - t0))
print("first report %9.3f last report %9.3f" % (ten[0][0], ten[-1][0]))
intervals = sorted(b[0] - a[0] for a, b in zip(ten, ten[1:]))
print("report interval ms: median %.1f min %.1f max %.1f" % (intervals[len(intervals) // 2] * 1000, intervals[0] * 1000, intervals[-1] * 1000))
print("distinct values per byte:")
for i in range(10):
    values = sorted(set(p[i] for _, p in ten))
    shown = ", ".join("0x%02x" % v for v in values[:10]) + (", ..." if len(values) > 10 else "")
    print("  [%d] n=%3d  %s" % (i, len(values), shown))

print()
print("runs of identical reports ignoring the counter bytes [3] and [4]:")
previous = None
run_start = None
last = None
for t, p in ten:
    key = bytes(p[i] for i in range(10) if i not in (3, 4))
    if key != previous:
        if previous is not None:
            print("  %9.3f .. %9.3f  flags=0x%02x switch=%d pedal=0x%02x ext=0x%02x tail=%s" % (run_start, last, previous[2], previous[3], previous[4], previous[5], previous[6:].hex(" ")))
        previous = key
        run_start = t
    last = t
print("  %9.3f .. %9.3f  flags=0x%02x switch=%d pedal=0x%02x ext=0x%02x tail=%s" % (run_start, last, previous[2], previous[3], previous[4], previous[5], previous[6:].hex(" ")))
