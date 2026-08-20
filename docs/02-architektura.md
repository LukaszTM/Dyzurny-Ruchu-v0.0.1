# 02 — Architektura (Godot 4)

## Zasada nadrzędna: rdzeń ≠ UI

Symulacja (rdzeń) to czyste klasy `RefCounted` bez odwołań do drzewa scen.
UI to sceny Godota, które: (a) subskrybują zdarzenia rdzenia, (b) wysyłają polecenia.
Dzięki temu ten sam rdzeń obsługuje pulpit kostkowy, nastawnię mechaniczną i ekran
komputerowy — różne UI, jedna logika. Rdzeń testowalny headless (GUT).

```
┌────────────────────────── UI (sceny Godot) ──────────────────────────┐
│ PulpitKostkowyView │ NastawniaMechView │ KomputerView │ Telefon │ Dok.│
└─────────▲──────────────────────▲───────────────▲──────────▲──────────┘
          │ zdarzenia (sygnały Godot)            │ polecenia (metody)
┌─────────┴────────────────── EventBus (autoload) ─────────┴───────────┐
└─────────▲─────────────────────────────────────────────────▲──────────┘
┌─────────┴───────────────────── RDZEŃ ──────────────────────┴─────────┐
│ SimWorld ── Interlocking ── TrackGraph/Sections/Turnouts/Signals     │
│          ── BlockLine(s) ── Trains ── Timetable ── Crossings ── Dsat │
│          ── NeighbourAI (sąsiednie posterunki) ── EventDirector      │
└──────────────────────────────────────────────────────────────────────┘
```

## Pętla symulacji

- `SimClock` (autoload): akumuluje `delta`, wywołuje `SimWorld.tick(0.1)` co 0,1 s
  czasu symulacji; mnożnik czasu ×1/×2/×5; pauza zatrzymuje tylko symulację, nie UI.
- Kolejność w ticku: (1) pociągi (ruch, zajmowanie/zwalnianie odcinków) →
  (2) zwrotnice (dokończenie przestawiania) → (3) interlocking (aktualizacja stanów
  przebiegów, zwalnianie sekcyjne) → (4) sygnalizatory (przeliczenie obrazów) →
  (5) blokady liniowe → (6) przejazdy/dSAT → (7) EventDirector (awarie, telefony) →
  (8) NeighbourAI → (9) emisja zdarzeń zbiorczo.
- Zdarzenia rdzenia to obiekty `SimEvent {type, payload}` publikowane przez EventBus,
  np. `section_occupied`, `signal_aspect_changed`, `phone_ring`, `dsat_alarm`.

## Polecenia gracza (command pattern)

UI nigdy nie zmienia stanu bezpośrednio. Wysyła `Command` do `SimWorld.execute(cmd)`:
`TurnoutThrow(id)`, `SignalButtonPress(id, mode)` (mode: press/pull),
`RouteSet(start_signal, end)`, `RouteEmergencyRelease(route)`, `SubSignal(signal)`,
`BlockAction(block, field)`, `LeverMove(lever, position)`, `CrossingClose(id)`,
`PhoneSend(telefonogram)`, `DocumentWrite(entry)`.
Rdzeń waliduje (zależności!) i zwraca `CommandResult {ok, reason}` — odrzucenie z
powodem to normalna sytuacja (np. „zwrotnica utwierdzona w przebiegu"). UI pokazuje
odmowę tak, jak zrobiłoby to urządzenie (brak reakcji / lampka), a w trybie
szkolenia dodatkowo tekstowo.

## Mapowanie urządzeń na rdzeń

Jedna logika przebiegów, trzy „skóry" o różnych ograniczeniach interakcji:
- **Mechaniczne**: gracz wykonuje ręcznie kroki, które w przekaźnikowych są
  automatyczne (kolejność dźwigni wymuszona skrzynią zależności — rdzeń udostępnia
  `can_move_lever()`).
- **Przekaźnikowe (pulpit)**: zwrotnice indywidualnie przyciskami, sygnał przyciskiem
  sygnałowym; zależności sprawdza interlocking.
- **Komputerowe**: polecenia przebiegowe (start–cel), dialog potwierdzeń; te same
  stany rdzenia renderowane na monitorze.

## Zapis gry

Snapshot pełnego stanu rdzenia do JSON (wszystkie obiekty mają `to_dict()/from_dict()`),
plus seed RNG i czas. Zapis w `user://saves/`. Autosave co 5 min symulacji.

## Wydajność

Cele: stacja do ~60 zwrotnic, ~40 pociągów/scenariusz — trywialne obciążenie.
Pulpit rysowany raz do `SubViewport`/tekstur; per tick aktualizują się tylko lampki
(węzły `Lamp` ze zmianą koloru). Unikaj przerysowywania całego planu co klatkę.

## Konwencje kodu

- Typowany GDScript; nazwy klas PascalCase, pliki snake_case.
- Stałe domenowe w `core/const.gd` (enumy: `Aspect`, `RouteState`, `TurnoutPos`...).
- Komentarze i komunikaty logów po polsku; identyfikatory po angielsku.
- Każda klasa rdzenia: krótki docstring z odsyłaczem do pliku dokumentacji, np.
  `## Zależności wg docs/04-logika-zaleznosci.md §3`.
