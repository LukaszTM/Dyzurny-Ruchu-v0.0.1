# 18 — Procedury ruchowe dyżurnego (wg Instrukcji Ir-1)

Podstawa: Ir-1 (R-1) „Instrukcja o prowadzeniu ruchu pociągów" PKP PLK —
rozdz. o zapowiadaniu (§23–26), rozkazach pisemnych (§58) i dokumentacji
(załączniki: Dziennik ruchu, Książka przebiegów; Dodatek 2: wzory telefonogramów).
Formuły poniżej sparafrazowano wiernie znaczeniowo; przed finalnym nagraniem/
tekstem w grze porównaj brzmienie z Dodatkiem 2 Ir-1 `[DO WERYFIKACJI]`.

## 1. Zapowiadanie pociągów — zasady

- Prowadzone między **posterunkami zapowiadawczymi** przez łączność zapowiadawczą.
- Zakres zależy od blokady: przy sprawnej półsamoczynnej — żądanie/danie pozwolenia
  zastępuje obsługa blokady tylko częściowo (telefonogramy wg Ir-1 §28); przy
  **telefonicznym zapowiadaniu** (brak/awaria blokady) — pełny komplet formuł.
- Każdy telefonogram: **powtórzenie przez odbierającego**, potwierdzenie nadającego,
  **zapis w dzienniku ruchu z godziną i nazwiskiem** (w grze: nazwisko AI/gracza
  automatycznie). Rozmowę kończy słowo „koniec".

## 2. Wzory telefonogramów (parafrazy do UI „składania formuły")

| # | Typ | Formuła (schemat) |
|---|---|---|
| 1 | Żądanie pozwolenia | „Czy droga dla pociągu nr **[nr]** wolna?" |
| 2 | Danie pozwolenia | „Droga dla pociągu nr **[nr]** wolna." |
| 3 | Odmowa/wstrzymanie | „Stój. Zatrzymajcie pociąg nr **[nr]**." |
| 4 | Oznajmienie odjazdu | „Pociąg nr **[nr]** odjedzie/odjechał o **[gg:mm]**." |
| 5 | Potwierdzenie przyjazdu | „Pociąg nr **[nr]** przyjechał o **[gg:mm]**." |
| 6 | Zamknięcie toru | „Tor nr **[n]** szlaku **[A–B]** zamknięty od **[gg:mm]** z powodu **[...]**." |
| 7 | Otwarcie toru | „Tor nr **[n]** szlaku **[A–B]** otwarty od **[gg:mm]**." |
| 8 | Do dróżnika przejazdowego | „Pociąg nr **[nr]** wyjedzie ze stacji **[X]** o **[gg:mm]**." |

UI: gracz składa telefonogram z pól (typ, nr pociągu, godzina, tor); rdzeń ocenia
adekwatność do sytuacji. Pociągi w rozmowie identyfikuje się numerem (i rodzajem
trakcji, gdy wymagane — pomijamy w 1.0).

## 3. Dziennik ruchu (posterunku zapowiadawczego)

Druk **R-142** (Ir-1 załącznik 1a). W grze formularz tabelaryczny; kolumny (układ
gry, odwzorowujący sens oryginału `[DO WERYFIKACJI: dokładny układ kolumn]`):
nr pociągu • relacja/kierunek • tor szlakowy • żądanie pozwolenia (gg:mm) •
pozwolenie otrzymane/dane (gg:mm) • oznajmienie odjazdu (gg:mm) • odjazd/przejazd
faktyczny (gg:mm) • przyjazd (gg:mm) • potwierdzenie przyjazdu (gg:mm) • uwagi
(Sz, rozkazy, zamknięcia).
Tryb łatwy: wpisy generowane automatycznie po każdej czynności (gracz zatwierdza);
tryb realistyczny: gracz wypełnia sam, błędy obniżają ocenę.

## 4. Książka przebiegów

Prowadzona na nastawni (dysponującej/wykonawczej) — ewidencja poleceń nastawienia
i utwierdzenia przebiegów (nr pociągu, semafor, tor, godzina). W grze: log
automatyczny z możliwością wglądu; na poziomie 3 (mechaniczna) — element rozgrywki.

## 5. Rozkazy pisemne (Ir-1 §58; druki R-305, R-306, R-307, R-315)

Doręczane/dyktowane drużynie, gdy trzeba zezwolić na jazdę wbrew normalnym
wskazaniom lub przekazać ograniczenia:

| Rozkaz | Druk | Typowe zastosowanie w grze |
|---|---|---|
| **„S"** | R-305 | zezwolenie na minięcie semafora wskazującego „Stój"/ciemnego (gdy nie można podać Sz), jazda po torze zamkniętym do miejsca robót |
| **„N"** | R-306 | jazda po torze szlakowym w kierunku przeciwnym do zasadniczego (tor lewy) |
| **„O"** | R-307 | ostrzeżenia i ograniczenia: awaria ssp na przejeździe, ograniczenie prędkości, obsługa zwrotnicy na gruncie |
| **„Nrob"** | R-315 | jazdy pociągów roboczych na tor zamknięty (poza zakresem 1.0) |

Obieg w grze: gracz otwiera formularz rozkazu → wybiera pozycje (checkboxy pól
odpowiadających treściom z druku, sparafrazowane) → „dyktuje przez radiotelefon"
(pasek postępu + odczyt AI maszynisty) → maszynista powtarza → rozkaz aktywny
(odblokowuje jazdę w rdzeniu). Numeracja rozkazów automatyczna, kopie w dokumentacji.

## 6. Sytuacje szczególne (katalog procedur do zdarzeń)

- **Awaria blokady liniowej** → zgłoszenie, przejście na telefoniczne zapowiadanie
  (pełne formuły §2), jazdy wyjazdowe przy zablokowanym semaforze na Sz lub „S".
- **Przerwa łączności zapowiadawczej** → łączność zastępcza (radiotelefon);
  całkowita przerwa: prowadzenie ruchu wg szczególnych zasad — w grze uproszczone:
  odstępy czasowe + rozkazy `[DO WERYFIKACJI: Ir-1 §32 zakres uproszczenia]`.
- **Pociąg niecały / brak sygnału końca** → nie potwierdzać przyjazdu, zatrzymać
  ruch na szlaku, sprawdzenie (zdarzenie czasowe).
- **Zamknięcie toru** (planowe/awaryjne) → telefonogramy 6/7, rozkazy dla jazd.
- **Jazda na sygnał zastępczy** → wpis w dzienniku (uwagi) + ograniczenia z `11 §3`.

## 7. Przekazanie dyżuru (rama scenariusza)

Początek/koniec zmiany: ekran „protokół zdania dyżuru" — stan liczników, zamknięcia,
usterki, pociągi na szlakach. Na starcie scenariusz może wstrzyknąć zaszłości
(np. „zwrotnica 3 zamknięta w −, usterka od 4:20") — gracz dziedziczy sytuację.
