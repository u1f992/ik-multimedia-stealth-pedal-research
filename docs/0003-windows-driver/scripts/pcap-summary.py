import struct
import sys

TRANSFER = {0: "iso", 1: "intr", 2: "ctrl", 3: "bulk"}
FUNCTION = {
    0x0000: "SELECT_CONFIGURATION",
    0x0001: "SELECT_INTERFACE",
    0x0008: "CONTROL_TRANSFER",
    0x0009: "BULK_OR_INTERRUPT_TRANSFER",
    0x000A: "ISOCH_TRANSFER",
    0x000B: "GET_DESCRIPTOR_FROM_DEVICE",
    0x001B: "CLASS_INTERFACE",
    0x0017: "VENDOR_DEVICE",
    0x0018: "VENDOR_INTERFACE",
    0x0019: "VENDOR_ENDPOINT",
    0x001A: "CLASS_DEVICE",
    0x001C: "CLASS_ENDPOINT",
    0x0032: "CONTROL_TRANSFER_EX",
}

path = sys.argv[1]
max_data = int(sys.argv[2]) if len(sys.argv) > 2 else 64
data = open(path, "rb").read()
magic, _, _, _, _, snaplen, linktype = struct.unpack("<IHHiIII", data[:24])
print("linktype=%d snaplen=%d" % (linktype, snaplen))
offset = 24
index = 0
first_ts = None
while offset + 16 <= len(data):
    ts_sec, ts_usec, caplen, _ = struct.unpack("<IIII", data[offset:offset + 16])
    offset += 16
    packet = data[offset:offset + caplen]
    offset += caplen
    index += 1
    if len(packet) < 27:
        continue
    header_len, irp_id, status, function, info, bus, device, endpoint, transfer, data_len = struct.unpack("<HQIHBHHBBI", packet[:27])
    ts = ts_sec + ts_usec / 1e6
    if first_ts is None:
        first_ts = ts
    direction = "IN " if info & 1 else "OUT"
    extra = ""
    if transfer == 2 and header_len >= 28:
        extra = " stage=%d" % packet[27]
    payload = packet[header_len:header_len + data_len]
    print("%5d %9.4f %s dev=%d ep=0x%02x %-4s %-26s status=0x%08x len=%d%s %s" % (
        index, ts - first_ts, direction, device, endpoint, TRANSFER.get(transfer, str(transfer)),
        FUNCTION.get(function, "0x%04x" % function), status, data_len, extra, payload[:max_data].hex(" ")))
