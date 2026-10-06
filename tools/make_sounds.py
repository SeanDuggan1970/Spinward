"""Synthesise Spinward's ship sounds into assets/audio/ (16-bit mono WAV, 32 kHz).

Everything is made from noise and resonance, no recordings. In vacuum nothing
reaches the crew but what travels through the hull, so these are structure-borne
sounds: low, thumpy, metallic. Loops are shaped in the frequency domain, so they
repeat seamlessly, and they carry a WAV loop point ('smpl' chunk) that Godot picks up.

    python tools/make_sounds.py
"""
import os, struct
import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
rng = np.random.default_rng(2061)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def shaped_noise(seconds, gain):
    """Periodic noise (loops seamlessly) with spectrum |X(f)| = gain(f)."""
    n = int(seconds * RATE)
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    spec *= gain(np.maximum(f, 1e-3))
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    return x / (np.max(np.abs(x)) + 1e-12)


def band(lo, hi, slope=0.0, q=2.0):
    """A soft band-pass gain curve, optionally tilted (slope in powers of f)."""
    def g(f):
        rise = 1.0 / (1.0 + (lo / f) ** (2 * q))
        fall = 1.0 / (1.0 + (f / hi) ** (2 * q))
        return np.sqrt(rise * fall) * (f / lo) ** slope
    return g


def fft_filter(x, gain):
    """Filter a one-shot signal by a gain curve (zero-padded so it doesn't wrap)."""
    n = len(x)
    m = 1 << int(np.ceil(np.log2(n * 2)))
    spec = np.fft.rfft(x, m)
    f = np.fft.rfftfreq(m, 1.0 / RATE)
    spec *= gain(np.maximum(f, 1e-3))
    return np.fft.irfft(spec, m)[:n]


def resonator_ir(freqs, decays, amps, seconds):
    """Impulse response of a struck metal part: decaying inharmonic modes."""
    t = t_axis(seconds)
    y = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        y += a * np.exp(-t / d) * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    return y


def convolve(a, b, length=None):
    """Convolution, padded or cut to `length` samples if given."""
    n = len(a) + len(b) - 1
    m = 1 << int(np.ceil(np.log2(n)))
    y = np.fft.irfft(np.fft.rfft(a, m) * np.fft.rfft(b, m), m)[:n]
    if length is None:
        return y
    out = np.zeros(length)
    out[: min(length, n)] = y[:length]
    return out


def envelope(t, attack, decay):
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-np.maximum(t - attack, 0.0) / decay)


def thump(seconds, freq=55.0, decay=0.12, glide=0.7):
    """A low knock felt through the frame: a decaying sine that sags in pitch."""
    t = t_axis(seconds)
    f = freq * (glide + (1.0 - glide) * np.exp(-t / (decay * 0.6)))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * envelope(t, 0.003, decay)


def metal_modes(count, lo, hi, decay_lo, decay_hi):
    f = np.sort(rng.uniform(lo, hi, count))
    d = rng.uniform(decay_lo, decay_hi, count)
    a = rng.uniform(0.3, 1.0, count) / np.sqrt(np.arange(1, count + 1))
    return f, d, a


def stick_slip(seconds, rate_lo, rate_hi, shape):
    """Friction in a joint: an irregular train of clicks, stronger where shape is."""
    n = int(seconds * RATE)
    x = np.zeros(n)
    t = 0.0
    while t < seconds:
        i = int(t * RATE)
        if i >= n:
            break
        x[i] = rng.uniform(0.4, 1.0) * shape(t / seconds) * rng.choice([-1, 1])
        t += 1.0 / rng.uniform(rate_lo, rate_hi)
    return x


def tone(t, freq, amp=1.0, phase=0.0):
    return amp * np.sin(2 * np.pi * freq * t + phase)


def norm(x, peak=0.9):
    return x * (peak / (np.max(np.abs(x)) + 1e-12))


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a = int(fin * RATE)
    b = int(fout * RATE)
    env = np.ones(n)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if b > 0:
        env[n - b:] = np.linspace(1, 0, b)
    return x * env


def write(name, x, loop=False, peak=0.9):
    x = norm(x, peak)
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    if loop:
        # 'smpl': one forward loop over the whole file, which Godot's importer reads.
        n = len(x)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(riff)
    print("%-18s %5.2f s%s" % (name, len(x) / RATE, "  loop" if loop else ""))


os.makedirs(OUT, exist_ok=True)

# --- the drive: a deep rumble through the keel ------------------------------------
L = 6.0
t = t_axis(L)
rumble = shaped_noise(L, band(22, 220, -0.8, 2.5))
# Tones at whole cycles per loop, so the loop stays seamless.
base = round(41.0 * L) / L
hum = tone(t, base, 0.5) + tone(t, 2 * base, 0.22) + tone(t, 3 * base, 0.08) + tone(t, round(118.0 * L) / L, 0.06)
throb = 1.0 + 0.18 * np.sin(2 * np.pi * t / 2.0) + 0.08 * np.sin(2 * np.pi * t / 1.5)
grit = shaped_noise(L, band(300, 1200, 0.0, 2.0)) * 0.03
drive = (rumble * 0.9 + hum * 0.55) * throb + grit
write("drive_loop", drive, loop=True, peak=0.8)

