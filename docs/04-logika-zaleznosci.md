# 04 — Logika zależności (interlocking) — specyfikacja rdzenia

Najważniejszy dokument implementacyjny. Odwzorowuje zasady wspólne dla polskich
urządzeń srk; różnice między typami urządzeń (mechaniczne/przekaźnikowe/komputerowe)
dotyczą tylko sposobu obsługi, nie zasad bezpieczeństwa.

## 1. Cel zależności

Urządzenia srk uniemożliwiają: podanie sygnału zezwalającego na drogę nieprzygotowaną
lub zajętą, przestawienie zwrotnicy pod pociągiem lub w utwierdzonym przebiegu,
nastawienie dwóch przebiegów sprzecznych, wyprawienie dwóch pociągów na ten sam
odstęp. Gracz nie może „zepsuć" bezpieczeństwa normalną obsługą — dopiero procedury
awaryjne (sygnał zastępczy, doraźne zwolnienie) przenoszą odpowiedzialność na niego.

## 2. Stany obiektów

### Zwrotnica (`Turnout`)
`PLUS` / `MINUS` / `MOVING(t)` / `NO_CONTROL` / `TRAILED` (rozpruta).
Przestawić można tylko gdy: sekcja zwrotnicowa wolna AND zwrotnica nieutwierdzona
w żadnym przebiegu AND niezamknięta indywidualnie AND sprawna.
Rozprucie: pojazd najeżdża „na ostrze" zwrotnicy ustawionej w złym kierunku →
`TRAILED`, alarm, zwrotnica wymaga procedury (oględziny = zdarzenie czasowe +
wpis do dokumentacji) zanim wróci do ruchu.

### Odcinek izolowany (`Section`)
`FREE` / `OCCUPIED` (fizycznie zajęty przez oś) / dodatkowa flaga `locked_by: route_id`.

### Przebieg (`Route`) — maszyna stanów
```
IDLE → SELECTED → SETTING → LOCKED → (TRAIN_ON) → RELEASING → IDLE
                     │                                ▲
                     └──── CANCELLED ────────────────┘ (procedura, ew. licznik)
```
- **SELECTED**: gracz wskazał przebieg (przycisk/polecenie); trwa walidacja.
- **SETTING**: zwrotnice przestawiają się do wymaganych położeń (w urządzeniach z
  nastawianiem przebiegowym); w nastawianiu indywidualnym gracz układa je sam wcześniej.
- **LOCKED (utwierdzony)**: wszystkie warunki spełnione → zwrotnice przebiegu i
  ochrony bocznej zamknięte, sekcje `locked`, semafor może podać sygnał zezwalający.
- **TRAIN_ON**: pierwsza sekcja przebiegu zajęta → semafor automatycznie na „stój"
  po minięciu czoła (patrz §6.4).
- **RELEASING**: zwalnianie sekcyjne — każda sekcja zwalnia się (odblokowuje
  zwrotnice w niej leżące), gdy: została zajęta i następnie zwolniona przez pociąg
  ORAZ sekcja poprzednia już zwolniona. Po ostatniej sekcji + zwolnieniu drogi
  ochronnej (timer `overlap.release_s` lub zajęcie toru docelowego) → IDLE.
- **CANCELLED**: skasowanie przebiegu przed jazdą — dozwolone; jeśli sekcja
  zbliżania zajęta (pociąg już jedzie na semafor), kasowanie tylko procedurą
  doraźnego zwolnienia: semafor na „stój" → odliczanie **czasu ewolucji 90 s**
  `[DO WERYFIKACJI: wartość zależna od typu urządzeń, przyjęto 90 s]` → zwolnienie
  + inkrementacja licznika + obowiązkowy wpis do dokumentacji (gra to punktuje).

## 3. Warunki utwierdzenia przebiegu (checklista rdzenia)

