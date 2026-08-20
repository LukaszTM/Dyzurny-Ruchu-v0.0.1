# 20 — Wygląd pulpitu kostkowego (specyfikacja graficzna)

Cel: gracz otwierający zdjęcie prawdziwego pulpitu typu E ma rozpoznać grę.
Wszystko rysowane wektorowo w Godot (`_draw`/`Polygon2D`) lub własne SVG.

## 1. Siatka i wymiary

- Kostka = **48×48 px** (bazowo; pulpit skalowany całościowo). Plan stacji mieści
  się w siatce `panel.grid` z JSON.
- Pulpit ma ramę: tło + delikatne fugi między kostkami (linie 1 px, ciemniejsze o 8%).
- Perspektywa: widok prostopadły (bez pochylenia) — czytelność ponad efektowność.

## 2. Paleta (robocza, do strojenia po materiałach referencyjnych)

| Element | Hex | Uwagi |
|---|---|---|
| tło kostek | `#C9C5B9` | kremowo-szary, lekko ciepły |
| fugi kostek | `#B8B4A8` | |
| linia toru | `#1C1C1C` | grubość 6 px, przez środek kostki |
| okienko lampki zgaszonej | `#8E8A80` | wpuszczone, z ciemną obwódką |
| zajętość (czerwień) | `#E0362C` | + poświata (glow) 20% |
| utwierdzenie (biel ciepła) | `#F4EFE2` | |
| powtarzacz sygnału zezw. | `#3FA34D` | zielony |
| powtarzacz „stój" | `#E0362C` | |
| Sz / światło białe | `#F4EFE2` migające 1 Hz | |
| przycisk szary | `#4A4A4A` (korpus), `#2E2E2E` (cień) | |
| przycisk z kołnierzem plomby | kołnierz `#D9B23C` + drucik plomby | |
| licznik | okienko `#111` z cyframi `#EDEDED`, font mono | |
| opisy/numery na kostkach | `#2B2B2B`, font bezszeryfowy 10–12 px | |

## 3. Typy kafelków (`tile` w JSON) — minimum

```
track_h      ──────      track_v  │   track_diag_ne  ╱   track_diag_nw  ╲
track_curve_* (łuki 90°)          track_end (kozioł: linia + poprzeczka)
turnout_ne / turnout_se / ...     (rozgałęzienie: linia główna + odgałęzienie 45°)
crossing     (dwie linie X)       insulation_gap (przerwa izolacyjna: mała poprzeczka)
signal_n/s/e/w  (symbol semafora przy torze: kółko z „chorągiewką" w kierunku jazdy)
tm_signal_*     (tarcza manewrowa: mniejsze kółko)
button          (sam przycisk)    counter_button (przycisk + licznik + plomba)
block_field     (pole blokady liniowej: lampka + etykieta Po/Ko/Poz)
crossing_ctrl   (pole przejazdu: lampki + przycisk)
label           (kostka z napisem: nr toru, kierunek szlaku „→ LIPNO")
```

### Rysunek kafelka toru z lampką
Okienko lampki: zaokrąglony prostokąt 20×8 px wpuszczony w linię toru (oś pozioma).
Odcinek może mieć kilka okienek (po jednym na kostkę) — wszystkie świecą tym samym
stanem sekcji.

### Zwrotnica
Linia zasadnicza ciągła; odgałęzienie w kolorze linii. Obok: numer zwrotnicy
(tabliczka 14×10 px). Kontrola położenia: dwie małe lampki przy rozgałęzieniu —
świeci ta strona, w którą droga zwarta `[DO WERYFIKACJI: w wielu urządzeniach
położenie pokazuje pojedyncza lampka/podświetlenie kierunku — parametr stylu]`;
w czasie przestawiania obie migają.

### Symbol semafora na planie
Kółko 12 px + kreska-podstawa prostopadła do toru; wypełnienie = powtarzacz
(zielone/czerwone/białe migające). Litera semafora obok (A, C1...). Przycisk
sygnałowy w tej samej lub sąsiedniej kostce.

## 4. Przyciski — kształt i stany

- Korpus walcowy widziany z góry: okrąg 22 px z cieniem; wciśnięcie = przesunięcie
  cienia + dźwięk kliknięcia; pociągnięcie = pierścień uniesienia wokół przycisku
  przez 0,3 s.
- Kolory główek wg funkcji `[robocze — DO WERYFIKACJI ze zdjęciami]`: zwrotnicowe
  szare, sygnałowe pociągowe zielone, manewrowe białe, specjalne czerwone pod
  plombą.
- Przycisk plombowany: żółty kołnierz + cienki drut plomby; po zerwaniu plomby
  drut znika do końca zmiany (wizualna konsekwencja!).

## 5. Elementy obrzeża pulpitu

- Pas górny: nazwa posterunku (grawerowana tabliczka), zegar wskazówkowy 24 px
  wysokości renderowany wektorowo, lampka zasilania.
- Pole blokady liniowej per szlak: ramka z etykietą szlaku, lampki: „odstęp zajęty"
  (czerwona), „pozwolenie u nas/u sąsiada" (strzałki), przyciski Po/Ko/Poz.
- Brzęczyk: ikona głośniczka podświetlana przy alarmie (klik = skasowanie).

## 6. Animacje i dźwięk

Miganie 1 Hz (50% duty). Przestawianie zwrotnicy: 3–6 s migania + stukot silnika.
Nastawienie przebiegu: sekwencyjne zapalanie białych okienek wzdłuż drogi
(50 ms/kostka) + trzask przekaźników. Wszystkie dźwięki własne/CC0.

## 7. Dostępność

Tryb wysokiego kontrastu (czerwień→pomarańcz #FF8C1A dla daltonizmu, wzory w
lampkach: zajętość = pełne, utwierdzenie = obrys). Skala UI 100–200%.
