# 15 — Blokada liniowa

Blokada liniowa zabezpiecza następstwo pociągów na szlaku: uniemożliwia wyprawienie
pociągu na odstęp zajęty. Uzupełnia (nie zastępuje!) zapowiadanie telefoniczne —
zakres telefonogramów zależy od typu blokady (patrz `18-procedury-ruchowe-ir1.md`).

## 1. Blokada półsamoczynna (poziomy 1–3)

Szlak = jeden odstęp między posterunkami zapowiadawczymi (lub dzielony posterunkiem
odstępowym z obsadą). Obsługa ręczna, kontrola zajętości tylko punktowa.

**Pola/przyciski na pulpicie (na jeden tor szlaku):**
- **Po** — „początkowe": zablokowanie wyjazdu po wyprawieniu pociągu (semafor
  wyjazdowy po przejeździe blokuje się do czasu zwolnienia przez sąsiada),
- **Ko** — „końcowe": potwierdzenie przyjazdu pociągu (zwalnia odstęp sąsiadowi),
- **Poz** — „pozwolenie": na szlaku jednotorowym określa, który posterunek ma prawo
  wyprawiać (pozwolenie można dać sąsiadowi / otrzymać od niego); tylko posterunek
  posiadający pozwolenie może podać semafor wyjazdowy.
- Lampki stanu: odstęp wolny/zajęty, kierunek pozwolenia, „blokada zajęta".

**Cykl na szlaku jednotorowym (gracz wyprawia):**
1. Gracz ma pozwolenie (lampka) — jeśli nie: żąda telefonicznie, sąsiad daje
   (przycisk u sąsiada → u gracza lampka zmienia stronę).
2. Telefonogram żądania/dania drogi (wg Ir-1) + zapis.
3. Nastawienie przebiegu wyjazdowego → semafor zezwalający (blokada pozwala,
   bo odstęp wolny i pozwolenie u gracza).
4. Po minięciu semafora: obsługa **Po** (zablokowanie — u niektórych odmian
   samoczynnie od oddziaływania pociągu `[konfigurowalne per stacja]`),
   telefonogram oznajmienia odjazdu.
5. Sąsiad po przyjeździe całego pociągu obsługuje **Ko** → u gracza odstęp wolny,
   telefonogram potwierdzenia przyjazdu.

**Awarie:** niemożność zwolnienia (pociąg niecały/usterka) → przyciski doraźne
z licznikami + przejście na **telefoniczne zapowiadanie** (pełne formuły, ruch
prowadzony „na telefon"; semafory wyjazdowe na Sz lub rozkaz).

## 2. Blokada samoczynna (sbl) — poziom 4

Szlak podzielony na odstępy z **samoczynnymi semaforami odstępowymi** (numerowane,
z tabliczką); kontrola zajętości ciągła (obwody/liczniki osi).
- Semafor odstępowy pokazuje sygnał zależnie od liczby wolnych odstępów przed nim:
  3-stawna: S1 (odstęp zajęty) ← S5 ← S2; 4-stawna: S1 ← S5 ← S3 ← S2.
- Semafor odstępowy sbl **ślepy na przebiegi** — steruje nim wyłącznie zajętość.
- **Kierunkowość:** na torze z ruchem dwukierunkowym zmiana kierunku blokady wymaga
  zgodnej obsługi obu posterunków i wolności szlaku (przyciski „zmiana kierunku",
  lampki kierunku na pulpicie). Na liniach dwutorowych zwykle każdy tor ma kierunek
  zasadniczy; jazda „pod prąd" po torze lewym = rozkaz pisemny „N" (gdy brak sbl
  dwukierunkowej).
- Wyprawianie za pociągiem: kolejny pociąg może wyjechać, gdy pierwszy zwolni
  pierwszy odstęp — telefonogramy zapowiadawcze przy sprawnej sbl ograniczone
  (pozostaje ewidencja) `[szczegół wg Ir-1 §29 — DO WERYFIKACJI zakresu formuł]`.
- Awaria sbl → prowadzenie ruchu jak przy braku blokady: telefoniczne zapowiadanie,
  jazda na rozkaz obok ciemnych semaforów odstępowych.

## 3. Blokada elektromechaniczna (poziom 3, klimat historyczny)

Funkcjonalnie jak półsamoczynna, ale obsługiwana **blokami w aparacie blokowym**
(okienka czerwono-białe, klawisze + induktor). Pola: początkowe, końcowe,
pozwolenia — jak w §1; dodatkowo fizyczna „korbka" induktora (przytrzymanie = animacja).
Stan pól: okienko **czerwone = zablokowane** (funkcja wykonana/odstęp zajęty),
**białe = odblokowane** `[DO WERYFIKACJI: konwencja barw okienek per pole]`.

## 4. Model w rdzeniu (`BlockLine`)

Stan per tor szlaku: `{direction, permission_at, occupied, po_locked, ko_pending}`.
API: `can_dispatch(side)`, `on_train_entered/exited`, `give_permission(side)`,
`press(field, side)`, zdarzenia do UI i NeighbourAI. Awarie ustawiane przez
EventDirector: `stuck_field`, `phantom_occupied`, `power_loss`.
