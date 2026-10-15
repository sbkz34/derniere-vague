#!/usr/bin/env python3
"""Generates the game's textures (PNG) and sound effects (WAV) procedurally.

Run from the repository root:  python3 tools/gen_assets.py
Everything in assets/tex and assets/sfx comes from this script: no third-party assets.
"""
import os
import wave

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
TEX = os.path.join(ROOT, "tex")
SFX = os.path.join(ROOT, "sfx")
os.makedirs(TEX, exist_ok=True)
os.makedirs(SFX, exist_ok=True)
rng = np.random.default_rng(7)

# ----------------------------------------------------------------------------------------------
# Textures (tileable: every blur wraps around the edges)
# ----------------------------------------------------------------------------------------------
N = 256


def noise(sigma, size=N):
    a = gaussian_filter(rng.standard_normal((size, size)), sigma, mode="wrap")
    a -= a.min()
    return a / max(a.max(), 1e-9)


def fbm(octaves=(1, 2, 4, 8, 16), weights=None, size=N):
    weights = weights or [0.5 ** i for i in range(len(octaves))]
    out = sum(w * noise(o, size) for o, w in zip(octaves, weights))
    out -= out.min()
    return out / out.max()


def save(name, rgb):
    img = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(os.path.join(TEX, name))


def colorize(v, dark, light):
    dark, light = np.array(dark), np.array(light)
    return dark + v[..., None] * (light - dark)


# Concrete wall: grey, stains running down, a few cracks.
v = fbm()
stains = gaussian_filter(rng.standard_normal((N, N)), (18, 3), mode="wrap")
stains = (stains - stains.min()) / (stains.max() - stains.min())
v = 0.55 * v + 0.45 * (1 - stains ** 2)
crack = np.zeros((N, N))
for _ in range(5):
    x, y = rng.integers(0, N, 2)
    for _ in range(120):
        crack[y % N, x % N] = 1
        x += rng.integers(-1, 2)
        y += rng.integers(0, 2)
v -= 0.35 * gaussian_filter(crack, 0.7, mode="wrap") * 3
save("concrete.png", colorize(np.clip(v, 0, 1), (0.22, 0.22, 0.21), (0.55, 0.54, 0.5)))

# Floor tiles: 4x4 tiles, grout lines, grime.
v = fbm((1, 3, 8))
tile = np.ones((N, N))
step = N // 4
for i in range(0, N, step):
    tile[i:i + 3, :] = 0.25
    tile[:, i:i + 3] = 0.25
tint = np.zeros((N, N))
for ty in range(4):
    for tx in range(4):
        tint[ty * step:(ty + 1) * step, tx * step:(tx + 1) * step] = rng.uniform(-0.08, 0.08)
grime = noise(20)
base = colorize(np.clip(0.6 * v + 0.4 * tile + tint - 0.3 * grime, 0, 1), (0.08, 0.09, 0.08),
                (0.42, 0.44, 0.4))
save("tiles.png", base)

# Wood planks (horizontal planks with grain).
y = np.arange(N)[:, None]
x = np.arange(N)[None, :]
streak = gaussian_filter(rng.standard_normal((N, N)), (1.2, 40), mode="wrap")
streak = (streak - streak.min()) / (streak.max() - streak.min())
grain = np.sin((y / N) * 2 * np.pi * 24 + 10 * streak) * 0.5 + 0.5
grain = 0.45 * grain + 0.55 * streak
plank_h = N // 4
seams = ((y % plank_h) < 3).astype(float)
shade = np.zeros((N, N))
for p in range(4):
    shade[p * plank_h:(p + 1) * plank_h, :] = rng.uniform(-0.12, 0.12)
v = np.clip(0.75 * grain + shade - 0.6 * seams, 0, 1)
save("wood.png", colorize(v, (0.16, 0.09, 0.04), (0.55, 0.36, 0.18)))

