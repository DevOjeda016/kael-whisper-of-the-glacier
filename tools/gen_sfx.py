#!/usr/bin/env python3
"""Genera los sonidos provisionales de Kael (síntesis procedural, sin dependencias).

Uso:  python3 tools/gen_sfx.py
Escribe .wav mono 16-bit en assets/audio/sfx/. Para usar audio real basta con
reemplazar el archivo con el mismo nombre (o cambiar la ruta en el script de Godot).
Todo es determinista (semillas fijas): volver a correrlo da los mismos archivos.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


# ---------- utilidades ----------

def write(name, samples):
	os.makedirs(OUT, exist_ok=True)
	peak = max(1e-9, max(abs(s) for s in samples))
	gain = 0.89 / peak
	path = os.path.join(OUT, name)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
	print(f"{name}: {len(samples) / RATE:.2f} s")


def white(n, rng):
	return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def brown(n, rng, leak=0.02):
	out, v = [], 0.0
	for _ in range(n):
		v = (v + rng.uniform(-1.0, 1.0) * 0.1) * (1.0 - leak)
		out.append(v)
	return out


def lowpass(x, cutoff):
	a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
	out, y = [], 0.0
	for s in x:
		y += a * (s - y)
		out.append(y)
	return out


def highpass(x, cutoff):
	lp = lowpass(x, cutoff)
	return [a - b for a, b in zip(x, lp)]


def bandpass(x, center, q=1.0):
	"""Biquad pasa-banda (RBJ)."""
	w0 = 2.0 * math.pi * center / RATE
	alpha = math.sin(w0) / (2.0 * q)
	b0, b1, b2 = alpha, 0.0, -alpha
	a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
	out = []
	x1 = x2 = y1 = y2 = 0.0
	for s in x:
		y = (b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2, x1, y2, y1 = x1, s, y1, y
		out.append(y)
	return out


def smooth_random(n, rng, every):
	"""Curva aleatoria suave (interpolación coseno entre puntos cada `every` muestras)."""
	pts = [rng.random() for _ in range(n // every + 3)]
	out = []
	for i in range(n):
		k, f = divmod(i, every)
		f = (1 - math.cos(math.pi * f / every)) * 0.5
		out.append(pts[k] * (1 - f) + pts[k + 1] * f)
	return out


def make_loop(x, fade):
	"""Vuelve un sonido cíclico sin clic: funde el final sobre el principio."""
	n = len(x) - fade
	out = x[:n]
	for i in range(fade):
		t = i / fade
		out[i] = out[i] * t + x[n + i] * (1 - t)
	return out


def env_ad(n, attack, decay_rate):
	a = max(1, int(attack * RATE))
	return [i / a if i < a else math.exp(-(i - a) / RATE * decay_rate) for i in range(n)]


def mix(*tracks):
	n = max(len(t) for t in tracks)
	return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


# ---------- sonidos ----------

def wind_loop():
	rng = random.Random(1)
	n = int(12 * RATE)
	fade = int(1.5 * RATE)
	base = brown(n + fade, rng, 0.01)
	low = lowpass(base, 500)
	hiss = bandpass(white(n + fade, rng), 900, 0.6)
	swell = smooth_random(n + fade, rng, int(1.6 * RATE))
	whistle_mod = smooth_random(n + fade, rng, int(2.3 * RATE))
	whistle = bandpass(white(n + fade, rng), 1500, 6.0)
	x = [l * (0.5 + 0.8 * s) + h * 0.12 * (0.3 + s) + w * 0.35 * wm * wm
		for l, h, s, w, wm in zip(low, hiss, swell, whistle, whistle_mod)]
	write("wind_loop.wav", make_loop(x, fade))


def water_loop():
	rng = random.Random(2)
	n = int(8 * RATE)
	fade = int(1.0 * RATE)
	total = n + fade
	bed = lowpass(brown(total, rng, 0.02), 300)
	laps = [0.0] * total
	t = 0
	while t < total:
		length = int(rng.uniform(0.35, 0.8) * RATE)
		burst = bandpass(white(length, rng), rng.uniform(350, 700), 1.2)
		for i in range(length):
			if t + i < total:
				e = math.sin(math.pi * i / length) ** 2
				laps[t + i] += burst[i] * e * rng.uniform(0.6, 1.0)
		t += int(rng.uniform(0.4, 1.1) * RATE)
	x = [b * 0.6 + l * 0.9 for b, l in zip(bed, laps)]
	write("water_loop.wav", make_loop(x, fade))


def snow_steps():
	for v in range(4):
		rng = random.Random(10 + v)
		n = int(0.16 * RATE)
		noise = bandpass(white(n, rng), rng.uniform(1800, 2600), 0.9)
		crackle = [0.0] * n
		for _ in range(rng.randint(18, 30)):
			i = rng.randrange(0, int(n * 0.8))
			crackle[i] = rng.uniform(-1, 1)
		crackle = bandpass(crackle, 3500, 1.5)
		thump = lowpass(white(n, rng), 180)
		env = env_ad(n, 0.008, 28)
		x = [(a * 0.6 + c * 2.0 + t * 1.5) * e for a, c, t, e in zip(noise, crackle, thump, env)]
		write(f"step_snow_{v + 1}.wav", x)


def ice_create():
	rng = random.Random(20)
	n = int(0.9 * RATE)
	partials = [(1180, 1.0, 5.0), (2630, 0.6, 7.0), (4070, 0.4, 9.0), (5910, 0.25, 12.0)]
	tone = [0.0] * n
	for f, amp, dec in partials:
		for i in range(n):
			t = i / RATE
			freq = f * (1.0 + 0.04 * min(t * 8, 1))   # leve subida, como algo que se forma
			tone[i] += amp * math.sin(2 * math.pi * freq * t) * math.exp(-t * dec)
	frost = bandpass(white(n, rng), 5000, 0.8)
	frost_env = [min(1.0, i / (0.15 * RATE)) * math.exp(-i / RATE * 6) for i in range(n)]
	attack = [min(1.0, i / (0.01 * RATE)) for i in range(n)]
	x = [(t * 0.5 + f * fe * 0.5) * a for t, f, fe, a in zip(tone, frost, frost_env, attack)]
	write("ice_create.wav", x)


def ice_shatter():
	rng = random.Random(30)
	n = int(0.8 * RATE)
	crack = highpass(white(n, rng), 1200)
	crack_env = env_ad(n, 0.002, 14)
	pings = [0.0] * n
	for _ in range(14):
		start = int(rng.uniform(0.0, 0.35) * RATE)
		f = rng.uniform(2500, 7000)
		dec = rng.uniform(18, 35)
		amp = rng.uniform(0.2, 0.5)
		for i in range(start, n):
			t = (i - start) / RATE
			pings[i] += amp * math.sin(2 * math.pi * f * t) * math.exp(-t * dec)
	x = [c * e * 0.8 + p * 0.6 for c, e, p in zip(crack, crack_env, pings)]
	write("ice_shatter.wav", x)


def splash():
	rng = random.Random(40)
	n = int(0.7 * RATE)
	body = bandpass(white(n, rng), 800, 0.7)
	spray = highpass(white(n, rng), 3000)
	env = env_ad(n, 0.01, 7)
	spray_env = env_ad(n, 0.02, 12)
	x = [b * e + s * se * 0.4 for b, e, s, se in zip(body, env, spray, spray_env)]
	write("splash.wav", x)


def beacon_chime():
	n = int(3.2 * RATE)
	notes = [(0.0, 659.25), (0.18, 987.77), (0.36, 1318.5)]   # mi, si, mi: abierto y "mágico"
	x = [0.0] * n
	for start, f in notes:
		s0 = int(start * RATE)
		for i in range(s0, n):
			t = (i - s0) / RATE
			env = min(1.0, t / 0.005) * math.exp(-t * 1.6)
			x[i] += env * (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-t * 3)
				+ 0.2 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-t * 6))
	write("beacon_chime.wav", x)


def glacier_groan():
	rng = random.Random(50)
	n = int(4.5 * RATE)
	x = [0.0] * n
	phase = 0.0
	wob = smooth_random(n, rng, int(0.4 * RATE))
	for i in range(n):
		t = i / RATE
		f = 55 + 25 * math.sin(t * 0.9) + 12 * wob[i]
		phase += 2 * math.pi * f / RATE
		env = math.sin(math.pi * min(t / 4.5, 1.0)) ** 1.5
		x[i] = (math.sin(phase) + 0.4 * math.sin(phase * 2.03) + 0.2 * math.sin(phase * 3.1)) * env
	rumble = lowpass(brown(n, rng, 0.01), 120)
	creak = [0.0] * n
	for _ in range(25):
		i = rng.randrange(int(0.5 * RATE), int(4 * RATE))
		creak[i] = rng.uniform(-1, 1)
	creak = bandpass(creak, 600, 3)
	x = [a * 0.6 + r * 1.2 + c * 3.0 for a, r, c in zip(x, rumble, creak)]
	write("glacier_groan.wav", x)


if __name__ == "__main__":
	wind_loop()
	water_loop()
	snow_steps()
	ice_create()
	ice_shatter()
	splash()
	beacon_chime()
	glacier_groan()
