# 06 — Roadmapa (fazy dla Claude Code)

Każda faza = osobne zlecenie. Nie zaczynaj następnej bez akceptacji użytkownika.

## F0 — Szkielet projektu
Projekt Godot 4, struktura katalogów wg CLAUDE.md, autoloady (EventBus, SimClock,
GameState), addon GUT + 1 test przykładowy, scena Main z zegarem symulacji i
mnożnikiem czasu, CHANGELOG.md, WERYFIKACJA.md.
**Test ręczny:** projekt się uruchamia, zegar chodzi, ×1/×2/×5/pauza działają.

## F1 — Graf torowy i loader
`TrackGraph`, `Section`, `Turnout`, `SignalDevice` (na razie tylko stany), loader
JSON z walidacją, wczytanie `data/stations/borki.json` (przenieś z `data/stacja-przyklad.json`).
Testy: walidacja, przestawianie zwrotnicy, zajętość sekcji ustawiana ręcznie.

## F2 — Pulpit kostkowy (widok, bez zależności)
Rysowanie pulpitu z sekcji `panel` wg `assets-spec/20`. Lampki odzwierciedlają stan
rdzenia (zajętości, położenia zwrotnic). Klik przycisku zwrotnicowego przestawia
zwrotnicę (jeszcze bez pełnych warunków). Tryb „debug": panel boczny stanu rdzenia.
**Test ręczny:** pulpit wygląda wg specyfikacji, zwrotnice klikalne, lampki żyją.

## F3 — Interlocking + sygnalizacja
Pełny `Interlocking` i `Route` wg `docs/04` + tabela obrazów z `data/signals/aspekty.json`
(wygeneruj z `systemy/11-sygnalizacja.md`). Nastawianie: indywidualne zwrotnice +
przycisk sygnałowy. Kasowanie, doraźne zwolnienie z licznikiem, Sz z licznikiem,
zamknięcia indywidualne. Komplet testów z `04 §9`.
**Test ręczny:** nastawienie wjazdu i wyjazdu, próby błędne odrzucane, liczniki rosną.

## F4 — Pociągi
`Train` + AI maszynisty, timetable, spawn/despawn, zajmowanie sekcji, zwalnianie
sekcyjne przebiegów przez prawdziwy pociąg, powrót semaforów na „stój", rozprucie.
**Test ręczny:** pociąg przejeżdża przez stację wg nastawionej drogi; zatrzymuje się
przed „stój".

## F5 — Blokada półsamoczynna + telefonogramy + dziennik
`BlockLine` (półsamoczynna) wg `systemy/15`, NeighbourAI, okno telefonu z formułami
wg `systemy/18`, dziennik ruchu (formularz + auto-tryb), pierwszy grywalny scenariusz
(zmiana 60 min na Borkach). Scoring v1.
**Test ręczny:** pełna pętla: zapowiedź → droga → jazda → potwierdzenie → wpisy.

## F6 — Zdarzenia i procedury awaryjne
EventDirector, katalog zdarzeń z `docs/05 §6`, rozkazy pisemne (formularz „S"/„O"/„N"),
telefoniczne zapowiadanie przy awarii blokady, obsługa Sz proceduralnie oceniana.

## F7 — Nastawnia mechaniczna
Widok wg `assets-spec/22` + tryb obsługi „mechaniczny" (kolejność dźwigni wymuszana,
bloki elektromechaniczne wg `systemy/12` i `15`). Stacja poziomu 3.

## F8 — Samoczynna blokada, ssp, dSAT
Linia dwutorowa, sbl 3/4-stawna, przejazdy ssp + kat. A, moduł dSAT z komunikatami.
Stacja poziomu 4.

## F9 — Komputerowe urządzenia nastawcze
Widok wg `assets-spec/21`, polecenia dwustopniowe, rejestr zdarzeń, zdalne sterowanie
2 posterunkami (LCS-lite). Stacja poziomu 5.

## F10 — Szlif wydawniczy
Samouczek (5 lekcji), 15 scenariuszy, tryb swobodny, save/load pełny, ustawienia,
menu, dźwięki (własne/CC0: dzwonek telefonu, buczek, przekaźniki), eksport
Windows/Linux, i18n-ready.

## Zasada ogólna
Jeśli w trakcie fazy odkryjesz brak w dokumentacji — dopisz propozycję do
`WERYFIKACJA.md` i zapytaj użytkownika, zamiast improwizować.
