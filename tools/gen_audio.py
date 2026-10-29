#!/usr/bin/env python3
"""Gera toda a trilha e os efeitos sonoros de The Witched Grove proceduralmente.

Sem samples de terceiros: harpa (Karplus-Strong), sinos (FM), flauta (seno com
vibrato e sopro), pads, ambiências (vento, pássaros, grilos, chuva) e efeitos.

Uso:
    python3 tools/gen_audio.py            # gera tudo em assets/audio/
Requisitos: numpy; ffmpeg com libvorbis para as músicas (.ogg).
Saída determinística (semente fixa) — rodar de novo produz os mesmos arquivos.
"""
import os
import shutil
import subprocess
import wave

import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")
SR_SFX = 22050
SR_MUS = 32000
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------- utilidades

def note_freq(name):
    """'A4' -> 440 Hz. Aceita sustenido (#)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[name[0]]
    i = 1
    if name[i] == "#":
        n += 1
        i += 1
    octave = int(name[i:])
    return 440.0 * 2 ** ((n + (octave - 4) * 12) / 12.0)


def t_axis(dur, sr):
    return np.arange(int(dur * sr)) / sr


def env_adsr(n, sr, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.ones(n) * s
    na, nd, nr = int(a * sr), int(d * sr), int(r * sr)
    na = max(1, min(na, n))
    e[:na] = np.linspace(0, 1, na)
    if nd > 0 and na + nd < n:
        e[na:na + nd] = np.linspace(1, s, nd)
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def env_exp(n, sr, decay):
    return np.exp(-np.arange(n) / sr / max(decay, 1e-4))


def fft_filter(x, sr, low=None, high=None):
    """Filtro passa-faixa suave no domínio da frequência (offline)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / sr)
    g = np.ones_like(f)
    if high is not None:
        g *= 1.0 / (1.0 + (f / high) ** 4)
    if low is not None:
        g *= 1.0 / (1.0 + (low / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(spec * g, len(x))


def reverb(x, sr, seconds=2.2, wet=0.3, wrap=False):
    n_ir = int(seconds * sr)
    ir = rng.standard_normal(n_ir) * np.exp(-np.arange(n_ir) / sr / (seconds / 5.0))
    ir = fft_filter(ir, sr, high=5000)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + n_ir
    size = 1 << int(np.ceil(np.log2(n)))
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
    if wrap:  # rabo de reverberação volta ao início: loop sem emenda
        tail = y[len(x):]
        y = y[:len(x)].copy()
        y[:len(tail)] += tail[:len(x)]
    else:
        y = y[:len(x)]
    return x * (1 - wet) + y * wet


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def place(buf, sig, start_s, sr, gain=1.0):
    i = int(start_s * sr)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[:end - i] * gain


def place_wrap(buf, sig, start_s, sr, gain=1.0):
    """Coloca um som e dá a volta no fim do buffer (loops perfeitos)."""
    i = int(start_s * sr) % len(buf)
    n = len(sig)
    first = min(n, len(buf) - i)
    buf[i:i + first] += sig[:first] * gain
    if first < n:
        rest = sig[first:]
        buf[:len(rest)] += rest[:len(buf)] * gain


# ----------------------------------------------------------------- instrumentos

def pluck(freq, dur, sr, bright=0.5, decay=0.996):
    """Harpa/violão por Karplus-Strong."""
    n = int(dur * sr)
    period = max(2, int(sr / freq))
    buf = rng.uniform(-1, 1, period)
    buf = fft_filter(np.concatenate([buf, buf]), sr, high=2000 + 6000 * bright)[:period]
    out = np.zeros(n)
    b = list(buf)
    idx = 0
    for i in range(n):
        v = b[idx]
        out[i] = v
        nxt = b[(idx + 1) % period]
        b[idx] = decay * 0.5 * (v + nxt)
        idx = (idx + 1) % period
    out *= env_adsr(n, sr, a=0.002, d=0.0, s=1.0, r=0.05)
    return out


def bell(freq, dur, sr, ratio=3.5, index=2.2, decay=1.2):
    t = t_axis(dur, sr)
    e = env_exp(len(t), sr, decay)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * e
    sig = np.sin(2 * np.pi * freq * t + mod) * e
    sig += 0.25 * np.sin(2 * np.pi * freq * 2.0 * t) * env_exp(len(t), sr, decay * 0.4)
    return sig * env_adsr(len(t), sr, a=0.003, d=0, s=1, r=0.05)


def flute(freq, dur, sr, vib=5.0):
    t = t_axis(dur, sr)
    vibrato = 1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.clip(t * 3, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vibrato) / sr
    sig = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = fft_filter(rng.standard_normal(len(t)), sr, low=freq, high=freq * 4) * 0.05
    return (sig + breath) * env_adsr(len(t), sr, a=0.08, d=0.1, s=0.8, r=min(0.25, dur * 0.4))


def pad(freqs, dur, sr, bright=1200):
    t = t_axis(dur, sr)
    sig = np.zeros(len(t))
    for f in freqs:
        for det in (-0.004, 0.0, 0.0045):
            ph = 2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6.28)
            sig += (2 * (ph / (2 * np.pi) % 1) - 1) * 0.3 + np.sin(ph) * 0.7
    sig = fft_filter(sig, sr, high=bright)
    return sig * env_adsr(len(t), sr, a=min(1.2, dur * 0.3), d=0.2, s=0.85, r=min(1.2, dur * 0.3))


def noise(dur, sr):
    return rng.standard_normal(int(dur * sr))


# ----------------------------------------------------------------- escrita

def write_wav(path, x, sr):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def write_ogg(path, x, sr, quality=3):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x, sr)
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis",
                        "-q:a", str(quality), path], check=True)
        os.remove(tmp)
    else:  # sem ffmpeg: mantém WAV
        os.replace(tmp, path.replace(".ogg", ".wav"))


