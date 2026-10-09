#!/usr/bin/env python3
"""Sinh bộ âm thanh game (WAV 16-bit mono 32000 Hz) vào assets/sfx/<chủ đề>/.

Chạy: python3 tools/gen_sfx_v2.py            (sinh mọi chủ đề)
      python3 tools/gen_sfx_v2.py sudoku     (chỉ sinh chủ đề nêu tên)
Thay thế bản cũ tools/gen_sfx.dart. Mỗi tên file trùng với tên SfxKind trong
lib/core/audio/sfx.dart. Mỗi game có một chủ đề âm sắc riêng (cùng tên với
bài nhạc nền): cùng các tình huống bấm/đặt/xoá/thắng/thua nhưng đổi nhạc cụ
và cao độ cho hợp chủ đề: sảnh kẹo ngọt, mộc cầm, chiptune, hộp nhạc, kèn rạp
xiếc, hoạt hình, neon, đồ chơi gỗ, đàn điện jazz.
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 32000
BASE = Path(__file__).resolve().parent.parent / "assets" / "sfx"
OUT = BASE

# Chủ đề hiện tại: bảng đổi loại sóng và hệ số cao độ.
THEME = {"map": {}, "pitch": 1.0}
RNG = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * RATE)) / RATE


def env(n, attack=0.004, decay=8.0):
    """Bao hình: lên nhanh rồi tắt mũ."""
    t = np.arange(n) / RATE
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-decay * t)


def tone(f0, dur, f1=None, wave_kind="sine", decay=8.0, attack=0.004, vib=0.0):
    """Một nốt: có thể trượt từ f0 sang f1, thêm hài âm cho tiếng 'kẹo'."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    wave_kind = THEME["map"].get(wave_kind, wave_kind)
    f1 = f0 if f1 is None else f1
    f0 *= THEME["pitch"]
    f1 *= THEME["pitch"]
    freq = f0 + (f1 - f0) * (t / max(dur, 1e-6))
    if vib:
        freq = freq * (1 + vib * np.sin(2 * np.pi * 6 * t))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if wave_kind == "sine":
        w = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    elif wave_kind == "tri":
        w = (2 / np.pi) * np.arcsin(np.sin(phase)) + 0.15 * np.sin(2 * phase)
    elif wave_kind == "square":
        w = np.sign(np.sin(phase)) * 0.5 + 0.3 * np.sin(phase)
    elif wave_kind == "bell":
        w = (
            np.sin(phase)
            + 0.5 * np.sin(2.76 * phase)
            + 0.25 * np.sin(5.4 * phase)
        )
    elif wave_kind == "pulse":
        w = np.where((phase / (2 * np.pi)) % 1.0 < 0.25, 1.0, -1.0) * 0.55
    elif wave_kind == "wood":
        w = np.sin(phase) + 0.5 * np.sin(3 * phase) * np.exp(-18 * t) + 0.2 * np.sin(6 * phase) * np.exp(-25 * t)
        decay = max(decay, 14.0)
    elif wave_kind == "box":
        w = np.sin(phase) + 0.4 * np.sin(2.76 * phase) * np.exp(-6 * t) + 0.15 * np.sin(5.4 * phase) * np.exp(-12 * t)
    elif wave_kind == "horn":
        w = sum(np.sin(k * phase) / k for k in range(1, 6))
        w = w * 0.6 * (1 + 0.05 * np.sin(2 * np.pi * 7 * t))
    elif wave_kind == "saw":
        w = sum(np.sin(k * phase) / k * np.exp(-0.4 * k * t) for k in range(1, 9)) * 0.6
    elif wave_kind == "epiano":
        w = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.3 * np.sin(7 * phase) * np.exp(-26 * t)
    else:
        w = np.sin(phase)
    return w * env(n, attack, decay)


