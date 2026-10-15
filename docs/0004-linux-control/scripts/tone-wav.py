import math
import struct
import sys
import wave

path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/tone.wav"
frequency = float(sys.argv[2]) if len(sys.argv) > 2 else 440.0
seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 10.0
amplitude = float(sys.argv[4]) if len(sys.argv) > 4 else 0.3
rate = 48000

with wave.open(path, "wb") as out:
    out.setnchannels(2)
    out.setsampwidth(2)
    out.setframerate(rate)
    frames = bytearray()
    for n in range(int(rate * seconds)):
        sample = int(32767 * amplitude * math.sin(2 * math.pi * frequency * n / rate))
        frames += struct.pack("<hh", sample, sample)
    out.writeframes(bytes(frames))
print(path, rate, seconds, frequency, amplitude)
