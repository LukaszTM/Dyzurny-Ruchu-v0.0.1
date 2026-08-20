# CHANGELOG

## Faza 1 — Graf torowy i loader (2026-08-20)

### Dodano

- `core/const.gd` — enumy domenowe (`TurnoutPos`, `TurnoutState`, `SectionType`,
  `SignalKind`) i mapowania łańcuchów JSON.
- `core/command_result.gd` — wynik polecenia `{ok, reason}` (command pattern
  z docs/02).
- `core/section.gd` — odcinek izolowany: zajętość, flaga utwierdzenia,
  snapshot stanu.
- `core/turnout.gd` — zwrotnica: stany PLUS/MINUS/MOVING/NO_CONTROL/TRAILED,
  przestawianie z czasem `throw_time_s`, rozprucie, zamknięcie indywidualne,
  utwierdzenie; odliczanie czasu odporne na dryf float.
- `core/signal_device.gd` — sygnalizator: konstrukcja (komory, paski, Ms2, Sz)
  i przechowywanie obrazu; obrazy zasadnicze S1/Ms1/Os1/Sp1 wg systemy/11.
- `core/track_graph.gd` — graf torowy: węzły, krawędzie, sekcje, zwrotnice,
  sygnalizatory; indeksy odwrotne; `throw_turnout()` z warunkami z docs/04 §2
  (sekcja wolna i nieutwierdzona); ręczna zajętość sekcji; tick zwrotnic.
- `core/station_data.gd` + `core/station_loader.gd` — wczytywanie stacji
  z JSON i pełna walidacja (docs/03 §7): spójność grafu, kompletność sekcji,
  istnienie elementów przebiegów, symetria konfliktów, odwołania pulpitu;
  komunikaty błędów po polsku z id elementu.
- `data/stations/borki.json` — mijanka Borki (przeniesiona
  z `data/stacja-przyklad.json`).
- `SimWorld.load_station_file()` + krok „zwrotnice" w ticku.
- Testy GUT: 32 nowe (loader/walidacja, zwrotnica, graf torowy) — razem 48.

### Jak przetestować ręcznie

1. `godot --headless -s addons/gut/gut_cmdln.gd` → 48/48 passed.
2. W edytorze: uruchom projekt — zachowanie F0 bez zmian (zegar, mnożniki);
   graf torowy nie ma jeszcze widoku (pulpit → Faza 2).
3. Walidację można sprawdzić psując `data/stations/borki.json` (np. zmień
   `"to": "nB"` na `"to": "nX"`) i wywołując w konsoli edytora:
   `StationLoader.load_from_file("res://data/stations/borki.json")` —
   wynik zawiera czytelny komunikat błędu z id elementu.

## Faza 0 — Szkielet projektu (2026-08-20)

**Uwaga:** repozytorium wystartowało od nowa — poprzedni prototyp „Symulator LCS
Warszawa Wschodnia" został usunięty (pozostaje w historii gita na gałęzi
`claude/lcs-simulator-warsaw-u9cxgs`). Nowy projekt realizowany jest fazami
wg `docs/06-roadmap.md` i zasad z `CLAUDE.md`.

### Dodano

- Projekt Godot 4.3 (`project.godot`): 1920×1080, stretch `canvas_items`,
  GL Compatibility, scena główna `res://ui/wspolne/main.tscn`.
- Struktura katalogów wg CLAUDE.md: `core/`, `autoload/`, `ui/`, `data/`
  (`stations/`, `scenarios/`, `signals/`), `tests/`.
- Autoloady:
  - `EventBus` — szyna zdarzeń rdzeń↔UI (`sim_event`, `command_result`).
  - `SimClock` — zegar symulacji: stały tick 10 Hz czasu symulacji,
    mnożnik ×1/×2/×5, pauza, bezpiecznik nadrabiania, czas wolny od dryfu
    float (wyliczany z liczby ticków).
  - `GameState` — szkielet stanu gry: jedyny RNG z seedem zapisywanym
    w save, godzina startu scenariusza, snapshot `to_dict()/from_dict()`.
- `core/sim_world.gd` — szkielet rdzenia (`RefCounted`, zero Node),
  `tick()` + snapshot stanu.
- Scena Main (`ui/wspolne/`): duży zegar HH:MM:SS (start 05:40 jak
  w przykładowym scenariuszu), przyciski Pauza/×1/×2/×5, skróty
  klawiszowe Spacja/1/2/5, licznik ticków.
- Addon GUT 9.3.0 (`addons/gut/`) + `.gutconfig.json`.
- Testy GUT (16 testów, w tym przypadki brzegowe): `test_sim_clock.gd`,
  `test_sim_world.gd`, `test_game_state.gd`.
- `WERYFIKACJA.md` (pusty — F0 nie dotyka elementów [DO WERYFIKACJI]).

### Jak przetestować ręcznie

1. Otwórz projekt w Godot 4.3+ i uruchom (F5).
2. Zegar startuje o 05:40:00 i chodzi w tempie rzeczywistym (×1).
3. Klik „×2" / „×5" (lub klawisze 2/5) — zegar przyspiesza; aktywny
   mnożnik ma wyszarzony przycisk.
4. Klik „Pauza" (lub Spacja) — zegar staje, UI dalej reaguje; „Wznów"
   wznawia od tego samego momentu.
5. Licznik ticków rośnie o 10/s przy ×1, 50/s przy ×5.
6. Testy: `godot --headless -s addons/gut/gut_cmdln.gd` → 16/16 passed.
