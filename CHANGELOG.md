# CHANGELOG

## Faza 5 — Blokada półsamoczynna, telefonogramy, dziennik ruchu (2026-08-20)

### Dodano

- `core/block_line.gd` — blokada półsamoczynna per szlak (systemy/15 §1/§4):
  pozwolenie Poz na szlaku jednotorowym, pola Po/Ko z warunkami, odmowy
  z powodem; warunek 6 checklisty utwierdzenia w interlockingu (wyjazd
  tylko przy pozwoleniu u gracza i wolnym odstępie).
- `core/neighbour_ai.gd` — AI sąsiada (docs/05 §4): żąda pozwolenia wg
  rozkładu (z ponagleniami), oznajmia odjazd i wprowadza pociąg do świata
  (wjazd sprzężony z zapowiedzią — docs/05 §3), odpowiada na telefonogramy
  gracza z opóźnieniem, po przyjeździe u siebie zwalnia odstęp (jego Ko),
  honoruje „Stój — zatrzymajcie pociąg".
- `core/comms.gd` — telefonogramy: 5 formuł wg systemy/18 §2 (parafrazy
  Ir-1), rejestr rozmów z nieodebranymi.
- `core/train_log.gd` — dziennik ruchu (R-142) w trybie auto: pozwolenie,
  oznajmienie, odjazd, przyjazd, potwierdzenie, uwagi.
- Scoring v1 (docs/05 §7): start 100 pkt; −1/min opóźnienia przyjazdu,
  −10 brak potwierdzenia przyjazdu (Ko + telefonogram) lub oznajmienia
  odjazdu w 5 min; podsumowanie „Koniec służby" po czasie scenariusza.
- UI: okno łączności (T) — składanie formuły z klocków (typ, nr, sąsiad),
  transkrypt, dzwonek z licznikiem nieodebranych; dziennik ruchu (D);
  pola blokad na pulpicie żywe (lampki odstępu/Po/pozwolenia + klikalne
  przyciski Po/Ko/Poz).
- Testy: 7 nowych (blokada — warunki pól i wyprawienia, pełna pętla
  zapowiadawcza z dziennikiem bez kar, kara za brak potwierdzenia,
  koniec zmiany, spawn po zapowiedzi). Razem 87.
- Scenariusz `borki-poranek` bez zmian danych (120 min — wartość z pliku
  źródłowego; roadmapowe „60 min" potraktowano orientacyjnie).

### Jak przetestować ręcznie

1. Start, ×5. Ok. 05:58 dzwoni Lipno: „Czy droga dla pociągu nr 45201
   wolna?" (przycisk ☎ miga). Otwórz telefon (T), odpowiedz formułą
   „Danie pozwolenia" i naciśnij Poz na polu BLOKADA LIPNO.
2. Ok. 06:00 Lipno oznajmia odjazd — pociąg pojawia się na szlaku,
   lampka „odstęp" czerwona. Nastaw wjazd (A).
3. Po przyjeździe całego pociągu naciśnij Ko (lampka gaśnie) i nadaj
   „Potwierdzenie przyjazdu". Dziennik (D) uzupełnia się sam.
4. Wyjazd na Suchowolę: bez pozwolenia (po oddaniu Poz) semafor C1
   odmawia; zażądaj drogi telefonicznie — sąsiad odda pozwolenie.
5. Po wyprawieniu nadaj „Oznajmienie odjazdu"; po ~2 min sąsiad
   potwierdzi przyjazd i odstęp się zwolni. Brak telefonogramów w 5 min
   = kara widoczna w pasku i w podsumowaniu po końcu zmiany.

## Faza 4 — Pociągi (2026-08-20)

### Dodano

- `core/train.gd` — pociąg: punkt z długością, fizyka wg docs/05 §1
  (przyspieszenie malejące z prędkością per typ trakcji, hamowanie
  służbowe/nagłe), ścieżka budowana przyrostowo z grafu (z wirtualnymi
  odcinkami zwrotnicowymi), zajmowanie sekcji czołem i zwalnianie końcem
  składu. AI maszynisty: krzywa hamowania do zatrzymania ~50 m przed
  semaforem „stój", jazda na Sz z podjazdem ≤40 km/h, postój handlowy
  min. 30 s (W4 = środek toru — uproszczenie), hamowanie nagłe przy
  nagłym „stój" przed pociągiem, rozprucie przy najechaniu z boku na źle
  ułożoną zwrotnicę (iglice wymuszane, jazda kontynuowana).
- `core/timetable.gd` — rozkład jazdy scenariusza, spawn 90 s przed
  planowym przyjazdem (uproszczenie F4 — od F5 wejście sprzężone
  z zapowiedzią), despawn za stacją.
- `SimWorld`: wczytywanie scenariusza (`load_scenario_file`), spawn od
  strony właściwego sąsiada (blokada → semafor wjazdowy → szlak),
  zajętości od pociągów (diff, ręczne debugowe nadal działają),
  kolejność ticku: pociągi → zwrotnice → interlocking.
- Scena Main startuje ze scenariusza `borki-poranek` (start 05:40,
  4 pociągi); panel debug pokazuje pociągi (faza, prędkość, pozycja).
- `data/scenariusz-przyklad.json` → `data/scenarios/borki-poranek.json`.
- 7 testów integracyjnych pociągów (zatrzymanie przed „stój", przejazd
  ze zwalnianiem sekcyjnym i powrotem semaforów na „stój", postój 30 s,
  rozprucie, limit 40 za Sz, hamowanie nagłe po dZw, spawn wg rozkładu).
  Razem 80.

### Jak przetestować ręcznie

1. Uruchom projekt, ustaw ×5. Ok. 06:00:30 na szlaku od Lipna pojawia
   się osobowy 45201 (iza czerwienieje) i staje przed semaforem A.
2. Nastaw wjazd na tor 1 (przycisk A) — pociąg rusza, sekcje
   czerwienieją kolejno, A wraca na „stój" po minięciu czoła, droga
   zwalnia się sekcyjnie za składem.
3. Pociąg staje w połowie toru 1 (postój), po ~30 s jest gotów;
   nastaw wyjazd (C1) — odjeżdża i znika za stacją, wszystko gaśnie.
4. O 06:01:30 od Suchowoli nadjeżdża 45302 → wjazd na tor 2 (z1/z2
   w MINUS, przycisk B), krzyżowanie jak w prawdziwej mijance.
5. Bez nastawionej drogi pociąg zawsze staje ~50 m przed semaforem.

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