# ----------------------------------------------------------------- música

def compose(chords, melody, bpm, beats_per_chord, sr, style):
    beat = 60.0 / bpm
    total = len(chords) * beats_per_chord * beat
    buf = np.zeros(int(total * sr))
    pad_buf = np.zeros_like(buf)
    for ci, chord in enumerate(chords):
        start = ci * beats_per_chord * beat
        freqs = [note_freq(n) for n in chord]
        p = pad([f / 2 for f in freqs[:3]], beats_per_chord * beat + 0.6, sr, bright=900 if style == "noite" else 1300)
        place_wrap(pad_buf, p, start, sr, 0.10)
        # arpejo
        steps = beats_per_chord * 2
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if style != "menu" else [0, 2, 1, 2, 3, 2]
        for s in range(steps):
            idx = pattern[s % len(pattern)] % len(freqs)
            f = freqs[idx]
            when = start + s * beat / 2
            if style == "dia":
                place_wrap(buf, pluck(f, 1.6, sr, bright=0.5), when, sr, 0.32)
            elif style == "noite":
                if s % 2 == 0:
                    place_wrap(buf, bell(f * 2, 2.2, sr, decay=1.0), when, sr, 0.16)
            else:
                place_wrap(buf, bell(f * 2, 1.4, sr, ratio=4.0, index=1.2, decay=0.6), when, sr, 0.13)
                if s % 3 == 0:
                    place_wrap(buf, pluck(f / 2, 1.8, sr, bright=0.3), when, sr, 0.22)
        # baixo
        place_wrap(buf, pluck(freqs[0] / 2, 2.5, sr, bright=0.2, decay=0.998), start, sr, 0.35)
    mel = np.zeros_like(buf)
    t = 0.0
    for name, beats in melody:
        dur = beats * beat
        if name != "-":
            f = note_freq(name)
            if style == "dia":
                place_wrap(mel, flute(f, dur * 0.95, sr), t, sr, 0.22)
            elif style == "noite":
                place_wrap(mel, bell(f, dur + 1.2, sr, ratio=2.0, index=1.0, decay=1.4), t, sr, 0.24)
            else:
                place_wrap(mel, bell(f * 2, dur + 0.8, sr, ratio=5.0, index=0.8, decay=0.8), t, sr, 0.2)
        t += dur
    mix = buf + pad_buf + mel
    mix = reverb(mix, sr, seconds=2.8 if style != "dia" else 2.0, wet=0.35, wrap=True)
    return normalize(mix, 0.8)


