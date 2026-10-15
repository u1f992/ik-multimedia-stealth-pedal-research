import re
import sys

path = sys.argv[1]
rows = []
for line in open(path, encoding="utf-8"):
    m = re.match(r"\s*([0-9.]+) report #(\d+) len=10 ((?:[0-9a-f]{2} ?){10})$", line.rstrip())
    if m:
        rows.append((float(m.group(1)), int(m.group(2)), bytes.fromhex(m.group(3).replace(" ", ""))))
print("logged change records:", len(rows), "last report number:", rows[-1][1] if rows else 0)


def show(title, predicate, limit=12):
    selected = [(t, p) for t, _, p in rows if predicate(p)]
    print("== %s: %d records" % (title, len(selected)))
    for t, p in selected[:limit]:
        print("   %8.3f flags=0x%02x switch=%d pedal=0x%02x knob=%02x %02x counter=0x%02x%02x" % (t, p[2], p[5], p[6], p[8], p[9], p[3], p[4]))
    if len(selected) > limit:
        t, p = selected[-1]
        print("   ... last %8.3f flags=0x%02x switch=%d pedal=0x%02x knob=%02x %02x" % (t, p[2], p[5], p[6], p[8], p[9]))


show("switch pressed", lambda p: p[5] == 1)
show("switch change flag (bit3)", lambda p: p[2] & 0x08)
show("periodic flag (bit0)", lambda p: p[2] & 0x01)
print("== pedal byte[6] range: 0x%02x .. 0x%02x" % (min(p[6] for _, _, p in rows), max(p[6] for _, _, p in rows)))
print("== knob byte[8] range: 0x%02x .. 0x%02x, byte[9] range: 0x%02x .. 0x%02x" % (
    min(p[8] for _, _, p in rows), max(p[8] for _, _, p in rows), min(p[9] for _, _, p in rows), max(p[9] for _, _, p in rows)))
print("== constant bytes: [0]=%s [1]=%s [7]=%s" % (
    sorted(set("0x%02x" % p[0] for _, _, p in rows)), sorted(set("0x%02x" % p[1] for _, _, p in rows)), sorted(set("0x%02x" % p[7] for _, _, p in rows))))
