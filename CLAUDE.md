# CLAUDE.md — instrukcja robocza projektu „Symulator Dyżurnego Ruchu"

Jesteś głównym programistą gry 2D w Godot 4 (GDScript). Gra to samodzielny,
jednoosobowy symulator pracy dyżurnego ruchu na polskiej kolei, z wiernie
odwzorowanymi urządzeniami sterowania ruchem kolejowym (srk).

## Stos technologiczny

- **Silnik:** Godot 4.3+ (sprawdź zainstalowaną wersję: `godot --version`).
- **Język:** GDScript z pełnym typowaniem statycznym (`var x: int`, `-> void` itd.).
- **Dane:** definicje stacji, scenariuszy i mapowań przycisków w plikach JSON
  w `res://data/` (patrz `docs/03-model-danych.md`).
- **Testy:** framework GUT (addon) dla logiki rdzenia. Logika zależności MUSI mieć testy.
- **Rozdzielczość bazowa:** 1920×1080, stretch mode `canvas_items`, UI skalowalne.

## Kolejność czytania dokumentacji (obowiązkowa przed kodowaniem)

1. `docs/00-koncepcja-gry.md` — co budujemy i po co.
2. `docs/02-architektura.md` — struktura projektu, separacja rdzeń/UI.
3. `docs/03-model-danych.md` + `data/stacja-przyklad.json` — format danych.
4. `docs/04-logika-zaleznosci.md` — najważniejszy dokument merytoryczny rdzenia.
5. `docs/systemy/11-sygnalizacja.md` — tabela sygnałów (źródło prawdy dla semaforów).
6. Pozostałe pliki `docs/systemy/*` i `assets-spec/*` — wg potrzeb bieżącej fazy.
7. `docs/06-roadmap.md` — realizuj fazy PO KOLEI, jedną na raz.

## Zasady twarde (nie łam ich)

1. **Źródło prawdy.** Znaczenia sygnałów, procedury i zachowanie urządzeń bierzesz
   WYŁĄCZNIE z `docs/systemy/`. Nie zgaduj i nie „poprawiaj" z pamięci. Jeśli czegoś
   brakuje — zatrzymaj się i zapytaj użytkownika.
2. **Znaczniki [DO WERYFIKACJI].** Gdy implementujesz coś oznaczone tym znacznikiem,
   umieść w kodzie komentarz `# TODO(weryfikacja): ...` i wpisz pozycję do pliku
   `WERYFIKACJA.md` w katalogu głównym (utwórz go, jeśli nie istnieje). Nie blokuj
   pracy — implementuj wg opisu, ale zostaw ślad.
3. **Separacja rdzenia od UI.** Cała logika symulacji (graf torowy, zależności,
   pociągi, blokady) to czyste klasy GDScript bez zależności od węzłów sceny
   (`RefCounted`, nie `Node`). UI tylko wyświetla stan i wysyła polecenia przez
   `EventBus`. Test: rdzeń musi dać się uruchomić headless w testach GUT.
4. **Dane, nie kod.** Układy stacji, przebiegi, mapowania przycisków pulpitu,
   rozkłady jazdy — wszystko w JSON. Dodanie nowej stacji nie może wymagać zmian w kodzie.
5. **Determinizm.** Symulacja chodzi na stałym ticku (10 Hz czasu symulacji,
   niezależnie od FPS; czas gry przyspieszany mnożnikiem ×1/×2/×5). Losowość tylko
   przez jeden `RandomNumberGenerator` z seedem zapisywanym w save.
6. **Wierność wizualna.** Wygląd pulpitów implementuj dokładnie wg `assets-spec/*`.
   Grafika wyłącznie własna (rysowana kodem/`draw_*`, SVG lub własne tekstury).
   ZAKAZ: kopiowania grafik, dźwięków, danych i kodu z Train Driver 2, symulatorów
   TTSK, zdjęć z internetu oraz 1:1 interfejsu oprogramowania PKP PLK
   (szczegóły: `docs/01-podstawy-prawne.md`).
7. **Język.** Cały tekst widoczny w grze po polsku, z poprawną terminologią kolejową
   (słownik w `docs/systemy/10-podstawy-srk.md`). Nazwy w kodzie po angielsku,
   komentarze po polsku.
8. **Jedna faza na raz.** Nie wybiegaj naprzód. Po zakończeniu fazy wypisz
   użytkownikowi listę rzeczy do ręcznego przetestowania w Godocie.

## Struktura projektu Godot (docelowa)

```
res://
├── project.godot
├── core/                  # czysta logika, zero Node
│   ├── track_graph.gd     # graf torowy: węzły, krawędzie, odcinki
│   ├── section.gd         # odcinek izolowany (zajętość)
│   ├── turnout.gd         # zwrotnica (stany, przestawianie, rozprucie)
│   ├── signal_device.gd   # sygnalizator (semafor, To, Tm) + wybór obrazu
│   ├── route.gd           # przebieg (stany, utwierdzenie, zwalnianie)
│   ├── interlocking.gd    # silnik zależności (warunki, ochrona boczna)
│   ├── block_line.gd      # blokada liniowa (półsamoczynna/samoczynna)
│   ├── train.gd           # pociąg (fizyka punktu, AI maszynisty)
│   ├── timetable.gd       # rozkład jazdy
│   ├── level_crossing.gd  # przejazd (ssp / rogatki obsługiwane)
│   ├── dsat.gd            # detekcja stanów awaryjnych taboru
│   └── sim_world.gd       # spina wszystko, tick()
├── autoload/
│   ├── event_bus.gd       # sygnały globalne (polecenia UI ↔ zdarzenia rdzenia)
│   ├── sim_clock.gd       # zegar symulacji, mnożnik czasu, pauza
│   └── game_state.gd      # bieżący scenariusz, punktacja, save/load
├── ui/
│   ├── pulpit_kostkowy/   # widok pulpitu przekaźnikowego
│   ├── nastawnia_mech/    # widok nastawni mechanicznej
│   ├── komputer/          # widok komputerowych urządzeń nastawczych
│   ├── dokumentacja/      # dziennik ruchu, książka przebiegów, rozkazy
│   ├── telefon/           # okno łączności zapowiadawczej
│   └── wspolne/           # zegar, menu, powiadomienia
├── data/
│   ├── stations/*.json
│   ├── scenarios/*.json
│   └── signals/aspekty.json   # tabela obrazów sygnałowych (z 11-sygnalizacja.md)
└── tests/                 # testy GUT rdzenia
```

## Definicja ukończenia (DoD) każdej fazy

- [ ] Kod przechodzi `godot --headless -s addons/gut/gut_cmdln.gd` bez błędów.
- [ ] Brak ostrzeżeń parsera GDScript; pełne typowanie.
- [ ] Nowa logika rdzenia ma testy (min. przypadki poprawne + 2 przypadki brzegowe).
- [ ] Zaktualizowany `WERYFIKACJA.md`, jeśli dotknięto elementów [DO WERYFIKACJI].
- [ ] Krótki wpis w `CHANGELOG.md` (co dodano, jak przetestować ręcznie).

## Priorytet realizmu

Gdy dokumentacja dopuszcza warianty (np. różne typy urządzeń), implementuj wariant
opisany jako podstawowy dla danej fazy w roadmapie. Realizm procedur (kolejność
czynności dyżurnego, liczniki, dokumentacja ruchowa) jest ważniejszy niż efekty
wizualne — to sedno tej gry.
