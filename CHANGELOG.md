# CHANGELOG

## GUI v1.4 — ciemna skórka widoku komputerowego (2026-08-23)

### Dodano

- `ui/komputer/komputer_plan.gd` — ciemny plan synoptyczny w konwencji
  barw CBI (docs/systemy/14 §2): tor wolny szary, droga przebiegu
  zielona, odcinek zajęty czerwony, zwrotnica bez kontroli miga,
  semafor czerwony/zielony, Sz biały migający; symbole semaforów
  z masztami, moduły (blokady/przejazd/ssp/dSAT/liczniki) jako ciemne
  kasety z lampkami i przyciskami (te same akcje co na pulpicie).
- Klik w semafor na planie filtruje listę przebiegów od tego semafora
  (docs/14 §3 „klik semafora początkowego"); ponowny klik = wszystkie.
- Kafelki semaforów w Brzezinach/Lipinach dziedziczą sekcję toru —
  kolor linii biegnie bez przerw pod symbolami semaforów.
- KomputerView: ciemne tło całego widoku; plan zastępuje osadzony
  wcześniej renderer pulpitu kostkowego.

### Jak przetestować ręcznie

„Wieczór w Lipinach": nastawić A→t3 — droga zapala się na zielono
przez rozjazd i łuki; zająć odcinek (debug F12) — czerwień z ciągłością
pod semaforami; kliknąć semafor na planie — lista przebiegów się
filtruje; Sz po potwierdzeniu miga na biało na symbolu semafora.

## GUI v1.2 — proceduralny tileset torowy (2026-08-23)

### Zmieniono

- `tools/gen_pulpit_tiles.py` — generator kafelków torowych: geometria
  liczona (oś toru w 50% kostki, ukosy 45° narożnik–narożnik, łuki
  Béziera styczne do sąsiadów), metaliczne szyny z rozbłyskiem, blacha
  z szumem, fazą i śrubami. Zastępuje kafelki torowe generowane przez
  AI (nie trzymały geometrii); lampki, kogut i licznik nadal z paczek
  graficznych użytkownika. Nowy kafelek = jedna funkcja w generatorze.
- Kostki torowe łączą się co do piksela: rozjazd → ukos → łuk → tor.
- Loader: kafelek torowy z pustą sekcją jest legalny (kostka ozdobna,
  tor biegnie poza plan — bez lampki).
- Brzeziny/Lipiny: tor 2 dociągnięty do lewej krawędzi planu (etykieta
  + kostki ozdobne), zgłoszone jako urwany tor.

## GUI v1.1 — poprawiona plansza torowa (2026-08-23)

### Zmieniono

- Nowe tekstury z poprawionej planszy użytkownika: łuki `curve_se/sw`
  (narożnik → środek krawędzi, geometria domyka się z sąsiadami),
  kostki rozjazdowe `turnout_ne/nw` (tor poziomy + odgałęzienie 45°
  z iglicami — zastępują wektorowe odgałęzienie), nowa przerwa
  izolacyjna. Zapas na przyszłość: `track_v` (tor pionowy),
  `crossing_diag` (skrzyżowanie).
- Cała droga zwrotnicowa (rozjazd → ukos → łuk → tor) jest teraz
  fotorealistyczna; fallback wektorowy pozostaje przy braku plików.

## GUI v1 — skórka fotorealistyczna pulpitu (2026-08-22)

### Dodano

- `assets/pulpit/*.png` — pierwsza partia grafik GUI od użytkownika
  (przetworzone: wygaszone wypalone podświetlenia torów, docięte
  i przeskalowane; stany pokazują wyłącznie dynamiczne lampki rdzenia).
- Kafelki pulpitu rysują teksturę kostki jako podkład, a na wierzchu
  tylko elementy dynamiczne: kapsuły zajętości/utwierdzenia, powtarzacze,
  przyciski, opisy. Brak pliku tekstury = dotychczasowe rysowanie
  wektorowe (pełny fallback, `PulpitTile.skin_texture`).
- Zastosowane tekstury: kostka pusta (tło całej siatki), tor poziomy
  (też pod semaforami i zwrotnicami), ukosy NE/NW, przerwa izolacyjna,
  płyta szeroka (pola blokad / przejazd / ssp / dSAT), lampki stanu
  (czerwona/zielona/biała/pomarańczowa/ciemna), kogut alarmu dSAT,
  licznik bębenkowy przycisków dSz/dZw.
- Łuki i odgałęzienia zwrotnic pozostały wektorowe — geometria musi
  domykać się z sąsiednimi kafelkami (do podmiany, gdy powstaną grafiki
  o zgodnej geometrii ćwiartek).
- Widok komputerowy (Lipiny) dziedziczy skórkę planu automatycznie.

### Jak przetestować ręcznie

Uruchomić „Szczyt w Brzezinach": plan stacji na kostkach PNG, zajętość
= czerwone kapsuły z poświatą, przebieg = białe, moduły po prawej na
płytach z lampkami-kloszami, liczniki dSz z bębenkiem. Alarm dSAT
(07:14) miga pomarańczowym kogutem.

## Faza 10 (mechaniki) — Pełny save/load i tryb swobodny (2026-08-22)

### Dodano

- Pełny save/load: serializacja pociągów w drodze (ścieżka, punkty
  sygnałowe, rozkazy, radiostop), metadanych proceduralnych, spraw dSAT,
  łączności (telefonogramy), dziennika ruchu, stanu AI sąsiadów,
  rozkładu (z wpisami generowanymi w locie) i RNG (jako tekst — uint64).
  Determinizm: po wczytaniu symulacja biegnie identycznie jak oryginał.
- `GameState.save_game/load_game` — zapis do `user://saves/<scenariusz>.json`;
  w grze klawisze F5 (zapis) / F9 (wczytanie).
- `core/traffic_gen.gd` — generator ruchu trybu swobodnego: dokłada
  pociągi do rozkładu w locie (relacje/rodzaje/odstępy z sekcji
  `generator` scenariusza, losowanie wyłącznie z RNG świata); nowy wpis
  przechodzi normalny obieg zapowiadania u AI sąsiada; zdarzenie
  `timetable_add` dla GUI.
- Scenariusz `brzeziny-swobodny` — służba bez limitu czasu
  (duration_min 0) z generatorem.
- Testy: 7 nowych (round-trip snapshotu przez JSON, determinizm po
  wczytaniu, zapis/odczyt z dysku, zgodność wstecz snapshotów,
  generator: dokładanie/determinizm/wyłączony). Razem 135.

### Test ręczny

Scenariusz „Tryb swobodny — Brzeziny": poczekać na telefonogram
o pierwszym wygenerowanym pociągu (komunikat „Rozkład: …"), przestawić
i obsłużyć; F5 w dowolnym momencie, pojeździć dalej, F9 — stan wraca
(pociągi w tych samych miejscach, te same przebiegi).

## Faza 9 — Komputerowe urządzenia nastawcze (2026-08-22)

### Dodano

- Nastawianie przebiegowe (docs/systemy/14 §3/§5): polecenie `route_set
  {id}` — konflikty sprawdzane od razu, niezgodne zwrotnice przestawiają
  się same, przebieg utwierdza się po dojściu zwrotnic do kontroli
  (limit 45 s); niepowodzenie po ułożeniu drogi zgłaszane zdarzeniem
  `route_set_failed`.
- Polecenia dwustopniowe (docs/14 §3): na stacji z panelem `komputer`
  polecenia specjalne (Sz, dZw, zamknięcie zwrotnicy, RADIOSTOP,
  otwarcie przejazdu, Poz blokady) odkładają się do potwierdzenia —
  `command_confirm` wykonuje, `command_cancel` rezygnuje, 30 s na
  decyzję (zdarzenia `confirm_required`/`confirm_expired`).
- `core/event_register.gd` — rejestr zdarzeń (docs/14 §4): każde
  polecenie dyżurnego (wykonano/odmowa z przyczyną) i każde zdarzenie
  rdzenia jako `hh:mm:ss | źródło | treść`; prowadzony na każdej
  stacji, w snapshotcie save.
- `data/stations/lipiny.json` — stacja poziomu 5 „Lipiny"
  (Kalina–Rogów, układ dwutorowy z sbl, urządzenia komputerowe);
  scenariusz `lipiny-wieczor` (60 min, 4 pociągi, usterka zwrotnicy
  18:30).
- `ui/komputer/komputer_view.gd` — REFERENCYJNY widok komputerowy:
  plan synoptyczny (współdzielony renderer pulpitu), okno „Wykonać?
  [Tak/Nie]", lista przebiegów (nastawianie przebiegowe), aktywne
  przebiegi z cofaniem, rejestr zdarzeń na żywo. Docelowe GUI buduje
  użytkownik na tym samym API.
- Testy: 11 nowych (route_set natychmiast/po przestawieniu/konflikt/
  niepowodzenie zdarzeniem, potwierdzenie/anulowanie/wygaśnięcie,
  pulpit bez trybu potwierdzeń, rejestr + przycinanie). Razem 128.

### Odłożone

- LCS-lite (zdalne sterowanie 2 posterunkami) — wymaga wielu stacji
  w SimWorld; zapisane w WERYFIKACJA.md (poz. 25), do iteracji po
  zbudowaniu docelowego GUI.

### Test ręczny

Scenariusz „Wieczór w Lipinach": nastawić A→t1 jednym kliknięciem
z listy PRZEBIEGI (zwrotnice ułożą się same), potem spróbować Sz —
pojawi się okno POLECENIE SPECJALNE (Tak/Nie). Obserwować REJESTR
ZDARZEŃ. O 18:30 usterka z1 — przebiegi przez z1 odmawiają.

## Faza 8 — Linia dwutorowa, sbl, przejazdy, dSAT (2026-08-22)

### Dodano

- Blokada samoczynna (docs/systemy/15 §2): typy `samoczynna_3staw`
  i `samoczynna_4staw` w `core/block_line.gd` — odstępy z sekcji,
  semafory odstępowe sterowane wyłącznie zajętością (3-staw S1←S5←S2,
  4-staw + S3), zajętość bloku = pierwszy odstęp, pola Po/Ko nieczynne
  („blokada samoczynna"), wyprawianie za pociągiem (warunek: wolny
  pierwszy odstęp), semafor wyjazdowy dobiera obraz wg pierwszego
  odstępowego. Awaria sbl = odstępowe na „stój".
- `core/level_crossing.gd` — przejazdy: kat. A obsługiwany poleceniami
  `crossing_close`/`crossing_open` (czas ruchu rogatek), ssp samoczynne
  od najazdu na odcinki oddziaływania; awaria (zdarzenie
  `crossing_failure`) → jazda 20 km/h przez rejon przejazdu; przejazd
  kat. A w drodze przebiegu musi być zamknięty (warunek 7 utwierdzenia,
  docs/04 §3.7).
- `core/dsat.gd` — dSAT (docs/systemy/17): raport przy przejeździe
  („bez usterek" / alarm GM–GH–PM z osią), alarm uzbrajany zdarzeniem
  scenariusza `dsat_alarm`. Procedura w rdzeniu: kwit (`dsat_ack`),
  zatrzymanie pociągu ≤180 s (inaczej kara −50), oględziny 300 s,
  wynik → rozkaz ograniczenia 40 km/h przy potwierdzeniu usterki.
- RADIOSTOP: polecenia `radio_stop`/`radio_release` (hamowanie nagłe,
  zwolnienie wznawia jazdę).
- `data/stations/brzeziny.json` — stacja poziomu 4 „Brzeziny"
  (Sosnów–Dęby, linia dwutorowa, sbl 3-stawna w obu kierunkach, tor 3
  wyprzedzania, przejazd kat. A na torze 2, ssp na szlaku zachodnim,
  dSAT na wjeździe); scenariusz `brzeziny-szczyt` (60 min, 5 pociągów,
  alarm dSAT 07:14, awaria ssp 07:28).
- Kafelki pulpitu: `crossing_ctrl` (lampka stanu + Zamk/Otw),
  `ssp_ctrl` (sprawna/załączona/awaria), `dsat_ctrl` (lampka alarmu
  migająca do skwitowania + przycisk KWIT).
- Testy: 9 nowych (aspekty odstępowe, wyprawianie za pociągiem, pola
  ręczne nieczynne, przejazd warunkiem przebiegu, ssp od najazdu,
  awaria ssp 20 km/h, procedura dSAT pełna i zaniedbana, radiostop).
  Razem 117.

### Naprawiono

- Kolejność ticku: blokady samoczynne liczą się PRZED interlockingiem,
  żeby semafor wyjazdowy widział świeży obraz odstępowego (bez opóźnienia
  o tick).
- Odmowa wyjazdu na zajęty szlak sbl niesie przyczynę blokową
  („pierwszy odstęp zajęty"), nie surową zajętość sekcji.

### Test ręczny

Scenariusz „Szczyt w Brzezinach": przed 07:05 zamknąć przejazd
(ZAMYKANIE → Zamk), nastawić A→tor 1 i wyjazd C1; obserwować kolumnę
pociągów na wschód (semafory odstępowe O1/O2 na planie). O 07:14 alarm
dSAT: KWIT, pociąg zatrzymać (nie podawać C1), po oględzinach rozkaz.
O 07:28 awaria ssp — pociągi zwalniają do 20 km/h na szlaku zachodnim.

## Faza 7 — Nastawnia mechaniczna (2026-08-22)

### Dodano

- `core/lever_frame.gd` — ława dźwigniowa ze skrzynią zależności
  (docs/systemy/12 §1–§3): dźwignie zwrotnicowe/ryglowe/sygnałowe,
  wymuszona kolejność zwrotnice → rygiel → nakaz → sygnałowa (i odwrotna
  przy cofaniu), bloki stacyjne „Nakaz wjazd/wyjazd" + „Zwol. przeb."
  (nastawnia wykonawcza w tle), odmowy z przyczyną („dźwignia nie
  puszcza"). Warunki bezpieczeństwa sprawdza ten sam Interlocking.
- Semafory kształtowe Sr1/Sr2/Sr3 (systemy/11 §7) w aspekty.json
  i rdzeniu: Sr2 na wprost, Sr3 w bok, stan zasadniczy Sr1;
  `shows_stop` zna Sr1.
- `data/stations/jodlow.json` — stacja poziomu 3 „Jodłów" (Cisów–Grabno):
  semafory kształtowe, blokada elektromechaniczna (funkcjonalnie jak
  półsamoczynna — systemy/15 §3), panel `mechaniczny` z 9 dźwigniami
  i 3 blokami stacyjnymi; scenariusz `jodlow-poludnie` (60 min,
  krzyżowanie + towarowy, pęknięcie pędni z1 o 12:25).
- `ui/nastawnia_mech/mech_view.gd` — widok wg assets-spec/22: panorama
  torów z okna (sylwetki pociągów z numerami, semafory kształtowe
  z animowanymi ramionami — kontroli zajętości BRAK, wolność toru
  sprawdza się wzrokiem), aparat blokowy (okienka biało-czerwone
  w mosiężnych ramkach, klawisze z induktorem — 2 s kręcenia korbką
  z paskiem postępu), ława dźwigni (kolory wg funkcji, tabliczki,
  przełożenie ~40°, miganie przy braku kontroli).
- Ekran wyboru służby na starcie (lista scenariuszy z data/scenarios —
  dane, nie kod); scena Main tworzy widok wg typu panelu stacji.
- Walidacja panelu mechanicznego w loaderze (dźwignie/bloki → istniejące
  obiekty).
- Testy: 10 nowych (pełna macierz kolejności dźwigni, blokada
  elektromechaniczna, Sr2/Sr3, pełny przejazd przez stację mechaniczną).
  Razem 108.

### Naprawiono

- Rdzeń pociągu: przy większym kroku ruchu czoło mogło przeskoczyć okno
  zaliczenia minięcia semafora — semafor wracający samoczynnie na „stój"
  zatrzymywał wtedy pociąg tuż ZA masztem na stałe. Minięcie liczy się
  teraz od przekroczenia słupka, niezależnie od obrazu.

### Jak przetestować ręcznie

1. Start → ekran wyboru służby → „Południe w Jodłowie".
2. Widok nastawni: panorama z oknem, aparat blokowy, ława 9 dźwigni.
   Spróbuj od razu przełożyć dźwignię A — odmowa „najpierw przełóż
   rygiel"; rygiel 3 przy przestawiającej się zwrotnicy też odmawia.
3. Ok. 12:06 dzwoni Cisów: daj pozwolenie (formuła + klawisz Poz
   z induktorem — 2 s kręcenia), przełóż rygiel 3, daj „Nakaz wjazd"
   i przełóż dźwignię A — ramię semafora podnosi się (Sr2), pociąg
   52101 wjeżdża na panoramie i staje przy peronie.
4. Ko Cisów + telefonogram; cofnij dźwignię A, „Nakaz wyjazd",
   dźwignia C1 — pociąg odjeżdża do Grabna. Krzyżowanie z 52302
   (tor 2: przestaw dźwignie 1 i 2, rygiel, B → Sr3).
5. O 12:25 pęka pędnia z1 (dźwignia miga czerwono) — naprawa po 8 min;
   w międzyczasie towarowy 641220 czeka albo jedzie na Sz/rozkaz.

## Faza 6 — Zdarzenia i procedury awaryjne (2026-08-22)

### Dodano

- `core/event_director.gd` — reżyser zdarzeń scenariusza (docs/05 §6):
  zdarzenia planowe („at") i losowane w oknach (window + p, rzut z RNG
  scenariusza — determinizm), naprawy po `repair_min`.
- Skutki zdarzeń w rdzeniu: `turnout_no_control` (utrata kontroli,
  przebiegi przez zwrotnicę niemożliwe, alarm; naprawa przywraca kontrolę
  w bieżącym położeniu iglic), `block_failure` (pola blokady nieczynne,
  semafory wyjazdowe zablokowane — przejście na telefoniczne
  zapowiadanie wg systemy/18 §6; AI sąsiada żąda i daje drogę wyłącznie
  formułami, „danie pozwolenia" od gracza działa jak pozwolenie).
- Rozkazy pisemne „S"/„O"/„N" (systemy/18 §5): bloczek rozkazów (R),
  dyktowanie przez radiotelefon 20 s, numeracja automatyczna, kopia
  w uwagach dziennika. „S" pozwala minąć wskazany semafor na „stój"
  (reżim jak przy Sz), „O" ogranicza prędkość pociągu do 20 km/h,
  „N" ewidencyjnie (tor lewy — od stacji poziomu 4).
- Proceduralna ocena jazd na Sz/rozkaz: wpis „jazda na Sz/rozkaz" do
  dziennika; −50 (zdarzenie niebezpieczne) za skierowanie pociągu na
  zajęty tor; −10 za wyprawienie przy awarii blokady bez telefonicznego
  zapowiadania.
- Alarmy zdarzeń w pasku górnym; scenariusz `borki-poranek` odpala teraz
  swoje zdarzenia (usterka z2 o 06:20 z naprawą po 25 min, losowa awaria
  blokady E po 06:50 z p=0,4).
- Testy: 11 nowych (reżyser: planowe/losowe/naprawy/brzegowe; usterka
  zwrotnicy z naprawą; awaria blokady — pola nieczynne i odmowa wyjazdu;
  wyjazd na Sz z zapowiedzią bez kary i bez zapowiedzi z karą; rozkaz „S"
  z zatrzymaniem na czas dyktowania; rozkaz „O"; Sz na zajęty tor).
  Razem 98.

### Jak przetestować ręcznie

1. Graj scenariusz do 06:20 — alarm „USTERKA: zwrotnica z2"; lampki
   położenia z2 migają czerwono, nastawienie wyjazdu C1/C2 odmawiane.
   Po 25 min kontrola wraca.
2. Po 06:50 może paść blokada E (alarm) — pola Po/Ko/Poz nieczynne,
   semafor wyjazdowy się nie poda. Zażądaj drogi telefonicznie
   (Suchowola odpowie „Droga wolna"), podaj Sz (dSz C1, licznik rośnie)
   — pociąg wyjedzie; bez telefonogramu dostaniesz −10.
3. Rozkazy (R): wybierz druk „S", pociąg i semafor, „Podyktuj" — przez
   ~20 s status „dyktowanie…", potem AKTYWNY; pociąg stojący przed tym
   semaforem rusza i mija go z prędkością ≤40 km/h. Druk „O" zwalnia
   pociąg do 20 km/h. Wszystko ląduje w uwagach dziennika.
4. Podaj Sz na tor zajęty (F12 → zajmij it1, dSz A, przyjmij pociąg) —
   kara −50 „ZDARZENIE NIEBEZPIECZNE" w pasku i podsumowaniu.

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
