extends GutTest
## Test tabeli obrazów: pełna tabela docs/04 §6 (16 kombinacji) + degradacje
## konstrukcyjne §6.1 + mapowania tarcz §6.3 (dane: data/signals/aspekty.json).

var _table: AspectTable


func before_all() -> void:
	_table = AspectTable.load_default()


func _semaphore(heads: int, green_bar: bool, orange_bar: bool) -> SignalDevice:
	var signal_device := SignalDevice.new()
	signal_device.id = &"T"
	signal_device.kind = Const.SignalKind.SEMAFOR
	signal_device.heads = heads
	signal_device.bar_green = green_bar
	signal_device.bar_orange = orange_bar
	signal_device.can_sz = true
	signal_device.can_ms2 = true
	return signal_device


func test_pelna_tabela_16_kombinacji() -> void:
	# Semafor umiejący wszystko: 2+ komory i oba pasy.
	var full := _semaphore(5, true, true)
	var expected := {
		"MAX": {"VMAX": &"S2", "V100": &"S3", "V40_60": &"S4", "STOP": &"S5"},
		"100": {"VMAX": &"S6", "V100": &"S7", "V40_60": &"S8", "STOP": &"S9"},
		"60": {"VMAX": &"S13a", "V100": &"S12a", "V40_60": &"S11a", "STOP": &"S10a"},
		"40": {"VMAX": &"S13", "V100": &"S12", "V40_60": &"S11", "STOP": &"S10"},
	}
	for v_group: String in expected:
		for next_info: String in (expected[v_group] as Dictionary):
			var want: StringName = expected[v_group][next_info]
			assert_eq(
				_table.pick(v_group, next_info, full), want,
				"v=%s, następny=%s → %s" % [v_group, next_info, want]
			)


func test_degradacja_brak_pasa_zielonego() -> void:
	# Bez pasa zielonego obrazy S6–S9 niedostępne → dwuświatłowe 40 km/h
	# (docs/systemy/11 §1, docs/04 §6.1).
	var no_bars := _semaphore(5, false, false)
	assert_eq(_table.pick("100", "VMAX", no_bars), &"S13")
	assert_eq(_table.pick("100", "STOP", no_bars), &"S10")


func test_degradacja_brak_pasa_pomaranczowego() -> void:
	var no_bars := _semaphore(5, false, false)
	assert_eq(_table.pick("60", "VMAX", no_bars), &"S13")
	assert_eq(_table.pick("60", "STOP", no_bars), &"S10")


func test_degradacja_do_s1_przy_jednej_komorze() -> void:
	# Przypadek brzegowy: jedna komora nie wyświetli obrazu dwuświatłowego,
	# a degradacja nie ma dalszych pozycji → S1.
	var one_head := _semaphore(1, false, false)
	assert_eq(_table.pick("40", "STOP", one_head), &"S1")
	assert_eq(_table.pick("MAX", "VMAX", one_head), &"S2", "jednoświatłowe dostępne")


func test_klasy_informacji() -> void:
	assert_eq(_table.info_class(&"S1"), "STOP")
	assert_eq(_table.info_class(&"S5"), "VMAX")
	assert_eq(_table.info_class(&"S9"), "V100")
	assert_eq(_table.info_class(&"S13a"), "V40_60")
	assert_eq(_table.info_class(&"Sz"), "STOP", "Sz traktowany jak stój (Os1)")
	assert_eq(_table.info_class(&"nieznany"), "STOP", "nieznany obraz ostrożnie jako stój")


func test_mapowanie_tarcz_i_powtarzaczy() -> void:
	assert_eq(_table.warning_aspect(&"S1"), &"Os1")
	assert_eq(_table.warning_aspect(&"S2"), &"Os2")
	assert_eq(_table.warning_aspect(&"S7"), &"Os3")
	assert_eq(_table.warning_aspect(&"S11"), &"Os4")
	assert_eq(_table.repeater_aspect(&"S1"), &"Sp1")
	assert_eq(_table.repeater_aspect(&"S13"), &"Sp4")
