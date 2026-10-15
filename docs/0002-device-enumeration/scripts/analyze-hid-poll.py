import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "docs/0002-device-enumeration/raw/hid-poll.log"
rows = []
for line in open(path, encoding="utf-8"):
    m = re.match(r"\s*([0-9.]+) ((?:[0-9a-f]{2} ?){24})$", line.rstrip())
    if m:
        rows.append((float(m.group(1)), bytes.fromhex(m.group(2).replace(" ", ""))))

print("change records:", len(rows), "time span: %.1f .. %.1f s" % (rows[0][0], rows[-1][0]))
baseline = rows[0][1]
print("baseline:", baseline.hex(" "))
observed = {i: set() for i in range(24)}
for _, report in rows:
    for i, value in enumerate(report):
        observed[i].add(value)
print("byte index -> observed values:")
for i in range(24):
    values = sorted(observed[i])
    if len(values) > 1:
        detail = " values=%s" % [hex(v) for v in values] if len(values) <= 8 else ""
        print("  [%2d] n=%3d min=0x%02x max=0x%02x%s" % (i, len(values), values[0], values[-1], detail))
    else:
        print("  [%2d] constant 0x%02x" % (i, values[0]))

varying = [i for i in range(24) if len(observed[i]) > 1]
print()
print("segments separated by gaps longer than 1 s:")
segment_start = rows[0][0]
previous_time = rows[0][0]
for t, _ in rows[1:]:
    if t - previous_time > 1.0:
        print("  %8.3f .. %8.3f" % (segment_start, previous_time))
        segment_start = t
    previous_time = t
print("  %8.3f .. %8.3f" % (segment_start, previous_time))
print()
print("varying byte indexes:", varying)
