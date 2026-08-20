extends GutTest
## Testy zegara symulacji (autoload/sim_clock.gd): stały tick 10 Hz,
## mnożnik ×1/×2/×5, pauza, akumulacja resztek delty.

const SimClockScript := preload("res://autoload/sim_clock.gd")

var _clock: Node
var _received_ticks: int = 0
var _received_dts: Array[float] = []


func before_each() -> void:
	_clock = SimClockScript.new()
	_received_ticks = 0
	_received_dts.clear()
	_clock.tick.connect(_on_tick)


func after_each() -> void:
	_clock.free()


func _on_tick(dt: float) -> void:
	_received_ticks += 1
	_received_dts.append(dt)


func test_one_second_realtime_gives_ten_ticks() -> void:
	var done: int = _clock.advance_real_time(1.0)
	assert_eq(done, 10, "1 s czasu rzeczywistego przy ×1 = 10 tickow")
	assert_eq(_received_ticks, 10, "sygnal tick emitowany przy kazdym ticku")
	assert_almost_eq(_clock.sim_time, 1.0, 0.0001, "czas symulacji narasta o TICK_DT")


func test_tick_dt_is_constant() -> void:
	_clock.advance_real_time(0.35)
	for dt: float in _received_dts:
		assert_almost_eq(dt, 0.1, 0.0001, "dt kazdego ticku rowne TICK_DT")


func test_multiplier_scales_sim_time() -> void:
	assert_true(_clock.set_multiplier(5), "x5 jest dozwolone")
	var done: int = _clock.advance_real_time(1.0)
	assert_eq(done, 50, "1 s czasu rzeczywistego przy x5 = 50 tickow")
	assert_almost_eq(_clock.sim_time, 5.0, 0.0001)


func test_invalid_multiplier_rejected() -> void:
	assert_false(_clock.set_multiplier(3), "x3 spoza listy dozwolonych")
	assert_eq(_clock.multiplier, 1, "mnoznik bez zmian po odrzuceniu")


# Przypadek brzegowy 1: delta mniejsza niz tick nie gubi czasu —
# resztki akumuluja sie do pelnego ticku.
func test_small_deltas_accumulate_without_loss() -> void:
	for i: int in range(10):
		_clock.advance_real_time(0.03)
	# 10 x 0,03 s = 0,3 s -> dokladnie 3 ticki
	assert_eq(_received_ticks, 3, "0,3 s po kawalku 0,03 s = 3 ticki")
	assert_almost_eq(_clock.sim_time, 0.3, 0.0001)


# Przypadek brzegowy 2: bezpiecznik MAX_TICKS_PER_FRAME ogranicza nadrabianie
# po bardzo dlugiej klatce (np. zawieszenie okna).
func test_catchup_capped_per_frame() -> void:
	var done: int = _clock.advance_real_time(100.0)
	assert_eq(done, _clock.MAX_TICKS_PER_FRAME, "jedna klatka nie wykona wiecej tickow niz limit")


func test_reset_zeroes_state() -> void:
	_clock.set_multiplier(5)
	_clock.advance_real_time(2.0)
	_clock.reset()
	assert_eq(_clock.tick_count, 0)
	assert_almost_eq(_clock.sim_time, 0.0, 0.0001)
	assert_eq(_clock.multiplier, 1)
	assert_false(_clock.paused)