t = t_axis(2.4)
ign_rumble = np.tile(drive, 2)[: len(t)] * np.clip((t - 0.15) / 1.6, 0.0, 1.0) ** 1.5
ign = thump(2.4, 38.0, 0.35, 0.6) * 1.2 + ign_rumble * 0.8
ign += convolve(stick_slip(0.25, 60, 140, lambda u: 1 - u), resonator_ir(*metal_modes(8, 150, 900, 0.03, 0.12), 0.3), length=len(t)) * 0.25
write("drive_ignite", fade(ign, 0.002, 0.3))

t = t_axis(2.2)
cut = np.tile(drive, 1)[: len(t)] * np.exp(-t / 0.35) + thump(2.2, 46.0, 0.25, 0.8) * 0.5
ticks = stick_slip(2.2, 3, 9, lambda u: np.exp(-u * 2.0) * (u > 0.2))
cut += convolve(ticks, resonator_ir(*metal_modes(6, 800, 2600, 0.02, 0.08), 0.15), length=len(t)) * 0.35
write("drive_cutoff", fade(cut, 0.002, 0.2))

# --- manoeuvring jets: a knock and a valve snap, felt through the frame ----------------
for k in range(4):
    t = t_axis(0.45)
    knock = thump(0.45, rng.uniform(62, 95), rng.uniform(0.05, 0.09), 0.75)
    snap = fft_filter(rng.normal(size=len(t)) * envelope(t, 0.001, 0.012), band(1200, 4000, 0.0, 2.0)) * 0.1
    ring = convolve(np.eye(1, len(t))[0], resonator_ir(*metal_modes(5, 250, 700, 0.03, 0.09), 0.3), length=len(t)) * 0.3
    burn = fft_filter(rng.normal(size=len(t)) * envelope(t, 0.01, 0.1), band(80, 400, 0.0, 1.0)) * 0.35
    write("rcs_%d" % (k + 1), fade(knock + snap + ring + burn, 0.001, 0.05))

# --- the structure: creaks and groans as the ship turns -------------------------------
for k in range(6):
    dur = rng.uniform(0.9, 2.2)
    t = t_axis(dur)
    peak_at = rng.uniform(0.3, 0.6)
    shape = lambda u, p=peak_at: np.exp(-((u - p) / 0.28) ** 2)
    clicks = stick_slip(dur, 25, 120, shape)
    modes = metal_modes(10, rng.uniform(120, 220), rng.uniform(900, 1600), 0.02, 0.09)
    creak = convolve(clicks, resonator_ir(*modes, 0.25), length=len(t))
    f0 = rng.uniform(70, 110)
    f = f0 * (1.0 - 0.18 * t / dur)
    groan = np.sin(2 * np.pi * np.cumsum(f) / RATE) * shape(t / dur) * (0.6 + 0.4 * fft_filter(rng.normal(size=len(t)), band(2, 12, 0, 1)) * 3)
    write("creak_%d" % (k + 1), fade(creak * 0.8 + groan * 0.25, 0.01, 0.1))

# --- life support: pumps cycling, air moving --------------------------------------------
L = 6.0
t = t_axis(L)
motor = tone(t, round(100 * L) / L, 0.35) + tone(t, round(200 * L) / L, 0.15) + tone(t, round(300 * L) / L, 0.06)
cycle = 0.5 - 0.5 * np.cos(2 * np.pi * t / 3.0)
swish = shaped_noise(L, band(220, 1100, -0.3, 2.0)) * cycle ** 2.0
pump = motor * (0.8 + 0.2 * cycle) + swish * 0.9
for at in (0.15, 3.15):
    i = int(at * RATE)
    tick = resonator_ir(*metal_modes(4, 1800, 3200, 0.004, 0.012), 0.05) * 0.4
    pump[i:i + len(tick)] += tick
write("pump_loop", pump, loop=True, peak=0.6)

L = 8.0
t = t_axis(L)
air = shaped_noise(L, band(180, 3200, -0.5, 1.0))
fan = tone(t, round(119 * L) / L, 0.08) + tone(t, round(238 * L) / L, 0.03)
whine = tone(t, round(7200 * L) / L, 0.006) + tone(t, round(2210 * L) / L, 0.01)
write("cabin_loop", air * 0.8 + fan + whine, loop=True, peak=0.5)

# --- servo motors: arrays, radiators and the dish turning -------------------------------
L = 2.0
t = t_axis(L)
g = round(420 * L) / L
servo = tone(t, g, 0.5) + tone(t, 2 * g, 0.25) + tone(t, 3 * g, 0.12) + tone(t, round(37 * L) / L, 0.2)
servo *= 1.0 + 0.15 * np.sin(2 * np.pi * t * 4.0)
servo += shaped_noise(L, band(700, 2400, 0.0, 2.0)) * 0.06
write("motor_loop", servo, loop=True, peak=0.6)

