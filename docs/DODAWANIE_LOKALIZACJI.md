# Dodawanie nowej lokalizacji

Lokalizacje są w pełni opisane danymi — nowa stacja nie wymaga zmian w kodzie.

## Kroki

1. Utwórz katalog `data/locations/<id_stacji>/`.
2. Dodaj `location.json`:

   ```json
   {
     "id": "moja_stacja",
     "name": "Moja Stacja",
     "short": "MST",
     "layout": "layout.json",
     "timetable": "timetable.json",
     "start_time_random": "12:00",
     "description": "Opis widoczny w menu."
   }
   ```

3. Dodaj `layout.json` — układ torowy. Konwencje:
   - `points` — punkty schematu (współrzędne w px; oś X rośnie na wschód),
   - `segments` — odcinki **zawsze opisane od punktu zachodniego (`from`)
     do wschodniego (`to`)**; jazda `dir=1` (na wschód) odbywa się po
     krawędziach `from→to`, jazda `dir=-1` po `to→from`,
   - `switch_points` — punkty będące rozjazdami (mogą ulegać usterkom),
   - `signals` — semafory: `point`, `dir` (1 = patrzy na wschód), opcjonalnie
     `shunt_only: true` (tarcza manewrowa),
   - `portals` — punkty brzegowe, z których zgłaszają się i do których
     odjeżdżają pociągi (`dir_in` = kierunek wjazdu do stacji),
   - `tracks` — tory stacyjne (numer, odcinek `seg`, końce `a`/`b`, peron),
   - `platforms`, `labels` — elementy rysunkowe.

4. Dodaj `timetable.json` — rozkład jazdy:

   ```json
   {
     "start_time": "04:45",
     "entries": [
       {"nr": "12345", "kat": "IC", "nazwa": "Przykład", "z": "A", "do": "B",
        "we": "WD1", "wy": "ED1", "tor": "5",
        "przyjazd": "05:04", "odjazd": "05:07"}
     ]
   }
   ```

   Pola specjalne wiersza:
   - `"przelot": true` — przejazd bez zatrzymania (towarowe),
   - `"koniec": true` — pociąg kończy bieg; po przyjeździe skład odstawia się
     manewrowo do zaplecza (portal w polu `wy`),
   - `"start": true` — pociąg zaczyna bieg; najpierw z portalu `we` trzeba
     manewrowo podstawić skład na tor `tor`,
   - `"opoznienie": <min>` — opóźnienie początkowe.

   Kategorie pociągów: `SKM`, `KM`, `IC`, `EIP`, `TLK`, `TME` (towarowy),
   `MAN` (manewrowy).

5. Uruchom grę — lokalizacja pojawi się w menu automatycznie.

## Aktualizacje online

Aby lokalizacja miała własny rozkład online, umieść plik JSON (format jak
`timetable.json`) pod publicznym adresem HTTP i wpisz go w Ustawieniach gry.
Opóźnienia: `{"delays": [{"nr": "12345", "delay_min": 5}]}`.
