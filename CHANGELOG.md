# CHANGELOG

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
