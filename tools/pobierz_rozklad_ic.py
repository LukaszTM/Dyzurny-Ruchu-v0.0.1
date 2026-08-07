#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Pobiera OFICJALNE zestawienie pociągów PKP Intercity dla stacji
Warszawa Wschodnia i scala je z rozkładem gry.

PKP Intercity publikuje dla każdej stacji plakatowe zestawienie odjazdów
(PDF: godzina, pociąg, stacja docelowa, peron, tor):
  https://www.intercity.pl/pl/site/dla-pasazera/kup-bilet/pociagi-i-stacje/zestawienia-pociagow.html

Uruchom NA WŁASNYM komputerze (wymaga dostępu do internetu):
  pip install requests pdfplumber
  python3 tools/pobierz_rozklad_ic.py [URL_PDF]

Skrypt:
  1. pobiera PDF (domyślnie zestawienie od 31.08.2025),
  2. wyciąga wiersze "HH:MM  KATEGORIA NUMER [NAZWA]  STACJA  PERON TOR",
  3. mapuje kategorie na oznaczenia gry (EIP/EIC->EIP/EIE, IC->MPE, TLK->MOE),
  4. zapisuje data/online/timetable_ic_wws.json w formacie gry.

Wynik można podstawić jako "Adres rozkładu jazdy (JSON)" w Ustawieniach gry
(np. przez raw.githubusercontent.com) — gra dołączy te pociągi do rozkładu.
Uwaga: PDF zawiera tylko odjazdy PKP Intercity (bez SKM/KM) i bez godzin
przyjazdu — skrypt przyjmuje postój 4 min. Format plakatu bywa zmieniany;
w razie potrzeby dostosuj wyrażenie regularne WIERSZ.
"""

import json
import os
import re
import sys

URL = ("https://www.intercity.pl/dokumenty/zestawienia%20poci%C4%85g%C3%B3w/"
       "od-31-08-2025/Warszawa_Wschodnia_31_08_2025.pdf")

KAT = {"EIP": "EIP", "EIC": "EIE", "EC": "EIE", "IC": "MPE", "TLK": "MOE"}

# kierunek wyjazdu w grze wg stacji docelowej
KIERUNEK_WY = {
    "Białystok": "it1R", "Suwałki": "it1R", "Terespol": "it1R",
    "Siedlce": "it1R", "Ełk": "it1R", "Wilno": "it1R", "Vilnius": "it1R",
    "Lublin": "it1W", "Chełm": "it1W", "Zamość": "it1W", "Hrubieszów": "it1W",
}

WIERSZ = re.compile(
    r"(?P<godz>\d{1,2}:\d{2})\s+(?P<kat>EIP|EIC|EC|IC|TLK)\s+(?P<nr>\d{2,5})"
    r"\s*(?P<nazwa>[A-ZŻŹĆŃÓŁĘĄŚ][\w\- ]*?)?\s{2,}(?P<cel>[A-ZŻŹĆŃÓŁĘĄŚ][\w\-\. ]+?)"
    r"\s{2,}(?P<peron>[IVX]+)\s+(?P<tor>\d+)\s*$", re.M)


def main() -> None:
    url = sys.argv[1] if len(sys.argv) > 1 else URL
    try:
        import requests
        import pdfplumber
    except ImportError:
        raise SystemExit("Zainstaluj zależności:  pip install requests pdfplumber")
    print("Pobieram:", url)
    pdf_path = "/tmp/wws_ic.pdf"
    with open(pdf_path, "wb") as f:
        f.write(requests.get(url, timeout=60).content)
    tekst = ""
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            tekst += (page.extract_text() or "") + "\n"
    entries = []
    for m in WIERSZ.finditer(tekst):
        cel = m.group("cel").strip()
        wy = "it2D"  # domyślnie: na zachód (przez Centralną)
        for klucz, kier in KIERUNEK_WY.items():
            if klucz.lower() in cel.lower():
                wy = kier
                break
        we = "it1D" if wy != "it2D" else "it2R"
        godz = m.group("godz")
        h, mi = int(godz.split(":")[0]), int(godz.split(":")[1])
        przyj = "%02d:%02d" % (h, mi - 4) if mi >= 4 else "%02d:%02d" % ((h - 1) % 24, mi + 56)
        e = {
            "nr": m.group("nr"),
            "kat": KAT.get(m.group("kat"), "MPE"),
            "z": "wg zestawienia IC", "do": cel,
            "we": we, "wy": wy,
            "tor": m.group("tor"),
            "przyjazd": przyj, "odjazd": godz, "postoj": 4,
        }
        if m.group("nazwa"):
            e["nazwa"] = m.group("nazwa").strip()
        entries.append(e)
    if not entries:
        raise SystemExit("Nie rozpoznano żadnego wiersza — dostosuj wyrażenie WIERSZ "
                         "do aktualnego układu PDF (zapisany w %s)." % pdf_path)
    out = os.path.join(os.path.dirname(__file__), "..", "data", "online",
                       "timetable_ic_wws.json")
    out = os.path.normpath(out)
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"start_time": "00:00", "entries": entries}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")
    print("Zapisano %d pociągów -> %s" % (len(entries), out))


if __name__ == "__main__":
    main()
