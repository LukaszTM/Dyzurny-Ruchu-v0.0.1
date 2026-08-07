# Instrukcja dyżurnego ruchu

## 1. Pulpit nastawczy

Obraz świetlny odwzorowany na LCS z gry SimRail: na środku u góry pasek
poleceń, pod nim „Dyżurny ruchu: …” i nazwa posterunku; zegar w lewym
dolnym rogu; ekrany pomocnicze pod przyciskami w prawym górnym rogu.

| Element | Wygląd |
|---|---|
| tor wolny | szara linia |
| droga przebiegu w trakcie nastawiania | miga na seledynowo (przestawiane rozjazdy) |
| droga przebiegu utwierdzona | biała linia |
| zajętość toru | czerwona linia z grotami kierunku jazdy |
| zamknięcie toru | pomarańczowa, przekreślona |
| semafor | podwójny grot w kierunku jazdy: szary — „Stój”, zielony — sygnał zezwalający, biały — manewrowy, biały migający — Sz; nazwa na żółto |
| tarcza manewrowa | pojedynczy grot w ramce (Tm1, Tm2, Tm3) |
| rozjazd | numer + położenie: **+** zasadnicze, **−** zwrotne |
| kasetka szlaku | szary prostokąt na krańcu pulpitu (it1P, it2R, itG …) z numerem toru szlakowego |
| odcinki zbliżania | groty na szlaku z seledynowymi nazwami ISp…, IISp… |
| pociąg | czerwona kasetka z numerem (przy szlaku — oczekujący, nad głowicą składu — jadący) |
| znaki km, przejazd | różowe widły z kilometrażem, różowa linia pionowa |
| usterka | pomarańczowe przekreślenie / migająca obwódka |
| tabliczka ostrzegawcza | pomarańczowa ramka wokół elementu |

Widok: **prawy przycisk myszy** — przesuwanie, **rolka** — powiększenie,
**WIDOK** — dopasowanie schematu do okna.

## 2. Nastawianie przebiegu (dwuprzyciskowe)

Tak jak na kolei — urządzenia same wybierają drogę przebiegu:

1. Wybierz rodzaj polecenia na górnej belce: **PRZEBIEG POCIĄGOWY** albo
   **PRZEBIEG MANEWROWY**.
2. Naciśnij **przycisk początku** drogi przebiegu — sygnalizator, spod
   którego ma odbyć się jazda (podświetla się na niebiesko).
3. Naciśnij **przycisk końca** drogi przebiegu — sygnalizator na końcu
   wybranego toru albo przycisk szlaku.

Urządzenia sprawdzają warunki (zajętość, przebiegi wrogie, zamknięcia,
usterki rozjazdów), przestawiają rozjazdy (**nastawianie** — miganie),
utwierdzają przebieg (**biel**) i dopiero wtedy podają sygnał zezwalający.

Przykłady:
- wjazd od strony W-wy Centralnej na tor 5: **C → N5**,
- wyjazd z toru 5 na Rembertów: **N5 → it1R**,
- przelot z W-wy Centralnej na Rembertów: **C → it1R**,
- podstawienie składu z Grochowa na tor 8 (przebieg manewrowy): **Tm1 → K8**,
- odstawienie z toru 6 do Grochowa (przebieg manewrowy): **N6 → itG**.

## 3. Pozostałe polecenia pulpitu

| Polecenie | Znaczenie |
|---|---|
| **ZD** | zwolnienie drogi przebiegu pociągowego (gdy pociąg nie wjechał w przebieg) |
| **ZDM** | zwolnienie drogi przebiegu manewrowego |
| **ZW** | indywidualne przestawienie rozjazdu (+ / −) |
| **ZWP** | zwolnienie awaryjne przebiegu — z kontrolą czasu **180 s** |
| **OPS** | opis wskazanego elementu (stan, usterki, tabliczki) |

Rozjazdu zamkniętego w przebiegu, zajętego taborem lub z założoną tabliczką
nie da się przestawić.

## 4. Menu sygnalizatora (prawy przycisk myszy)

| Polecenie | Znaczenie |
|---|---|
| **STOP** | nakaz podania sygnału „Stój” |
| **OSTOP** | odwołanie nakazu „Stój” |
| **SZ** | sygnał zastępczy jednorazowy (przy usterce semafora) |
| **SZP** | sygnał zastępczy powtarzalny (przy usterce trwałej) |
| **NSZ / NSZP** | skasowanie sygnału zastępczego |
| **WTAB / KTAB** | założenie i skasowanie tabliczki ostrzegawczej |

