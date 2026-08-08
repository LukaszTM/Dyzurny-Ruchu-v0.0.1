# Dyżurny Ruchu — Symulator LCS (v0.4.0)

Symulator pracy **dyżurnego ruchu** w Lokalnym Centrum Sterowania (LCS).
Wygląd i obsługa pulpitu odwzorowane na oryginalnym polskim LCS (tym samym,
który wiernie kopiuje tryb dyżurnego ruchu w grze **SimRail**): czarny obraz
świetlny z szarymi torami, **utwierdzone przebiegi pociągowe podświetlane na
zielono** (manewrowe na biało), żółta nazwa posterunku i wiersz „Zalogowany:”,
zielony zegar, pasek poleceń PRZEBIEG POCIĄGOWY … OPS na środku u góry,
listwa poleceń sygnalizatora STOP…KTAB, semafory jako podwójne groty
z żółtymi nazwami i kreską masztu, seledynowe numery rozjazdów, przerwy
izolacyjne na torach, kozły oporowe i sąsiednie posterunki na krańcach,
czerwone kasetki z numerami pociągów, różowe znaki km i przejazd, a na dole
ekranu zadokowane jasnoszare tabele **ZDARZENIA** i **ALARMY** (zwijane).
Wykaz pociągów w stylu oryginalnego EDR: kolorowe kolumny, malinowe
podświetlenie wybranego wiersza, motyw jasny i ciemny.
Pierwsza lokalizacja: **Warszawa Wschodnia** (9 torów, 31 rozjazdów,
27 sygnalizatorów, 4 kierunki szlakowe + stacja techniczna Grochów).

Silnik: **Godot 4.3+** (renderer Compatibility).

## Funkcje

- **Nastawianie przebiegów odwzorowane 1:1 z praktyką kolejową** —
  dwuprzyciskowe: rodzaj polecenia (PRZEBIEG POCIĄGOWY / MANEWROWY) →
  przycisk początku → przycisk końca drogi przebiegu. Urządzenia same
  wybierają drogę, przestawiają rozjazdy, utwierdzają przebieg i dopiero
  wtedy podają sygnał. Sekcyjne zwalnianie za pociągiem, kontrola wrogości
  przebiegów, rozjazdy z położeniem + / −.
  Polecenia pulpitu: **ZD, ZDM, ZW, ZWP, OPS**; menu sygnalizatora:
  **STOP, OSTOP, SZ, SZP, NSZ, NSZP, WTAB, KTAB**.
- **System łączności między posterunkami** — pełne telefoniczne
  zapowiadanie pociągów: żądanie i danie pozwolenia, oznajmienie odjazdu
  (nr pociągu, godzina, tor), potwierdzenie przyjazdu „w całości”, monity.
  Bez pozwolenia sąsiada urządzenia nie pozwolą wyprawić pociągu na szlak.
- **System zgłaszania usterek** — usterki nie ustępują same; trzeba je
  zgłosić właściwej służbie (Automatyk SRK, SOK, Dyspozytor przewoźnika),
  a wtedy symulowany jest przyjazd służby i usuwanie usterki.
- **EDR — Elektroniczny Dziennik Ruchu** (zastąpił dziennik papierowy):
  zapowiedzi, przebiegi, ruch, manewry, usterki, wpisy własne; filtrowanie
  i zapis do pliku.
- **Dwa tryby ruchu**:
  - **REALNY ROZKŁAD JAZDY** — czas rzeczywisty: gra zaczyna się o aktualnej
    dacie i godzinie systemowej, obowiązuje całodobowy rozkład (278 pozycji)
    aktualny dla tej pory; nie można przyspieszać czasu ani zmieniać natężenia
    ruchu, a usterki występują losowo ze stałą częstotliwością, na którą gracz
    nie ma wpływu; po północy rozkład dobowy zaczyna się od nowa,
  - **RUCH LOSOWY** — przy rozpoczęciu dyżuru generowany jest fikcyjny
    całodobowy rozkład jazdy (widoczny w wykazie pociągów), według którego
    zgłaszają się pociągi; gęstość rozkładu wynika z natężenia ustawionego
    w opcjach gry (zmiana natężenia w trakcie dyżuru przebudowuje przyszłe
    pozycje), częstotliwość zdarzeń regulowana, tempo 1–10×.
- **Osobne ekrany** (F2–F5): rozkład jazdy, EDR, zdarzenia, łączność —
  otwierane w nowej scenie; symulacja działa dalej w tle.
- **Wykaz pociągów jak w prawdziwym EDR** — zaczyna się od najbliższego
  przyjazdu (przycisk TERAZ ▶), zawiera godziny przyjazdu i odjazdu
  (plan/rzeczywiste), postój handlowy lub przelot, numer peronu i toru,
  wyraźne malinowe zaznaczenie wiersza oraz przełącznik motywu ☾/☀.