# Rusty metal panels.
v = fbm((1, 2, 4, 8))
rust = np.clip(noise(5) * 1.6 - 0.6, 0, 1)
panel = np.ones((N, N))
panel[:, :3] = panel[:3, :] = 0.3
panel[N // 2:N // 2 + 2, :] = 0.4
rivets = np.zeros((N, N))
for cy in (12, N // 2 - 10, N // 2 + 12, N - 12):
    for cx in range(12, N, 40):
        rivets[cy - 2:cy + 3, cx - 2:cx + 3] = 1
metal = colorize(np.clip(0.5 + 0.3 * v, 0, 1) * panel[..., None].squeeze(), (0.12, 0.13, 0.14),
                 (0.5, 0.52, 0.55))
rust_col = colorize(v, (0.25, 0.1, 0.04), (0.55, 0.28, 0.1))
out = metal * (1 - rust[..., None]) + rust_col * rust[..., None] + 0.25 * rivets[..., None]
save("metal.png", np.clip(out, 0, 1))

# Dirt for the ground outside.
v = fbm((1, 2, 4, 10, 24))
save("dirt.png", colorize(v, (0.06, 0.05, 0.03), (0.3, 0.25, 0.16)))

# Bricks (lower walls outside / accents).
bh, bw = N // 8, N // 4
mortar = np.zeros((N, N))
for row in range(8):
    mortar[row * bh:row * bh + 3, :] = 1
    off = (bw // 2) * (row % 2)
    for c in range(-1, 5):
        xx = (c * bw + off) % N
        mortar[row * bh:(row + 1) * bh, xx:xx + 3] = 1
bt = np.zeros((N, N))
for row in range(8):
    for c in range(5):
        bt[row * bh:(row + 1) * bh, (c * bw) % N:(c * bw) % N + bw] += rng.uniform(-0.1, 0.1)
v = np.clip(0.55 + 0.35 * fbm((1, 3, 6)) + bt - 0.7 * mortar, 0, 1)
save("brick.png", colorize(v, (0.15, 0.06, 0.04), (0.55, 0.25, 0.17)))

# ----------------------------------------------------------------------------------------------
# Sounds (44.1 kHz mono 16-bit)
# ----------------------------------------------------------------------------------------------
SR = 44100


def t(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.002, decay=0.2):
    tt = t(dur)
    a = np.clip(tt / max(attack, 1e-6), 0, 1)
    return a * np.exp(-tt / decay)


def white(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    # One-pole low-pass, cutoff in Hz (scalar or per-sample array).
    cutoff = np.broadcast_to(cutoff, x.shape)
    out = np.zeros_like(x)
    acc = 0.0
    k = 1 - np.exp(-2 * np.pi * cutoff / SR)
    for i in range(len(x)):
        acc += k[i] * (x[i] - acc)
        out[i] = acc
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write(name, x):
    x = np.clip(norm(x), -1, 1)
    fade = min(len(x), 200)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(SFX, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def pad(x, dur):
    out = np.zeros(int(SR * dur))
    out[:min(len(x), len(out))] = x[:len(out)]
    return out


def gunshot(dur, body_hz, crack_decay, body_decay, tone=0.0, cutoff=5000):
    n = white(dur)
    crack = highpass(n, 1500) * env(dur, 0.0005, crack_decay)
    body = lowpass(n, cutoff) * env(dur, 0.001, body_decay)
    thump = np.sin(2 * np.pi * body_hz * t(dur) * np.exp(-t(dur) * 8)) * env(dur, 0.001, body_decay * 0.8)
    return crack * 0.8 + body + thump * (0.8 + tone)


write("pistol.wav", gunshot(0.35, 110, 0.02, 0.06))
write("smg.wav", gunshot(0.22, 140, 0.012, 0.04, cutoff=6000))
write("rifle.wav", gunshot(0.5, 80, 0.03, 0.1, tone=0.3))
write("carbine.wav", gunshot(0.45, 95, 0.025, 0.09))
write("shotgun.wav", gunshot(0.8, 60, 0.04, 0.22, tone=0.5, cutoff=3000))
write("sniper.wav", gunshot(1.0, 55, 0.05, 0.25, tone=0.6, cutoff=4000))
write("lmg.wav", gunshot(0.4, 75, 0.02, 0.08, tone=0.4))
write("revolver.wav", gunshot(0.6, 70, 0.035, 0.13, tone=0.4))

# Energy weapon: falling sine sweep with buzz.
d = 0.45
tt = t(d)
freq = 1400 * np.exp(-tt * 9) + 180
phase = 2 * np.pi * np.cumsum(freq) / SR
zap = np.sign(np.sin(phase)) * 0.4 + np.sin(phase * 1.5) * 0.6
write("energy.wav", lowpass(zap, 4000) * env(d, 0.002, 0.15))

write("dryfire.wav", pad(highpass(white(0.03), 2000) * env(0.03, 0.0005, 0.006), 0.1))


def click(dur=0.04, hz=2500, decay=0.008):
    return highpass(white(dur), hz) * env(dur, 0.0005, decay)


r = np.zeros(int(SR * 1.0))
c1 = click(0.05, 1500, 0.01)
c2 = click(0.06, 900, 0.02)
r[int(SR * 0.05):int(SR * 0.05) + len(c1)] += c1
r[int(SR * 0.55):int(SR * 0.55) + len(c2)] += c2 * 1.2
write("reload.wav", r)

d = 0.25
sw = lowpass(white(d), 600 + 4000 * np.sin(np.pi * t(d) / d)) * np.sin(np.pi * t(d) / d) ** 2
write("knife.wav", sw)

d = 0.18
write("hit.wav", lowpass(white(d), 900) * env(d, 0.001, 0.04) + np.sin(2 * np.pi * 90 * t(d)) * env(d, 0.001, 0.05))
d = 0.35
write("headshot.wav", lowpass(white(d), 2200) * env(d, 0.001, 0.08) + 0.6 * np.sin(2 * np.pi * 60 * t(d)) * env(d, 0.001, 0.1))
d = 0.12
write("hitmarker.wav", np.sin(2 * np.pi * 2800 * t(d)) * env(d, 0.001, 0.02))

d = 0.5
cr = highpass(white(d), 800) * env(d, 0.001, 0.05)
cr += lowpass(white(d), 300) * env(d, 0.005, 0.12)
write("plank_break.wav", cr)
d = 0.3
write("plank_place.wav", lowpass(white(d), 500) * env(d, 0.001, 0.05) + np.sin(2 * np.pi * 180 * t(d)) * env(d, 0.001, 0.06))

# Purchase: two bright coin pings.
d = 0.6
p = np.zeros(int(SR * d))
for start, hz in ((0.0, 1318.5), (0.09, 1975.5)):
    s = int(SR * start)
    tt = np.arange(len(p) - s) / SR
    p[s:] += np.sin(2 * np.pi * hz * tt) * np.clip(tt / 0.002, 0, 1) * np.exp(-tt / 0.15)
write("buy.wav", p)
d = 0.35
write("denied.wav", np.sign(np.sin(2 * np.pi * 110 * t(d))) * 0.5 * env(d, 0.005, 0.2))


def groan(d, f0, wobble, brightness, seed):
    g = np.random.default_rng(seed)
    tt = t(d)
    f = f0 * (1 + 0.15 * np.sin(2 * np.pi * wobble * tt + g.uniform(0, 6))) * (1 - 0.25 * tt / d)
    phase = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((phase / (2 * np.pi)) % 1) - 1
    rough = g.uniform(-1, 1, len(tt))
    src = saw * 0.7 + rough * 0.5
    # Two crude formants ("aah" / "ooh") via band-passing.
    f1 = lowpass(src, brightness) - lowpass(src, brightness * 0.35)
    f2 = lowpass(src, brightness * 2.4) - lowpass(src, brightness * 1.6)
    shape = np.sin(np.pi * tt / d) ** 0.6
    return (f1 + 0.5 * f2) * shape


write("groan1.wav", groan(1.4, 85, 3.0, 700, 1))
write("groan2.wav", groan(1.1, 110, 5.0, 900, 2))
write("groan3.wav", groan(1.7, 70, 2.0, 600, 3))
write("growl.wav", groan(0.7, 140, 11.0, 1300, 4) + 0.3 * lowpass(white(0.7), 2000) * np.sin(np.pi * t(0.7) / 0.7))
write("zombie_death.wav", groan(0.9, 95, 1.5, 500, 5) * np.exp(-t(0.9) * 2))

d = 0.4
write("hurt.wav", lowpass(white(d), 400) * env(d, 0.001, 0.08) + np.sin(2 * np.pi * 55 * t(d)) * env(d, 0.001, 0.15))


def tone_seq(notes, dur_note, wave_fn, decay, gap=0.0, tail=0.6):
    total = len(notes) * (dur_note + gap) + tail
    out = np.zeros(int(SR * total))
    for i, hz in enumerate(notes):
        s = int(SR * i * (dur_note + gap))
        n = len(out) - s
        dd = n / SR
        tt = np.arange(n) / SR
        out[s:] += wave_fn(hz, tt) * np.clip(tt / 0.005, 0, 1) * np.exp(-tt / decay)
    return out


def bell(hz, tt):
    return (np.sin(2 * np.pi * hz * tt) + 0.5 * np.sin(2 * np.pi * hz * 2.76 * tt) * np.exp(-tt * 3)
            + 0.25 * np.sin(2 * np.pi * hz * 5.4 * tt) * np.exp(-tt * 6))


def pad_wave(hz, tt):
    return np.sin(2 * np.pi * hz * tt) + 0.3 * np.sin(2 * np.pi * hz * 2.01 * tt) + 0.2 * np.sin(2 * np.pi * hz * 0.5 * tt)


# Round start: low ominous bell strokes. Round end: descending minor figure.
write("round_start.wav", tone_seq([73.4, 73.4, 77.8], 0.9, bell, 1.2, tail=2.5))
write("round_end.wav", tone_seq([293.7, 277.2, 220.0, 146.8], 0.45, bell, 0.9, tail=2.0))
write("game_over.wav", tone_seq([146.8, 138.6, 110.0, 73.4], 0.8, pad_wave, 1.5, tail=3.0))

d = 1.0
sh = sum(np.sin(2 * np.pi * hz * t(d)) * np.exp(-t(d) * 3) for hz in (1568, 2093, 2637, 3136))
write("powerup_spawn.wav", sh * np.clip(t(d) / 0.05, 0, 1))
write("powerup_pick.wav", tone_seq([523.3, 659.3, 784.0, 1046.5], 0.07, lambda hz, tt: np.sin(2 * np.pi * hz * tt), 0.25, tail=0.5))
write("bomb.wav", lowpass(white(2.0), 600 * np.exp(-t(2.0) * 1.5) + 80) * env(2.0, 0.002, 0.6)
      + np.sin(2 * np.pi * 40 * t(2.0)) * env(2.0, 0.002, 0.5))

# Perk machine jingle (cheerful, slightly detuned organ).
def organ(hz, tt):
    return np.sin(2 * np.pi * hz * tt) + 0.5 * np.sin(2 * np.pi * hz * 2 * tt) + 0.3 * np.sin(2 * np.pi * hz * 3.01 * tt)


write("perk.wav", tone_seq([392, 523.3, 659.3, 784, 659.3, 784, 1046.5], 0.14, organ, 0.25, tail=0.8))

# Mystery box: music box arpeggio, about 4 s.
notes = [659.3, 784, 987.8, 1318.5, 1174.7, 987.8, 784, 880, 1046.5, 1318.5, 1567.9, 1318.5,
         1046.5, 880, 987.8, 1174.7, 1479.9, 1174.7, 987.8, 784, 659.3]
write("box.wav", tone_seq(notes, 0.18, lambda hz, tt: np.sin(2 * np.pi * hz * tt) + 0.2 * np.sin(2 * np.pi * hz * 4 * tt), 0.35, tail=0.5))

# Upgrade machine: rising mechanical whirr with clanks.
d = 3.2
tt = t(d)
f = 60 + 220 * tt / d
whirr = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 + lowpass(white(d), 400) * 0.6
for c in (0.2, 1.1, 2.0, 2.9):
    s = int(SR * c)
    k = click(0.15, 300, 0.05) * 2
    whirr[s:s + len(k)] += k
write("forge.wav", whirr * np.clip(tt / 0.1, 0, 1))

d = 1.2
creak_f = 200 + 80 * np.sin(2 * np.pi * 3 * t(d))
creak = lowpass(np.sign(np.sin(2 * np.pi * np.cumsum(creak_f) / SR)), 1500) * 0.3 * np.sin(np.pi * t(d) / d)
thud = np.zeros(int(SR * d))
th = lowpass(white(0.4), 200) * env(0.4, 0.002, 0.1)
thud[int(SR * 0.8):int(SR * 0.8) + len(th)] = th * 2
write("door.wav", creak + thud)

d = 0.25
write("step.wav", lowpass(white(d), 350) * env(d, 0.002, 0.03))
d = 0.6
write("jump_land.wav", lowpass(white(d), 250) * env(d, 0.002, 0.06))

# Dark ambient loop (10 s, loops cleanly: whole periods only).
d = 10.0
tt = t(d)
amb = (np.sin(2 * np.pi * 55 * tt) * 0.5 + np.sin(2 * np.pi * 82.5 * tt) * 0.3
       + np.sin(2 * np.pi * 110.3 * tt + 2 * np.sin(2 * np.pi * 0.2 * tt)) * 0.15)
amb *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.1 * tt)
wind = lowpass(white(d), 300 + 200 * (np.sin(2 * np.pi * 0.3 * tt) + 1))
wind_loop = wind.copy()
xf = int(SR * 1.0)
wind_loop[:xf] = wind[:xf] * np.linspace(0, 1, xf) + wind[-xf:] * np.linspace(1, 0, xf)
x = amb * 0.6 + wind_loop * 2.0
data = (np.clip(norm(x, 0.5), -1, 1) * 32767).astype("<i2")
with wave.open(os.path.join(SFX, "ambient.wav"), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data.tobytes())

print("textures:", sorted(os.listdir(TEX)))
print("sounds:", sorted(os.listdir(SFX)))
