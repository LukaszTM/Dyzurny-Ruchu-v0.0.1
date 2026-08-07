#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generator układu torowego (layout.json) dla stacji Warszawa Wschodnia.

Układ budowany jest programowo, aby zagwarantować poprawność struktury:
  * każdy odcinek prowadzi z zachodu na wschód (x rosnące),
  * każdy rozjazd ma dokładnie trzy odgałęzienia: root (iglice) oraz
    plus (położenie zasadnicze) i minus (położenie zwrotne),
  * jazda przez rozjazd możliwa jest wyłącznie root<->plus albo root<->minus.

Uruchomienie:
    python3 tools/build_layout_wws.py
zapisuje data/locations/warszawa_wschodnia/layout.json
"""

import json
import os
from collections import defaultdict

points = {}
segments = []
switches = []
signals = []
line_ends = []
tracks = []


def P(pid, x, y):
    points[pid] = (x, y)
    return pid


def S(sid, a, b, kind="stacyjny"):
    segments.append({"id": sid, "from": a, "to": b, "kind": kind})
    return sid


def SW(num, point, root, plus, minus):
    switches.append({
        "id": str(num), "point": point,
        "root": root, "plus": plus, "minus": minus,
    })


def SIG(sid, point, d, typ, opis=""):
    signals.append({"id": sid, "point": point, "dir": d, "typ": typ, "opis": opis})


def LE(pid, name, dir_in, lk, kind="pociagowy", tor=""):
    line_ends.append({
        "id": pid, "name": name, "dir_in": dir_in,
        "lk": lk, "kind": kind, "tor": tor,
    })


def TRK(nr, seg, a, b, peron, dl):
    tracks.append({"nr": nr, "seg": seg, "a": a, "b": b, "peron": peron, "dl": dl})


# ---------------------------------------------------------------- geometria
# Grupa podmiejska: tory 3, 1, 2, 4        (perony 1 i 2)
# Grupa dalekobieżna: tory 5, 6, 7, 8      (perony 3 i 4)
# Tor 9 — postojowy, wyjazd na Grochów (stacja techniczna)

Y = {
    "t3": 300, "t1": 360, "t2": 420, "t4": 480,
    "t5": 560, "t6": 620, "t7": 680, "t8": 740, "t9": 800,
}
X_TRK_W, X_TRK_E = 760, 1240

# ---- głowica zachodnia, grupa podmiejska ----------------------------------
P("it1P", 80, Y["t1"]); P("pA", 260, Y["t1"])
P("WA1", 340, Y["t1"]); P("WA2", 420, Y["t1"]); P("WA3", 500, Y["t1"])
P("it2P", 80, Y["t2"]); P("pB", 260, Y["t2"])
P("WB1", 340, Y["t2"]); P("WB2", 420, Y["t2"]); P("WB3", 500, Y["t2"])
P("WB4", 540, Y["t4"])

S("sz1P", "it1P", "pA", "szlak"); S("wA", "pA", "WA1")
S("sz2P", "it2P", "pB", "szlak"); S("wB", "pB", "WB1")
S("c1", "WA1", "WA2"); S("c2", "WA1", "WB2")
S("c3", "WB1", "WB2"); S("c4", "WB1", "WA2")
S("a1", "WA2", "WA3"); S("a2", "WA3", "T3s"); S("a3", "WA3", "T1s")
S("b1", "WB2", "WB3"); S("b2", "WB3", "T2s"); S("b3", "WB3", "WB4")
S("b4", "WB4", "T4s"); S("b5", "WB4", "WC4")

SW(1, "WA1", "wA", "c1", "c2")
SW(2, "WB1", "wB", "c3", "c4")
SW(3, "WA2", "a1", "c1", "c4")
SW(4, "WB2", "b1", "c3", "c2")
SW(5, "WA3", "a1", "a3", "a2")
SW(6, "WB3", "b1", "b2", "b3")
SW(7, "WB4", "b3", "b4", "b5")

# ---- głowica zachodnia, grupa dalekobieżna -------------------------------
P("it1D", 80, Y["t6"]); P("pC", 260, Y["t6"])
P("WC1", 340, Y["t6"]); P("WC2", 420, Y["t6"]); P("WC3", 500, Y["t6"])
P("it2D", 80, Y["t7"]); P("pD", 260, Y["t7"])
P("WD1", 340, Y["t7"]); P("WD2", 420, Y["t7"]); P("WD3", 500, Y["t7"])
P("WC4", 620, Y["t5"]); P("WD4", 540, Y["t8"])

S("sz1D", "it1D", "pC", "szlak"); S("wC", "pC", "WC1")
S("sz2D", "it2D", "pD", "szlak"); S("wD", "pD", "WD1")
S("d1", "WC1", "WC2"); S("d2", "WC1", "WD2")
S("d3", "WD1", "WD2"); S("d4", "WD1", "WC2")
S("e1", "WC2", "WC3"); S("e2", "WC3", "WC4"); S("e3", "WC3", "T6s")
S("e4", "WC4", "T5s")
S("f1", "WD2", "WD3"); S("f2", "WD3", "T7s"); S("f3", "WD3", "WD4")
S("f4", "WD4", "T8s"); S("f5", "WD4", "T9s")

SW(8, "WC1", "wC", "d1", "d2")
SW(9, "WD1", "wD", "d3", "d4")
SW(10, "WC2", "e1", "d1", "d4")
SW(11, "WD2", "f1", "d3", "d2")
SW(12, "WC3", "e1", "e3", "e2")
SW(13, "WD3", "f1", "f2", "f3")
SW(14, "WD4", "f3", "f4", "f5")
SW(15, "WC4", "e4", "e2", "b5")

# ---- tory stacyjne --------------------------------------------------------
TRACK_DEF = [
    ("3", "t3", "Peron 1", 400), ("1", "t1", "Peron 1", 400),
    ("2", "t2", "Peron 2", 400), ("4", "t4", "Peron 2", 350),
    ("5", "t5", "Peron 3", 450), ("6", "t6", "Peron 3", 450),
    ("7", "t7", "Peron 4", 450), ("8", "t8", "Peron 4", 400),
    ("9", "t9", "", 300),
]
for nr, key, peron, dl in TRACK_DEF:
    a, b = "T%ss" % nr, "T%se" % nr
    P(a, X_TRK_W, Y[key]); P(b, X_TRK_E, Y[key])
    S("trk%s" % nr, a, b, "tor")
    TRK(nr, "trk%s" % nr, a, b, peron, dl)

# ---- głowica wschodnia, grupa podmiejska ---------------------------------
P("EA3", 1500, Y["t1"]); P("EA2", 1580, Y["t1"]); P("EA1", 1660, Y["t1"])
P("pS", 1740, Y["t1"]); P("it1W", 1920, Y["t1"])
P("EB3", 1500, Y["t2"]); P("EB2", 1580, Y["t2"]); P("EB1", 1660, Y["t2"])
P("pT", 1740, Y["t2"]); P("it2W", 1920, Y["t2"])
P("EB4", 1460, Y["t4"]); P("EC4", 1380, Y["t5"])

S("ea2", "T3e", "EA3"); S("ea3", "T1e", "EA3"); S("ea1", "EA3", "EA2")
S("eb2", "T2e", "EB3"); S("eb3", "EB4", "EB3"); S("eb1", "EB3", "EB2")
S("eb4", "T4e", "EB4"); S("eb5", "EC4", "EB4")
S("ec1", "EA2", "EA1"); S("ec2", "EA2", "EB1")
S("ec3", "EB2", "EB1"); S("ec4", "EB2", "EA1")
S("wS", "EA1", "pS"); S("sz1W", "pS", "it1W", "szlak")
S("wT", "EB1", "pT"); S("sz2W", "pT", "it2W", "szlak")

SW(16, "EA3", "ea1", "ea3", "ea2")
SW(17, "EB3", "eb1", "eb2", "eb3")
SW(18, "EB4", "eb3", "eb4", "eb5")
SW(19, "EA2", "ea1", "ec1", "ec2")
SW(20, "EB2", "eb1", "ec3", "ec4")
SW(21, "EA1", "wS", "ec1", "ec4")
SW(22, "EB1", "wT", "ec3", "ec2")

# ---- głowica wschodnia, grupa dalekobieżna + wyjazd na Grochów -----------
P("EC3", 1500, Y["t6"]); P("EC2", 1600, Y["t6"]); P("EC1", 1680, Y["t6"])
P("pP", 1760, Y["t6"]); P("it1R", 1920, Y["t6"])
P("ED3", 1500, Y["t7"]); P("EDg", 1545, Y["t7"])
P("ED2", 1600, Y["t7"]); P("ED1", 1680, Y["t7"])
P("pR", 1760, Y["t7"]); P("it2R", 1920, Y["t7"])
P("ED4", 1460, Y["t8"])
P("pTm1", 1760, Y["t9"]); P("itG", 1920, Y["t9"])

S("ee2", "T5e", "EC4"); S("ee4", "EC4", "EC3"); S("ee3", "T6e", "EC3")
S("ee1", "EC3", "EC2")
S("ef2", "T7e", "ED3"); S("ef3", "ED4", "ED3"); S("ef1", "ED3", "EDg")
S("ef4", "T8e", "ED4"); S("ef5", "T9e", "ED4")
S("efg", "EDg", "ED2"); S("efG", "EDg", "pTm1")
S("ed1", "EC2", "EC1"); S("ed2", "EC2", "ED1")
S("ed3", "ED2", "ED1"); S("ed4", "ED2", "EC1")
S("wP", "EC1", "pP"); S("sz1R", "pP", "it1R", "szlak")
S("wR", "ED1", "pR"); S("sz2R", "pR", "it2R", "szlak")
S("szG", "pTm1", "itG", "szlak")

SW(23, "EC4", "ee2", "ee4", "eb5")
SW(24, "EC3", "ee1", "ee3", "ee4")
SW(25, "ED4", "ef3", "ef4", "ef5")
SW(26, "ED3", "ef1", "ef2", "ef3")
SW(27, "EDg", "ef1", "efg", "efG")
SW(28, "EC2", "ee1", "ed1", "ed2")
SW(29, "ED2", "efg", "ed3", "ed4")
SW(30, "EC1", "wP", "ed1", "ed4")
SW(31, "ED1", "wR", "ed3", "ed2")

# ---- sygnalizatory --------------------------------------------------------
# semafory wjazdowe
SIG("A", "pA", 1, "wjazdowy", "od W-wa Centralna (podm.), tor 1")
SIG("B", "pB", 1, "wjazdowy", "od W-wa Centralna (podm.), tor 2")
SIG("C", "pC", 1, "wjazdowy", "od W-wa Centralna (dalek.), tor 1")
SIG("D", "pD", 1, "wjazdowy", "od W-wa Centralna (dalek.), tor 2")
SIG("S", "pS", -1, "wjazdowy", "od W-wa Wawer, tor 1")
SIG("T", "pT", -1, "wjazdowy", "od W-wa Wawer, tor 2")
SIG("P", "pP", -1, "wjazdowy", "od W-wa Rembertów, tor 1")
SIG("R", "pR", -1, "wjazdowy", "od W-wa Rembertów, tor 2")
SIG("Tm1", "pTm1", -1, "manewrowy", "od stacji technicznej Grochów")
# semafory wyjazdowe
for nr, key, _peron, _dl in TRACK_DEF:
    if nr == "9":
        SIG("Tm2", "T9s", -1, "manewrowy", "tor 9 w kierunku zachodnim")
        SIG("Tm3", "T9e", 1, "manewrowy", "tor 9 w kierunku wschodnim")
    else:
        SIG("K%s" % nr, "T%ss" % nr, -1, "wyjazdowy", "z toru %s w kier. zachodnim" % nr)
        SIG("N%s" % nr, "T%se" % nr, 1, "wyjazdowy", "z toru %s w kier. wschodnim" % nr)

# tarcze ostrzegawcze (elementy informacyjne, rysowane na szlaku)
tarcze_ostrz = [
    {"id": "ToA", "sem": "A", "x": 150, "y": Y["t1"], "km": "3.150"},
    {"id": "ToB", "sem": "B", "x": 150, "y": Y["t2"], "km": "3.150"},
    {"id": "ToC", "sem": "C", "x": 150, "y": Y["t6"], "km": "3.210"},
    {"id": "ToD", "sem": "D", "x": 150, "y": Y["t7"], "km": "3.210"},
    {"id": "ToS", "sem": "S", "x": 1850, "y": Y["t1"], "km": "6.480"},
    {"id": "ToT", "sem": "T", "x": 1850, "y": Y["t2"], "km": "6.480"},
    {"id": "ToP", "sem": "P", "x": 1850, "y": Y["t6"], "km": "6.520"},
    {"id": "ToR", "sem": "R", "x": 1850, "y": Y["t7"], "km": "6.520"},
]

# ---- końce przebiegów (szlaki) -------------------------------------------
LE("it1P", "W-wa Centralna (podm.)", 1, "LK 448", tor="1")
LE("it2P", "W-wa Centralna (podm.)", 1, "LK 448", tor="2")
LE("it1D", "W-wa Centralna (dalek.)", 1, "LK 2", tor="1")
LE("it2D", "W-wa Centralna (dalek.)", 1, "LK 2", tor="2")
LE("it1W", "W-wa Wawer", -1, "LK 7", tor="1")
LE("it2W", "W-wa Wawer", -1, "LK 7", tor="2")
LE("it1R", "W-wa Rembertów", -1, "LK 2", tor="1")
LE("it2R", "W-wa Rembertów", -1, "LK 2", tor="2")
LE("itG", "Grochów (st. techniczna)", -1, "bocznica", kind="manewrowy")

# ---- perony i opisy -------------------------------------------------------
platforms = [
    {"name": "Peron 1", "x": 790, "y": (Y["t3"] + Y["t1"]) // 2 - 7, "w": 420, "h": 14},
    {"name": "Peron 2", "x": 790, "y": (Y["t2"] + Y["t4"]) // 2 - 7, "w": 420, "h": 14},
    {"name": "Peron 3", "x": 790, "y": (Y["t5"] + Y["t6"]) // 2 - 7, "w": 420, "h": 14},
    {"name": "Peron 4", "x": 790, "y": (Y["t7"] + Y["t8"]) // 2 - 7, "w": 420, "h": 14},
]
labels = [
    {"text": "GRUPA PODMIEJSKA", "x": 760, "y": 250, "size": 12},
    {"text": "GRUPA DALEKOBIEŻNA", "x": 760, "y": 530, "size": 12},
    {"text": "tor postojowy", "x": 900, "y": 828, "size": 11},
]

# ------------------------------------------------------------- walidacja ---
def validate():
    err = []
    inc = defaultdict(list)
    ids = set()
    for s in segments:
        if s["id"] in ids:
            err.append("duplikat odcinka %s" % s["id"])
        ids.add(s["id"])
        for e in (s["from"], s["to"]):
            if e not in points:
                err.append("odcinek %s: brak punktu %s" % (s["id"], e))
        if s["from"] in points and s["to"] in points:
            if points[s["from"]][0] >= points[s["to"]][0]:
                err.append("odcinek %s nie prowadzi na wschód" % s["id"])
        inc[s["from"]].append(s["id"])
        inc[s["to"]].append(s["id"])
    sw_pts = set()
    for w in switches:
        p = w["point"]
        sw_pts.add(p)
        legs = set(inc[p])
        want = {w["root"], w["plus"], w["minus"]}
        if len(legs) != 3 or legs != want:
            err.append("rozjazd %s (%s): odgałęzienia %s != %s" % (w["id"], p, sorted(legs), sorted(want)))
    for p, legs in inc.items():
        if p not in sw_pts and len(legs) > 2:
            err.append("punkt %s ma %d odgałęzień, a nie jest rozjazdem" % (p, len(legs)))
    for sg in signals:
        if sg["point"] not in points:
            err.append("sygnalizator %s: brak punktu %s" % (sg["id"], sg["point"]))
        if sg["point"] in sw_pts:
            err.append("sygnalizator %s stoi na rozjeździe %s" % (sg["id"], sg["point"]))
    for le in line_ends:
        if le["id"] not in points:
            err.append("koniec szlaku %s: brak punktu" % le["id"])
    return err


def main():
    errs = validate()
    if errs:
        for e in errs:
            print("BŁĄD:", e)
        raise SystemExit(1)
    data = {
        "name": "Warszawa Wschodnia",
        "short": "WWS",
        "points": [{"id": k, "x": v[0], "y": v[1]} for k, v in points.items()],
        "segments": segments,
        "switches": switches,
        "signals": signals,
        "tarcze_ostrzegawcze": tarcze_ostrz,
        "line_ends": line_ends,
        "tracks": tracks,
        "platforms": platforms,
        "labels": labels,
    }
    out = os.path.join(os.path.dirname(__file__), "..",
                       "data", "locations", "warszawa_wschodnia", "layout.json")
    out = os.path.normpath(out)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("Zapisano %s" % out)
    print("  punktów: %d, odcinków: %d, rozjazdów: %d, sygnalizatorów: %d" % (
        len(points), len(segments), len(switches), len(signals)))


if __name__ == "__main__":
    main()
