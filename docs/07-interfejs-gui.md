# 07 — Interfejs rdzeń ↔ GUI (kontrakt dla własnego interfejsu)

Ten dokument opisuje **kompletne API rdzenia symulacji** — wszystko, czego
potrzebuje własny interfejs użytkownika. Rdzeń (katalog `core/`, czyste klasy
`RefCounted`) nie zna węzłów sceny; GUI **tylko czyta stan i wysyła
polecenia**. Istniejące widoki (`ui/pulpit_kostkowy`, `ui/nastawnia_mech`,
`ui/komputer`) są implementacjami referencyjnymi — można je podmieniać
w całości, bez zmian w rdzeniu.

## 1. Szkielet: kto czym zarządza

- **`SimWorld`** — cały stan symulacji + `tick(dt)` + `execute(polecenie)`.
  Właścicielem jest jedna scena (obecnie `ui/wspolne/main.gd`).
- **`SimClock`** (autoload) — zegar: stały tick 10 Hz czasu symulacji,
  mnożnik ×1/×2/×5, pauza. Emituje `tick(dt)`; scena właściciela woła
  wtedy `world.tick(dt)`.
- **`EventBus`** (autoload) — trzy sygnały:
  - `command(name: StringName, args: Dictionary)` — GUI → właściciel świata,
  - `command_result(command: StringName, ok: bool, reason: String)` — wynik,
  - `sim_event(type: StringName, payload: Dictionary)` — zdarzenia rdzenia.
- **`GameState`** (autoload) — scenariusz, punktacja, kary, RNG (determinizm),
  zapis/odczyt na dysk.

### Minimalny własny interfejs

```gdscript
extends Control

var world := SimWorld.new()

func _ready() -> void:
    world.load_scenario_file("res://data/scenarios/brzeziny-szczyt.json")
    GameState.new_game("brzeziny-szczyt", 0, world.start_of_day_s)
    world.rng = GameState.rng          # determinizm: jeden RNG
    EventBus.command.connect(_on_command)
    SimClock.tick.connect(_on_tick)
    SimClock.paused = false

func _on_tick(dt: float) -> void:
    world.tick(dt)
    for event: Dictionary in world.drain_events():
        EventBus.emit_sim_event(event["type"], event)  # + scoring, patrz §4
    queue_redraw()                     # odśwież swój widok ze stanu świata

func _on_command(name: StringName, args: Dictionary) -> void:
    var result := world.execute(name, args)
    EventBus.emit_command_result(name, result.ok, result.reason)
```

Uwagi:
- `drain_events()` trzeba wołać co tick — zdarzenia są jednorazowe;
  `penalty` należy przekazać do `GameState.add_penalty()` (wzór: `main.gd`,
  `_dispatch_world_events`).