def music():
    # Dia: Ré maior, aconchegante.
    dia_chords = [["D4", "F#4", "A4", "D5"], ["G3", "B3", "D4", "G4"], ["B3", "D4", "F#4", "B4"], ["A3", "C#4", "E4", "A4"],
                  ["F#3", "A3", "C#4", "F#4"], ["G3", "B3", "D4", "G4"], ["D4", "F#4", "A4", "D5"], ["A3", "C#4", "E4", "A4"]]
    dia_mel = [("F#5", 2), ("E5", 1), ("D5", 1), ("A5", 3), ("-", 1), ("G5", 1), ("F#5", 1), ("E5", 1), ("D5", 1), ("B4", 3), ("-", 1),
               ("D5", 1), ("E5", 1), ("F#5", 2), ("E5", 2), ("C#5", 2), ("A4", 2), ("-", 2),
               ("F#5", 2), ("A5", 2), ("B5", 1), ("A5", 1), ("F#5", 2), ("G5", 2), ("F#5", 1), ("E5", 1), ("D5", 3), ("-", 1),
               ("E5", 2), ("F#5", 1), ("E5", 1), ("D5", 2), ("C#5", 2), ("D5", 4)]
    write_ogg(os.path.join(MUS_DIR, "tema_dia.ogg"), compose(dia_chords * 2, dia_mel, 84, 4, SR_MUS, "dia"), SR_MUS)
    # Noite: Lá menor dórico, sinos e estrelas.
    noite_chords = [["A3", "C4", "E4", "G4"], ["F3", "A3", "C4", "E4"], ["C4", "E4", "G4", "B4"], ["G3", "B3", "D4", "F#4"],
                    ["A3", "C4", "E4", "G4"], ["D4", "F4", "A4", "C5"], ["F3", "A3", "C4", "E4"], ["E3", "G#3", "B3", "E4"]]
    noite_mel = [("E5", 3), ("D5", 1), ("C5", 2), ("A4", 2), ("G4", 3), ("A4", 1), ("C5", 4),
                 ("E5", 2), ("G5", 2), ("F#5", 2), ("D5", 2), ("E5", 4), ("-", 4),
                 ("A5", 3), ("G5", 1), ("E5", 2), ("D5", 2), ("C5", 3), ("D5", 1), ("A4", 4),
                 ("C5", 2), ("B4", 2), ("A4", 2), ("G#4", 2), ("A4", 4), ("-", 4)]
    write_ogg(os.path.join(MUS_DIR, "tema_noite.ogg"), compose(noite_chords * 2, noite_mel, 66, 4, SR_MUS, "noite"), SR_MUS)
    # Menu: valsa em Mi maior, caixinha de música.
    menu_chords = [["E4", "G#4", "B4"], ["C#4", "E4", "G#4"], ["A3", "C#4", "E4"], ["B3", "D#4", "F#4"],
                   ["E4", "G#4", "B4"], ["G#3", "B3", "D#4"], ["A3", "C#4", "E4"], ["B3", "D#4", "F#4"]]
    menu_mel = [("B5", 2), ("G#5", 1), ("E5", 3), ("G#5", 2), ("F#5", 1), ("E5", 2), ("C#5", 1), ("E5", 3), ("B4", 3),
                ("C#5", 2), ("E5", 1), ("A5", 3), ("G#5", 2), ("F#5", 1), ("D#5", 3),
                ("E5", 2), ("G#5", 1), ("B5", 3), ("A5", 2), ("G#5", 1), ("F#5", 3), ("E5", 3)]
    write_ogg(os.path.join(MUS_DIR, "tema_menu.ogg"), compose(menu_chords * 2, menu_mel, 72, 3, SR_MUS, "menu"), SR_MUS)


# ----------------------------------------------------------------- ambiências

def bird_chirp(sr):
    dur = rng.uniform(0.08, 0.18)
    t = t_axis(dur, sr)
    f0 = rng.uniform(2500, 4200)
    sweep = f0 * (1 + rng.uniform(-0.3, 0.4) * t / dur)
    ph = 2 * np.pi * np.cumsum(sweep) / sr
    return np.sin(ph) * np.sin(np.pi * t / dur) ** 2


