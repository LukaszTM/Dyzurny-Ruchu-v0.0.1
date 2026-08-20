# 11 — Sygnalizacja kolejowa (wg Ie-1 / rozporządzenia MI z 18.07.2005)

Źródło prawdy dla `data/signals/aspekty.json` i grafiki sygnalizatorów.
Systematyka zgodna z Instrukcją sygnalizacji Ie-1 (E-1) PKP PLK, opisy własne.
Weryfikacja końcowa: załącznik 1 Ie-1 („Zestawienie obrazów sygnałowych semaforów
świetlnych") — PDF w `19-zrodla.md`.

## 1. Zasady ogólne semaforów świetlnych

- Kolory świateł: **czerwone** (tylko ciągłe), **zielone**, **pomarańczowe**,
  **białe** (matowobiałe); zielone/pomarańczowe/białe mogą być ciągłe lub migające.
- Obraz = 1 lub 2 światła. Przy dwóch światłach **dolne jest zawsze pomarańczowe
  ciągłe** i oznacza jazdę z prędkością zmniejszoną (40/60/100 km/h) przez okręg
  zwrotnicowy za semaforem; **górne** informuje o wskazaniu następnego semafora.
- **Pas świetlny** pod światłami podnosi próg prędkości obrazów dwuświatłowych:
  **zielony pas → 100 km/h** (sygnały S6–S9), **pomarańczowy pas → 60 km/h**
  (sygnały S10a–S13a). Bez pasa obrazy dwuświatłowe oznaczają 40 km/h (S10–S13).
- Semafor nieoświetlony lub o wątpliwym wskazaniu = „Stój".
- Częstotliwość migania: ~1 Hz (w grze: 60 tików wł. / 60 wył. przy 120 FPS → użyj
  timera 0,5 s).

## 2. Tabela obrazów semaforów świetlnych (S1–S13a)

Zapis: G = górne, D = dolne, ○ ciągłe, ✱ migające, [pas] = pas świetlny.

| Sygnał | Obraz | Prędkość przy tym semaforze | Informacja o następnym semaforze |
|---|---|---|---|
| **S1** | czerwone ○ | STÓJ | — |
| **S2** | zielone ○ | maksymalna | zezwala z prędkością maksymalną |
| **S3** | zielone ✱ | maksymalna | zezwala ≤100 km/h |
| **S4** | pomarańczowe ✱ | maksymalna | zezwala ≤40 lub 60 km/h |
| **S5** | pomarańczowe ○ | maksymalna | „Stój" |
| **S6** | G zielone ○, D pomarańczowe ○, [pas zielony] | ≤100 km/h | zezwala z maksymalną |
| **S7** | G zielone ✱, D pomarańczowe ○, [pas zielony] | ≤100 km/h | zezwala ≤100 km/h |
| **S8** | G pomarańczowe ✱, D pomarańczowe ○, [pas zielony] | ≤100 km/h | zezwala ≤40/60 km/h |
| **S9** | G pomarańczowe ○, D pomarańczowe ○, [pas zielony] | ≤100 km/h | „Stój" |
| **S10** | G pomarańczowe ○, D pomarańczowe ○ | ≤40 km/h | „Stój" |
| **S11** | G pomarańczowe ✱, D pomarańczowe ○ | ≤40 km/h | zezwala ≤40/60 km/h |
| **S12** | G zielone ✱, D pomarańczowe ○ | ≤40 km/h | zezwala ≤100 km/h |
| **S13** | G zielone ○, D pomarańczowe ○ | ≤40 km/h | zezwala z maksymalną |
| **S10a–S13a** | jak S10–S13 + [pas pomarańczowy] | ≤60 km/h | jak odpowiednio S10–S13 |

Uwaga na odwrotną kolejność numeracji w grupach: w S6–S9 kolejność „następny:
max→stój", w S10–S13 „następny: stój→max". Tak jest w instrukcji — nie „poprawiać".

## 3. Sygnał zastępczy Sz

**Jedno matowobiałe światło migające** na semaforze (lub na słupie semafora)
wskazującym „Stój", sygnał wątpliwy albo nieoświetlonym. Zezwala minąć taki semafor
bez rozkazu pisemnego. Jazda za Sz z ograniczoną prędkością i szczególną ostrożnością
— w grze przyjmij ≤40 km/h przez okręg zwrotnicowy, z gotowością do zatrzymania
`[DO WERYFIKACJI: dokładny reżim wg aktualnego Ir-1 §61 i rozporządzenia]`.

## 4. Sygnały manewrowe (tarcze manewrowe świetlne, także na semaforach)

| Sygnał | Obraz | Znaczenie |
|---|---|---|
| **Ms1** | niebieskie ○ | Jazda manewrowa zabroniona |
| **Ms2** | białe ○ | Jazda manewrowa dozwolona |

Tarcza manewrowa (Tm) — niski/karzełkowy sygnalizator przy torach bocznych.
Semafor może wyświetlać Ms2 dla manewrów (białe światło w głowicy).

## 5. Tarcze ostrzegawcze semaforowe (To) — świetlne

Ustawione na drodze hamowania przed semaforem, powtarzają grupę jego wskazania:

| Sygnał | Obraz | Semafor, do którego się odnosi, wskazuje |
|---|---|---|
| **Os1** | pomarańczowe ○ | „Stój" (S1) — dotyczy też jazdy na Sz |
| **Os2** | zielone ○ | sygnał z prędkością maksymalną (S2–S5) |
| **Os3** | zielone ✱ | sygnał ≤100 km/h (S6–S9) |
| **Os4** | pomarańczowe ✱ | sygnał ≤40/60 km/h (S10–S13a) |

## 6. Sygnalizatory powtarzające (Sp)

Stosowane, gdy widoczność semafora jest niewystarczająca. **Dolne światło białe ○**
(cecha rozpoznawcza) + górne jak niżej:

| Sygnał | Górne światło | Semafor wskazuje |
|---|---|---|
| **Sp1** | pomarańczowe ○ | „Stój" |
| **Sp2** | zielone ○ | jazda z maksymalną |
| **Sp3** | zielone ✱ | jazda ≤100 km/h |
| **Sp4** | pomarańczowe ✱ | jazda ≤40/60 km/h |

## 7. Semafory kształtowe (ramienne) — poziom 3 gry

| Sygnał | Dzień (ramiona) | Noc (światła) | Znaczenie |
|---|---|---|---|
| **Sr1** | ramię poziomo w prawo | czerwone | „Stój" |
| **Sr2** | jedno ramię ukośnie w górę (45°) | zielone | Wolna droga (jazda z maks. prędkością wg wskazań) |
| **Sr3** | dwa ramiona ukośnie w górę | zielone + pomarańczowe | Wolna droga ze zmniejszoną prędkością (≤40 km/h, jazda w kierunku zwrotnym rozjazdów) |

Tarcza ostrzegawcza kształtowa (Od): **Od1** — tarcza (okrągła, pomarańczowa
z białą obwódką) widoczna płaszczyzną / noc: pomarańczowe — semafor „Stój";
**Od2** — tarcza obrócona (niewidoczna) / noc: zielone — semafor zezwala.
`[DO WERYFIKACJI: dokładny rysunek tarczy i świateł nocnych wg Ie-1 rozdz. o
sygnalizacji kształtowej]`

## 8. Tarcze zaporowe (osłona żeberek, obrotnic, przejść)

Sygnały „Stój" / zezwolenie dla jazd manewrowych w miejscach osłanianych. W grze
występują na żeberkach ochronnych. `[DO WERYFIKACJI: obrazy Z1/Z2 dzienne i nocne
wg Ie-1 — zaimplementować dopiero przy stacji, która ich używa]`

## 9. Tarcza ostrzegawcza przejazdowa (ToP)

Przed przejazdami z ssp; informuje drużynę o stanie urządzeń przejazdowych:
- **Osp1** — urządzenia przejazdowe NIE działają prawidłowo → jazda z ograniczeniem
  i ostrożnością (obraz: pomarańczowe ✱ `[DO WERYFIKACJI]`),
- **Osp2** — urządzenia działają prawidłowo (obraz: białe ✱ `[DO WERYFIKACJI]`).
Dla rdzenia: stan ToP wynika ze stanu ssp (sprawne/załączone vs awaria).

## 10. Wskaźniki niezbędne w grze (minimum)

- **W4** — miejsce zatrzymania czoła pociągu przy peronie.
- **W5** — granica przetaczania (manewry nie dalej).
- **Ukres** — słupek graniczny zbiegających się torów (element logiki zajętości:
  tabor poza ukresem = kolizja z drogą sąsiednią).
- Pozostałe wskaźniki (W1, W6a, W11a itd.) — poza zakresem 1.0; dodawaj wyłącznie
  z opisem z Ie-1.

## 11. Sygnały dźwiękowe i końca pociągu (tło klimatyczne)

- Rp1 „Baczność" (syrena lokomotywy) przy ruszaniu/przy przejazdach — tylko audio.
- Sygnał końca pociągu (tarcze/światła na ostatnim wagonie) — dyżurny obserwuje,
  czy pociąg przyjechał cały; w grze: podświetlenie „końcówki" przy przejeździe
  obok nastawni; brak końcówki = zdarzenie „pociąg niecały" → procedura zamknięcia
  szlaku.

## 12. Mapowanie do `data/signals/aspekty.json`

Wygeneruj plik z tabel §2–§9: dla każdego obrazu: id, lampy (kolor, pozycja,
tryb ciągłe/migające), pas, znaczenie skrócone (tooltip), grupa dla tarcz (Os/Sp).
Klucz zgodności: patrz algorytm wyboru obrazu w `docs/04-logika-zaleznosci.md §6`.