# --- docking: clamps close, pressure equalises -----------------------------------------
t = t_axis(1.8)
clunk = thump(1.8, 48.0, 0.3, 0.7) * 1.1
clunk += convolve(np.eye(1, len(t))[0], resonator_ir(*metal_modes(14, 110, 1100, 0.08, 0.5), 1.2), length=len(t)) * 0.6
for at in (0.42, 0.58):
    i = int(at * RATE)
    latch = resonator_ir(*metal_modes(6, 600, 2400, 0.01, 0.05), 0.15) * 0.45
    clunk[i:i + len(latch)] += latch[: len(clunk) - i]
t = t_axis(1.6)
hiss = fft_filter(rng.normal(size=len(t)), band(900, 6500, -0.2, 1.0)) * envelope(t, 0.05, 0.5)
write("hiss", fade(hiss, 0.01, 0.2), peak=0.5)
# The clamps, then the pressure equalising through the lock.
dock = np.concatenate([clunk, np.zeros(int(0.9 * RATE))])
i = int(0.9 * RATE)
dock[i:i + len(hiss)] += hiss / (np.max(np.abs(hiss)) + 1e-12) * 0.18 * np.max(np.abs(clunk))
write("dock_clunk", fade(dock, 0.001, 0.2))

# --- collisions: a knock, a crunch, the end --------------------------------------------
t = t_axis(1.0)
rattle = convolve(stick_slip(1.0, 20, 80, lambda u: np.exp(-u * 5)), resonator_ir(*metal_modes(10, 300, 2200, 0.02, 0.08), 0.2), length=len(t))
light = thump(1.0, 60.0, 0.15, 0.7) + rattle * 0.5 + convolve(np.eye(1, len(t))[0], resonator_ir(*metal_modes(10, 140, 900, 0.05, 0.3), 0.9), length=len(t)) * 0.5
write("impact_light", fade(light, 0.001, 0.1))
t = t_axis(3.0)
burst = fft_filter(rng.normal(size=len(t)) * envelope(t, 0.002, 0.25), band(40, 2500, -0.4, 1.0))
crunch = convolve(stick_slip(3.0, 30, 200, lambda u: np.exp(-u * 2.5)), resonator_ir(*metal_modes(16, 90, 1800, 0.03, 0.25), 0.4), length=len(t))
heavy = thump(3.0, 36.0, 0.5, 0.55) * 1.3 + burst * 0.8 + crunch * 0.6
write("impact_heavy", fade(heavy, 0.001, 0.4))
t = t_axis(5.0)
boom = fft_filter(rng.normal(size=len(t)) * envelope(t, 0.01, 1.1), band(18, 160, -0.6, 1.0)) * 1.4
crackle = convolve(stick_slip(5.0, 10, 90, lambda u: np.exp(-u * 1.5)), resonator_ir(*metal_modes(12, 200, 2600, 0.01, 0.1), 0.2), length=len(t)) * 0.3
write("explosion", fade(boom + crackle + thump(5.0, 30.0, 1.0, 0.5), 0.002, 0.8))

# --- alerts ------------------------------------------------------------------------------
L = 1.0
t = t_axis(L)
beep = np.where((t % 0.5) < 0.22, 1.0, 0.0) * np.where(t < 0.5, tone(t, 880, 1) + tone(t, 1760, 0.2), tone(t, 660, 1) + tone(t, 1320, 0.2))
write("alarm_loop", fft_filter(beep, band(300, 5000, 0, 1)), loop=True, peak=0.45)
t = t_axis(0.16)
write("beep", fade(tone(t, 1250, 1) * envelope(t, 0.004, 0.06), 0.002, 0.03), peak=0.4)

# --- docked: the station around you ------------------------------------------------------
L = 8.0
t = t_axis(L)
station = shaped_noise(L, band(25, 140, -0.6, 1.5)) * 0.7 + tone(t, round(60 * L) / L, 0.15) + tone(t, round(120 * L) / L, 0.05)
station += shaped_noise(L, band(200, 2000, -0.5, 1.0)) * 0.12
for at in (2.3, 5.9):
    i = int(at * RATE)
    far = resonator_ir(*metal_modes(10, 90, 700, 0.15, 0.8), 1.6) * 0.35
    far = fft_filter(far, band(40, 700, 0, 1))
    station[i:i + len(far)] += far[: len(station) - i]
write("station_loop", station, loop=True, peak=0.6)

# --- riding the ribbon: traction wheels over joints --------------------------------------
L = 2.0
t = t_axis(L)
roll = shaped_noise(L, band(35, 320, -0.7, 1.2))
joints = np.zeros_like(t)
for at in np.arange(0.0, L, 0.25):
    i = int(at * RATE)
    k = thump(0.2, 70.0, 0.05, 0.8) * 0.6
    joints[i:i + len(k)] += k[: len(joints) - i]
write("climber_loop", roll * 0.8 + joints + tone(t, round(140 * L) / L, 0.08), loop=True, peak=0.7)
print("wrote", OUT)
