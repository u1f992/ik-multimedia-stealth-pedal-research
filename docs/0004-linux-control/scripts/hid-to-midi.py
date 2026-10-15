import argparse
import glob
import os
import select
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("--midi", default="")
parser.add_argument("--channel", type=int, default=1)
parser.add_argument("--pedal-cc", type=int, default=11)
parser.add_argument("--switch-cc", type=int, default=64)
parser.add_argument("--knob-cc", type=int, default=7)
parser.add_argument("--ext-pedal-cc", type=int, default=4)
parser.add_argument("--ext-switch1-cc", type=int, default=80)
parser.add_argument("--ext-switch2-cc", type=int, default=81)
parser.add_argument("--pedal-heel", type=lambda s: int(s, 0), default=0x00)
parser.add_argument("--pedal-toe", type=lambda s: int(s, 0), default=0xFF)
parser.add_argument("--ext-pedal-heel", type=lambda s: int(s, 0), default=0x00)
parser.add_argument("--ext-pedal-toe", type=lambda s: int(s, 0), default=0xFF)
parser.add_argument("--seconds", type=float, default=0.0)
parser.add_argument("--verbose", action="store_true")
args = parser.parse_args()


def find_hidraw(vendor=0x1963, product=0x0003):
    wanted = "HID_ID=0003:%08X:%08X" % (vendor, product)
    for uevent in sorted(glob.glob("/sys/class/hidraw/hidraw*/device/uevent")):
        if wanted in open(uevent).read():
            return "/dev/" + uevent.split("/")[4]
    return None


def find_virmidi():
    for line in open("/proc/asound/cards"):
        fields = line.split()
        if len(fields) >= 3 and fields[1].strip("[]") == "VirMIDI":
            return "/dev/snd/midiC%sD0" % fields[0]
    return None


def scale_to_cc(raw, heel, toe):
    span = toe - heel
    value = (raw - heel) * 127 / span if span else 0
    return max(0, min(127, int(round(value))))


hidraw = find_hidraw()
if hidraw is None:
    sys.exit("StealthPedal hidraw not found")
hid = os.open(hidraw, os.O_RDWR | os.O_NONBLOCK)
midi_path = args.midi or find_virmidi()
if midi_path is None:
    sys.exit("virtual MIDI card (snd-virmidi) not found; load it or pass --midi")
midi = os.open(midi_path, os.O_WRONLY)
status = 0xB0 | ((args.channel - 1) & 0x0F)
os.write(hid, b"\x00\x00\x04\x01")

state = {}
started = time.time()


def emit(name, cc, value):
    if state.get(name) == value:
        return
    state[name] = value
    os.write(midi, bytes([status, cc, value]))
    if args.verbose:
        print("%8.3f %s cc=%d value=%d" % (time.time() - started, name, cc, value), flush=True)


while args.seconds <= 0 or time.time() - started < args.seconds:
    ready, _, _ = select.select([hid], [], [], 0.5)
    if not ready:
        continue
    report = os.read(hid, 64)
    if len(report) != 10 or report[0] != 0x81:
        continue
    emit("pedal", args.pedal_cc, scale_to_cc(report[6], args.pedal_heel, args.pedal_toe))
    emit("switch", args.switch_cc, 127 if report[5] & 0x01 else 0)
    emit("knob", args.knob_cc, report[9] & 0x7F)
    emit("ext-pedal", args.ext_pedal_cc, scale_to_cc(report[7], args.ext_pedal_heel, args.ext_pedal_toe))
    emit("ext-switch1", args.ext_switch1_cc, 127 if report[5] & 0x02 else 0)
    emit("ext-switch2", args.ext_switch2_cc, 127 if report[5] & 0x04 else 0)