def drop(f_lo, f_hi, dur, tau=0.03, decay=30.0):
    """Giọt nước: sine vút lên nhanh từ f_lo tới f_hi rồi tắt mũ ('bloop')."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    k = THEME["pitch"]
    freq = (f_hi - (f_hi - f_lo) * np.exp(-t / tau)) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    w = np.sin(phase) + 0.18 * np.sin(2 * phase) * np.exp(-40 * t)
    return w * np.minimum(1.0, t / 0.003) * np.exp(-decay * t)


def noise(dur, decay=20.0, attack=0.001):
    n = int(dur * RATE)
    return RNG.standard_normal(n) * env(n, attack, decay)


def lowpass(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def place(parts, total):
    """Ghép các (offset giây, tín hiệu, âm lượng) thành một tín hiệu."""
    out = np.zeros(int(total * RATE))
    for off, sig, gain in parts:
        s = int(off * RATE)
        e = min(len(out), s + len(sig))
        if s < len(out):
            out[s:e] += sig[: e - s] * gain
    return out


def fade_out(x, ms=12):
    n = int(RATE * ms / 1000)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


# Chủ đề âm sắc cho từng game (cùng tên với bài nhạc nền).
THEMES = {
    "lobby": {"map": {}, "pitch": 1.0},
    "sudoku": {"map": {"sine": "wood", "tri": "wood", "bell": "wood"}, "pitch": 1.12},
    "game2048": {"map": {"sine": "pulse", "tri": "pulse", "square": "pulse", "bell": "pulse"}, "pitch": 1.0},
    "nonogram": {"map": {"sine": "box", "tri": "box", "bell": "box"}, "pitch": 1.19},
    "memory": {"map": {"sine": "horn", "tri": "horn"}, "pitch": 0.94},
    "minesweeper": {"map": {"sine": "wood", "tri": "wood", "square": "saw", "bell": "wood"}, "pitch": 0.9},
    "lights_out": {"map": {"sine": "saw", "tri": "saw"}, "pitch": 1.25},
    "sliding": {"map": {"sine": "box", "tri": "wood"}, "pitch": 1.06},
    "kakuro": {"map": {"sine": "epiano", "tri": "epiano", "bell": "epiano"}, "pitch": 1.0},
}


def save(name, x, peak=0.85):
    x = fade_out(np.asarray(x, dtype=np.float64))
    m = np.max(np.abs(x)) or 1.0
    pcm = (x / m * peak * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print(f"{name}.wav  {len(x) / RATE:.2f}s")


# Tần số các nốt (C major, quãng 4-7).
C4, D4, E4, F4, G4, A4, B4 = 261.6, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9
C5, D5, E5, F5, G5, A5, B5 = 523.3, 587.3, 659.3, 698.5, 784.0, 880.0, 987.8
C6, E6, G6, C7 = 1046.5, 1318.5, 1568.0, 2093.0


def main():
    # ---- Giao diện ngoài game ----
    # Tiếng bấm nút: giọt nước "tách-bloop" kèm gợn sóng nhỏ phía sau.
    save("click", place([
        (0, drop(420, 1250, 0.13, 0.026, 30), 1.0),
        (0.052, drop(560, 1650, 0.1, 0.03, 42), 0.32),
        (0, highpass(noise(0.008, 220), 3500), 0.05),
    ], 0.2), 0.7)
    save("back", place([(0, tone(740, 0.09, 600, "tri", 22), 1.0),
                         (0.07, tone(520, 0.12, 430, "tri", 20), 0.9)], 0.22), 0.7)
    sw = lowpass(highpass(noise(0.22, 9, 0.03), 300), 3500)
    save("open", place([(0, sw, 0.5),
                         (0.02, tone(420, 0.2, 880, "sine", 10, 0.01), 0.7),
                         (0.14, tone(C6, 0.2, None, "bell", 14), 0.35)], 0.4), 0.7)
    save("pause", place([(0, tone(G5, 0.1, None, "tri", 16), 0.9),
                          (0.09, tone(C5, 0.16, None, "tri", 14), 0.9)], 0.3), 0.7)
    save("resume", place([(0, tone(C5, 0.1, None, "tri", 16), 0.9),
                           (0.09, tone(G5, 0.16, None, "tri", 14), 0.9)], 0.3), 0.7)
    save("newGame", place(
        [(0, lowpass(highpass(noise(0.25, 8, 0.02), 400), 4500), 0.45)]
        + [(0.04 + i * 0.07, tone(f, 0.18, None, "sine", 11), 0.7)
           for i, f in enumerate([C5, E5, G5, C6])], 0.5), 0.75)

    # ---- Thao tác chung trong game ----
    save("tap", place([(0, tone(520, 0.07, 380, "sine", 40), 1.0)], 0.09), 0.6)
    save("place", place([(0, tone(660, 0.1, 700, "tri", 28), 1.0),
                          (0.0, tone(1320, 0.07, None, "sine", 40), 0.3)], 0.14), 0.75)
    save("erase", place([(0, tone(440, 0.1, 280, "tri", 30), 0.9),
                          (0, lowpass(noise(0.05, 60), 2500), 0.12)], 0.13), 0.65)
    save("pop", place([(0, tone(700, 0.08, 1100, "sine", 35, 0.002), 1.0)], 0.1), 0.65)
    save("flip", place([(0, highpass(noise(0.05, 70), 1800), 0.5),
                         (0.012, tone(880, 0.1, 960, "tri", 30), 0.7)], 0.16), 0.7)
    save("slide", place([(0, lowpass(highpass(noise(0.13, 18, 0.01), 500), 3000), 0.55),
                          (0, tone(330, 0.12, 520, "tri", 22), 0.5)], 0.16), 0.65)
    save("flag", place([(0, tone(300, 0.08, 240, "square", 40), 0.5),
                         (0.05, tone(1500, 0.07, None, "sine", 50), 0.55)], 0.14), 0.7)
    save("merge", place([(0, tone(C5, 0.12, E5, "sine", 14, 0.003, 0.01), 0.9),
                          (0.07, tone(G5, 0.2, None, "sine", 12), 0.85)], 0.3), 0.8)
    save("hint", place([(i * 0.07, tone(f, 0.25, None, "bell", 12), 0.6)
                         for i, f in enumerate([C6, E6, G6])], 0.5), 0.7)

    # ---- Đúng / sai / thành công ----
    save("match", place([(0, tone(C6, 0.3, None, "bell", 9), 0.7),
                          (0.1, tone(E6, 0.4, None, "bell", 8), 0.7)], 0.55), 0.8)
    save("success", place([(i * 0.07, tone(f, 0.28, None, "sine", 9), 0.75)
                            for i, f in enumerate([C5, E5, G5, C6])], 0.55), 0.8)
    save("error", place([(0, tone(220, 0.12, 190, "square", 14, 0.003, 0.02), 0.6),
                          (0.11, tone(165, 0.2, 140, "square", 12, 0.003, 0.02), 0.6)], 0.34), 0.7)

    # ---- Thắng ----
    chord = [(0.5, tone(f, 0.9, None, "sine", 3.2, 0.01), 0.45)
             for f in (C5, E5, G5, C6)]
    steps = [(i * 0.11, tone(f, 0.3, None, "bell", 7), 0.7)
             for i, f in enumerate([C5, E5, G5, C6])]
    sparkle = [(0.55 + i * 0.09, tone(f, 0.35, None, "bell", 9), 0.3)
               for i, f in enumerate([E6, G6, C7])]
    save("win", place(steps + chord + sparkle, 1.6), 0.85)

    # ---- Thua ----
    down = [(i * 0.2, tone(f, 0.45, f * 0.97, "tri", 5, 0.01, 0.015), 0.7)
            for i, f in enumerate([G4, E4, D4, C4 * 0.89])]
    low = [(0.62, tone(110, 0.8, 82, "sine", 3.5, 0.02), 0.55)]
    save("lose", place(down + low, 1.5), 0.8)

    # ---- Nổ mìn ----
    body = lowpass(noise(0.7, 5.5, 0.002), 900)
    crack = highpass(noise(0.12, 30, 0.001), 1500)
    thump = tone(95, 0.55, 40, "sine", 5.5, 0.002)
    save("boom", place([(0, body, 1.0), (0, crack, 0.35), (0, thump, 0.9)], 0.8), 0.95)


if __name__ == "__main__":
    global_names = sys.argv[1:] or list(THEMES)
    for theme in global_names:
        THEME["map"] = THEMES[theme]["map"]
        THEME["pitch"] = THEMES[theme]["pitch"]
        RNG = np.random.default_rng(7)
        OUT = BASE / theme
        print(f"== {theme}")
        main()