def ambience():
    sr = SR_MUS
    dur = 24.0
    # Floresta: vento + pássaros + folhas.
    wind = fft_filter(noise(dur, sr), sr, low=150, high=900)
    t = t_axis(dur, sr)
    wind *= 0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 3) ** 2
    buf = wind * 0.25
    for _ in range(40):
        start = rng.uniform(0, dur)
        n = rng.integers(2, 5)
        for k in range(n):
            place_wrap(buf, bird_chirp(sr), start + k * rng.uniform(0.1, 0.18), sr, rng.uniform(0.08, 0.2))
    buf = reverb(buf, sr, 1.5, 0.25, wrap=True)
    write_ogg(os.path.join(MUS_DIR, "amb_floresta.ogg"), normalize(buf, 0.6), sr, 2)
    # Noite: grilos + coruja + brisa.
    buf = fft_filter(noise(dur, sr), sr, low=100, high=500) * 0.12
    for c in range(3):
        f = 4300 + c * 350
        carrier = np.sin(2 * np.pi * f * t)
        pulses = (np.sin(2 * np.pi * (28 + c * 3) * t) > 0.3).astype(float)
        gate = (np.sin(2 * np.pi * (0.55 + c * 0.13) * t + c) > 0.1).astype(float)
        buf += fft_filter(carrier * pulses * gate, sr, high=6000) * 0.05
    for start in (3.0, 14.5):
        for k, (f, d) in enumerate([(392, 0.35), (370, 0.5)]):
            tt = t_axis(d, sr)
            hoot = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / d) ** 1.5
            place_wrap(buf, hoot, start + k * 0.5, sr, 0.18)
    buf = reverb(buf, sr, 2.5, 0.35, wrap=True)
    write_ogg(os.path.join(MUS_DIR, "amb_noite.ogg"), normalize(buf, 0.6), sr, 2)
    # Chuva
    rain = fft_filter(noise(dur, sr), sr, low=400, high=7000) * 0.35
    for _ in range(500):
        d = rng.uniform(0.01, 0.03)
        drip = noise(d, sr) * env_exp(int(d * sr), sr, 0.006)
        place_wrap(rain, fft_filter(drip, sr, low=1500, high=9000), rng.uniform(0, dur), sr, rng.uniform(0.1, 0.4))
    write_ogg(os.path.join(MUS_DIR, "amb_chuva.ogg"), normalize(rain, 0.55), sr, 2)


# ----------------------------------------------------------------- efeitos

def arpeggio(notes, step, sr, inst="bell", tail=0.8, gain=0.6):
    dur = step * len(notes) + tail
    buf = np.zeros(int(dur * sr))
    for i, n in enumerate(notes):
        f = note_freq(n)
        sig = bell(f, tail + 0.2, sr, decay=tail * 0.5) if inst == "bell" else pluck(f, tail + 0.2, sr)
        place(buf, sig, i * step, sr, gain)
    return buf


def sweep(f0, f1, dur, sr, shape="sine"):
    t = t_axis(dur, sr)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / sr
    return np.sin(ph) if shape == "sine" else (2 * (ph / (2 * np.pi) % 1) - 1)


