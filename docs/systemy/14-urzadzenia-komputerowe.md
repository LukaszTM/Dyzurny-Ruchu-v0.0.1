# 14 — Komputerowe urządzenia nastawcze (poziom 5)

Gra odwzorowuje **konwencje** polskich komputerowych systemów nastawczych
(zależnościowych), bez klonowania interfejsu konkretnego produktu — patrz
`docs/01-podstawy-prawne.md §2.2`. Nazwa w grze: „komputerowe urządzenia nastawcze".

## 1. Stanowisko

- 1–2 monitory z **planem stacji** (schemat synoptyczny), klawiatura + mysz/trackball.
- Pasek menu poleceń, linia komend/dialogów, **rejestr zdarzeń** (log) z czasem,
  pole alarmów z potwierdzaniem (kwitowaniem).
- LCS (lokalne centrum sterowania): jeden pulpit steruje kilkoma posterunkami —
  przełączanie widoków stacji zakładkami.

## 2. Konwencja barw planu (przyjęta w grze)

`[DO WERYFIKACJI: dobrana wg powszechnych konwencji CBI; dopasować po materiałach
referencyjnych]`

| Element | Kolor |
|---|---|
| tor wolny, nieutwierdzony | szary |
| odcinek zajęty | czerwony |
| droga przebiegu pociągowego utwierdzona | zielony (podświetlenie linii toru) |
| droga przebiegu manewrowego | żółty |
| zwrotnica bez kontroli / w ruchu | miganie symbolu |
| tor zamknięty | niebieski / przekreślenie |
| semafor: stój / zezwalający / Sz | czerwony / zielony / biały migający symbol |

## 3. Obsługa (filozofia dwóch kroków)

Każde polecenie ruchowe wymaga **wskazania i potwierdzenia** (zapobieganie
pomyłkom — odpowiednik plomb):
1. klik semafora początkowego → klik końca drogi (lub wybór z menu „Przebiegi"),
2. system pokazuje podgląd drogi (podświetlenie) + okno „Wykonać? [Tak/Nie]",
3. wykonanie: zwrotnice układają się same, droga utwierdza, semafor podaje sygnał.

Polecenia specjalne (odpowiedniki przycisków plombowanych) mają **dodatkową
autoryzację**: wpisanie kodu polecenia lub drugie potwierdzenie z ostrzeżeniem,
a system zlicza użycia w rejestrze (licznik programowy):
`Sz <semafor>`, `ZWOLNIJ PRZEBIEG <id>`, `ZAMKNIJ TOR <nr>`, `ZAMKNIJ ZWROTNICĘ <nr> W <+/->`,
`BLOKADA: POZWOLENIE/ZWOLNIENIE`, `SSP: WYŁĄCZ/ZAŁĄCZ <przejazd>`.

## 4. Rejestr zdarzeń

Każda operacja i zdarzenie: `hh:mm:ss | źródło | treść` (np. „12:03:11 | DYŻ |
Utwierdzono przebieg A→t1", „12:05:40 | SYS | Zajętość it1"). Rejestr przewijalny,
eksport do raportu zmiany (scoring korzysta z tych samych danych).

## 5. Różnice względem pulpitu (dla rdzenia)

Rdzeń identyczny; UI komputerowe ma dodatkowo: nastawianie przebiegowe zawsze,
listę aktywnych przebiegów z możliwością zwolnienia, zdalne stacje (SimWorld
utrzymuje kilka stacji, NeighbourAI zastępowane przez gracza na wszystkich),
awarie łącza do stacji zdalnej (stacja „szarzeje", ruch prowadzony telefonicznie
przez miejscowego pracownika AI — mini-tryb dyktowania poleceń).