Przebieg R może przejść do LOCKED gdy WSZYSTKIE:
1. każda sekcja z `R.sections` jest FREE i nie-`locked`,
2. każda zwrotnica z `R.turnouts` jest w wymaganym położeniu, z kontrolą, niezamknięta,
3. warunki ochrony bocznej `R.flank` spełnione (zwrotnice ochronne w położeniu
   ochronnym i zamknięte, sygnalizatory osłaniające na „stój"),
4. żaden przebieg z `R.conflicts` nie jest w stanie ≥ SETTING,
5. droga ochronna (`overlap`) wolna i możliwa do zamknięcia (dla przebiegów wjazdowych),
6. dla przebiegu wyjazdowego: blokada liniowa pozwala (kierunek/pozwolenie — patrz
   `15-blokada-liniowa.md`) i odstęp wolny,
7. przejazdy kat. A w drodze przebiegu zamknięte (rogatki), a ssp sprawne
   `[wariant konfigurowalny per stacja: uzależnienie przejazdu w przebiegu]`.

## 4. Zamknięcia indywidualne

Gracz może zamknąć zwrotnicę w wybranym położeniu (przycisk/polecenie „zamknięcie") —
np. na czas awarii lub dla ochrony miejsca robót. Zamknięta zwrotnica nie bierze
udziału w nastawianiu przebiegowym (przebieg wymagający innego położenia → odmowa).

## 5. Sygnał zastępczy (Sz) i jazdy w warunkach awaryjnych

- Podanie Sz: osobny przycisk/polecenie per semafor, **z licznikiem** i (na pulpicie)
  plombą. Warunek minimalny: semafor wskazuje „stój". Zależności NIE sprawdzają drogi —
  gra wymaga od gracza ręcznego sprawdzenia (checklista w UI trybu szkolenia) i
  odnotowania; błędna jazda na Sz = potencjalne zdarzenie niebezpieczne (scoring).
- Sz świeci przez ustalony czas (np. 90 s) lub do zajęcia pierwszej sekcji
  `[DO WERYFIKACJI: zachowanie zależne od typu urządzeń]`.
- Alternatywa dla Sz: rozkaz pisemny „S" doręczony/podyktowany drużynie (patrz
  `18-procedury-ruchowe-ir1.md`) — wolniejsze, ale zawsze dostępne.

## 6. Wybór obrazu sygnałowego (algorytm)

Semafor pokazuje S1 („stój"), chyba że jest LOCKED przebieg pociągowy zaczynający
się od niego. Wtedy obraz = f(v_route, next_info):

- `v_route` — prędkość drogą przebiegu za semaforem: `MAX` | `100` | `60` | `40`
  (z `route.v_route_kmh`; wynika z geometrii rozjazdów w drodze).
- `next_info` — co pokazuje następny semafor w drodze jazdy:
  `STOP` | `V40_60` | `V100` | `VMAX` (mapowanie z obrazu następnika: S1→STOP;
  S10–S13a→V40_60; S6–S9→V100; S2–S5→VMAX; brak następnika w danych → traktuj
  ostrożnie jako STOP, chyba że semafor wyjazdowy na szlak z blokadą samoczynną —
  wtedy wg stanu pierwszego odstępu).

Tabela (patrz też `systemy/11-sygnalizacja.md`):

| v_route \ next | VMAX | V100 | V40_60 | STOP |
|---|---|---|---|---|
| MAX | S2 | S3 | S4 | S5 |
| 100 | S6 | S7 | S8 | S9 |
| 40  | S13 | S12 | S11 | S10 |
| 60  | S13a | S12a | S11a | S10a |

6.1 Semafor musi konstrukcyjnie umieć wyświetlić obraz (liczba komór, paski) —
inaczej wybierz najbliższy bardziej restrykcyjny dostępny obraz.
6.2 Przebieg manewrowy → Ms2 na semaforze/tarczy manewrowej (Ms1 = zabroniona).
6.3 Tarcza ostrzegawcza powiązana pokazuje: Os1 gdy semafor „stój"/Sz; Os2 gdy
S2–S5; Os3 gdy S6–S9; Os4 gdy S10–S13a. Powtarzacz: analogicznie Sp1–Sp4.
6.4 Powrót na „stój": gdy czoło pociągu minie semafor (zajęcie pierwszej sekcji za
nim), semafor natychmiast S1.

## 7. Przebiegi manewrowe

Różnice vs pociągowe: brak drogi ochronnej i tarczy ostrzegawczej; koniec przebiegu
może być na torze zajętym (podstawianie); sygnał Ms2; zwalnianie sekcyjne jak wyżej;
manewrów nie wolno wypuścić poza granicę przetaczania (wskaźnik W5 / semafor wjazdowy)
— przebiegi manewrowe w tabeli po prostu nie wychodzą poza tę granicę.

## 8. Zdarzenia awaryjne generowane przez rdzeń

- `turnout_no_control` — zwrotnica traci kontrolę (lampki migają): przebiegi przez
  nią niemożliwe; naprawa po czasie/wizycie ekipy (zdarzenie) albo obsługa ręczna
  na miejscu (rozkaz „O" ograniczenie prędkości) — uproszczenie: przycisk „obsługa
  ręczna" z opóźnieniem czasowym.
- `signal_failure` — semafor ciemny → traktowany jak „stój", jazdy na Sz/rozkaz.
- `crossing_failure`, `block_failure` (→ telefoniczne zapowiadanie), `dsat_alarm`.

## 9. Testy wymagane (GUT)

1. Nie da się utwierdzić przebiegu na zajętą sekcję / sprzecznego / bez ochrony bocznej.
2. Zwrotnicy w LOCKED nie da się przestawić; po zwolnieniu sekcyjnym — da się.
3. Zwalnianie sekcyjne krok po kroku dla przebiegu 3-sekcyjnego.
4. Pełna tabela obrazów §6 (16 kombinacji + degradacje konstrukcyjne).
5. Kasowanie z zajętą sekcją zbliżania → wymusza timer i licznik.
6. Rozprucie ustawia TRAILED i wyklucza zwrotnicę z przebiegów.
