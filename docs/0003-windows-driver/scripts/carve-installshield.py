import os
import shutil
import subprocess
import sys

installer, disk1, unshield, out_dir = sys.argv[1:5]
group = sys.argv[5] if len(sys.argv) > 5 else "Driver"

data = open(installer, "rb").read()
signature = b"ISc("
offsets = []
position = data.find(signature)
while position != -1:
    offsets.append(position)
    position = data.find(signature, position + 1)
offsets.append(len(data))

os.makedirs(out_dir, exist_ok=True)
for index, (start, end) in enumerate(zip(offsets, offsets[1:])):
    segment = data[start:end]
    segment_path = os.path.join(out_dir, "seg%d_%d.bin" % (index, start))
    open(segment_path, "wb").write(segment)
    print("seg%d: offset=%d size=%d head=%s" % (index, start, len(segment), segment[:16].hex(" ")))

for index, start in enumerate(offsets[:-1]):
    trial = os.path.join(out_dir, "try-seg%d" % index)
    shutil.rmtree(trial, ignore_errors=True)
    os.makedirs(os.path.join(trial, "out"))
    shutil.copy(os.path.join(disk1, "data1.hdr"), trial)
    shutil.copy(os.path.join(disk1, "data1.cab"), trial)
    shutil.copy(os.path.join(out_dir, "seg%d_%d.bin" % (index, start)), os.path.join(trial, "data2.cab"))
    result = subprocess.run(
        [unshield, "-g", group, "-d", os.path.join(trial, "out"), "x", os.path.join(trial, "data1.cab")],
        capture_output=True,
        text=True,
    )
    extracted = [os.path.join(root, f) for root, _, files in os.walk(os.path.join(trial, "out")) for f in files]
    failed = result.stdout.count("Failed to extract")
    print("seg%d as data2.cab: %d files extracted, %d failures" % (index, len(extracted), failed))
    if extracted and failed == 0:
        print("usable volume: seg%d (offset %d); extracted files under %s" % (index, start, os.path.join(trial, "out")))
