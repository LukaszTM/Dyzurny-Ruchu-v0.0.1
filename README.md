# Dyżurny Ruchu — Symulator LCS (v0.0.1)

Symulator pracy **dyżurnego ruchu** w Lokalnym Centrum Sterowania (LCS),
wzorowany na trybie dyżurnego ruchu z gry SimRail. Pierwsza lokalizacja:
**Warszawa Wschodnia** (schemat uproszczony: grupa podmiejska — tory 1–4,
perony 1–2; grupa dalekobieżna — tory 5–8, perony 3–4; tor postojowy 9
i łącznica do zaplecza technicznego Grochów).

Silnik: **Godot 4.3+** (renderer Compatibility — działa też na słabszych GPU).

## Funkcje

- **Dwa tryby ruchu:**
  - *Ruch losowy* — pociągi generowane losowo, **natężenie (poc./h) regulowane
    suwakiem** w trakcie gry (zakładka „Ruch"),
  - *Ruch wg rozkładu jazdy* — pełny rozkład stacji z priorytetami torów,
    pociągami kończącymi/zaczynającymi bieg i przelotami towarowymi.
- **Pulpit nastawczy** w stylu rzeczywistych systemów zdalnego sterowania:
  odcinki podświetlane wg stanu (wolny / przebieg pociągowy / przebieg
  manewrowy / zajęty / zamknięty), semafory i tarcze manewrowe, sekcyjne
  zwalnianie przebiegów, kontrola wrogości przebiegów.
- **Podgląd rozkładu jazdy** z opóźnieniami i statusami pociągów.
- **Dziennik ruchu dyżurnego** — wpisy automatyczne i ręczne, zapis do pliku.
- **Zdarzenia losowe** z regulowaną częstotliwością: usterki rozjazdów,
  usterki semaforów (obsługa **sygnałem zastępczym Sz**), osoby postronne
  i zwierzęta na torach, awarie taboru.
- **Przejazdy manewrowe** — podstawianie i odstawianie składów z/do zaplecza
  Grochów, tryb manewrowy (przebiegi „białe"), zlecenia manewrowe.
- **Rozkład jazdy i opóźnienia aktualizowane online** (HTTP/JSON, adresy
  konfigurowalne w ustawieniach; przy braku sieci gra korzysta z danych
  lokalnych).
- **Tryb nauki** — samouczek krok po kroku dla początkujących: przyjęcie
  i wyprawienie pociągu, dziennik, sygnał zastępczy, jazdy manewrowe.
- **Ustawienia**: wybór rozdzielczości, tryb okna (okno / pełny ekran /
  bez ramki), VSync, adresy aktualizacji online.
- **Modułowe lokalizacje** — nowe stacje dodaje się bez zmian w kodzie
  (patrz `docs/DODAWANIE_LOKALIZACJI.md`).

## Uruchomienie

1. Zainstaluj [Godot 4.3+](https://godotengine.org/download) (wystarczy
   wersja standardowa, bez .NET).
2. Otwórz projekt (`project.godot`) w Godot i naciśnij **F5**, albo z konsoli:

   ```bash
   godot --path .
   ```

## Sterowanie

| Akcja | Sterowanie |
|---|---|
| Ustawienie przebiegu | klik semafor początkowy → klik semafor docelowy lub portal wyjazdowy |
| Tryb manewrowy | przełącznik na dolnym pasku lub klawisz **M** |
| Sygnał zastępczy (Sz) / zwolnienie przebiegu | przyciski na dolnym pasku po wybraniu semafora |
| Przesuwanie pulpitu | prawy lub środkowy przycisk myszy |
| Zoom | rolka myszy |
| Pauza | **Spacja** |
| Tempo symulacji 1x/2x/5x/10x | klawisze **1/2/3/4** |
| Pomoc | **F1** |

Szczegółowa instrukcja: `docs/INSTRUKCJA_DYZURNEGO.md`.

## Aktualizacje online

Gra cyklicznie (oraz na żądanie — przycisk „Aktualizuj online" w zakładce
„Rozkład jazdy") pobiera:

- **opóźnienia**: `data/online/delays.json`,
- **uzupełnienia rozkładu**: `data/online/timetable_warszawa_wschodnia.json`.

Domyślne adresy wskazują na pliki w tym repozytorium (gałąź `main`) — edycja
pliku w repozytorium zmienia opóźnienia u wszystkich graczy. Adresy można
zmienić w **Ustawieniach** (np. na własny serwer).

## Struktura projektu

```
autoload/          # singletony: EventBus, Settings, Locations, GameState
scenes/            # sceny: MainMenu, Simulator
scripts/sim/       # logika: układ torowy, srk, pociągi, rozkład, zdarzenia
scripts/ui/        # pulpit i panele interfejsu
data/locations/    # lokalizacje (każda stacja = katalog z JSON)
data/online/       # pliki serwowane graczom jako aktualizacje online
docs/              # instrukcje
```

## Testy (headless)

Test dymny pełnej pętli rozgrywki (wjazd → odjazd, manewry, Sz, zwolnienie
doraźne, dziennik, rozkład):

```bash
godot --headless --path . res://tests/SmokeTest.tscn --quit-after 20000
```

Sonda trybów (wychwytywanie błędów runtime przy dużym natężeniu ruchu
i częstych zdarzeniach):

```bash
SIM_MODE=random godot --headless --path . res://tests/ModeProbe.tscn --quit-after 6000
```

## Licencja / status

Wersja 0.0.1 — szkielet rozgrywki z pełną pętlą: przyjmowanie, wyprawianie,
manewry, zdarzenia, dziennik, rozkład online. Schemat stacji jest świadomie
uproszczony względem rzeczywistej Warszawy Wschodniej.
