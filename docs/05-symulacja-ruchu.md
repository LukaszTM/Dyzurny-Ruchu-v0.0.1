# 05 — Symulacja ruchu pociągów i AI

## 1. Model pociągu

Pociąg = punkt materialny z długością (czoło + `len_m`). Stan: pozycja na krawędzi
grafu (edge, offset_m, dir), prędkość v, tryb AI. Parametry z rozkładu jazdy:
`vmax_kmh`, `len_m`, `mass_t`, `power_class` (EZT / lokomotywa el. / spalinowa / towarowy).

Fizyka uproszczona, ale wiarygodna:
- przyspieszenie: EZT 0,7 m/s², osobowy 0,4, towarowy 0,15 (malejące z prędkością: a·(1−v/vmax)),
- hamowanie służbowe: 0,5 m/s² (towarowy 0,3), nagłe: 1,0 m/s²,
- pociąg zajmuje sekcję, gdy czoło na nią wjedzie; zwalnia, gdy koniec ją opuści.

## 2. AI maszynisty

Maszyna stanów + regulator prędkości celowej:
1. Cel prędkości = min(vmax pociągu, vmax toru, ograniczenie z sygnału).
2. Sygnały: maszynista „widzi" tarczę ostrzegawczą/semafor z odległości widoczności
   (parametr, domyślnie 400 m) i wykonuje krzywą hamowania tak, by przed semaforem
   „stój" zatrzymać się ~50 m przed (a przy Sz podjechać i jechać ≤40 przez okręg
   zwrotnicowy `[DO WERYFIKACJI: dokładny reżim prędkości przy Sz wg Ir-1]`).
3. Zatrzymanie planowe: przy peronie w miejscu wskaźnika W4; postój `dep−arr`,
   min. 30 s; odjazd tylko przy sygnale zezwalającym.
4. Reakcje specjalne: rozkaz pisemny otrzymany „przez telefon" (gracz dyktuje) →
   odblokowanie jazdy obok semafora „stój" / jazda z ograniczeniem; sygnał „stój"
   nagle (skasowanie przebiegu przed pociągiem) → hamowanie nagłe + zdarzenie
   niebezpieczne w scoringu.
5. Maszynista melduje się przez radiotelefon przy dłuższym staniu pod semaforem
   (>3 min) — element presji na gracza.

## 3. Rozkład jazdy i generowanie ruchu

- Scenariusz: jawna lista pociągów (patrz `03-model-danych.md §6`).
- Tryb swobodny: generator — interwały per kategoria, losowe opóźnienia wejściowe
  (rozkład wykładniczy, np. 70% punktualnie, ogon do +20 min).
- Pociąg pojawia się na krawędzi wejściowej stacji, gdy sąsiad (AI) go zapowie
  i uzyska pozwolenie/blokadę — czyli wejście do świata jest sprzężone z procedurami.

## 4. AI sąsiednich posterunków

`NeighbourAI` symuluje dyżurnego za szlakiem:
- inicjuje telefonogramy (żądanie drogi, oznajmienie odjazdu) zgodnie z rozkładem,
- odpowiada na telefonogramy gracza w poprawnych formułach (z małym opóźnieniem),
- obsługuje swoją stronę blokady (daje/przyjmuje pozwolenia, kwituje),
- przy telefonicznym zapowiadaniu pilnuje zasad następstwa,
- popełnia błędy tylko jako zaplanowane zdarzenie scenariusza (nigdy losowo).

## 5. Telefon i radiotelefon (interfejs proceduralny)

Rozmowa = wybór formuły z klocków (dropdowny: typ telefonogramu, nr pociągu, godzina),
nie wolne pisanie. Rdzeń ocenia poprawność względem sytuacji (właściwy typ, właściwy
pociąg, kolejność). Błędna formuła → sąsiad prosi o powtórzenie (kara czasowa),
poprawna → skutek w świecie + automatyczny szkic wpisu do dziennika (tryb łatwy).
Wzory formuł: `systemy/18-procedury-ruchowe-ir1.md`.

## 6. Zdarzenia (EventDirector)

Zaplanowane w scenariuszu lub losowane w oknach czasowych. Każde zdarzenie ma:
warunki wstępne, skutek w rdzeniu, oczekiwaną procedurę gracza (do scoringu),
timeout eskalacji. Katalog typów: usterka zwrotnicy, rozprucie (gdy gracz zrobi
manewr po złej drodze — także „naturalne"), awaria ssp, awaria blokady, przerwa
łączności zapowiadawczej (→ radiotelefon/rozkazy), dsat_alarm (GM/GH/PM →
zatrzymanie pociągu, oględziny — patrz `systemy/17-dsat.md`), pasażer-zdarzenie
(kolorytu: zgłoszenie z peronu).

## 7. Scoring (podsumowanie zmiany)

- Bezpieczeństwo: −50 za zdarzenie niebezpieczne (najechanie na „stój" z winy gracza,
  jazda bez pozwolenia, przejazd otwarty pod pociągiem), −10 za procedurę pominiętą.
- Punktualność: −1 pkt za każdą minutę opóźnienia wygenerowanego przez gracza
  (start liczenia: pociąg gotów do jazdy, brak drogi z winy gracza).
- Dokumentacja: −2 za brakujący/błędny wpis (tryb łatwy: auto-wpisy, bez kar).
- Bonusy: obsłużenie awarii wg procedury w czasie < limit.
