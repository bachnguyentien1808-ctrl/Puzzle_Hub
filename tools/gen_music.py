#!/usr/bin/env python3
"""Sáng tác và sinh nhạc nền vào assets/music/<tên>.mp3.

Chạy: python3 tools/gen_music.py              (sinh nhạc 8 game)
      python3 tools/gen_music.py lobby sudoku (chỉ sinh các bài nêu tên)
Cần numpy và ffmpeg. Mỗi bài lặp liền mạch (đuôi vang ghép vào đầu).

Các bài (tên file = id game, riêng "lobby" là nhạc sảnh chờ), đều vui vẻ,
giải trí và hợp chủ đề từng game:
  lobby       "Tươi vui thư giãn": ukulele quạt nhẹ, hộp nhạc, shaker, búng ngón tay
  lobby_candy "Kẹo ngọt": ukulele quạt, huýt sáo, nhịp pop vỗ tay (bài trước)
  sudoku      "Đố vui": pizzicato nảy, mộc cầm, swing nhẹ
  game2048    "Arcade": chiptune xung vuông, kick/snare 8-bit
  nonogram    "Họa sĩ pixel": hộp nhạc, piano đồ chơi, shaker
  memory      "Rạp xiếc": calliope, oom-pah, trống diễu hành
  minesweeper "Điệp viên hoạt hình": kèn staccato, slap bass, funk
  lights_out  "Disco neon": synth sáng, bè octave, hi-hat mở, vỗ tay
  sliding     "Xưởng đồ chơi": piano đồ chơi, mộc cầm, shaker nhẹ
  kakuro      "Gameshow": swing, kèn đồng nảy, bè đi bộ
  lobby_lofi  bài lo-fi chill cũ (không sinh mặc định)
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "music"

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi_of(name):
    n = NOTE[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        n -= 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + n


def hz_of_midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lowpass(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def tt(dur):
    return np.arange(int(dur * RATE)) / RATE


def rel_env(t, dur, r):
    return np.clip((dur - t) / r, 0, 1)


# ---------------------------------------------------------------- nhạc cụ
def rhodes(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    body = np.sin(ph) + 0.22 * np.sin(2 * ph)
    tine = 0.35 * np.sin(2 * np.pi * f * 7 * t) * np.exp(-26 * t)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 4.6 * t)
    return (body + tine) * np.minimum(1, t / 0.006) * np.exp(-1.6 * t) * trem * rel_env(t, dur, 0.18) * vel


def piano(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.5 * np.sin(2 * ph) * np.exp(-3 * t) + 0.25 * np.sin(3 * ph) * np.exp(-5 * t) + 0.1 * np.sin(4 * ph) * np.exp(-8 * t)
    return w * np.minimum(1, t / 0.003) * np.exp(-1.9 * t) * rel_env(t, dur, 0.12) * vel


def musicbox(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.4 * np.sin(2.76 * ph) * np.exp(-6 * t) + 0.15 * np.sin(5.4 * ph) * np.exp(-12 * t)
    return w * np.minimum(1, t / 0.002) * np.exp(-3.4 * t) * rel_env(t, dur, 0.1) * vel


def marimba(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.35 * np.sin(4 * ph) * np.exp(-14 * t)
    return w * np.minimum(1, t / 0.002) * np.exp(-7 * t) * rel_env(t, dur, 0.05) * vel


def bell(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.18 * np.sin(3.01 * ph) + 0.06 * np.sin(4.2 * ph)
    return w * np.minimum(1, t / 0.006) * np.exp(-2.6 * t) * rel_env(t, dur, 0.25) * vel


def glass(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.5 * np.sin(3 * ph) * np.exp(-2 * t) + 0.2 * np.sin(5.04 * ph)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 3.1 * t)
    return w * np.minimum(1, t / 0.05) * np.exp(-1.3 * t) * trem * rel_env(t, dur, 0.4) * vel


def pad(f, dur, vel=1.0, att=0.4):
    t = tt(dur)
    w = np.zeros_like(t)
    for det in (-0.005, 0.0, 0.005):
        ph = 2 * np.pi * f * (1 + det) * t
        w += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    return w / 3 * np.minimum(1, t / att) * rel_env(t, dur, 0.7) * vel


def synth_pluck(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = sum(np.sin(k * ph) / k for k in range(1, 7))
    w = w * (0.35 + 0.65 * np.exp(-9 * t))  # sáng rồi tối dần
    return w * np.minimum(1, t / 0.003) * np.exp(-5.5 * t) * rel_env(t, dur, 0.05) * vel


def ks_pluck(f, dur, vel=1.0, damp=0.996, rng=None):
    """Karplus-Strong: dây gảy (guitar/pizzicato)."""
    rng = rng or np.random.default_rng(3)
    n = int(dur * RATE)
    L = max(2, int(RATE / f))
    buf = rng.uniform(-1, 1, L)
    buf = buf - buf.mean()
    out = np.zeros(n)
    out[:L] = buf[: min(L, n)]
    i = L
    while i < n:
        seg = min(L, n - i)
        prev = out[i - L : i - L + seg]
        prev2 = out[i - L - 1 : i - L - 1 + seg] if i - L - 1 >= 0 else prev
        out[i : i + seg] = damp * 0.5 * (prev + prev2)
        i += seg
    t = np.arange(n) / RATE
    return out * rel_env(t, dur, 0.05) * vel


def bass_sine(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.18 * np.sin(2 * ph)
    return w * np.minimum(1, t / 0.012) * np.exp(-2.4 * t) * rel_env(t, dur, 0.08) * vel


def sub(f, dur, vel=1.0):
    t = tt(dur)
    return np.sin(2 * np.pi * f * t) * np.minimum(1, t / 0.08) * np.exp(-0.9 * t) * rel_env(t, dur, 0.3) * vel


def drone(f, dur, vel=1.0):
    t = tt(dur)
    w = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t + 0.6 * np.sin(2 * np.pi * 0.25 * t))
    return w * np.minimum(1, t / 1.2) * rel_env(t, dur, 1.2) * vel


def whistle(f, dur, vel=1.0):
    t = tt(dur)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.15)
    w = np.sin(2 * np.pi * f * t * vib) + 0.12 * np.sin(4 * np.pi * f * t * vib)
    return w * np.minimum(1, t / 0.04) * np.exp(-1.1 * t) * rel_env(t, dur, 0.1) * vel


def chip(f, dur, vel=1.0, duty=0.25):
    t = tt(dur)
    pulse = np.where((f * t) % 1.0 < duty, 1.0, -1.0) * 0.55
    return pulse * np.minimum(1, t / 0.002) * np.exp(-3.2 * t) * rel_env(t, dur, 0.03) * vel


def calliope(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = sum(np.sin(k * ph) / k for k in (1, 3, 5, 7)) + 0.18 * np.sin(2 * ph)
    trem = 1 + 0.07 * np.sin(2 * np.pi * 6 * t)
    return w * 0.6 * np.minimum(1, t / 0.02) * np.exp(-0.9 * t) * trem * rel_env(t, dur, 0.06) * vel


def brass(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = sum(np.sin(k * ph) / k * np.exp(-0.5 * k * t) for k in range(1, 9))
    swell = 1 - np.exp(-t / 0.025)
    return w * 0.6 * swell * np.exp(-2.8 * t) * rel_env(t, dur, 0.05) * vel


def toypiano(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.6 * np.sin(2.3 * ph) * np.exp(-8 * t) + 0.3 * np.sin(4.1 * ph) * np.exp(-14 * t)
    return w * np.minimum(1, t / 0.002) * np.exp(-6 * t) * rel_env(t, dur, 0.05) * vel


def xylo(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.5 * np.sin(3 * ph) * np.exp(-18 * t) + 0.2 * np.sin(6 * ph) * np.exp(-25 * t)
    return w * np.minimum(1, t / 0.001) * np.exp(-8 * t) * rel_env(t, dur, 0.04) * vel


def slap_bass(f, dur, vel=1.0):
    t = tt(dur)
    ph = 2 * np.pi * f * t
    w = np.sin(ph) + 0.55 * np.sin(2 * ph) * np.exp(-12 * t)
    click = np.sin(2 * np.pi * f * 6 * t) * np.exp(-60 * t) * 0.25
    return (w + click) * np.minimum(1, t / 0.002) * np.exp(-6 * t) * rel_env(t, dur, 0.04) * vel


# ---------------------------------------------------------------- trống
def kick(rng, soft=1.0):
    t = tt(0.3)
    f = 95 * np.exp(-16 * t) + 42
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-10 * t) * soft


def snare(rng):
    t = tt(0.22)
    x = lowpass(rng.standard_normal(len(t)), 3200) * np.exp(-22 * t)
    return x + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-30 * t)


def clap(rng):
    t = tt(0.14)
    return lowpass(rng.standard_normal(len(t)), 3800) * np.exp(-30 * t)


def hat(rng, open_=False):
    t = tt(0.16 if open_ else 0.04)
    x = rng.standard_normal(len(t))
    x = x - lowpass(x, 6000)
    return lowpass(x, 9000) * np.exp(-(24 if open_ else 110) * t)


def chip_kick():
    t = tt(0.12)
    f = 140 * np.exp(-28 * t) + 50
    return np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.6 * np.exp(-18 * t)


def chip_snare(rng):
    t = tt(0.1)
    return rng.choice([-1.0, 1.0], len(t)) * 0.5 * np.exp(-30 * t)


def chip_hat(rng):
    t = tt(0.03)
    return rng.choice([-1.0, 1.0], len(t)) * 0.3 * np.exp(-80 * t)


def shaker(rng):
    t = tt(0.09)
    x = rng.standard_normal(len(t))
    x = x - lowpass(x, 4500)
    return x * np.minimum(1, t / 0.02) * np.exp(-38 * t)


def brush(rng):
    t = tt(0.2)
    x = lowpass(rng.standard_normal(len(t)), 5000)
    x = x - lowpass(x, 800)
    return x * np.minimum(1, t / 0.03) * np.exp(-12 * t)


def tick(rng):
    t = tt(0.025)
    return np.sin(2 * np.pi * 2800 * t) * np.exp(-150 * t)


def vinyl(total, rng):
    n = int(total * RATE)
    out = lowpass(rng.standard_normal(n), 4000) * 0.004
    for _ in range(int(total * 2.2)):
        i = int(rng.uniform(0, n - 400))
        pop = rng.standard_normal(60) * np.exp(-np.arange(60) / 9.0)
        out[i : i + 60] += pop * rng.uniform(0.01, 0.05)
    return out


# ---------------------------------------------------------------- hoà âm
# (bè trầm, các nốt đàn) trong Đô trưởng; chuyển giọng bằng "transpose".
CH = {
    "C": ("C2", ["E3", "G3", "C4", "E4"]),
    "G": ("G1", ["B3", "D4", "G4"]),
    "Am": ("A1", ["C4", "E4", "A4"]),
    "F": ("F1", ["A3", "C4", "F4"]),
    "Cmaj7": ("C2", ["E3", "G3", "B3", "D4"]),
    "Am7": ("A1", ["E3", "G3", "B3", "C4"]),
    "Dm7": ("D2", ["F3", "A3", "C4", "E4"]),
    "G7": ("G1", ["F3", "A3", "B3", "D4"]),
    "Fmaj7": ("F1", ["E3", "G3", "A3", "C4"]),
    "Em7": ("E2", ["D3", "G3", "B3", "E4"]),
    "Dm9": ("D2", ["F3", "A3", "C4", "E4"]),
    "A7": ("A1", ["E3", "G3", "C#4", "E4"]),
    "Cadd9": ("C2", ["E3", "G3", "D4", "G4"]),
    "Fadd9": ("F1", ["A3", "C4", "G4", "C5"]),
}

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "pent": [0, 2, 4, 7, 9],
    "minpent": [0, 3, 5, 7, 10],
}

RHYTHMS = {
    "sparse": [
        [(0, 3)], [(1, 1.5), (3, 1)], [(0, 1), (2, 2)], [(0.5, 1.5), (2.5, 1.5)],
        [(2, 2)], [(0, 2), (3, 1)],
    ],
    "medium": [
        [(0, 1), (1, 1), (2, 2)], [(0, 0.5), (0.5, 0.5), (1, 1), (2, 1), (3, 1)],
        [(0, 1.5), (1.5, 0.5), (2, 1), (3, 1)], [(1, 1), (2, 0.5), (2.5, 0.5), (3, 1)],
        [(0, 1), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5)],
    ],
    "busy": [
        [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)],
        [(0, 1), (1, 0.5), (1.5, 0.5), (2, 0.5), (2.5, 0.5), (3, 1)],
        [(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 0.5), (3, 0.5), (3.5, 0.5)],
    ],
}


def gen_melody(rng, prog, scale, lo, hi, density):
    """Giai điệu 8 ô: A A' B C. Nốt đầu ô rơi vào nốt hoà âm cho êm tai."""
    pcs = set()
    for r in scale:
        pcs.add(r % 12)
    notes = [m for m in range(lo, hi + 1) if (m % 12) in pcs]
    bars = []
    prev = notes[len(notes) // 2]

    def chord_pcs(name):
        _, voicing = CH[name]
        return {midi_of(x) % 12 for x in voicing}

    def make_bar(chord, last=False):
        nonlocal prev
        cp = chord_pcs(chord)
        rhythm = RHYTHMS[density][rng.integers(len(RHYTHMS[density]))]
        out = []
        for k, (pos, ln) in enumerate(rhythm):
            if k == 0:
                cands = [m for m in notes if (m % 12) in cp] or notes
                m = min(cands, key=lambda x: abs(x - prev) + rng.uniform(0, 3))
            else:
                i = notes.index(prev) if prev in notes else len(notes) // 2
                step = rng.choice([-2, -1, -1, 0, 1, 1, 2], p=[.08, .27, .1, .05, .27, .15, .08])
                i = int(np.clip(i + step, 0, len(notes) - 1))
                m = notes[i]
            prev = m
            out.append((pos, m, ln))
        return out

    a = [make_bar(prog[0]), make_bar(prog[1])]
    b = [make_bar(prog[2]), make_bar(prog[3])]
    bars = a + b
    bars += [a[0], make_bar(prog[5])]
    c = [make_bar(prog[6]), make_bar(prog[7])]
    bars += c
    # Ô cuối: nốt chủ âm dài, khép câu.
    root_pc = midi_of(CH[prog[7]][0]) % 12
    cands = [m for m in notes if (m % 12) == root_pc] or notes
    last = min(cands, key=lambda x: abs(x - prev))
    bars[7] = [(0, last, 3.5)]
    return bars


# ---------------------------------------------------------------- cấu hình bài
LOBBY_MEL_A = [
    [(0.0, "E5", 2.5)], [(1.0, "C5", 1.5), (3.0, "D5", 1.0)],
    [(0.0, "F5", 1.0), (1.5, "E5", 0.5), (2.0, "D5", 2.0)], [(2.0, "B4", 1.5)],
    [(0.5, "A4", 1.5), (2.5, "C5", 1.5)], [(0.0, "B4", 1.0), (1.5, "G4", 2.5)],
    [(1.0, "A4", 1.0), (2.0, "C5", 0.5), (2.5, "D5", 1.5)], [(0.0, "E5", 3.0)],
]
LOBBY_MEL_B = [
    [(0.0, "G5", 1.5), (2.0, "E5", 2.0)], [(0.5, "E5", 1.0), (2.0, "C5", 1.0), (3.0, "A4", 1.0)],
    [(0.0, "A5", 1.5), (2.0, "F5", 1.0), (3.0, "E5", 1.0)], [(0.0, "D5", 1.0), (2.0, "B4", 2.0)],
    [(0.0, "C5", 1.0), (1.0, "E5", 1.0), (2.0, "A5", 2.0)],
    [(0.0, "G5", 1.0), (1.5, "E5", 1.0), (3.0, "D5", 1.0)],
    [(0.0, "F5", 1.5), (2.0, "E5", 0.5), (2.5, "D5", 0.5), (3.0, "C5", 1.0)],
    [(0.0, "D5", 1.0), (1.5, "E5", 3.0)],
]

PROG_JAZZ = ["Cmaj7", "Am7", "Dm7", "G7", "Fmaj7", "Em7", "Dm7", "G7"]

TRACKS = {
    "lobby_lofi": dict(
        bpm=72, swing=0.63, seed=21, transpose=0, prog=PROG_JAZZ,
        comp="rhodes", comp_vel=0.2, bass="sine", drums="lofi", mel_inst=bell,
        mel_fixed=[None, LOBBY_MEL_A, LOBBY_MEL_B], vinyl=True, mel_gain=0.2,
    ),
    "lobby": dict(
        # "Tươi vui thư giãn": hoà âm add9 sáng, ukulele quạt nhẹ, hộp nhạc
        # và mộc cầm lấp lánh, nền dây mỏng, shaker và búng ngón tay.
        bpm=100, swing=0.54, seed=311, transpose=7,
        prog=["Cadd9", "G", "Am7", "Fadd9", "F", "G", "Em7", "Am7"],
        comp="uke_strum", comp_vel=0.26, bass="bounce", drums="fresh", mel_inst=musicbox,
        scale="pent", register=(76, 95), density="medium", pad=True, mel_gain=0.26,
    ),
    "lobby_candy": dict(
        bpm=112, swing=0.5, seed=211, transpose=0,
        prog=["C", "G", "Am", "F", "C", "G", "F", "G"],
        comp="uke_strum", comp_vel=0.3, bass="bounce", drums="pop", mel_inst=whistle,
        scale="pent", register=(72, 91), density="medium", pad=False, mel_gain=0.26,
    ),
    "sudoku": dict(
        bpm=108, swing=0.58, seed=221, transpose=5,
        prog=["C", "Am", "F", "G", "C", "Em7", "F", "G"],
        comp="pizz_bounce", comp_vel=0.34, bass="bounce", drums="swing_fun", mel_inst=xylo,
        scale="pent", register=(72, 91), density="medium", pad=False, mel_gain=0.24,
    ),
    "game2048": dict(
        bpm=124, swing=0.5, seed=231, transpose=2,
        prog=["C", "G", "Am", "F", "C", "G", "F", "G"],
        comp="chip_arp", comp_vel=0.18, bass="octave", drums="chip", mel_inst=chip,
        scale="pent", register=(76, 95), density="busy", pad=False, mel_gain=0.17,
    ),
    "nonogram": dict(
        bpm=100, swing=0.5, seed=241, transpose=7,
        prog=["C", "Am", "F", "G", "C", "Em7", "Fmaj7", "G"],
        comp="musicbox_arp", comp_vel=0.2, bass="bounce", drums="shaker", mel_inst=toypiano,
        scale="pent", register=(76, 93), density="medium", pad=True, mel_gain=0.24,
    ),
    "memory": dict(
        bpm=120, swing=0.5, seed=251, transpose=2,
        prog=["C", "F", "G", "C", "Am", "F", "G", "C"],
        comp="oompah", comp_vel=0.3, bass="oompah", drums="march", mel_inst=calliope,
        scale="major", register=(72, 91), density="busy", pad=False, mel_gain=0.2,
    ),
    "minesweeper": dict(
        bpm=116, swing=0.5, seed=261, transpose=0,
        prog=["Am7", "Dm7", "Em7", "Am7", "Fmaj7", "Dm7", "Em7", "A7"],
        comp="funk_stab", comp_vel=0.3, bass="slap", drums="funky", mel_inst=brass,
        scale="pent", register=(69, 88), density="medium", pad=False, mel_gain=0.2,
    ),
    "lights_out": dict(
        bpm=118, swing=0.5, seed=271, transpose=3,
        prog=["Am7", "Fmaj7", "Cmaj7", "G7", "Am7", "Dm7", "Fmaj7", "G7"],
        comp="disco", comp_vel=0.22, bass="octave", drums="disco", mel_inst=bell,
        scale="pent", register=(72, 91), density="medium", pad=True, mel_gain=0.2,
    ),
    "sliding": dict(
        bpm=104, swing=0.5, seed=281, transpose=2,
        prog=["C", "Am", "F", "G", "C", "Am", "F", "G"],
        comp="toy_arp", comp_vel=0.3, bass="bounce", drums="shaker_soft", mel_inst=xylo,
        scale="pent", register=(72, 88), density="medium", pad=False, mel_gain=0.24,
    ),
    "kakuro": dict(
        bpm=126, swing=0.6, seed=291, transpose=0,
        prog=["Dm7", "G7", "Cmaj7", "Am7", "Dm7", "G7", "Cmaj7", "A7"],
        comp="quiz", comp_vel=0.3, bass="walk", drums="swing_fun", mel_inst=brass,
        scale="pent", register=(67, 86), density="medium", pad=False, mel_gain=0.18,
    ),
}


def render(name, cfg):
    rng = np.random.default_rng(cfg["seed"])
    bpm = cfg["bpm"]
    beat = 60.0 / bpm
    swing = cfg["swing"]
    tr = cfg["transpose"]
    prog = cfg["prog"]
    sections = ["intro", "A", "B"]
    bars_total = 8 * len(sections)
    total_beats = bars_total * 4
    tail = 4.0
    n = int((total_beats * beat + tail) * RATE)
    mix = np.zeros(n)

    def put(sig, at_beat, gain):
        s = int(at_beat * beat * RATE)
        e = min(n, s + len(sig))
        if s < n:
            mix[s:e] += sig[: e - s] * gain

    def off(p):
        whole = int(p)
        return whole + (swing if abs(p - whole - 0.5) < 1e-6 else p - whole)

    def fz(note_name):
        return hz_of_midi(midi_of(note_name) + tr)

    def fm(midi):
        return hz_of_midi(midi + tr)

    mels = []
    if "mel_fixed" in cfg:
        for m in cfg["mel_fixed"]:
            mels.append(None if m is None else [[(p, midi_of(nt), ln) for p, nt, ln in bar] for bar in m])
    else:
        scale = [x for x in SCALES[cfg["scale"]]]
        lo, hi = cfg["register"]
        mels = [None, gen_melody(rng, prog, scale, lo, hi, cfg["density"]),
                gen_melody(rng, prog, scale, lo + 2, hi + 2, cfg["density"])]

    comp = cfg["comp"]
    cv = cfg["comp_vel"]
    drums = cfg["drums"]
    bass_kind = cfg["bass"]
    mel_inst = cfg["mel_inst"]
    bar = 0
    for si, sec in enumerate(sections):
        for bi in range(8):
            chord = prog[bi]
            root, notes = CH[chord]
            b0 = bar * 4
            active = sec != "intro"
            # --- đệm hoà âm
            if cfg.get("pad"):
                for nt in notes:
                    put(pad(fz(nt), beat * 4.3, 1.0), b0, 0.09)
            if comp == "rhodes":
                for k, nt in enumerate(notes):
                    put(rhodes(fz(nt), beat * 2.6, 0.9), b0 + k * 0.02, cv)
                    if active:
                        put(rhodes(fz(nt), beat * 1.0, 0.7), b0 + off(2.5) + k * 0.02, cv * 0.6)
            elif comp == "pad_only":
                for nt in notes:
                    put(pad(fz(nt), beat * 4.3, 1.0, 0.9), b0, cv * 0.5)
                if active:
                    for k, nt in enumerate(notes):
                        put(glass(fz(nt) * 2, beat * 3.5, 0.6), b0 + 0.5 + k * 0.6, 0.06)
            elif comp in ("piano_arp", "musicbox_arp", "synth_arp", "guitar_arp"):
                inst = {"piano_arp": piano, "musicbox_arp": musicbox, "synth_arp": synth_pluck}.get(comp)
                steps = 8
                for k in range(steps):
                    nt = notes[[0, 1, 2, 1, 3 % len(notes), 2, 1, 2][k] % len(notes)]
                    f = fz(nt) * (2 if comp == "musicbox_arp" else 1)
                    if comp == "guitar_arp":
                        sig = ks_pluck(f, beat * 1.4, 1.0, 0.997, rng)
                    else:
                        sig = inst(f, beat * 1.4, 1.0)
                    g = cv * (0.6 if (active or comp != "synth_arp") else 0.0)
                    if comp == "synth_arp" and not active:
                        g = cv * 0.3
                    put(sig, b0 + off(k * 0.5), g * (1.0 if k % 2 == 0 else 0.7))
            elif comp == "harp_arp":
                order = [0, 1, 2, 3, 2, 1, 2, 1]
                for k in range(8):
                    nt = notes[order[k] % len(notes)]
                    g = cv * (0.7 if active else 0.5) * (1.0 if k % 2 == 0 else 0.75)
                    put(ks_pluck(fz(nt) * 2, beat * 1.6, 1.0, 0.9985, rng), b0 + k * 0.5, g)
            elif comp == "uke_strum":
                # Đàn ukulele quạt hợp âm: xuống ở phách, lên ở "và".
                strum = [(0, 1), (1, 1), (1.5, 0.7), (2.5, 0.8), (3, 1), (3.5, 0.7)]
                if not active:
                    strum = [(0, 1), (2, 0.8)]
                for pos, g in strum:
                    order = notes if pos % 1 == 0 else list(reversed(notes))
                    for k, nt in enumerate(order):
                        put(ks_pluck(fz(nt) * 2, beat * 0.9, 1.0, 0.993, rng),
                            b0 + off(pos) + k * 0.025, cv * g * 0.5)
            elif comp == "pizz_bounce":
                for pos in (0, 1.5, 2, 3.5) if active else (0, 2):
                    for nt in notes[:3]:
                        put(ks_pluck(fz(nt), beat * 0.7, 1.0, 0.992, rng), b0 + off(pos), cv * 0.4)
                if active:
                    for k, pos in enumerate((0.5, 1.0, 2.5, 3.0)):
                        put(musicbox(fz(notes[(k + 1) % len(notes)]) * 2, beat * 0.9), b0 + off(pos), cv * 0.35)
            elif comp == "chip_arp":
                order = [0, 2, 1, 3, 2, 1, 3, 2]
                for k in range(8):
                    nt = notes[order[k] % len(notes)]
                    put(chip(fz(nt) * 2, beat * 0.45, 1.0, 0.25 if k % 2 == 0 else 0.5),
                        b0 + k * 0.5, cv * (0.5 if active else 0.3))
            elif comp == "oompah":
                if active:
                    for pos in (1, 3):
                        for nt in notes[:3]:
                            put(calliope(fz(nt), beat * 0.45, 0.8), b0 + pos, cv * 0.22)
                else:
                    for nt in notes[:3]:
                        put(calliope(fz(nt), beat * 1.6, 0.8), b0, cv * 0.18)
            elif comp == "funk_stab":
                pat = (0, 0.75, 1.5, 2.5, 3.25) if active else (0, 2)
                for pos in pat:
                    for nt in notes[:3]:
                        put(brass(fz(nt), beat * 0.35, 0.9), b0 + off(pos), cv * 0.3)
            elif comp == "disco":
                order = [0, 1, 2, 3, 2, 1, 2, 3]
                for k in range(8):
                    nt = notes[order[k] % len(notes)]
                    put(synth_pluck(fz(nt) * 2, beat * 0.5), b0 + k * 0.5, cv * (0.6 if active else 0.3))
            elif comp == "toy_arp":
                for k in range(8):
                    nt = notes[[0, 2, 1, 2, 0, 3, 1, 2][k] % len(notes)]
                    put(toypiano(fz(nt) * 2, beat * 0.6), b0 + k * 0.5, cv * (0.6 if active else 0.35))
            elif comp == "quiz":
                if active:
                    for pos in (0.5, 1.5, 2.5, 3.5):
                        for nt in notes[:3]:
                            put(brass(fz(nt), beat * 0.3, 0.9), b0 + off(pos), cv * 0.22)
                else:
                    for nt in notes[:3]:
                        put(rhodes(fz(nt), beat * 2.5, 0.9), b0, cv * 0.5)
            elif comp == "stab":
                if active:
                    for pos in (0, 1.5, 2, 3.5):
                        for nt in notes[:3]:
                            put(marimba(fz(nt), beat * 0.5, 0.9), b0 + off(pos), cv * 0.6)
            elif comp == "pizz":
                for pos, k in ((0, 0), (1.5, 2), (2.5, 1), (3.5, 2)):
                    if not active and pos not in (0, 2.5):
                        continue
                    put(ks_pluck(fz(notes[k % len(notes)]) / 2, beat * 1.2, 1.0, 0.994, rng), b0 + off(pos), cv)
            # --- bè trầm
            rf = fz(root)
            if bass_kind == "sine":
                put(bass_sine(rf, beat * 1.8), b0, 0.6)
                if active:
                    put(bass_sine(rf * 1.5, beat * 0.8), b0 + off(2.5), 0.25)
                    put(bass_sine(rf, beat * 1.0), b0 + 3.0, 0.4)
            elif bass_kind == "bounce":
                for pos in (0, 1.5, 2, 3.5) if active else (0, 2):
                    put(bass_sine(rf * (2 if pos in (1.5, 3.5) else 1), beat * 0.7), b0 + off(pos), 0.45)
            elif bass_kind == "octave":
                for k in range(8):
                    put(bass_sine(rf * (2 if k % 2 else 1), beat * 0.45), b0 + k * 0.5, 0.42 if active else 0.3)
            elif bass_kind == "slap":
                for pos in (0, 0.75, 1.5, 2.5, 3.25) if active else (0, 2):
                    put(slap_bass(rf * (2 if pos in (0.75, 3.25) else 1), beat * 0.4), b0 + off(pos), 0.5)
            elif bass_kind == "oompah":
                put(bass_sine(rf, beat * 0.8), b0, 0.55)
                put(bass_sine(rf * 1.5, beat * 0.8), b0 + 2, 0.45)
            elif bass_kind == "drone":
                put(drone(rf * 2, beat * 4.3), b0, 0.4)
                if active:
                    put(sub(rf, beat * 4), b0, 0.3)
            elif bass_kind == "sub":
                put(sub(rf * 2, beat * 4.2), b0, 0.5)
            elif bass_kind == "walk":
                walk = [rf, rf * 1.26, rf * 1.5, rf * 1.26] if active else [rf, rf, rf, rf]
                for k in range(4):
                    put(bass_sine(walk[k], beat * 0.95), b0 + k, 0.5 if k == 0 else 0.38)
            # --- trống
            if active:
                if drums == "lofi":
                    put(kick(rng), b0, 0.42); put(kick(rng), b0 + off(2.5), 0.28)
                    put(snare(rng), b0 + 1, 0.2); put(snare(rng), b0 + 3, 0.2)
                    for h in range(4):
                        put(hat(rng), b0 + h, 0.05); put(hat(rng), b0 + off(h + 0.5), 0.028)
                elif drums == "pop":
                    put(kick(rng), b0, 0.3); put(kick(rng), b0 + 2, 0.26)
                    put(kick(rng), b0 + 2.5, 0.16)
                    put(clap(rng), b0 + 1, 0.14); put(clap(rng), b0 + 3, 0.14)
                    for h in range(8):
                        put(hat(rng), b0 + h * 0.5, 0.045 if h % 2 else 0.03)
                    if bi % 4 == 3:
                        put(hat(rng, True), b0 + 3.5, 0.06)
                elif drums == "fresh":
                    put(kick(rng), b0, 0.2); put(kick(rng), b0 + 2, 0.16)
                    put(clap(rng), b0 + 1, 0.07); put(clap(rng), b0 + 3, 0.07)
                    for h in range(8):
                        put(shaker(rng), b0 + off(h * 0.5), 0.04 if h % 2 else 0.06)
                elif drums == "chip":
                    for h in range(4):
                        put(chip_kick(), b0 + h, 0.3)
                    put(chip_snare(rng), b0 + 1, 0.25); put(chip_snare(rng), b0 + 3, 0.25)
                    for h in range(8):
                        put(chip_hat(rng), b0 + h * 0.5 + 0.25, 0.1)
                elif drums == "march":
                    put(kick(rng), b0, 0.3); put(kick(rng), b0 + 2, 0.3)
                    for h in range(4):
                        put(snare(rng), b0 + h + 0.5, 0.1)
                    put(snare(rng), b0 + 1, 0.2); put(snare(rng), b0 + 3, 0.2)
                    if bi % 4 == 3:
                        for k in range(4):
                            put(snare(rng), b0 + 3 + k * 0.25, 0.1 + k * 0.03)
                elif drums == "funky":
                    for pos in (0, 1.75, 2.5):
                        put(kick(rng), b0 + pos, 0.3)
                    put(snare(rng), b0 + 1, 0.22); put(snare(rng), b0 + 3, 0.22)
                    for h in range(16):
                        put(hat(rng), b0 + h * 0.25, 0.045 if h % 4 == 0 else 0.025)
                elif drums == "disco":
                    for h in range(4):
                        put(kick(rng), b0 + h, 0.3)
                        put(hat(rng, True), b0 + h + 0.5, 0.06)
                    put(clap(rng), b0 + 1, 0.16); put(clap(rng), b0 + 3, 0.16)
                elif drums == "swing_fun":
                    put(kick(rng), b0, 0.26); put(kick(rng), b0 + off(2.5), 0.2)
                    put(snare(rng), b0 + 1, 0.18); put(snare(rng), b0 + 3, 0.18)
                    for h in range(4):
                        put(hat(rng), b0 + h, 0.05); put(hat(rng), b0 + off(h + 0.5), 0.04)
                elif drums == "four":
                    for h in range(4):
                        put(kick(rng), b0 + h, 0.3)
                        put(hat(rng), b0 + h + 0.5, 0.05)
                    put(clap(rng), b0 + 1, 0.12); put(clap(rng), b0 + 3, 0.12)
                elif drums == "shaker":
                    put(kick(rng), b0, 0.28); put(kick(rng), b0 + 2, 0.2)
                    for h in range(8):
                        put(shaker(rng), b0 + off(h * 0.5), 0.05 if h % 2 else 0.08)
                elif drums == "shaker_soft":
                    put(kick(rng), b0, 0.18); put(kick(rng), b0 + 2.5, 0.12)
                    for h in range(8):
                        put(shaker(rng), b0 + h * 0.5, 0.035 if h % 2 else 0.055)
                elif drums == "tense":
                    put(kick(rng), b0, 0.3); put(kick(rng), b0 + 0.75, 0.18)
                    put(kick(rng), b0 + 2, 0.3); put(kick(rng), b0 + 2.75, 0.18)
                    for h in range(8):
                        put(tick(rng), b0 + h * 0.5, 0.05)
                elif drums == "brush":
                    for h in range(4):
                        put(brush(rng), b0 + h, 0.14 if h % 2 else 0.1)
                    put(kick(rng), b0, 0.2); put(kick(rng), b0 + off(2.5), 0.12)
                    put(hat(rng), b0 + off(1.5), 0.04); put(hat(rng), b0 + off(3.5), 0.04)
            # --- giai điệu
            mel = mels[si]
            if mel:
                for pos, m, ln in mel[bi]:
                    put(mel_inst(fm(m), beat * (ln + 0.6)), b0 + off(pos), cfg["mel_gain"])
            bar += 1

    total_s = n / RATE
    if cfg.get("vinyl"):
        mix += vinyl(total_s, rng)
    # vang nhẹ
    for delay, g in ((0.4, 0.24), (0.8, 0.12)):
        d = int(delay * RATE)
        mix[d:] += lowpass(mix[:-d], 3200) * g
    mix = lowpass(mix, 7500) * 0.7 + mix * 0.3

    loop_len = int(total_beats * beat * RATE)
    out = mix[:loop_len].copy()
    t = mix[loop_len:]
    out[: len(t)] += t
    # Cân âm lượng theo RMS để các bài nghe đều nhau.
    rms = np.sqrt(np.mean(out**2)) or 1.0
    out = np.tanh(out * (0.14 / rms))
    out = out / np.max(np.abs(out)) * 0.85
    pcm = (out * 32767).astype("<i2")

    OUT.mkdir(parents=True, exist_ok=True)
    wav = OUT / f"{name}.wav"
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    mp3 = OUT / f"{name}.mp3"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
         "-codec:a", "libmp3lame", "-b:a", "80k", str(mp3)],
        check=True,
    )
    wav.unlink()
    print(f"{name:12s} {loop_len / RATE:5.1f}s  {mp3.stat().st_size // 1024} KB")


def main():
    names = sys.argv[1:] or [k for k in TRACKS if not k.startswith("lobby_")]
    for name in names:
        render(name, TRACKS[name])


if __name__ == "__main__":
    main()
