#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generator całodobowego rozkładu jazdy dla Warszawy Wschodniej.

Tryb REALNY ROZKŁAD JAZDY startuje o rzeczywistej godzinie, więc rozkład
musi pokrywać pełną dobę (cykl dobowy):
  * AOE (aglomeracyjne) co 30 min/kierunek w porze 04:30-23:30,
  * ROJ (regionalne) co godzinę w porze 04:50-22:50,
  * MPE/EIE/EIP (dalekobieżne) co ok. 2 h w porze 05:00-23:00,
  * TDE/TME (towarowe, przeloty) całą dobę co ok. 3 h,
  * nocą dodatkowo PWE/LPE oraz towarowe na Grochów,
  * kilka pociągów rozpoczynających i kończących bieg (skład z/do Grochowa).

Uruchomienie:
    python3 tools/build_timetable_wws.py
zapisuje data/locations/warszawa_wschodnia/timetable.json, kopiuje go do
data/online/ oraz odświeża data/online/delays.json.
"""

import json
import os
import random

R = random.Random(20260801)
entries = []


def hm(h, m):
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


# ---- AOE: aglomeracyjne co 30 min/kierunek, 04:30-23:30 -------------------
nr_e, nr_w = 21801, 21802
for h in range(4, 24):
    for m in (5, 35):
        if h == 4 and m == 5:
            continue
        tor_e = "1" if (h * 2 + m // 30) % 2 == 0 else "3"
        add(nr_e, "AOE", "Pruszków", "Otwock", "it1P", "it1W", tor_e,
            hm(h, m), hm(h, m + 2), 2)
        nr_e += 2
    for m in (20, 50):
        tor_w = "2" if (h * 2 + m // 30) % 2 == 0 else "4"
        add(nr_w, "AOE", "Otwock", "Pruszków", "it2W", "it2P", tor_w,
            hm(h, m), hm(h, m + 2), 2)
        nr_w += 2

# ---- ROJ: regionalne co godzinę, 04:50-22:50 ------------------------------
nr_e, nr_w = 91101, 91102
for h in range(5, 23):
    kier_e = "Mińsk Mazowiecki" if h % 2 == 0 else "Siedlce"
    add(nr_e, "ROJ", "W-wa Zachodnia", kier_e, "it1P", "it1W",
        "3" if h % 2 == 0 else "1", hm(h, 27), hm(h, 29), 2)
    nr_e += 2
    add(nr_w, "ROJ", kier_e, "W-wa Zachodnia", "it2W", "it2P",
        "4" if h % 2 == 0 else "2", hm(h, 44), hm(h, 46), 2)
    nr_w += 2

# ---- dalekobieżne ---------------------------------------------------------
NAZWY = ["Podlasiak", "Sawa", "Hetman", "Kmicic", "Bug", "Narew",
         "Cukrownik", "Żeromski", "Norwid", "Skarga"]
nr_e, nr_w, ni = 1701, 1702, 0
for h in range(5, 23, 2):
    kat = ["MPE", "EIE", "EIP"][(h // 2) % 3]
    przez_otwock = h % 4 == 1
    do = "Lublin Główny" if przez_otwock else ("Białystok" if h % 3 else "Terespol")
    nazwa = NAZWY[ni % len(NAZWY)] if kat in ("EIE", "EIP") else ""
    ni += 1
    add(nr_e, kat, "W-wa Zachodnia", do, "it1D",
        "it1W" if przez_otwock else "it1R",
        "5" if h % 4 < 2 else "7", hm(h, 12), hm(h, 16), 4, nazwa=nazwa)
    nr_e += 2
for h in range(6, 24, 2):
    kat = ["MPE", "EIE", "EIP"][(h // 2) % 3]
    z_otwocka = h % 4 == 2
    z = "Lublin Główny" if z_otwocka else ("Białystok" if h % 3 else "Terespol")
    nazwa = NAZWY[ni % len(NAZWY)] if kat in ("EIE", "EIP") else ""
    ni += 1
    add(nr_w, kat, z, "W-wa Zachodnia",
        "it2W" if z_otwocka else "it2R", "it2D",
        "6" if h % 4 < 2 else "8", hm(h, 41), hm(h, 45), 4, nazwa=nazwa)
    nr_w += 2

# ---- towarowe: przeloty całą dobę -----------------------------------------
nr_t = 44601
for h in range(0, 24, 3):
    add(nr_t, "TME" if h % 2 else "TDE", "Pruszków", "Małaszewicze",
        "it1D", "it1R", "7", hm(h, 52), przelot=True)
    nr_t += 2
    add(nr_t, "TDE" if h % 2 else "TME", "Małaszewicze", "Pruszków",
        "it2R", "it2D", "8", hm((h + 1) % 24, 22), przelot=True)
    nr_t += 2
# towarowe na Grochów (przez tor 9)
add(44120, "TDE", "Pruszków", "Grochów", "it2D", "itG", "9", "06:08", przelot=True)
add(44122, "TDE", "Pruszków", "Grochów", "it2D", "itG", "9", "18:08", przelot=True)

# ---- noc: próżne składy i lokomotywy --------------------------------------
add(38801, "PWE", "W-wa Grochów", "Pruszków", "it1D", "it1R", "7", "00:35", przelot=True)
add(38803, "PWE", "Pruszków", "W-wa Grochów", "it2R", "it2D", "8", "02:15", przelot=True)
add(48901, "LPE", "W-wa Zachodnia", "Białystok", "it1D", "it1R", "5", "03:05", "03:07", 2)

# ---- pociągi rozpoczynające i kończące bieg -------------------------------
add(1731, "MPE", "W-wa Wschodnia", "Lublin Główny", "itG", "it1W", "7",
    dep="05:40", start=True, nazwa="Słowacki")
add(4501, "EIE", "W-wa Wschodnia", "Białystok", "itG", "it1R", "5",
    dep="14:35", start=True, nazwa="Kmicic")
add(3902, "MPE", "Lublin Główny", "W-wa Wschodnia", "it2W", "itG", "6",
    arr="09:22", koniec=True, nazwa="Hetman")
add(4504, "EIE", "Białystok", "W-wa Wschodnia", "it2R", "itG", "8",
    arr="21:17", koniec=True, nazwa="Narew")


def klucz(e):
    t = e.get("przyjazd", e.get("odjazd", "99:99"))
    return t


entries.sort(key=klucz)

base = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
data = {"start_time": "04:45", "entries": entries}
tt_path = os.path.join(base, "data", "locations", "warszawa_wschodnia", "timetable.json")
with open(tt_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
    f.write("\n")
online_path = os.path.join(base, "data", "online", "timetable_warszawa_wschodnia.json")
with open(online_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
    f.write("\n")

# opóźnienia online dla kilku pociągów z wygenerowanego rozkładu
kandydaci = [e for e in entries if not e.get("start")]
delays = []
for e in R.sample(kandydaci, 8):
    delays.append({"nr": e["nr"], "delay_min": R.choice([3, 4, 6, 8, 12, 15])})
delays_path = os.path.join(base, "data", "online", "delays.json")
with open(delays_path, "w", encoding="utf-8") as f:
    json.dump({
        "generated": "2026-08-01T17:00:00Z",
        "info": "Opóźnienia pociągów aktualizowane online. Edytuj ten plik w repozytorium, aby gra pobrała nowe opóźnienia.",
        "delays": delays,
    }, f, ensure_ascii=False, indent=1)
    f.write("\n")

print("Rozkład: %d pozycji -> %s" % (len(entries), tt_path))
print("Opóźnienia online: %d pozycji" % len(delays))
