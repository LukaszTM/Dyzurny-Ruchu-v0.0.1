extends Node
## Zegar symulacji wg docs/02-architektura.md ("Pętla symulacji").
## Akumuluje delta czasu rzeczywistego i wywołuje stały tick 10 Hz czasu
## symulacji (TICK_DT = 0,1 s), niezależnie od FPS. Mnożnik czasu ×1/×2/×5,
## pauza zatrzymuje tylko symulację, nie UI.
##
## Logika akumulacji jest w publicznej metodzie advance_real_time(), dzięki
## czemu testy GUT mogą ją wywoływać deterministycznie bez drzewa scen.

## Emitowany co 0,1 s czasu symulacji; dt zawsze równe TICK_DT.
signal tick(dt: float)
## Emitowany po zmianie mnożnika czasu.
signal multiplier_changed(multiplier: int)
## Emitowany po wstrzymaniu/wznowieniu symulacji.
signal paused_changed(paused: bool)

## Długość jednego ticku w sekundach czasu symulacji (10 Hz).
const TICK_DT: float = 0.1
## Dozwolone mnożniki czasu (CLAUDE.md, zasada 5).
const ALLOWED_MULTIPLIERS: Array[int] = [1, 2, 5]
## Bezpiecznik: górny limit ticków nadrabianych w jednej klatce
## (chroni przed spiralą śmierci po zawieszeniu okna).
const MAX_TICKS_PER_FRAME: int = 50
## Tolerancja błędu zmiennoprzecinkowego akumulatora — bez niej suma wielu
## małych delt (np. 10 × 0,03 s) potrafi wypaść włos poniżej progu ticku.
const ACCUMULATOR_EPSILON: float = 1e-9

## Czas symulacji w sekundach od startu scenariusza.
var sim_time: float = 0.0
## Liczba wykonanych ticków od startu scenariusza.
var tick_count: int = 0
## Bieżący mnożnik czasu.
var multiplier: int = 1
## Czy symulacja jest wstrzymana.
var paused: bool = false

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	advance_real_time(delta)


## Przesuwa symulację o real_delta sekund czasu rzeczywistego (z mnożnikiem).
## Zwraca liczbę wykonanych ticków. Publiczna dla testów GUT.
func advance_real_time(real_delta: float) -> int:
	_accumulator += real_delta * float(multiplier)
	var ticks_done: int = 0
	while _accumulator >= TICK_DT - ACCUMULATOR_EPSILON and ticks_done < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_DT
		tick_count += 1
		# Czas wyliczany z liczby ticków, nie sumowany — zero dryfu float.
		sim_time = float(tick_count) * TICK_DT
		ticks_done += 1
		tick.emit(TICK_DT)
	return ticks_done


## Ustawia mnożnik czasu; wartości spoza ALLOWED_MULTIPLIERS są odrzucane.
func set_multiplier(value: int) -> bool:
	if value not in ALLOWED_MULTIPLIERS:
		push_warning("SimClock: niedozwolony mnożnik czasu: %d" % value)
		return false
	if multiplier != value:
		multiplier = value
		multiplier_changed.emit(multiplier)
	return true


## Wstrzymuje/wznawia symulację (UI działa dalej).
func set_paused(value: bool) -> void:
	if paused != value:
		paused = value
		paused_changed.emit(paused)


## Przełącza pauzę (skrót klawiszowy w UI).
func toggle_paused() -> void:
	set_paused(not paused)


## Zeruje zegar (nowy scenariusz).
func reset() -> void:
	sim_time = 0.0
	tick_count = 0
	_accumulator = 0.0
	set_paused(false)
	set_multiplier(1)