def sfx():
    sr = SR_SFX
    S = {}
    S["ui_click"] = bell(note_freq("E6"), 0.12, sr, ratio=2, index=0.5, decay=0.04) * 0.5
    S["ui_open"] = arpeggio(["C5", "G5"], 0.05, sr, tail=0.3, gain=0.35)
    S["ui_close"] = arpeggio(["G5", "C5"], 0.05, sr, tail=0.3, gain=0.3)
    st = fft_filter(noise(0.09, sr), sr, low=300, high=2200) * env_exp(int(0.09 * sr), sr, 0.025)
    S["step"] = st * 0.5
    S["pickup"] = arpeggio(["E6", "B6"], 0.06, sr, tail=0.35, gain=0.4)
    rust = fft_filter(noise(0.35, sr), sr, low=1500, high=7000) * env_exp(int(0.35 * sr), sr, 0.08)
    S["harvest"] = rust * 0.6 + np.pad(pluck(note_freq("A5"), 0.3, sr), (0, len(rust)))[:len(rust)] * 0.3
    sh = np.zeros(int(0.9 * sr))
    place(sh, sweep(400, 1600, 0.5, sr) * env_adsr(int(0.5 * sr), sr, 0.05, 0.1, 0.6, 0.3), 0, sr, 0.25)
    place(sh, arpeggio(["C6", "E6", "G6", "C7"], 0.05, sr, tail=0.5, gain=0.3), 0.05, sr)
    S["spell_cast"] = reverb(sh, sr, 1.0, 0.3)
    fail = sweep(300, 120, 0.35, sr, "saw") * env_adsr(int(0.35 * sr), sr, 0.01, 0.05, 0.6, 0.15)
    S["spell_fail"] = fft_filter(fail, sr, high=900) * 0.6
    fire = fft_filter(noise(0.8, sr), sr, low=200, high=2500) * env_adsr(int(0.8 * sr), sr, 0.05, 0.2, 0.5, 0.4)
    fire *= 1 + 0.6 * np.sin(2 * np.pi * 14 * t_axis(0.8, sr))
    S["spell_fire"] = reverb(fire * 0.6 + np.pad(S["spell_cast"], (0, 0))[:len(fire)] * 0.3, sr, 0.8, 0.2)
    grow = np.zeros(int(1.2 * sr))
    for i, n in enumerate(["G4", "B4", "D5", "G5", "B5", "D6"]):
        place(grow, pluck(note_freq(n), 0.8, sr, bright=0.6), i * 0.07, sr, 0.3)
    S["spell_grow"] = reverb(grow, sr, 1.2, 0.3)
    S["spell_light"] = reverb(arpeggio(["A5", "C#6", "E6", "A6", "E7"], 0.06, sr, tail=0.9, gain=0.28), sr, 1.5, 0.35)
    ice = np.zeros(int(1.0 * sr))
    for i in range(10):
        place(ice, bell(rng.uniform(2500, 5000), 0.4, sr, ratio=1.41, index=3, decay=0.12), i * 0.05, sr, 0.15)
    S["spell_ice"] = reverb(ice, sr, 1.2, 0.3)
    wind = fft_filter(noise(1.0, sr), sr, low=300, high=1500) * np.sin(np.pi * t_axis(1.0, sr)) ** 2
    S["spell_wind"] = wind * 0.7
    shield = sweep(200, 600, 0.6, sr) * env_adsr(int(0.6 * sr), sr, 0.02, 0.1, 0.7, 0.3) * 0.3
    shield += np.pad(bell(note_freq("E5"), 0.6, sr, ratio=1.5, index=1.5, decay=0.4), (0, 0))[:len(shield)] * 0.3
    S["spell_shield"] = reverb(shield, sr, 1.0, 0.3)
    veil = fft_filter(noise(0.9, sr), sr, low=800, high=3000) * env_adsr(int(0.9 * sr), sr, 0.3, 0.1, 0.6, 0.4) * 0.4
    veil += sweep(900, 300, 0.9, sr) * env_adsr(int(0.9 * sr), sr, 0.2, 0.1, 0.5, 0.4) * 0.15
    S["spell_veil"] = reverb(veil, sr, 1.5, 0.4)
    S["spell_purify"] = reverb(arpeggio(["C5", "G5", "C6", "E6", "G6", "C7"], 0.08, sr, tail=1.2, gain=0.25), sr, 2.0, 0.4)
    S["brew_success"] = reverb(arpeggio(["C5", "E5", "G5", "C6"], 0.09, sr, tail=0.8, gain=0.35), sr, 1.2, 0.3)
    poof = fft_filter(noise(0.5, sr), sr, low=80, high=800) * env_exp(int(0.5 * sr), sr, 0.12)
    S["brew_fail"] = poof * 0.7 + np.pad(sweep(220, 110, 0.4, sr, "saw") * 0.15, (0, int(0.1 * sr)))[:len(poof)]
    pg = fft_filter(noise(0.28, sr), sr, low=1200, high=6000) * np.sin(np.pi * t_axis(0.28, sr)) ** 3
    S["page_turn"] = pg * 0.6
    S["discovery"] = reverb(arpeggio(["G5", "B5", "D6", "G6"], 0.07, sr, tail=1.0, gain=0.3), sr, 1.6, 0.35)
    S["quest_complete"] = reverb(arpeggio(["C5", "E5", "G5", "C6", "G5", "C6"], 0.1, sr, inst="pluck", tail=0.9, gain=0.35), sr, 1.2, 0.3)
    water = np.zeros(int(0.6 * sr))
    for i in range(14):
        b = sweep(rng.uniform(600, 1200), rng.uniform(1500, 2600), 0.05, sr) * env_exp(int(0.05 * sr), sr, 0.015)
        place(water, b, rng.uniform(0, 0.5), sr, 0.2)
    water += fft_filter(noise(0.6, sr), sr, low=600, high=4000) * env_exp(int(0.6 * sr), sr, 0.2) * 0.15
    S["water"] = water
    S["plant"] = fft_filter(noise(0.2, sr), sr, low=100, high=900) * env_exp(int(0.2 * sr), sr, 0.06) * 0.8
    S["coin"] = arpeggio(["B6", "E7"], 0.05, sr, tail=0.3, gain=0.35)
    gr = sweep(110, 80, 0.9, sr, "saw") * (1 + 0.5 * np.sin(2 * np.pi * 9 * t_axis(0.9, sr)))
    S["grumble"] = fft_filter(gr, sr, high=600) * env_adsr(int(0.9 * sr), sr, 0.05, 0.1, 0.8, 0.3) * 0.8
    trill = np.zeros(int(0.7 * sr))
    for i in range(6):
        place(trill, bell(note_freq("E6") * (1.12 if i % 2 else 1.0), 0.2, sr, ratio=2, index=0.4, decay=0.08), i * 0.07, sr, 0.25)
    S["creature_calm"] = reverb(trill, sr, 1.0, 0.3)
    S["wisp_chime"] = reverb(arpeggio(["E6", "G#6", "B6"], 0.12, sr, tail=1.2, gain=0.25), sr, 1.8, 0.4)
    tp = sweep(300, 2400, 0.7, sr) * env_adsr(int(0.7 * sr), sr, 0.05, 0.1, 0.7, 0.3) * 0.2
    S["teleport"] = reverb(tp + np.pad(arpeggio(["C6", "G6", "C7"], 0.06, sr, tail=0.4, gain=0.2), (0, int(0.7 * sr)))[:len(tp)], sr, 1.5, 0.4)
    S["rest"] = reverb(arpeggio(["E5", "C5", "A4", "E4"], 0.25, sr, tail=1.2, gain=0.25), sr, 2.0, 0.4)
    # porta de madeira: rangido + batida
    creak = sweep(180, 260, 0.45, sr, "saw") * (1 + 0.6 * np.sin(2 * np.pi * 23 * t_axis(0.45, sr)))
    creak = fft_filter(creak, sr, low=150, high=1400) * env_adsr(int(0.45 * sr), sr, 0.03, 0.1, 0.5, 0.2) * 0.35
    thud = fft_filter(noise(0.2, sr), sr, low=40, high=300) * env_exp(int(0.2 * sr), sr, 0.05)
    door = np.zeros(int(0.75 * sr))
    place(door, creak, 0.0, sr)
    place(door, thud, 0.45, sr, 0.9)
    S["door"] = door
    # "bip" de voz dos diálogos
    S["blip"] = bell(note_freq("A5"), 0.06, sr, ratio=1.0, index=0.3, decay=0.03) * 0.6
    # livro abrindo: farfalhar + acorde suave
    swish = fft_filter(noise(0.6, sr), sr, low=800, high=5000) * np.sin(np.pi * t_axis(0.6, sr)) ** 2
    book = np.zeros(int(1.4 * sr))
    place(book, swish * 0.6, 0.0, sr)
    place(book, arpeggio(["D5", "F#5", "A5", "D6"], 0.06, sr, tail=0.9, gain=0.22), 0.3, sr)
    S["book_open"] = reverb(book, sr, 1.5, 0.3)
    # borbulhar do caldeirão
    bub = np.zeros(int(1.6 * sr))
    for i in range(22):
        b = sweep(rng.uniform(150, 300), rng.uniform(400, 900), 0.07, sr) * env_exp(int(0.07 * sr), sr, 0.02)
        place(bub, b, rng.uniform(0, 1.5), sr, rng.uniform(0.15, 0.35))
    S["brew_bubble"] = fft_filter(bub, sr, high=2500)
    for name, sig in S.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), normalize(sig, 0.85), sr)
    return list(S.keys())


if __name__ == "__main__":
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUS_DIR, exist_ok=True)
    names = sfx()
    print("Efeitos:", len(names))
    ambience()
    music()
    print("Músicas e ambiências geradas em", MUS_DIR)
