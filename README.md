# Symulator Dyżurnego Ruchu — pakiet dokumentacji projektu

Kompletny pakiet dokumentacji do zbudowania **samodzielnej gry 2D** (Godot 4), w której gracz
wciela się w dyżurnego ruchu na polskiej kolei i obsługuje realistycznie odwzorowane
urządzenia sterowania ruchem kolejowym (srk): od nastawni mechanicznej, przez pulpit
kostkowy urządzeń przekaźnikowych, po komputerowe urządzenia nastawcze.

## Zawartość pakietu

```
symulator-dyzurnego/
├── README.md                  ← ten plik
├── CLAUDE.md                  ← instrukcja robocza dla Claude Code (start tutaj)
├── docs/
│   ├── 00-koncepcja-gry.md    ← game design document (GDD)
│   ├── 01-podstawy-prawne.md  ← co wolno legalnie wykorzystać i jak
│   ├── 02-architektura.md     ← architektura projektu w Godot 4
│   ├── 03-model-danych.md     ← format danych stacji (JSON), graf torowy
│   ├── 04-logika-zaleznosci.md← rdzeń symulacji: przebiegi, utwierdzanie, sygnały
│   ├── 05-symulacja-ruchu.md  ← pociągi, rozkład jazdy, AI maszynistów i sąsiadów
│   ├── 06-roadmap.md          ← plan wdrożenia fazami (F0–F10)
│   └── systemy/               ← DOKUMENTACJA REALNYCH SYSTEMÓW
│       ├── 10-podstawy-srk.md
│       ├── 11-sygnalizacja.md          ← pełna tabela sygnałów wg Ie-1
│       ├── 12-urzadzenia-mechaniczne.md
│       ├── 13-pulpit-kostkowy.md       ← urządzenia przekaźnikowe
│       ├── 14-urzadzenia-komputerowe.md
│       ├── 15-blokada-liniowa.md
│       ├── 16-przejazdy-kolejowe.md
│       ├── 17-dsat.md                  ← detekcja stanów awaryjnych taboru
│       ├── 18-procedury-ruchowe-ir1.md ← telefonogramy, dziennik ruchu, rozkazy
│       └── 19-zrodla.md                ← oficjalne dokumenty źródłowe (linki)
├── assets-spec/               ← SPECYFIKACJE WYGLĄDU (wierność wizualna)
│   ├── 20-pulpit-kostkowy-wyglad.md
│   ├── 21-ekran-komputerowy-wyglad.md
│   └── 22-nastawnia-mechaniczna-wyglad.md
└── data/
    ├── stacja-przyklad.json   ← przykładowa definicja stacji (format docelowy)
    └── scenariusz-przyklad.json
```

## Jak użyć z Claude Code

1. Zainstaluj Godot 4.x i Claude Code.
2. Utwórz katalog projektu i rozpakuj do niego ten pakiet (plik `CLAUDE.md` musi być
   w katalogu głównym projektu — Claude Code czyta go automatycznie).
3. Uruchom `claude` w katalogu projektu i wydaj polecenie, np.:
   > Przeczytaj CLAUDE.md oraz docs/06-roadmap.md i zrealizuj Fazę 0 (szkielet projektu Godot).
4. Kolejne fazy zlecaj pojedynczo: "Zrealizuj Fazę 1 zgodnie z roadmapą", itd.
   Po każdej fazie testuj grę ręcznie w Godocie.

## Ważne: znaczniki [DO WERYFIKACJI]

Dokumentacja systemów została opracowana na bazie publicznie dostępnej wiedzy i
zweryfikowana tam, gdzie było to możliwe, z oficjalnymi instrukcjami (Ie-1, Ir-1).
Miejsca, w których szczegół (np. dokładny odcień lampki, kolor dźwigni, brzmienie
formuły) wymaga potwierdzenia ze źródłem pierwotnym, oznaczono `[DO WERYFIKACJI]`.

**Zalecany krok przed produkcją grafiki:** pobierz oficjalne PDF-y wymienione w
`docs/systemy/19-zrodla.md` (są publicznie udostępniane przez PKP PLK), wrzuć je do
katalogu `docs/zrodla-pdf/` i poproś Claude Code o zweryfikowanie wszystkich
znaczników `[DO WERYFIKACJI]` względem tych dokumentów. Architektura gry jest tak
zaprojektowana (dane w JSON), że korekty nie wymagają zmian w kodzie.

## Zakres prawny — skrót

Gra odwzorowuje **realne, publiczne systemy kolejowe** (sygnalizację wg rozporządzenia
i instrukcji Ie-1, procedury wg Ir-1, fizyczne urządzenia srk). Nie kopiuje żadnych
materiałów TTSK/TD2 ani cudzych grafik. Szczegóły i uzasadnienie: `docs/01-podstawy-prawne.md`.
