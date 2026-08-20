# 03 — Model danych stacji (JSON)

Stacja = graf torowy + urządzenia + tabela przebiegów + opis pulpitu. Wzorcowy plik:
`data/stacja-przyklad.json` (mijanka „Borki" — używana w Fazach 1–5).

## 1. Graf torowy

- **node** — punkt łączenia torów: koniec toru, styk odcinków, początek rozjazdu.
  `{"id": "n1"}` (współrzędne tylko w sekcji `panel`, rdzeń ich nie potrzebuje).
- **edge** — odcinek toru między dwoma węzłami:
  `{"id": "e_t1a", "from": "n2", "to": "n3", "len_m": 350, "vmax_kmh": 100}`
- **turnout** — zwrotnica jako węzeł z trzema krawędziami:
  ```json
  {"id": "z1", "node": "n2", "edge_root": "e_wjazd",
   "edge_plus": "e_t1a", "edge_minus": "e_z1z2",
   "throw_time_s": 6, "v_minus_kmh": 40}
  ```
  Położenia: `PLUS` (zasadnicze, zwykle na wprost) / `MINUS` (zwrotne, jazda w bok
  z ograniczeniem `v_minus_kmh` — 40, a dla rozjazdów łagodnych 60 lub 100).
  Stany dodatkowe: `MOVING` (brak kontroli w czasie przestawiania), `NO_CONTROL`
  (usterka), `TRAILED` (rozprucie).
- **section** — odcinek izolowany (kontrola niezajętości) grupujący krawędzie:
  `{"id": "it1", "edges": ["e_t1a", "e_t1b"], "type": "track"}`
  typy: `track` (torowy), `turnout` (zwrotnicowy — zawiera rozjazd), `approach`
  (zbliżania, na szlaku przed semaforem wjazdowym).
- Kierunki: krawędź ma orientację `from→to = kierunek N` (nieparzysty), przeciwny = `P`.

## 2. Sygnalizatory

```json
{"id": "A", "kind": "semafor", "at_node": "n1", "dir": "N",
 "heads": 5, "bar_green": false, "bar_orange": false,
 "can_ms2": true, "can_sz": true,
 "tarcza_ostrzegawcza": "ToA"}
```
- `kind`: `semafor` | `tarcza_manewrowa` | `tarcza_ostrzegawcza` | `powtarzacz` |
  `semafor_ksztaltowy` | `tarcza_zaporowa` | `top` (tarcza ostrzeg. przejazdowa).
- `heads`/paski określają, jakie obrazy sygnalizator umie fizycznie wyświetlić —
  rdzeń wybiera obraz wg `docs/04-logika-zaleznosci.md §6`, ale nie może wybrać
  obrazu niedostępnego dla danej konstrukcji (patrz `data/signals/aspekty.json`).
- Nazewnictwo semaforów jak na PKP: wjazdowe A, B...; wyjazdowe C1, D2... (litera +
  numer toru); tarcze manewrowe Tm1, Tm2...

## 3. Tabela przebiegów (route table)

Przebiegi definiowane jawnie (jak w rzeczywistej tablicy zależności):
```json
{"id": "A_t1", "class": "train", "entry_signal": "A", "target": "t1",
 "exit_signal": "C1",
 "sections": ["iza", "it1"],
 "turnouts": {"z1": "PLUS"},
 "flank": {"z2": "MINUS", "signals_at_stop": ["Tm3"]},
 "overlap": {"sections": ["ij2"], "turnouts": {"z3": "PLUS"}, "release_s": 90},
 "v_route_kmh": 100,
 "conflicts": ["B_t1", "C1_out", "man_5"]}
```
- `class`: `train` (pociągowy) / `shunt` (manewrowy — bez drogi ochronnej,
  sygnał Ms2, łagodniejsze warunki wg `04 §7`).
- `flank` — ochrona boczna: wymagane położenia zwrotnic ochronnych, wykolejnic
  i sygnalizatorów osłaniających na „stój".
- `overlap` — droga ochronna za semaforem końcowym (dla przebiegów wjazdowych).
- `conflicts` — jawna lista przebiegów sprzecznych (generator w edytorze może to
  wyliczać, ale plik ma listę jawną — jak w tablicy zależności).
- `v_route_kmh` — prędkość drogą przebiegu (decyduje o grupie obrazu sygnałowego:
  max/100/60/40).

## 4. Blokady, przejazdy, dSAT

```json
"blocks": [{"id": "blk_lipno", "type": "polsamoczynna",
            "neighbour": "Lipno", "track": "szlak1",
            "entry_signal": "A", "exit_signals": ["C1", "C2"]}],
"crossings": [{"id": "przA", "type": "kat_A_rogatki",
               "close_time_s": 25, "on_sections": ["it1"]}],
"dsat": [{"id": "dsat1", "on_edge": "e_szlak_km34", "types": ["GM","GH","PM"]}]
```
Typy blokad: `polsamoczynna` | `samoczynna_3staw` | `samoczynna_4staw` |
`elektromechaniczna` | `telefoniczne_zapowiadanie` (brak blokady).

## 5. Opis pulpitu (`panel`)

Warstwa prezentacji: siatka kostek i mapowanie elementów UI → obiekty rdzenia.
```json
"panel": {"type": "kostkowy", "grid": [24, 10], "tiles": [
   {"xy": [3,4], "tile": "track_h", "section": "it1"},
   {"xy": [5,4], "tile": "turnout_ne", "turnout": "z1", "label": "1"},
   {"xy": [2,4], "tile": "signal_n", "signal": "A", "button": {"id": "przA",
      "actions": {"press": "route_start", "pull": "signal_cancel"}}},
   {"xy": [20,8], "tile": "counter_button", "label": "dSz C1",
      "actions": {"press": "sub_signal:C1"}, "counter": true, "sealed": true}
]}
```
Zestaw kafelków i wygląd: `assets-spec/20-pulpit-kostkowy-wyglad.md`.
Dla nastawni mechanicznej `panel.type = "mechaniczny"` z listą dźwigni i bloków;
dla komputerowych `panel.type = "komputer"` (plan generowany z grafu + współrzędne).

## 6. Scenariusz (`data/scenarios/*.json`)

```json
{"station": "borki", "start_time": "05:40", "duration_min": 240,
 "difficulty": {"auto_docs": true, "hints": true},
 "timetable": [
   {"nr": "5321", "kind": "osobowy", "from": "Lipno", "to": "Suchowola",
    "arr": "06:02", "dep": "06:03", "track": "t1", "stop": true,
    "len_m": 120, "vmax_kmh": 100, "mass_t": 180, "power_class": "EZT"}],
 "events": [
   {"at": "06:40", "type": "turnout_no_control", "target": "z2"},
   {"at": "random", "window": ["07:00","09:00"], "p": 0.5,
    "type": "dsat_alarm", "payload": {"code": "GM", "axle": 14}}]}
```

## 7. Walidacja

Loader (`core/station_loader.gd`) waliduje: spójność grafu, kompletność sekcji,
czy każdy przebieg ma rozłączne/istniejące elementy, czy konflikty są symetryczne.
Błąd walidacji = czytelny komunikat z id elementu (kluczowe dla moderów).
