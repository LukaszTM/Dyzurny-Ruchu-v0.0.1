# 01 — Podstawy prawne: co wolno wykorzystać i jak

> **Zastrzeżenie:** to analiza robocza na potrzeby projektu, nie porada prawna.
> Przy publikacji komercyjnej warto skonsultować się z prawnikiem od IP.

## 1. Co jest bezpieczne do odwzorowania

### 1.1 Funkcjonowanie systemów srk — TAK
Idee, procedury, metody i zasady działania **nie podlegają ochronie prawnoautorskiej**
(art. 1 ust. 2¹ ustawy o prawie autorskim). Wolno więc w pełni odwzorować:
- logikę zależności (utwierdzanie przebiegów, ochrona boczna, zwalnianie sekcyjne),
- znaczenie i wygląd sygnałów kolejowych,
- procedury ruchowe (zapowiadanie, rozkazy pisemne, prowadzenie dokumentacji),
- zasadę działania blokad liniowych, ssp, dSAT itd.

### 1.2 Sygnalizacja kolejowa — TAK, wprost z prawa
Sygnały i wskaźniki są opisane w **Rozporządzeniu Ministra Infrastruktury z 18 lipca
2005 r. w sprawie ogólnych warunków prowadzenia ruchu kolejowego i sygnalizacji**
(Dz.U. z późn. zm.). Akty normatywne **nie są przedmiotem prawa autorskiego**
(art. 4 pkt 1 pr. aut.) — treść rozporządzenia można wykorzystywać swobodnie,
łącznie z opisami obrazów sygnałowych. To najmocniejsza podstawa całego projektu.

### 1.3 Instrukcje PKP PLK (Ie-1, Ir-1 i inne) — wiedza TAK, kopiowanie ostrożnie
Instrukcje są **publicznie udostępniane** przez PKP PLK na stronie plk-sa.pl
(zakładka Akty prawne i przepisy). Można:
- korzystać z zawartej w nich wiedzy bez ograniczeń (fakty, procedury, tabele znaczeń),
- opisywać ich treść własnymi słowami (jak zrobiono w tej dokumentacji).
Ostrożnie z: kopiowaniem 1:1 dużych fragmentów tekstu, rysunków i wzorów druków do
samej gry. W grze używaj **własnych sformułowań i własnej grafiki** oddających tę samą
treść merytoryczną. Numery druków (R-142, R-305 itd.) i nazwy dokumentów to fakty —
wolno ich używać.

### 1.4 Wygląd fizycznych urządzeń — TAK (własną grafiką)
Pulpit kostkowy, nastawnica mechaniczna, semafor — to urządzenia przemysłowe o
kształcie funkcjonalnym. Narysowanie **własnej grafiki** przedstawiającej takie
urządzenie w grze jest dozwolone (analogicznie jak samochody czy samoloty w grach —
ryzyko dotyczy głównie znaków towarowych i wzorów, patrz niżej; dla kilkudziesięcio-
letnich urządzeń srk ewentualne wzory przemysłowe dawno wygasły).
- NIE wolno: wklejać cudzych zdjęć/skanów jako tekstur bez licencji.
- Zdjęcia jako **materiał referencyjny** do własnego rysunku — tak (własne zdjęcia
  najlepiej; przy cudzych inspiruj się, nie przekalkowuj).

### 1.5 Nazwy i oznaczenia — z rozwagą
- Oznaczenia typów i skróty techniczne („urządzenia typu E", „ssp", „dSAT",
  „blokada typu C/Eap", kategorie przejazdów A–F) — określenia rodzajowe/techniczne, OK.
- **Znaki towarowe producentów** (np. Ebilock — Alstom; ASDEK — nazwa handlowa
  systemu detekcji) — w grze używaj nazw rodzajowych: „komputerowe urządzenia
  nastawcze", „urządzenia detekcji stanów awaryjnych taboru (dSAT)". Wzmianka
  informacyjna w dokumentacji to co innego niż użycie nazwy w produkcie.
- Nazwy geograficzne stacji — dozwolone; bezpieczniej jednak (i ciekawiej dla
  scenariuszy) używać stacji fikcyjnych wzorowanych na realnych układach torowych.
  Same **układy torowe** (schematy) to fakty — można odwzorowywać rzeczywiste.

## 2. Czego NIE wykorzystywać

1. **Materiałów TTSK / Train Driver 2**: kodu, grafik, dźwięków, scenerii, danych,
   dokumentacji ich symulatorów. Gra ma być niezależnym dziełem. Nie używaj też ich
   nazw (TD2, SWDR4, SPK, SCS, SPE, SUP jako nazw produktów) w tytule/marketingu.
2. **Interfejsu oprogramowania firmowego 1:1** — np. rzeczywisty program wspomagania
   dyżurnego czy wizualizacja konkretnego systemu komputerowego producenta to
   utwory (programy komputerowe / GUI). Rób interfejs **inspirowany konwencjami**
   (układ, kolorystyka stanów), nie piksel-w-piksel klon konkretnego produktu.
3. Cudzych zdjęć, skanów instrukcji jako grafik w grze, map i planów z publikacji
   (np. atlasy kolejowe są chronione — układ torów przerysuj do własnego formatu JSON).
4. Fontów bez licencji (używaj SIL OFL, np. Inter, JetBrains Mono, IBM Plex).

## 3. Praktyczne zasady dla tego projektu

- Cała grafika: rysowana kodem Godota (`_draw`), własne SVG lub własne tekstury.
- Wszystkie teksty w grze: własne sformułowania na bazie treści merytorycznej instrukcji.
- Plik `CREDITS.md` w grze: wykaz źródeł wiedzy (rozporządzenie, instrukcje PLK) —
  dobra praktyka i transparentność.
- W opisie gry: informacja, że to niezależna produkcja edukacyjno-rozrywkowa,
  niezwiązana z PKP PLK ani żadnym producentem urządzeń.
- Licencje bibliotek/addonów Godot: tylko MIT/Apache/CC0 (GUT jest MIT — OK).
