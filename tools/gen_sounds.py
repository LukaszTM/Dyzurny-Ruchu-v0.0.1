#!/usr/bin/env python3
"""Proceduralny generator dźwięków gry (assets/audio, WAV 44,1 kHz mono).

Wszystkie dźwięki są syntezowane — zero nagrań z zewnątrz (CLAUDE.md
zasada 6: dźwięki własne). Użycie: python3 tools/gen_sounds.py
"""

import math
import os
import struct
import wave

OUT = "assets/audio"
RATE = 44100


def write_wav(name: str, samples: list) -> None:
    path = f"{OUT}/{name}.wav"
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        f.writeframes(frames)
    print(name, len(samples) / RATE, "s")


def sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def square(freq: float, t: float) -> float:
    return 1.0 if sine(freq, t) >= 0.0 else -1.0


def phone_ring() -> list:
    """Dzwonek telefonu zapowiadawczego: elektromechaniczny terkot
    (młoteczek ~20 Hz na dwóch czaszach) w dwóch seriach."""
    out = []
    for t_all in range(int(RATE * 1.6)):
        t = t_all / RATE
        burst = (0.0 <= t < 0.55) or (0.8 <= t < 1.35)
        if not burst:
            out.append(0.0)
            continue
        hammer = 0.5 + 0.5 * square(20.0, t)
        bell = 0.6 * sine(1750.0, t) + 0.4 * sine(2100.0, t) \
            + 0.2 * sine(2620.0, t)
        out.append(0.35 * hammer * bell)
    return out


def buzzer() -> list:
    """Buczek alarmowy: niski prostokąt z modulacją (urządzenia srk)."""
    out = []
    for t_all in range(int(RATE * 0.7)):
        t = t_all / RATE
        env = min(1.0, t * 60.0) * min(1.0, (0.7 - t) * 30.0)
        am = 0.75 + 0.25 * sine(16.0, t)
        out.append(0.30 * env * am * square(420.0, t))
    return out


def click() -> list:
    """Klik przycisku pulpitu: krótki stuk przekaźnikowy."""
    out = []
    for t_all in range(int(RATE * 0.05)):
        t = t_all / RATE
        env = math.exp(-t * 120.0)
        out.append(0.5 * env * (sine(1900.0, t) + 0.4 * sine(950.0, t)))
    return out


def ding() -> list:
    """Pojedynczy gong (koniec służby / potwierdzenie)."""
    out = []
    for t_all in range(int(RATE * 1.1)):
        t = t_all / RATE
        env = math.exp(-t * 3.5)
        out.append(0.4 * env * (sine(880.0, t) + 0.5 * sine(1320.0, t)
            + 0.25 * sine(1760.0, t)))
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    write_wav("phone_ring", phone_ring())
    write_wav("buzzer", buzzer())
    write_wav("click", click())
    write_wav("ding", ding())


if __name__ == "__main__":
    main()
