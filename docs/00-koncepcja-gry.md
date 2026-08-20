# 00 — Koncepcja gry (GDD)

## Wizja

Samodzielna gra 2D dla jednego gracza: **symulator służby dyżurnego ruchu** na polskiej
kolei. Gracz obsługuje posterunek ruchu — od zapowiedzenia pociągu przez telefon,
przez ułożenie drogi przebiegu na realistycznym urządzeniu srk, po prowadzenie
dokumentacji i reagowanie na awarie. Wszystkie pociągi prowadzi AI; sąsiednie
posterunki obsługuje AI. Gra działa w pełni offline, w jednym programie.

Inspiracją jest realna praca dyżurnego oraz istnienie hobbystycznych symulatorów tego
typu; gra jest jednak budowana **od zera, na podstawie publicznej dokumentacji
realnych systemów** (patrz `01-podstawy-prawne.md`).

## Filary projektu

1. **Wierność urządzeniom** — pulpit kostkowy, nastawnia mechaniczna i ekran
   komputerowy wyglądają i zachowują się jak prawdziwe (stany lampek, liczniki,
   kolejność czynności, blokady zależnościowe).
2. **Wierność procedurom** — telefonogramy zapowiadawcze, dziennik ruchu, książka
   przebiegów, rozkazy pisemne. Sytuacje awaryjne wymuszają procedury zastępcze
   (sygnał zastępczy, telefoniczne zapowiadanie) — to główne źródło emocji w grze.
3. **Dostępność** — wbudowany samouczek i tryb podpowiedzi tłumaczą kolejarski
   żargon; gra ma być grywalna dla osoby spoza branży, a satysfakcjonująca dla fana kolei.

## Pętla rozgrywki (core loop)

1. Dzwoni telefon / blokada zgłasza pociąg od sąsiada → gracz odbiera zapowiedź
   (lub sam żąda drogi dla pociągu do wyprawienia).
2. Gracz sprawdza wolność drogi, układa zwrotnice, nastawia przebieg, podaje sygnał.
3. Pociąg AI wjeżdża, zatrzymuje się (lub przejeżdża), odjeżdża; gracz obsługuje
   blokadę liniową i telefonogramy (oznajmienie odjazdu, potwierdzenie przyjazdu).
4. Gracz prowadzi dokumentację (gra może częściowo automatyzować wpisy w trybie łatwym).
5. Zdarzenia losowe (usterka zwrotnicy, awaria przejazdu, alarm dSAT, opóźnienia)
   przerywają rutynę i wymagają procedur specjalnych.
6. Koniec zmiany → podsumowanie i ocena.

## Tryby gry

- **Szkolenie** — interaktywne lekcje: sygnalizacja → obsługa danego typu urządzeń →
  zapowiadanie → sytuacje awaryjne. Każda lekcja na małym, dedykowanym posterunku.
- **Służba (scenariusz)** — zmiana 1–8 h czasu symulacji (przyspieszanego) na wybranym
  posterunku wg rozkładu jazdy, z zaplanowanymi i losowymi zdarzeniami.
- **Tryb swobodny** — dowolna stacja, generator ruchu, bez oceny.

## Progresja i zawartość

Posterunki odblokowywane od najprostszych do najbardziej złożonych — jednocześnie
przechodzimy przez historię techniki:

| Poziom | Posterunek | Urządzenia |
|---|---|---|
| 1 | Mijanka na linii jednotorowej | przekaźnikowe, pulpit kostkowy, blokada półsamoczynna |
| 2 | Mała stacja z bocznicą | j.w. + manewry, przejazd kat. A |
| 3 | Stacja z nastawnią mechaniczną | urządzenia mechaniczne scentralizowane, blokada elektromechaniczna |
| 4 | Stacja na linii dwutorowej | przekaźnikowe + samoczynna blokada liniowa, ssp, dSAT |
| 5 | Duża stacja / LCS | komputerowe urządzenia nastawcze, zdalne sterowanie kilkoma posterunkami |

## Ocena gracza (po zmianie)

- **Bezpieczeństwo** (waga największa): zdarzenia niebezpieczne = ciężkie kary
  (podanie sygnału na zajęty tor jest niemożliwe przez zależności, ale np. przyjęcie
  pociągu na tor zajęty na sygnał zastępczy bez procedury, niezamknięcie przejazdu
  kat. A, błędna zapowiedź).
- **Punktualność**: suma opóźnień wygenerowanych przez gracza (mierzona względem
  teoretycznego przejazdu).
- **Poprawność procedur**: kompletność dziennika ruchu, prawidłowe telefonogramy,
  rozkazy pisemne wydane gdy wymagane.
- Wynik: 0–100 pkt + odznaki („Zmiana bez opóźnień", „Mistrz procedur" itp.).

## Interfejs gracza (ekrany)

1. **Widok urządzeń** — pełnoekranowy pulpit/nastawnia/monitor (główny ekran gry).
2. **Telefon/radiotelefon** — okno dialogowe z formułami telefonogramów do złożenia
   (wybór elementów formuły, nie wolne pisanie — patrz `18-procedury-ruchowe-ir1.md`).
3. **Dokumentacja** — dziennik ruchu, książka przebiegów, bloczek rozkazów (formularze).
4. **Podgląd sytuacji** — uproszczony pasek: rozkład jazdy najbliższych pociągów,
   zegar, komunikaty. W trybie trudnym rozkład tylko w formie papierowej (osobne okno).
5. Brak widoku „z lotu ptaka" na tory w trybie służby — gracz widzi tylko to, co
   widzi dyżurny (lampki kontrolne!). W trybie szkolenia dostępny podgląd torów.

## Zakres wersji 1.0 (cel)

- 5 posterunków (po jednym na poziom), 3 typy urządzeń nastawczych,
  blokady: półsamoczynna, samoczynna, elektromechaniczna.
- Pełna sygnalizacja świetlna wg Ie-1 + semafory kształtowe na poziomie 3.
- Telefonogramy, dziennik ruchu, rozkazy „O"/„S"/„N".
- Zdarzenia: usterka zwrotnicy (brak kontroli), rozprucie, awaria ssp,
  alarm dSAT (GM/GH/PM), przerwa w łączności, opóźnienia.
- Samouczek, 15+ scenariuszy, tryb swobodny, zapisy gry, polski (UI gotowe do i18n).

## Poza zakresem 1.0 (świadomie)

Tryb maszynisty i widok 3D, multiplayer, edytor stacji z GUI (stacje dodaje się
plikami JSON — dokumentacja formatu wystarczy moderom), dźwięki licencjonowane.
