import struct
import sys


def rva_to_offset(sections, rva):
    for virtual_address, virtual_size, raw_pointer, raw_size in sections:
        if virtual_address <= rva < virtual_address + max(virtual_size, raw_size):
            return rva - virtual_address + raw_pointer
    raise ValueError("rva 0x%x not in any section" % rva)


def read_cstring(data, offset):
    end = data.index(b"\0", offset)
    return data[offset:end].decode("ascii", errors="replace")


path = sys.argv[1]
data = open(path, "rb").read()
pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
machine, section_count = struct.unpack_from("<HH", data, pe_offset + 4)
optional_offset = pe_offset + 24
magic = struct.unpack_from("<H", data, optional_offset)[0]
if magic == 0x20B:
    export_dir_offset = optional_offset + 112
    optional_size = struct.unpack_from("<H", data, pe_offset + 20)[0]
else:
    export_dir_offset = optional_offset + 96
    optional_size = struct.unpack_from("<H", data, pe_offset + 20)[0]
export_rva, export_size = struct.unpack_from("<II", data, export_dir_offset)
sections = []
section_offset = optional_offset + optional_size
for i in range(section_count):
    name, virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<8sIIII", data, section_offset + i * 40)
    sections.append((virtual_address, virtual_size, raw_pointer, raw_size))
print("machine=0x%04x pe32%s export_rva=0x%x size=%d" % (machine, "+" if magic == 0x20B else "", export_rva, export_size))
if export_rva == 0:
    sys.exit(0)
base = rva_to_offset(sections, export_rva)
(_, _, _, _, name_rva, ordinal_base, function_count, name_count, functions_rva, names_rva, ordinals_rva) = struct.unpack_from("<IIHHIIIIIII", data, base)
print("module:", read_cstring(data, rva_to_offset(sections, name_rva)), "functions=%d names=%d ordinal_base=%d" % (function_count, name_count, ordinal_base))
names_offset = rva_to_offset(sections, names_rva)
ordinals_offset = rva_to_offset(sections, ordinals_rva)
functions_offset = rva_to_offset(sections, functions_rva)
for i in range(name_count):
    name_ptr = struct.unpack_from("<I", data, names_offset + i * 4)[0]
    ordinal = struct.unpack_from("<H", data, ordinals_offset + i * 2)[0]
    function_rva = struct.unpack_from("<I", data, functions_offset + ordinal * 4)[0]
    print("  [%3d] 0x%08x %s" % (ordinal + ordinal_base, function_rva, read_cstring(data, rva_to_offset(sections, name_ptr))))
