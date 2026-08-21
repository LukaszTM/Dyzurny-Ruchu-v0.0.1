# CHANGELOG

## Faza 3 — Interlocking + sygnalizacja (2026-08-20)

### Dodano

- `data/signals/aspekty.json` — tabela obrazów sygnałowych wygenerowana
  z docs/systemy/11-sygnalizacja.md (S1–S13a, Sz, Ms1/Ms2, Os1–4, Sp1–4)
  z lampami, pasami, wymaganiami konstrukcyjnymi, tabelą wyboru §6
  i łańcuchem degradacji §6.1.
- `core/aspect_table.gd` — wybór obrazu f(grupa prędkości, następny
  semafor) z degradacją konstrukcyjną; mapowania tarcz Os/Sp.
- `core/route.gd` — przebieg: maszyna stanów IDLE→LOCKED→TRAIN_ON→
  RELEASING→IDLE + CANCELLED (docs/04 §2), zwalnianie sekcyjne.
- `core/interlocking.gd` — silnik zależności: checklista utwierdzenia
  (docs/04 §3, konflikty najpierw), nastawianie indywidualne (przycisk
  sygnałowy dobiera przebieg do położenia zwrotnic), kasowanie (wolne
  zbliżanie = natychmiast; zajęte = dZw z czasem ewolucji 90 s
  i licznikiem), sygnał zastępczy Sz z licznikiem i timerem, zamknięcia
  indywidualne (dwustopniowo: przycisk „zamkn. zwr." + przycisk
  zwrotnicy), przeliczanie obrazów semaforów/tarcz po każdym ticku,
  utrata kontroli zwrotnicy gasi sygnał zezwalający.
- `SimWorld.execute()` — pełny command pattern (docs/02); scena Main
  tylko przekazuje polecenia.
- UI: liczniki bębenkowe na przyciskach dSz/dZw pokazują stan z rdzenia,
  pociągnięcie przycisku = PPM (kasowanie przebiegu), panel debug
  pokazuje stany przebiegów.
- Testy: 25 nowych (komplet z docs/04 §9 — utwierdzanie i odmowy,
  zwrotnice w przebiegu, zwalnianie sekcyjne 3-sekcyjne, kasowanie
  z timerem i licznikiem, Sz, rozprucie, zamknięcia, pełna tabela 16
  obrazów + degradacje, propagacja obrazów, ochrona boczna). Razem 73.

### Jak przetestować ręcznie

1. Zwrotnice z1/z2 na wprost (PLUS) → klik zielonego przycisku przy
   semaforze A: droga izw1→it1 podświetla się na biało, powtarzacz A
   zielenieje (S5 w debugu), izw2 (droga ochronna) też biała.
2. Próba przestawienia z1/z2 → odmowa „utwierdzona w przebiegu A_t1".
3. Próba nastawienia od B → odmowa „przebieg sprzeczny A_t1".
4. PPM na przycisku A (pociągnięcie) → kasowanie: droga gaśnie.
5. F12 → zajmij iza, nastaw od A, PPM na A → odmowa „wymagane dZw";
   klik dZw, potem przycisk A → przebieg CANCELLED z odliczaniem 90 s
   (w debugu), licznik dZw pokazuje 001.
6. Klik „dSz C1" → powtarzacz C1 miga na biało (Sz), licznik 001;
   po 90 s czasu symulacji (×5 przyspiesza) wraca S1.
7. Klik „zamkn. zwr.", potem przycisk z1 → zwrotnica zamknięta
   (przestawienie odmawiane); ponowne zamknięcie/otwarcie tak samo.

## Faza 2 — Pulpit kostkowy (widok, bez zależności) (2026-08-20)

### Dodano

- `ui/pulpit_kostkowy/pulpit_tile.gd` — rysowanie kostek wg assets-spec/20:
  tory (proste, łuki, ukosy, przerwy izolacyjne), okienka lampek odcinków
  (czerwona zajętość z poświatą / biała utwierdzenie / ciemna), zwrotnice
  z lampkami kontroli położenia (miganie przy przestawianiu, czerwone przy
  braku kontroli/rozpruciu), symbole semaforów z powtarzaczami, przyciski
  (zwrotnicowe szare, sygnałowe zielone, specjalne czerwone pod plombą
  z licznikami), pola blokad, tabliczki, etykiety.
- `ui/pulpit_kostkowy/pulpit_view.gd` — budowa pulpitu z sekcji `panel`
  JSON, tło kostek z fugami, rama, miganie 1 Hz.
- `ui/wspolne/debug_panel.gd` — tryb debug (F12): stan sekcji (z ręcznym
  zajmowaniem/zwalnianiem), zwrotnic (z przestawianiem) i sygnalizatorów.
- `ui/wspolne/analog_clock.gd` — zegar wskazówkowy w pasie górnym.
- Nowa scena Main: tabliczka posterunku, zegary, sterowanie czasem,
  komunikaty odmów (tryb szkolenia), pulpit + panel debug.
- `EventBus.command` — kanał poleceń UI → rdzeń; scena Main jako
  właściciel SimWorld wykonuje polecenia i publikuje wyniki.
- `data/stations/borki.json` — sekcja `panel` poprawiona do spójnej
  geometrii (ciągłe linie torów, poprawione pozycje ukosów/łuków);
  id przycisków i akcje bez zmian.
- `WERYFIKACJA.md` — 5 pozycji [DO WERYFIKACJI] z F2 (lampki położenia,
  kolory przycisków i powtarzaczy, brak kontroli, naciśnij/pociągnij).

### Jak przetestować ręcznie

1. Uruchom projekt — pulpit Borek na środku, pas górny z tabliczką
   „BORKI", zegarem wskazówkowym i cyfrowym.
2. Klik szarego przycisku przy zwrotnicy 1/2 — lampki położenia migają
   ~5 s (przestawianie), potem świeci strona docelowa; stan widać też
   w panelu debug (F12).
3. W panelu debug „Zajmij" sekcję it1 — okienka toru 1 czerwienieją
   z poświatą; przestawienie zwrotnicy w zajętej sekcji zwrotnicowej
   (izw1/izw2) jest odrzucane z komunikatem w pasku górnym.
4. Klik zielonego przycisku sygnałowego — komunikat „funkcja dostępna
   od Fazy 3 (interlocking)".
5. ×1/×2/×5/pauza działają jak w F0; miganie lampek nie zamiera w pauzie.

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
