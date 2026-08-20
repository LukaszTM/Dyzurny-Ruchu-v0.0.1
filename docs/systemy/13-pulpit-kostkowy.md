# 13 — Urządzenia przekaźnikowe: pulpit kostkowy

Podstawowy tryb gry (poziomy 1–2, 4). Wzorowany na polskich urządzeniach
przekaźnikowych (rodzina „typu E") z pulpitem kostkowym — planem świetlnym
składanym z kwadratowych kostek.

## 1. Budowa pulpitu

- **Plan świetlny** — schemat torów stacji z kostek (~40×40 mm), linie torów czarne
  na jasnym (kremowo-szarym) tle pulpitu. W liniach torów **okienka lampek**.
- **Lampki odcinków** (kontrola niezajętości):
  - **czerwona** — odcinek zajęty przez tabor,
  - **biała** — odcinek w utwierdzonym przebiegu (droga nastawiona),
  - **ciemna** — odcinek wolny, nieutwierdzony.
  Kolejność ważności wyświetlania: zajętość (czerwona) nadpisuje białą.
- **Symbol zwrotnicy** — rozgałęzienie linii + numer; kontrola położenia lampkami
  (kierunek „+" / „−"); podczas przestawiania miganie; brak kontroli = miganie
  ciągłe + brzęczyk `[DO WERYFIKACJI: dokładny sposób sygnalizacji braku kontroli]`.
- **Symbole sygnalizatorów** — przy torze; powtarzacz semafora świeci:
  zielono = sygnał zezwalający, czerwono = „Stój", biało-migająco = Sz
  `[DO WERYFIKACJI: kolory powtarzaczy w typie E]`.
- **Przyciski** — wystające z kostek, dwucalowe grzybki/cylindry:
  - **zwrotnicowe** (przy symbolu zwrotnicy) — indywidualne przestawianie,
  - **sygnałowe** (przy symbolu semafora) — podanie/odwołanie sygnału (przebiegu),
  - **specjalne z licznikami, plombowane** — patrz §4.
  Obsługa: **naciśnięcie** = działanie zasadnicze; **pociągnięcie** (przycisk
  wyciągany) = działanie odwrotne/awaryjne `[DO WERYFIKACJI: mapowanie
  naciśnij/pociągnij per typ przycisku — w grze konfigurowalne w JSON `panel`]`.
- **Liczniki** — mechaniczne bębenkowe przy przyciskach specjalnych; każdy użycie
  +1, stan spisywany przy zdaniu dyżuru.
- **Pola dodatkowe pulpitu**: powtarzacze blokady liniowej (patrz `15`), przejazdów
  (patrz `16`), zegar, brzęczyki/dzwonki alarmowe, kontrola zasilania.

## 2. Nastawianie przebiegu pociągowego (wariant podstawowy: indywidualne)

1. Sprawdź na planie wolność drogi (brak czerwonych lampek) i brak kolizji.
2. Przestaw kolejno zwrotnice drogi i ochrony bocznej przyciskami zwrotnicowymi;
   obserwuj kontrolę położenia (podczas ruchu — miganie ~3–6 s).
3. Naciśnij **przycisk sygnałowy** semafora początkowego. Urządzenia sprawdzają
   zależności (warunki z `docs/04 §3`); jeśli OK:
   - odcinki drogi podświetlają się **na biało** (utwierdzenie),
   - semafor podaje sygnał zezwalający (powtarzacz zielony),
   - zwrotnice drogi zostają zamknięte.
   Jeśli nie OK — sygnał się nie wyświetla (brak reakcji); w trybie szkolenia gra
   pokazuje przyczynę.
4. Przejazd pociągu: kolejne odcinki czerwienieją i po zwolnieniu przez skład
   gasną (zwalnianie sekcyjne); semafor po minięciu przez czoło wraca na „Stój".
5. Wariant „nastawianie przebiegowe" (nowsze odmiany): naciśnięcie przycisku
   sygnału początkowego i przycisku końca drogi → zwrotnice układają się same.
   W grze dostępne na stacji poziomu 4 (parametr `panel.route_setting = "przebiegowe"`).

## 3. Przebieg manewrowy

Jak wyżej, ale od tarczy manewrowej (Tm)/semafora do wskazanego końca; sygnał Ms2
(białe); bez drogi ochronnej; możliwy na tor zajęty.

## 4. Przyciski specjalne (plombowane, z licznikami)

| Przycisk (etykieta w grze) | Działanie | Rygor |
|---|---|---|
| **dSz [semafor]** | podanie sygnału zastępczego Sz | licznik + wpis do dokumentacji |
| **dZw [przebieg/zwrotnica]** | doraźne zwolnienie utwierdzenia (gdy pociąg nie pojedzie / usterka) | licznik + czas ewolucji 90 s `[DO WERYFIKACJI]` + wpis |
| **dWbl / awaryjne blokady** | awaryjne czynności blokady liniowej (np. zwolnienie przy niecałkowitym przejeździe) | licznik + telefonogram wymagany |
| **zamknięcie zwrotnicy** | wyłączenie zwrotnicy z nastawiania (utrzymanie/awaria) | odnotowanie |

Zerwanie plomby w grze = kliknięcie z potwierdzeniem („Zrywasz plombę przycisku…")
— moment celowo „ciężki", z wpisem automatycznym do rejestru zdarzeń scoringu.

## 5. Sygnalizacja awarii na pulpicie

- Brak kontroli zwrotnicy: miganie lampek położenia + brzęczyk do skasowania.
- Zajętość „duch" (usterka obwodu): odcinek czerwony bez pociągu → procedura
  sprawdzenia toru, jazdy na Sz/rozkaz.
- Przepalenie żarówki semafora: powtarzacz sygnalizuje; semafor fizycznie ciemny =
  „Stój" (rdzeń degraduje obraz, patrz `docs/04 §6.1`).
- Zanik zasilania: pulpit na zasilaniu awaryjnym (lampki przygaszone — efekt wizualny),
  ograniczenia funkcji wg scenariusza.

## 6. Odwzorowanie w grze — wymagania

- Klik lewym = naciśnięcie, klik prawym / przeciągnięcie w dół = pociągnięcie.
- Dźwięki: klik przekaźników przy nastawianiu (stukot z szafy przekaźnikowej),
  brzęczyk alarmów, dzwonek blokady — pliki własne/CC0.
- Wszystkie mapowania przycisk→akcja per stacja w JSON (`panel.tiles[].actions`),
  bo odmiany urządzeń się różnią — korekta po weryfikacji nie zmienia kodu.
- Wygląd szczegółowy: `assets-spec/20-pulpit-kostkowy-wyglad.md`.