- Odrzucenie polecenia (`ok == false`) to **normalna sytuacja** („urządzenie
  nie reaguje"); `reason` po polsku nadaje się wprost na komunikat.

## 2. Polecenia (`world.execute(name, args)` → `CommandResult {ok, reason}`)

### Ruchowe (wszystkie typy nastawni)

| Polecenie | Argumenty | Działanie |
|---|---|---|
| `turnout_throw` | `{id}` | przestawienie zwrotnicy (czas biegu, kontrola) |
| `route_start` | `{id: semafor}` | utwierdzenie przebiegu od semafora — **nastawianie indywidualne**: kandydat wybierany po bieżącym położeniu zwrotnic |
| `route_set` | `{id: przebieg}` | **nastawianie przebiegowe** (poziom 4+/komputer): zwrotnice układają się same, utwierdzenie po dojściu do kontroli; niepowodzenie po ułożeniu → zdarzenie `route_set_failed` |
| `signal_cancel` | `{id: semafor}` | cofnięcie przebiegu / doraźne zwolnienie z czasem ewolucji 90 s, gdy pociąg w drodze |
| `sub_signal` | `{id: semafor}` | sygnał zastępczy Sz (licznik `dSz:<id>`), świeci 90 s |
| `route_emergency_release` | `{}` | uzbrojenie dZw (10 s) — potem wskazać semafor przez `route_start` |
| `turnout_lock_toggle` | `{}` | uzbrojenie zamknięcia indywidualnego — potem wskazać zwrotnicę przez `turnout_throw` |
| `block_press` | `{id: blokada, value: "Po"/"Ko"/"Poz"}` | pola blokady półsamoczynnej (przy samoczynnej odmowa) |
| `crossing_close` / `crossing_open` | `{id}` | rogatki przejazdu kat. A (ssp odmawia — samoczynne) |
| `dsat_ack` | `{nr?}` | skwitowanie alarmu dSAT (bez nr: wszystkie) |
| `radio_stop` / `radio_release` | `{nr}` | RADIOSTOP i zwolnienie |
| `phone_send` | `{type, nr, neighbour}` | telefonogram do sąsiada; `type` ∈ `Comms.TYPES` (żądanie/danie pozwolenia, stój, oznajmienie odjazdu, potwierdzenie przyjazdu) |
| `phone_open` | `{}` | zeruje licznik nieprzeczytanych (`world.comms.unread`) |
| `order_dictate` | `{type: "S"/"O"/"N", nr, signal?}` | rozkaz pisemny — dyktowanie trwa 20 s czasu symulacji |

### Nastawnia mechaniczna (gdy `world.lever_frame != null`)

| Polecenie | Argumenty | Działanie |
|---|---|---|
| `lever_move` | `{id: dźwignia}` | przełożenie dźwigni (wymuszona kolejność) |
| `station_block_press` | `{id: blok}` | klawisz bloku stacyjnego (nakaz/zwolnienie) |

### Komputerowe polecenia dwustopniowe (gdy `world.confirm_mode == true`)

Polecenia **specjalne** (`SimWorld.SPECIAL_COMMANDS`: `sub_signal`,
`route_emergency_release`, `turnout_lock_toggle`, `radio_stop`,
`crossing_open` oraz `block_press` z `value=="Poz"`) nie wykonują się od
razu: pierwsze wywołanie zwraca odmowę „wymaga potwierdzenia", odkłada
polecenie w `world.pending_confirm` i emituje zdarzenie `confirm_required`.
GUI pokazuje okno „Wykonać? [Tak/Nie]" i wysyła:

| Polecenie | Działanie |
|---|---|
| `command_confirm` `{}` | wykonuje odłożone polecenie |
| `command_cancel` `{}` | rezygnuje |

Czas na decyzję: `SimWorld.CONFIRM_TIME_S` (30 s) — potem `confirm_expired`.
Dwustopniowość przebiegów (podgląd drogi + Tak/Nie przed `route_set`)
realizuje samo GUI — rdzeń tego nie wymusza.

### Debug

| Polecenie | Argumenty |
|---|---|
| `debug_section_occupied` | `{id, value: "0"/"1"}` — ręczna zajętość sekcji |

## 3. Stan do czytania (odświeżaj po każdym ticku)

Wszystko poniżej to zwykłe pola/gettery — czytać wolno, **pisać nie**.

| Co | Gdzie | Uwagi |
|---|---|---|
| sekcje | `world.station.graph.sections[id]` | `.occupied`, `.is_locked()`, `.locked_by`, `.type` |
| zwrotnice | `world.station.graph.turnouts[id]` | `.state` (PLUS/MINUS/MOVING/NO_CONTROL/TRAILED), `.is_plus()`, `.has_control()`, `.closed_individually`, `.locked_by` |
| sygnalizatory | `world.station.graph.signals[id]` | `.aspect` (S1…S13a, Sz, Ms1/2, Sr1–3, Os, Sp), `.shows_stop()`, `.kind`, `.failed`, `.sbl` |
| przebiegi | `world.interlocking.routes[id]` | `.state` (`Const.RouteState`, nazwa: `Const.route_state_name()`), `.entry_signal`, `.target`, `.sections` |
| nastawianie przebiegowe | `world.interlocking.pending_route_id` | `&""` = nic się nie układa |
| liczniki plombowane | `world.interlocking.counters` | np. `"dSz:A"`, `"dZw"` |
| blokady liniowe | `world.block_lines[id]` | `.automatic`, `.occupied`, `.failed`, `.permission_at`, `.po_locked`, `.odstepy`, aspekty semaforów odstępowych przez graf |
| przejazdy | `world.crossings[id]` | `.state` + `LevelCrossing.STATE_NAMES`, `.is_automatic()`, `.requires_caution()` |
| dSAT | `world.dsats[id]`, `world.dsat_unacked()` | lampka alarmu do skwitowania |
| pociągi | `world.trains` (Array[Train]) | `.nr`, `.front_m`, `.rear_m()`, `.v_ms`, `.phase`, `.eastbound`, `.covered_sections()`, `.radio_hold` |
| rozkład | `world.timetable.entries` | `Timetable.Entry`: `.nr`, `.arr_s`, `.dep_s`, `.track`, `.spawned` |
| telefonogramy | `world.comms.log`, `world.comms.unread` | `Comms.Message`; formuły: `Comms.format_message()` |
| dziennik ruchu | `world.train_log.entries` | układ R-142 (docs/systemy/18 §3) |
| rozkazy pisemne | `world.orders` | `{no, type, nr, signal, left_s, active}` |
| rejestr zdarzeń | `world.register.entries`, `.last(n)` | linia: `EventRegister.format_line(entry)` |
| polecenie odłożone | `world.pending_confirm` | `{name, args}` albo `{}` |
| czas | `world.time_of_day_s()`, `world.sim_time` | sekundy doby / od startu |
| punktacja | `GameState.score`, `GameState.penalties` | scoring v1 (docs/05 §7) |
| typ nastawni | `world.lever_frame != null` → mechaniczna; `world.confirm_mode` → komputerowa; inaczej pulpit | z pola `panel.type` stacji |
| plan stacji | `world.station.panel` | siatka kafelków (docs/03 §5) — geometria do rysowania planu |

## 4. Zdarzenia (`drain_events()` / `EventBus.sim_event`)

Każde zdarzenie to `Dictionary` z kluczem `type` (StringName); pola tekstowe
gotowe do pokazania graczowi.

| `type` | Pola | Znaczenie / oczekiwana reakcja GUI |
|---|---|---|
| `penalty` | `points, reason` | kara scoringu → `GameState.add_penalty()` + komunikat |
| `alarm` | `text` | ważny komunikat (usterki, oględziny, awarie) |
| `phone_ring` | `nr?, text?` | przyszedł telefonogram — dzwonek, migająca słuchawka |
| `dsat_report` | `text, nr` | przejazd przez dSAT „bez usterek" |
| `dsat_alarm` | `text, nr, code, level` | ALARM dSAT — migająca lampka do `dsat_ack` |
| `shift_end` | — | koniec służby → podsumowanie z `GameState` |
| `route_set_failed` | `route, reason, text` | nastawianie przebiegowe nie doszło do skutku |
| `confirm_required` | `command, args, text` | pokazać okno „Wykonać? [Tak/Nie]" |
| `confirm_expired` | `command, text` | okno zamknąć — polecenie wygasło |
| `timetable_add` | `nr, text` | generator dołożył pociąg do rozkładu |

## 5. Zapis / odczyt / scenariusze

- `GameState.save_game(world)` → `user://saves/<scenariusz>.json`;
  `GameState.load_game(world)` wczytuje do działającego świata **tego samego
  scenariusza** (pełny stan: pociągi w drodze, procedury, RNG — po wczytaniu
  symulacja biegnie identycznie). `GameState.has_save(id)` do menu.
- Nowa stacja/scenariusz = **tylko pliki JSON** w `data/stations/` i
  `data/scenarios/` (format: docs/03-model-danych.md). Tryb swobodny:
  sekcja `generator` w scenariuszu (przykład: `brzeziny-swobodny.json`).
- Sterowanie czasem: `SimClock.paused`, `SimClock.set_multiplier(1/2/5)`,
  `SimClock.toggle_paused()`.

## 6. Jak podmienić widok

W `main.gd` widok wybierany jest po typie panelu stacji i musi spełniać
tylko dwa warunki: mieć metodę `refresh()` (wołaną po ticku) i wysyłać
polecenia (bezpośrednio `EventBus.send_command` albo sygnałem do sceny).
Własny widok wystarczy podstawić w `_start_scenario` — rdzeń pozostaje
bez zmian. Konwencję barw planu komputerowego opisuje docs/systemy/14 §2
(w widoku referencyjnym nieużyta — patrz WERYFIKACJA.md poz. 25).
