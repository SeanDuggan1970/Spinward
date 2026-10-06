"""A listening demo of the ship's sounds: about a minute of a ship's working day,
mixed offline from assets/audio/ (stereo, with rough placement and distance), so the
set can be auditioned without running the game.

    python tools/make_sound_demo.py [out=build/ship-sounds-demo.wav]
"""
import os, sys, struct
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "ship-sounds-demo.wav")
RATE = 32000
LENGTH = 62.0


def load(name):
    b = open(os.path.join(AUDIO, name + ".wav"), "rb").read()
    i = b.index(b"data")
    n = struct.unpack("<I", b[i + 4:i + 8])[0]
    return np.frombuffer(b[i + 8:i + 8 + n], "<i2").astype(float) / 32768


mix = np.zeros((int(LENGTH * RATE), 2))


def place(name, at, db=0.0, pan=0.0, dist=1.0, loop_for=None, fade_in=0.0, fade_out=0.0):
    """Add a sound at `at` seconds, panned -1..1, quieter and duller with distance (m)."""
    x = load(name)
    if loop_for:
        reps = int(np.ceil(loop_for * RATE / len(x)))
        x = np.tile(x, reps)[: int(loop_for * RATE)]
    gain = 10 ** (db / 20.0) * min(1.0, 7.0 / max(dist, 1.0))
    # Distance dulls the highs: a one-pole low-pass that closes with distance.
    a = np.exp(-2 * np.pi * max(300.0, 6000.0 / max(dist / 6.0, 1.0)) / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    env = np.ones(len(y))
    if fade_in > 0:
        k = int(fade_in * RATE)
        env[:k] = np.linspace(0, 1, k)
    if fade_out > 0:
        k = int(fade_out * RATE)
        env[-k:] = np.linspace(1, 0, k)
    y *= env * gain
    s = int(at * RATE)
    e = min(len(mix), s + len(y))
    l = np.sqrt(0.5 * (1 - pan))
    r = np.sqrt(0.5 * (1 + pan))
    mix[s:e, 0] += y[: e - s] * l
    mix[s:e, 1] += y[: e - s] * r


# The cabin around you all the way through, the pumps just behind.
place("cabin_loop", 0.0, -20, 0.0, 1.0, loop_for=LENGTH, fade_in=2, fade_out=2)
place("pump_loop", 0.0, -12, 0.2, 3.0, loop_for=LENGTH, fade_in=2, fade_out=2)
# Drifting: the panels track round, their motors whining out on the booms.
place("motor_loop", 3.0, -16, -0.7, 9.0, loop_for=3.5, fade_in=0.3, fade_out=0.4)
place("motor_loop", 4.0, -18, 0.7, 10.0, loop_for=2.5, fade_in=0.3, fade_out=0.4)
# Turning to the burn: attitude jets fore and aft, and the frame takes the strain.
t = 9.0
for k in range(10):
    place("rcs_%d" % (k % 4 + 1), t + k * 0.14, -6, -0.5 if k % 2 else 0.5, 4.0 if k % 2 else 20.0)
place("creak_1", 9.6, -6, 0.3, 12.0)
place("creak_4", 11.2, -8, -0.4, 18.0)
for k in range(8):
    place("rcs_%d" % ((k + 2) % 4 + 1), 12.4 + k * 0.15, -7, 0.5 if k % 2 else -0.5, 20.0 if k % 2 else 4.0)
place("creak_3", 13.6, -7, 0.1, 14.0)
# The dish slews round to the destination.
place("motor_loop", 14.5, -17, 0.0, 6.0, loop_for=2.0, fade_in=0.2, fade_out=0.3)
# Ignition, the long burn, the cut-off; the keel creaks as the load comes on and off.
place("drive_ignite", 18.0, -2, 0.0, 22.0)
place("drive_loop", 20.0, 1, 0.0, 22.0, loop_for=18.0, fade_in=0.6, fade_out=0.3)
place("creak_2", 19.0, -6, -0.3, 15.0)
place("creak_6", 27.5, -9, 0.4, 10.0)
place("drive_cutoff", 37.8, -4, 0.0, 22.0)
place("creak_5", 38.6, -6, 0.2, 16.0)
# Coming in to dock: a nudge from the jets, a gentle bump, the clamps.
for k in range(5):
    place("rcs_%d" % (k % 4 + 1), 42.0 + k * 0.16, -6, 0.6 if k % 2 else -0.6, 5.0)
place("impact_light", 44.5, -10, 0.0, 3.0)
place("dock_clunk", 46.5, -2, 0.0, 2.0)
# And the bad day: a heavy hit, the alarm.
place("impact_heavy", 52.0, 0, -0.2, 6.0)
place("alarm_loop", 53.0, -14, 0.0, 1.0, loop_for=6.0, fade_out=1.0)
place("creak_1", 54.0, -4, 0.5, 8.0)

peak = np.max(np.abs(mix))
mix = mix * (0.89 / peak)
pcm = np.clip(np.round(mix * 32767), -32768, 32767).astype("<i2").tobytes()
fmt = struct.pack("<HHIIHH", 1, 2, RATE, RATE * 4, 4, 16)
data = b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "wb") as f:
    f.write(b"RIFF" + struct.pack("<I", 4 + len(data)) + b"WAVE" + data)
print("wrote", OUT)
