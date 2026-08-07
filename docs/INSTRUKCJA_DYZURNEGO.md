# Instrukcja dyżurnego ruchu

## Pulpit

- **Odcinki torowe**: szary — wolny; zielony — ustawiony przebieg pociągowy;
  biały — przebieg manewrowy; czerwony — zajęty przez tabor; pomarańczowy,
  przekreślony — zamknięty (przeszkoda).
- **Semafory** (kółka): czerwone — „Stój"; zielone — sygnał zezwalający;
  białe — jazda manewrowa; białe mrugające — sygnał zastępczy (Sz).
  Przekreślenie — usterka. **Tarcze manewrowe** są kwadratowe (np. M10).
- **Portale** (prostokąty ze strzałką) — kierunki, z których zgłaszają się
  pociągi. Czerwony napis pod portalem = pociąg(i) oczekujące na wjazd.
- **Rozjazdy** z mrugającą pomarańczową obwódką mają usterkę — przebiegi
  przez nie są niemożliwe do czasu jej ustąpienia.

## Prowadzenie ruchu

1. **Przyjęcie pociągu**: kliknij semafor wjazdowy przy portalu (np. `Ad`),
   następnie semafor na końcu wybranego toru (np. `H5` = wjazd na tor 5
   od zachodu). System sam wyznaczy i zablokuje drogę przebiegu.
2. **Wyprawienie pociągu**: gdy pociąg zgłosi gotowość (mrugające „GOTÓW"),
   kliknij semafor wyjazdowy przy jego torze (np. `H5` na wschód, `K5` na
   zachód), a następnie **portal** kierunku jazdy.
3. **Przelot** (np. towarowy): ustaw przebieg od semafora wjazdowego
   bezpośrednio do portalu wyjazdowego — droga poprowadzi przez wolny tor.
4. **Manewry**: włącz **Tryb manewrowy (M)**. Podstawienie z Grochowa:
   tarcza `M10` → semafor `K…` na początku toru docelowego. Odstawienie:
   semafor `H…` przy torze → portal `Grochów`. Zlecenia manewrowe widać
   w zakładce „Ruch".
5. **Usterka semafora**: ustaw przebieg normalnie, wybierz semafor i użyj
   przycisku **„Sygnał zastępczy (Sz)"** — pociąg pojedzie z prędkością
   ograniczoną. Użycie Sz jest odnotowywane w dzienniku.
6. **Zwolnienie przebiegu**: wybierz semafor → „Zwolnij przebieg" (możliwe
   tylko, gdy pociąg nie wjechał w drogę przebiegu; odnotowywane jako
   zwolnienie doraźne).

## Rozkład jazdy i opóźnienia

Zakładka „Rozkład jazdy" pokazuje plan z opóźnieniami (żółte wiersze) oraz
statusami. Przycisk „Aktualizuj online" pobiera świeże opóźnienia i
uzupełnienia rozkładu z sieci. W trybie losowym tabela wypełnia się
pociągami wygenerowanymi.

## Dziennik ruchu

Zakładka „Dziennik" dokumentuje: przebiegi, jazdy pociągów, zdarzenia,
użycia Sz i wpisy własne dyżurnego. „Zapisz do pliku" tworzy plik
`dziennik_RRRRMMDD_<stacja>.txt` w katalogu użytkownika; przy wyjściu z
symulacji dziennik zapisuje się automatycznie (opcja w Ustawieniach).

## Zdarzenia losowe

Zakładka „Zdarzenia": suwak częstotliwości (0 = wyłączone), lista aktywnych
zdarzeń z przyciskiem „Potwierdź przyjęcie". Typy: usterka rozjazdu,
usterka semafora, osoba postronna na torach, zwierzęta na torach, awaria
taboru.

## Wskazówki

- Pociągi podmiejskie przyjmuj zasadniczo na tory 1–2 (jazda na wschód)
  i 3–4 (na zachód); dalekobieżne odpowiednio 5–6 i 7–8.
- Pociąg oznaczony „kończy bieg" po przyjeździe trzeba odstawić manewrowo
  do Grochowa; pociąg „zaczynający bieg" wymaga wcześniejszego podstawienia
  składu — pilnuj zleceń w zakładce „Ruch".
- Odjazd przed czasem rozkładowym jest odnotowywany jako nieprawidłowość.