- **Zadokowane tabele ZDARZENIA i ALARMY** na dole pulpitu (jak w LCS) —
  bieżące zapisy EDR i czynne usterki z wyróżnieniem niezgłoszonych; zwijane.
- **Zwijane okno skróconego rozkładu** na pulpicie — cztery najbliższe
  pociągi.
- **Przejazdy manewrowe** — podstawianie i odstawianie składów ze stacji
  technicznej Grochów, zlecenia manewrowe.
- **Rozkład jazdy i opóźnienia aktualizowane online** (HTTP/JSON).
- **Tryb nauki** — 17-krokowy samouczek: zapowiadanie, nastawianie
  przebiegów, EDR, sygnał zastępczy, zgłaszanie usterek, manewry, rozjazdy.
- **Ustawienia**: rozdzielczość, tryb okna, VSync, nazwisko dyżurnego,
  natężenie ruchu, praca manewrowa, częstotliwość zdarzeń, zapowiadanie,
  adresy aktualizacji online.
- **Modułowe lokalizacje** — nowe stacje dodaje się bez zmian w kodzie
  (`docs/DODAWANIE_LOKALIZACJI.md`).

## Uruchomienie

1. Zainstaluj [Godot 4.3+](https://godotengine.org/download).
2. Otwórz `project.godot` i naciśnij **F5**, albo z konsoli:

   ```bash
   godot --path .
   ```

## Sterowanie

| Akcja | Sterowanie |
|---|---|
| Nastawienie przebiegu | wybierz PRZEBIEG POCIĄGOWY/MANEWROWY → klik początku → klik końca |
| Menu sygnalizatora | prawy przycisk myszy na sygnalizatorze |
| Przesuwanie pulpitu / zoom | prawy przycisk myszy / rolka |
| Pauza | **Spacja** |
| Tempo 1x/2x/5x/10x | **1 / 2 / 3 / 4** |
| Rozkład / EDR / Zdarzenia / Łączność | **F2 / F3 / F4 / F5** |
| Pomoc | **F1** |
| Powrót, wyjście | **Esc** |

Pełna instrukcja: `docs/INSTRUKCJA_DYZURNEGO.md`.

## Struktura projektu

```
autoload/          # EventBus, Settings, Locations, GameState (właściciel symulacji)
scenes/            # MainMenu, Panel, RozkladJazdy, EDR, Zdarzenia, Lacznosc
scripts/core/      # rdzeń: układ torowy, urządzenia srk, pociągi, rozkład,
                   # zdarzenia, EDR, łączność, samouczek
scripts/ui/        # pulpit nastawczy i ekrany pomocnicze
data/locations/    # lokalizacje (stacja = katalog z plikami JSON)
data/online/       # pliki serwowane graczom jako aktualizacje online
tools/             # generator i walidator układu torowego
tests/             # testy headless
docs/              # instrukcje
```

Symulacja żyje jako dziecko autoloadu `GameState`, dlatego przełączanie
ekranów nie przerywa prowadzenia ruchu.

## Testy (headless)

Test dymny pełnej pętli — 22 kontrole: zapowiadanie, nastawianie
dwuprzyciskowe, utwierdzenie i położenia rozjazdów, wjazd, potwierdzenie
przyjazdu, odmowa wyprawienia bez pozwolenia, wyjazd, manewry, usterka
semafora i sygnał zastępczy, zgłoszenie usterki i jej usunięcie, ZW, ZD,
wrogość przebiegów, EDR:

```bash
godot --headless --path . res://tests/SmokeTest.tscn --quit-after 60000
```

Sonda trybów — uruchamia symulację przy dużym natężeniu ruchu i częstych
zdarzeniach oraz cyklicznie przełącza wszystkie ekrany:

```bash
SIM_MODE=random godot --headless --path . res://tests/ModeProbe.tscn --quit-after 5000
```

Automatyczny dyżurny — sonda przepustowości: gra jak gracz (odbiera rozmowy,
nastawia przebiegi wjazdowe i wyjazdowe, zapowiada pociągi) przez 90 minut
czasu symulacji i wykrywa każde zakleszczenie ruchu:

```bash
godot --headless --path . res://tests/DispatchProbe.tscn --quit-after 90000
```

Sonda tabel ZDARZENIA/ALARMY na pulpicie:

```bash
godot --headless --path . res://tests/DockProbe.tscn --quit-after 12000
```

Walidacja układu torowego:

```bash
python3 tools/build_layout_wws.py
```

## Status

Wersja 0.4.0. Schemat Warszawy Wschodniej jest świadomie uproszczony
względem rzeczywistej stacji. Nazwy poleceń pulpitu odpowiadają
konwencjom spotykanym na nastawnicach komputerowych PKP; w konkretnej
instalacji mogą się różnić.
