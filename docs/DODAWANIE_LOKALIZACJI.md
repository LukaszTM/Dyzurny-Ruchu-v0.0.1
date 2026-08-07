# Dodawanie nowej lokalizacji

Posterunki opisane są wyłącznie danymi — nowa stacja nie wymaga zmian
w kodzie. Wystarczy katalog `data/locations/<id>/` z trzema plikami JSON.

## 1. `location.json`

```json
{
  "id": "moja_stacja",
  "name": "Moja Stacja",
  "short": "MST",
  "layout": "layout.json",
  "timetable": "timetable.json",
  "start_time_random": "12:00",
  "description": "Opis widoczny w menu."
}
```

## 2. `layout.json` — układ torowy

**Zasady, których musi przestrzegać układ:**

- każdy odcinek (`segments`) prowadzi z **zachodu na wschód**
  (`x` punktu `from` musi być mniejsze niż `x` punktu `to`);
  jazda w kierunku wschodnim ma `dir = 1`, w zachodnim `dir = -1`,
- **rozjazd** ma dokładnie trzy odgałęzienia: `root` (od strony iglic) oraz
  `plus` (położenie zasadnicze) i `minus` (położenie zwrotne). Jazda przez
  rozjazd możliwa jest wyłącznie `root ↔ plus` albo `root ↔ minus`,
- punkt niebędący rozjazdem może mieć najwyżej dwa odgałęzienia,
- sygnalizator nie może stać na rozjeździe.

Sekcje pliku:

| Sekcja | Zawartość |
|---|---|
| `points` | punkty schematu: `{id, x, y}` (px, oś X rośnie na wschód) |
| `segments` | odcinki: `{id, from, to, kind}`; `kind`: `tor`, `stacyjny`, `szlak` |
| `switches` | rozjazdy: `{id (numer), point, root, plus, minus}` |
| `signals` | sygnalizatory: `{id, point, dir, typ, opis}`; `typ`: `wjazdowy`, `wyjazdowy`, `manewrowy` |
| `tarcze_ostrzegawcze` | elementy rysunkowe na szlaku: `{id, sem, x, y, km}` |
| `line_ends` | przyciski szlaków: `{id, name, dir_in, lk, kind, tor}`; `kind`: `pociagowy` albo `manewrowy` |
| `tracks` | tory stacyjne: `{nr, seg, a, b, peron, dl}` |
| `platforms`, `labels` | elementy opisowe schematu |

**Nazewnictwo sygnalizatorów** (konwencja PKP zastosowana w grze):
semafory wjazdowe — pojedyncze litery (A, B, C, D, P, R, S, T);
semafory wyjazdowe — litera kierunku + numer toru (K1…K8 na zachód,
N1…N8 na wschód); tarcze manewrowe — Tm1, Tm2, …

**Generator.** Ręczne pisanie układu jest podatne na błędy, dlatego układ
Warszawy Wschodniej powstaje skryptem `tools/build_layout_wws.py`, który
sprawdza wszystkie powyższe zasady i dopiero wtedy zapisuje `layout.json`:

```bash
python3 tools/build_layout_wws.py
```

Najprościej skopiować ten skrypt i przerobić na własną stację — walidacja
zgłosi każdy błąd struktury (zły kierunek odcinka, rozjazd o innej liczbie
odgałęzień, sygnalizator na rozjeździe).

## 3. `timetable.json` — rozkład jazdy

```json
{
  "start_time": "04:45",
  "entries": [
    {"nr": "5100", "kat": "EIE", "nazwa": "Podlasiak",
     "z": "W-wa Zachodnia", "do": "Białystok",
     "we": "it1D", "wy": "it1R", "tor": "5",
     "przyjazd": "05:04", "odjazd": "05:07", "postoj": 3}
  ]
}
```

Pola `we` i `wy` to **identyfikatory przycisków szlaków** z `layout.json`.

Pola specjalne wiersza:

- `"przelot": true` — przejazd bez zatrzymania,
- `"koniec": true` — pociąg kończy bieg; skład trzeba odstawić manewrowo
  (pole `wy` wskazuje szlak techniczny),
- `"start": true` — pociąg rozpoczyna bieg; najpierw trzeba podstawić skład
  manewrowo z posterunku wskazanego w `we`,
- `"opoznienie": <min>` — opóźnienie początkowe.

Rodzaje pociągów (`kat`) wg wykazu PKP: `EIP`, `EIE`, `MPE`, `MOE`, `ROJ`,
`AOE`, `TDE`, `TME`, `PWE`, `LPE` oraz `MAN` (jazda manewrowa).

## 4. Łączność

Posterunki zapowiadawcze tworzone są automatycznie na podstawie pola `name`
w `line_ends` — szlaki o tej samej nazwie należą do jednego posterunku.
Szlak z `"kind": "manewrowy"` staje się posterunkiem technicznym (bez
zapowiadania, tylko jazdy manewrowe).

## 5. Aktualizacje online

Rozkład i opóźnienia można serwować z dowolnego adresu HTTP (JSON w tym
samym formacie; opóźnienia: `{"delays": [{"nr": "5100", "delay_min": 5}]}`).
Adresy ustawia się w Ustawieniach gry.

Po dodaniu katalogu lokalizacja pojawi się w menu automatycznie.
