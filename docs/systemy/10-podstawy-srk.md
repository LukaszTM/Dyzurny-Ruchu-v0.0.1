# 10 — Podstawy sterowania ruchem kolejowym (srk) i słownik

Podstawa merytoryczna: Instrukcja Ir-1 (R-1) PKP PLK oraz rozporządzenie MI z 18.07.2005.
Opisano własnymi słowami na potrzeby gry.

## 1. Posterunki ruchu

- **Posterunek następczy** — reguluje następstwo pociągów: pozwala na jazdę, gdy
  przyległy odstęp jest wolny. Rodzaje:
  - **posterunek zapowiadawczy** — może zmieniać kolejność pociągów (ma tory do
    wyprzedzania/krzyżowania): **stacje** i **posterunki odgałęźne**,
  - **posterunek odstępowy** — tylko dzieli szlak na odstępy (przy blokadzie
    półsamoczynnej, obsadzony) albo samoczynny (semafory sbl, bez obsady).
- **Posterunek odgałęźny (podg)** — poza stacją, przy rozgałęzieniu linii.
- **Nastawnia dysponująca** — z niej dyżurny ruchu kieruje pracą; **nastawnie
  wykonawcze** obsługują swoje okręgi na polecenie dyżurnego (u nas: gracz = dyżurny;
  nastawnie wykonawcze symulowane jako AI lub scalone, zależnie od stacji).
- **Okręg nastawczy** — obszar zwrotnic/sygnałów obsługiwany z jednej nastawni.

## 2. Tory i elementy stacji

- **Tory główne zasadnicze** — przedłużenie torów szlakowych; **główne dodatkowe** —
  pozostałe tory do jazd pociągowych; **boczne** — manewrowe, ładunkowe.
- **Szlak** — odcinek między posterunkami zapowiadawczymi; **odstęp** — część szlaku
  między posterunkami następczymi.
- **Ukres** — słupek między zbiegającymi się torami wskazujący granicę, do której
  można zająć tor, by nie zagrażać jazdom po torze sąsiednim.
- **Żeberko ochronne / wykolejnica** — chronią tor główny przed zbiegnięciem taboru
  z torów bocznych (element ochrony bocznej przebiegów).
- **Granica przetaczania** — manewry nie mogą wyjechać poza nią w stronę szlaku
  (wskaźnik W5, praktycznie okolica semafora wjazdowego).

## 3. Droga przebiegu i pojęcia zależnościowe

- **Przebieg** — zorganizowana jazda po określonej drodze: **pociągowy** (na sygnał
  semafora) lub **manewrowy** (na sygnał Ms2/ustne polecenie).
- **Droga przebiegu** — tory i rozjazdy, po których jedzie pojazd; **droga ochronna**
  (overlap) — odcinek za semaforem końcowym wjazdu, wolny na wypadek niewyhamowania.
- **Ochrona boczna** — ustawienie sąsiednich zwrotnic/wykolejnic/sygnałów tak, by nic
  nie mogło wjechać w bok drogi przebiegu.
- **Utwierdzenie przebiegu** — zablokowanie wszystkich elementów drogi w urządzeniach;
  od tej chwili do przejazdu pociągu (lub procedury doraźnego zwolnienia) nic nie
  można zmienić.
- **Zwalnianie sekcyjne** — automatyczne zwalnianie kolejnych odcinków drogi za
  jadącym pociągiem.
- **Kontrola niezajętości** — obwody torowe lub liczniki osi wykrywają obecność
  taboru na odcinku (na pulpicie: czerwona lampka).

## 4. Generacje urządzeń nastawczych (w grze wszystkie trzy)

1. **Mechaniczne** (kluczowe i scentralizowane) — dźwignie + pędnie drutowe,
   zależności w skrzyni mechanicznej, współpraca posterunków przez bloki
   elektromechaniczne. Patrz `12-urzadzenia-mechaniczne.md`.
2. **Przekaźnikowe** — zależności realizują przekaźniki; obsługa z **pulpitu
   kostkowego** (plan świetlny). Patrz `13-pulpit-kostkowy.md`.
3. **Komputerowe** — zależności w komputerze zależnościowym; obsługa z monitorów.
   Patrz `14-urzadzenia-komputerowe.md`.

## 5. Ramowy tok pracy dyżurnego (jedna jazda pociągowa)

1. Zapowiedź: uzgodnienie z sąsiednim posterunkiem (blokada + ew. telefonogramy).
2. Przygotowanie drogi przebiegu: sprawdzenie wolności, przerwanie kolidujących
   manewrów, ułożenie i utwierdzenie drogi, zamknięcie przejazdów obsługiwanych.
3. Podanie sygnału zezwalającego na semaforze.
4. Obserwacja jazdy (sygnał końca pociągu!), obsługa blokady po przejeździe.
5. Telefonogramy potwierdzające + wpisy do dziennika ruchu / książki przebiegów.

## 6. Słowniczek do UI gry (tooltipy)

dyżurny ruchu • nastawniczy • przebieg • utwierdzenie • ochrona boczna • droga
ochronna • okręg zwrotnicowy • semafor wjazdowy/wyjazdowy/drogowskazowy • tarcza
ostrzegawcza • tarcza manewrowa • sygnał zastępczy • blokada stacyjna/liniowa •
odstęp • szlak • posterunek zapowiadawczy • rozprucie zwrotnicy • kontrola
położenia • plomba i licznik • zamknięcie toru • telefonogram zapowiadawczy.
Każde hasło w grze ma definicję 1–2 zdania (napisz na bazie tego pliku).
