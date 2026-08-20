# 21 — Wygląd komputerowych urządzeń nastawczych (specyfikacja)

Stylizacja: przemysłowy system SCADA/CBI lat 2000+ — surowy, funkcjonalny,
ciemne tło, żadnych ozdobników „gamingowych". Interfejs inspirowany konwencjami,
nie klon konkretnego produktu (`docs/01-podstawy-prawne.md`).

## 1. Układ ekranu (1920×1080)

```
┌──────────────────────────────────────────────────────────────┐
│ PASEK: [POSTERUNEK ▾] [PRZEBIEGI] [ZWROTNICE] [BLOKADA]      │ 32 px
│        [PRZEJAZDY] [SZLAK] [POLECENIA SPECJALNE]   12:03:11  │
├──────────────────────────────────────────────┬───────────────┤
│                                              │ ALARMY (kwit.)│
│              PLAN SYNOPTYCZNY                │───────────────│
│         (schemat stacji, ~75% ekranu)        │ REJESTR ZDARZEŃ│
│                                              │ 12:03 DYŻ ... │
├──────────────────────────────────────────────┴───────────────┤
│ LINIA DIALOGU: „Przebieg A → tor 1. Wykonać? [TAK] [NIE]"    │ 40 px
└──────────────────────────────────────────────────────────────┘
```

## 2. Paleta

| Element | Hex |
|---|---|
| tło planu | `#101216` |
| tor wolny | `#7A828C` (linia 4 px) |
| zajętość | `#E5483C` |
| przebieg pociągowy utwierdzony | `#38B24A` |
| przebieg manewrowy | `#D9B23C` |
| tor zamknięty | `#3D7DD8` + przekreślenia |
| zwrotnica w ruchu/bez kontroli | miganie `#E5483C`/`#101216` |
| teksty | `#D6D6D6`, font mono (JetBrains Mono / IBM Plex Mono, SIL OFL) |
| tła paneli bocznych | `#181B20`, ramki `#2A2E35` |
| alarm niekwitowany | pasek `#E5483C` migający + sygnał dźwiękowy |

Symbole: semafor = trójkącik przy torze (wypełnienie wg stanu: czerwony/zielony/
biały migający = Sz); zwrotnica = numer przy rozgałęzieniu, aktywne położenie
podświetlone; odcinki podpisane (it1, iz3) w trybie serwisowym (klawisz F9).

## 3. Interakcje

- Klik semafora → podświetlenie możliwych końców drogi (pulsujące) → klik końca →
  dialog potwierdzenia. Esc = anuluj.
- Menu kontekstowe elementu (PPM): zwrotnica: [Przestaw] [Zamknij w +] [Zamknij w −];
  semafor: [Sz] [Odwołaj sygnał]; tor: [Zamknij] [Otwórz].
- Polecenia specjalne wymagają wpisania krótkiego kodu potwierdzenia pokazanego
  w dialogu (np. „Wpisz: ZW-3" — mechanika anty-pomyłkowa), wykonania liczone.
- Rejestr zdarzeń: monospace, autoscroll z pauzą przy hover, filtr [DYŻ/SYS/ALARM].

## 4. Wygląd fizyczny stanowiska (rama ekranu)

Wokół „monitora" wąska obudowa (ciemnoszary bezel 12 px, logo fikcyjne „SNK-5"),
pod nim pasek klawiszy F1–F10 z opisami funkcji — klikalne odpowiedniki skrótów.
Dla immersji tło pokoju nastawni (nieinteraktywne, przyciemnione) za monitorem.
