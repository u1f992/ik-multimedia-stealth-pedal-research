import sys

NAMES = {
    0x04: "Usage Page",
    0x08: "Usage",
    0x14: "Logical Minimum",
    0x24: "Logical Maximum",
    0x74: "Report Size",
    0x94: "Report Count",
    0x80: "Input",
    0x90: "Output",
    0xB0: "Feature",
    0xA0: "Collection",
    0xC0: "End Collection",
}

descriptor = bytes.fromhex("".join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read())
offset = 0
indent = 0
while offset < len(descriptor):
    prefix = descriptor[offset]
    tag = prefix & 0xFC
    size = prefix & 0x03
    size = 4 if size == 3 else size
    data = int.from_bytes(descriptor[offset + 1:offset + 1 + size], "little") if size else None
    name = NAMES.get(tag, "tag 0x%02x" % tag)
    if tag == 0xC0:
        indent -= 1
    print("  " * indent + name + ("" if data is None else " (0x%x = %d)" % (data, data)))
    if tag == 0xA0:
        indent += 1
    offset += 1 + size
