#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rozkład jazdy Warszawy Wschodniej odtworzony z realnej siatki połączeń.

Źródło: realna oferta przewozowa przez stację Warszawa Wschodnia
(stan ~2025): SKM S1/S2, Koleje Mazowieckie R6/R7, PKP Intercity
(sprintery W-wa Wschodnia — Białystok: Esperanto, Zamenhof, Prząśniczka;
IC Żubr, IC Cracovia, IC Hańcza, IC Podlasiak, IC Skaryna, pociągi do
Lublina i Zamościa, EC Berlin—Warszawa kończące bieg na Wschodniej,
EIP/EIC kończące bieg z Krakowa/Gdyni/Wrocławia) oraz ruch towarowy.

Godziny i numery pociągów są PRZYBLIŻONE (odtworzone, nie pobrane z
oficjalnego zestawienia). Oficjalne dane można zaciągnąć narzędziem
tools/pobierz_rozklad_ic.py i podmienić przez aktualizację online.

Uruchomienie:
    python3 tools/build_timetable_wws.py
"""

import json
import os
import random

R = random.Random(20260801)
entries = []


def hm(h, m):
    while m >= 60:
        m -= 60
        h += 1
    return "%02d:%02d" % (h % 24, m)


def add(nr, kat, z, do, we, wy, tor, arr=None, dep=None, postoj=0,
        przelot=False, start=False, koniec=False, nazwa=""):
    e = {"nr": str(nr), "kat": kat, "z": z, "do": do,
         "we": we, "wy": wy, "tor": str(tor)}
    if nazwa:
        e["nazwa"] = nazwa
    if arr is not None:
        e["przyjazd"] = arr
    if dep is not None:
        e["odjazd"] = dep
    if postoj:
        e["postoj"] = postoj
    if przelot:
        e["przelot"] = True
    if start:
        e["start"] = True
    if koniec:
        e["koniec"] = True
    entries.append(e)


# =====================================================================
# SKM — linia S1 Pruszków — Otwock (przez średnicę podmiejską)
# szczyt co 20 min, poza szczytem co 30 min
# =====================================================================
SZCZYT = (6, 7, 8, 14, 15, 16, 17)
nr = 21401
for h in range(5, 24):
    minuty = (4, 24, 44) if h in SZCZYT else (14, 44)
    for i, m in enumerate(minuty):
        tor = "1" if (h + i) % 2 else "3"
        add(nr, "AOE", "Pruszków", "Otwock", "it1P", "it1W", tor,
            hm(h, m), hm(h, m + 1), 1)
        nr += 2
nr = 21402
for h in range(5, 24):
    minuty = (9, 29, 49) if h in SZCZYT else (19, 49)
    for i, m in enumerate(minuty):
        tor = "2" if (h + i) % 2 else "4"
        add(nr, "AOE", "Otwock", "Pruszków", "it2W", "it2P", tor,
            hm(h, m), hm(h, m + 1), 1)
        nr += 2

# =====================================================================
# SKM — linia S2 Sulejówek Miłosna — W-wa Lotnisko Chopina
# szczyt co 30 min, poza co 60 min
# =====================================================================
nr = 21601
for h in range(5, 23):
    minuty = (0, 30) if h in SZCZYT else (0,)
    for m in minuty:
        add(nr, "AOE", "Lotnisko Chopina", "Sulejówek Miłosna", "it1P", "it1W",
            "3" if h % 2 else "1", hm(h, m + 7), hm(h, m + 8), 1)
        nr += 2
nr = 21602
for h in range(5, 23):
    minuty = (15, 45) if h in SZCZYT else (30,)
    for m in minuty:
        add(nr, "AOE", "Sulejówek Miłosna", "Lotnisko Chopina", "it2W", "it2P",
            "4" if h % 2 else "2", hm(h, m + 2), hm(h, m + 3), 1)
        nr += 2

# =====================================================================
# Koleje Mazowieckie — R7 W-wa Zachodnia/Grodzisk — Dęblin (przez Otwock)
# co godzinę
# =====================================================================
nr = 21701
for h in range(4, 23):
    add(nr, "ROJ", "Grodzisk Mazowiecki", "Dęblin", "it1P", "it1W",
        "1" if h % 2 else "3", hm(h, 52), hm(h, 54), 2)
    nr += 2
nr = 21702
for h in range(5, 24):
    add(nr, "ROJ", "Dęblin", "Grodzisk Mazowiecki", "it2W", "it2P",
        "2" if h % 2 else "4", hm(h, 6), hm(h, 8), 2)
    nr += 2

# =====================================================================
# Koleje Mazowieckie — R6 W-wa Zachodnia — Siedlce (przez Mińsk Maz.)
# co godzinę (w grze wyjazd wschodni wspólny — uproszczenie schematu)
# =====================================================================
nr = 19101
for h in range(4, 23):
    do = "Siedlce" if h % 2 else "Mińsk Mazowiecki"
    add(nr, "ROJ", "W-wa Zachodnia", do, "it1P", "it1W",
        "3" if h % 2 else "1", hm(h, 33), hm(h, 35), 2)
    nr += 2
nr = 19102
for h in range(5, 24):
    z = "Siedlce" if h % 2 else "Mińsk Mazowiecki"
    add(nr, "ROJ", z, "W-wa Zachodnia", "it2W", "it2P",
        "4" if h % 2 else "2", hm(h, 21), hm(h, 23), 2)
    nr += 2

# =====================================================================
# PKP Intercity — kierunek Białystok/Suwałki (LK 6, wyjazd wschodni it1R)
# =====================================================================
# sprintery W-wa Wschodnia — Białystok (zaczynają/kończą bieg na Wschodniej)
add(1110, "EIE", "W-wa Wschodnia", "Białystok", "itG", "it1R", "5",
    dep="06:20", start=True, nazwa="Esperanto")
add(1112, "EIE", "W-wa Wschodnia", "Białystok", "itG", "it1R", "5",
    dep="15:20", start=True, nazwa="Zamenhof")
add(1111, "EIE", "Białystok", "W-wa Wschodnia", "it2R", "itG", "6",
    arr="09:35", koniec=True, nazwa="Esperanto")
add(1113, "EIE", "Białystok", "W-wa Wschodnia", "it2R", "itG", "6",
    arr="18:40", koniec=True, nazwa="Zamenhof")
# przez stację
add(1130, "EIE", "Łódź Fabryczna", "Białystok", "it1D", "it1R", "5",
    "18:07", "18:11", 4, nazwa="Prząśniczka")
add(1131, "EIE", "Białystok", "Łódź Fabryczna", "it2R", "it2D", "8",
    "10:44", "10:48", 4, nazwa="Prząśniczka")
add(3120, "MPE", "Kraków Główny", "Białystok", "it1D", "it1R", "5",
    "10:07", "10:11", 4, nazwa="Cracovia")
add(3121, "MPE", "Białystok", "Kraków Główny", "it2R", "it2D", "8",
    "16:44", "16:48", 4, nazwa="Cracovia")
add(8120, "MPE", "Szczecin Główny", "Białystok", "it1D", "it1R", "7",
    "12:07", "12:11", 4, nazwa="Żubr")
add(8121, "MPE", "Białystok", "Szczecin Główny", "it2R", "it2D", "6",
    "13:44", "13:48", 4, nazwa="Żubr")
add(3140, "MPE", "Kraków Główny", "Suwałki", "it1D", "it1R", "7",
    "07:07", "07:11", 4, nazwa="Hańcza")
add(3141, "MPE", "Suwałki", "Kraków Główny", "it2R", "it2D", "8",
    "19:44", "19:48", 4, nazwa="Hańcza")
add(5120, "MPE", "W-wa Zachodnia", "Suwałki", "it1D", "it1R", "5",
    "08:07", "08:11", 4, nazwa="Podlasiak")
add(5121, "MPE", "Suwałki", "W-wa Zachodnia", "it2R", "it2D", "6",
    "17:44", "17:48", 4, nazwa="Podlasiak")

# =====================================================================
# PKP Intercity — kierunek Terespol (LK 2)
# =====================================================================
add(1310, "MPE", "Łódź Fabryczna", "Terespol", "it1D", "it1R", "7",
    "09:07", "09:11", 4, nazwa="Skaryna")
add(1311, "MPE", "Terespol", "Łódź Fabryczna", "it2R", "it2D", "8",
    "16:07", "16:11", 4, nazwa="Skaryna")
add(1330, "MPE", "W-wa Zachodnia", "Terespol", "it1D", "it1R", "5",
    "13:07", "13:11", 4)
add(1331, "MPE", "Terespol", "W-wa Zachodnia", "it2R", "it2D", "6",
    "11:37", "11:41", 4)

# =====================================================================
# PKP Intercity — kierunek Lublin/Zamość (przez Otwock, wyjazd it1W)
# =====================================================================
add(2110, "MPE", "W-wa Zachodnia", "Lublin Główny", "it1D", "it1W", "5",
    "06:07", "06:11", 4)
add(2112, "EIE", "W-wa Zachodnia", "Lublin Główny", "it1D", "it1W", "7",
    "12:22", "12:26", 4, nazwa="Wieniawski")
add(2114, "MPE", "W-wa Zachodnia", "Lublin Główny", "it1D", "it1W", "5",
    "17:07", "17:11", 4)
add(2111, "MPE", "Lublin Główny", "W-wa Zachodnia", "it2W", "it2D", "8",
    "08:41", "08:45", 4)
add(2113, "EIE", "Lublin Główny", "W-wa Zachodnia", "it2W", "it2D", "6",
    "14:41", "14:45", 4, nazwa="Wieniawski")
add(2115, "MPE", "Lublin Główny", "W-wa Zachodnia", "it2W", "it2D", "8",
    "20:41", "20:45", 4)
add(2130, "MPE", "W-wa Wschodnia", "Zamość", "itG", "it1W", "7",
    dep="07:50", start=True, nazwa="Zamoyski")
add(2131, "MPE", "Zamość", "W-wa Wschodnia", "it2W", "itG", "6",
    arr="20:35", koniec=True, nazwa="Hetman")

# =====================================================================
# EC Berlin — Warszawa Wschodnia (kończą/zaczynają bieg na Wschodniej)
# =====================================================================
for i, dep in enumerate(("05:45", "09:45", "13:45", "17:45")):
    add(40 + 2 * i, "EIE", "W-wa Wschodnia", "Berlin Hbf", "itG", "it2D", "8",
        dep=dep, start=True, nazwa="Berlin-Warszawa-Express")
for i, arr in enumerate(("10:05", "14:05", "18:05", "22:05")):
    add(41 + 2 * i, "EIE", "Berlin Hbf", "W-wa Wschodnia", "it1D", "itG", "7",
        arr=arr, koniec=True, nazwa="Berlin-Warszawa-Express")

# =====================================================================
# EIP/EIC kończące bieg na Wschodniej (z Krakowa, Gdyni, Wrocławia)
# =====================================================================
add(3100, "EIP", "Kraków Główny", "W-wa Wschodnia", "it1D", "itG", "5",
    arr="08:50", koniec=True)
add(3102, "EIP", "W-wa Wschodnia", "Kraków Główny", "itG", "it2D", "5",
    dep="09:40", start=True)
add(3104, "EIP", "Kraków Główny", "W-wa Wschodnia", "it1D", "itG", "7",
    arr="16:50", koniec=True)
add(3106, "EIP", "W-wa Wschodnia", "Kraków Główny", "itG", "it2D", "7",
    dep="17:40", start=True)
add(5100, "EIE", "Gdynia Główna", "W-wa Wschodnia", "it1D", "itG", "5",
    arr="12:50", koniec=True)
add(5102, "EIE", "W-wa Wschodnia", "Gdynia Główna", "itG", "it2D", "5",
    dep="13:40", start=True)
add(6100, "MPE", "Wrocław Główny", "W-wa Wschodnia", "it1D", "itG", "7",
    arr="19:50", koniec=True)
add(6102, "MPE", "W-wa Wschodnia", "Wrocław Główny", "itG", "it2D", "5",
    dep="06:40", start=True)

# =====================================================================
# Ruch towarowy — przeloty (całodobowo) + obsługa Grochowa
# =====================================================================
nr = 44601
for h in (0, 2, 4, 8, 11, 16, 20, 22):
    add(nr, "TME" if h % 2 else "TDE", "Pruszków", "Małaszewicze",
        "it1D", "it1R", "7" if h % 2 else "9", hm(h, 37), przelot=True)
    nr += 2
    add(nr, "TDE" if h % 2 else "TME", "Małaszewicze", "Pruszków",
        "it2R", "it2D", "8", hm((h + 1) % 24, 12), przelot=True)
    nr += 2
add(44120, "TDE", "Pruszków", "Grochów", "it2D", "itG", "9", "05:52", przelot=True)
add(44122, "TDE", "Pruszków", "Grochów", "it2D", "itG", "9", "18:22", przelot=True)
add(38801, "PWE", "W-wa Grochów", "Pruszków", "it1D", "it1R", "7", "01:35", przelot=True)
add(38803, "PWE", "Pruszków", "W-wa Grochów", "it2R", "it2D", "8", "03:15", przelot=True)


def klucz(e):
    return e.get("przyjazd", e.get("odjazd", "99:99"))


entries.sort(key=klucz)

nrs = [e["nr"] for e in entries]
assert len(nrs) == len(set(nrs)), "zduplikowane numery pociągów"

base = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
data = {"start_time": "04:45", "entries": entries}
tt_path = os.path.join(base, "data", "locations", "warszawa_wschodnia", "timetable.json")
with open(tt_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
    f.write("\n")
with open(os.path.join(base, "data", "online", "timetable_warszawa_wschodnia.json"),
          "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
    f.write("\n")

kandydaci = [e for e in entries if not e.get("start")]
delays = [{"nr": e["nr"], "delay_min": R.choice([3, 4, 6, 8, 12, 15])}
          for e in R.sample(kandydaci, 8)]
with open(os.path.join(base, "data", "online", "delays.json"), "w", encoding="utf-8") as f:
    json.dump({
        "generated": "2026-08-01T17:00:00Z",
        "info": "Opóźnienia pociągów aktualizowane online. Edytuj ten plik w repozytorium, aby gra pobrała nowe opóźnienia.",
        "delays": delays,
    }, f, ensure_ascii=False, indent=1)
    f.write("\n")

print("Rozkład: %d pozycji -> %s" % (len(entries), tt_path))