Sygnał zastępczy można podać dopiero po **utwierdzeniu** przebiegu. Jazda na
Sz odbywa się z prędkością ograniczoną i jest odnotowywana w EDR.

## 5. Zapowiadanie pociągów (ekran ŁĄCZNOŚĆ, F5)

Kolejność telefonicznego zapowiadania:

1. **Żądanie pozwolenia** — sąsiad pyta: „Czy droga wolna dla pociągu nr …?”
   Odpowiadasz *Droga wolna* (pociąg zgłasza się przed semaforem wjazdowym)
   albo *Nie mogę przyjąć* (pociąg zgłosi się ponownie za ok. 3 minuty).
2. **Danie pozwolenia** — przed wyprawieniem pociągu na szlak sam żądasz
   pozwolenia u sąsiada („Żądaj pozwolenia”). **Bez pozwolenia urządzenia
   nie pozwolą nastawić przebiegu wyjazdowego.**
3. **Oznajmienie odjazdu** — po odjeździe: „Pociąg nr … odjechał o godz. …”.
4. **Potwierdzenie przyjazdu** — po przyjeździe: „Pociąg nr … przybył
   o godz. … w całości”. Brak potwierdzenia w ciągu 7 minut kończy się
   monitem sąsiada.

Zapowiadanie można wyłączyć w Ustawieniach (opcja dla początkujących).

## 6. Zdarzenia losowe i usterki (ekran ZDARZENIA, F4)

**Usterki nie ustępują samoczynnie.** Trzeba je zgłosić właściwej służbie
— dopiero wtedy rozpoczyna się ich usuwanie i biegnie czas naprawy:

| Zdarzenie | Właściwa służba |
|---|---|
| brak kontroli położenia rozjazdu, usterka semafora | **Automatyk SRK** |
| osoba postronna w torach, zwierzęta w skrajni | **Straż Ochrony Kolei** |
| awaria taboru | **Dyspozytor przewoźnika** |

Zgłoszenie do niewłaściwej służby zostanie odesłane ze wskazaniem
właściwej. Częstotliwość zdarzeń ustawiasz w **Ustawieniach**.

## 7. EDR — Elektroniczny Dziennik Ruchu (F3)

Rejestruje wszystkie czynności: zapowiedzi, nastawianie i zwalnianie
przebiegów, jazdy pociągów, manewry, usterki i wpisy własne dyżurnego.
Zapisy można filtrować po rodzaju i numerze pociągu, dodać wpis własny
oraz zapisać dziennik do pliku (`user://EDR_RRRRMMDD_stacja.txt`).

## 8. Tryb REALNY ROZKŁAD JAZDY

Gra zaczyna się o **aktualnej dacie i godzinie** (zegar z datą w lewym dolnym
rogu pulpitu). Czas płynie jak w rzeczywistości — tempa nie można zmienić,
natężenie ruchu wynika z całodobowego rozkladu, a usterki występują losowo ze
stałą częstotliwością. Po północy rozkład dobowy obowiązuje od początku.

## 9. Rozkład jazdy (F2)

Pełny wykaz pociągów posterunku: godziny planowe i rzeczywiste, opóźnienia,
tor, kierunki, stacja początkowa i końcowa oraz status. Przycisk
**Aktualizuj online** pobiera świeże opóźnienia i uzupełnienia rozkładu.
Na pulpicie widoczne jest zwijane okno z **czterema najbliższymi pociągami**.

## 10. Wskazówki

- Pociągi podmiejskie przyjmuj na tory 1 i 3 (kierunek wschodni) oraz
  2 i 4 (zachodni); dalekobieżne odpowiednio 5, 7 i 6, 8.
- Pociąg oznaczony **kończy bieg** po przyjeździe odstaw manewrowo do
  Grochowa; pociąg **rozpoczynający bieg** wymaga wcześniejszego
  podstawienia składu z Grochowa.
- Odjazd przed rozkładową godziną jest odnotowywany w EDR jako
  nieprawidłowość.
- Przy usterce rozjazdu prowadź ruch drogą okrężną — układ torowy
  Warszawy Wschodniej ma połączenia między grupą podmiejską a dalekobieżną
  (rozjazdy 7, 15 na zachodzie i 18, 23 na wschodzie).
