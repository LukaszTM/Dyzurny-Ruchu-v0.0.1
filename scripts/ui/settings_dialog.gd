class_name SettingsDialog
extends AcceptDialog
## Okno ustawień: rozdzielczość, tryb okna, VSync, adresy aktualizacji
## online, autozapis dziennika.

var res_opt: OptionButton
var mode_opt: OptionButton
var vsync_check: CheckBox
var online_check: CheckBox
var url_delays_edit: LineEdit
var url_tt_edit: LineEdit
var autosave_check: CheckBox


func _init() -> void:
	title = "Ustawienia"
	ok_button_text = "Zapisz i zastosuj"
	min_size = Vector2i(620, 560)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14.0
	vb.offset_top = 14.0
	vb.offset_right = -14.0
	vb.offset_bottom = -56.0

	vb.add_child(_header("Ekran"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_child(_label("Rozdzielczość:"))
	res_opt = OptionButton.new()
	for r in Settings.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	grid.add_child(res_opt)
	grid.add_child(_label("Tryb okna:"))
	mode_opt = OptionButton.new()
	for n in Settings.WINDOW_MODE_NAMES:
		mode_opt.add_item(n)
	grid.add_child(mode_opt)
	grid.add_child(_label("Synchronizacja pionowa:"))
	vsync_check = CheckBox.new()
	vsync_check.text = "VSync"
	grid.add_child(vsync_check)
	vb.add_child(grid)

	vb.add_child(_header("Aktualizacje online (rozkład i opóźnienia)"))
	online_check = CheckBox.new()
	online_check.text = "Pobieraj rozkład jazdy i opóźnienia z sieci"
	vb.add_child(online_check)
	vb.add_child(_label("Adres opóźnień (JSON):"))
	url_delays_edit = LineEdit.new()
	vb.add_child(url_delays_edit)
	vb.add_child(_label("Adres rozkładu jazdy (JSON):"))
	url_tt_edit = LineEdit.new()
	vb.add_child(url_tt_edit)

	vb.add_child(_header("Dziennik ruchu"))
	autosave_check = CheckBox.new()
	autosave_check.text = "Automatyczny zapis dziennika przy wyjściu"
	vb.add_child(autosave_check)

	add_child(vb)
	confirmed.connect(_apply)
	about_to_popup.connect(_sync)


func _header(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color("22d3ee"))
	return l


func _label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	return l


func _sync() -> void:
	var idx := 2
	for i in range(Settings.RESOLUTIONS.size()):
		if Settings.RESOLUTIONS[i] == Settings.resolution:
			idx = i
			break
	res_opt.select(idx)
	mode_opt.select(Settings.window_mode)
	vsync_check.button_pressed = Settings.vsync
	online_check.button_pressed = Settings.online_enabled
	url_delays_edit.text = Settings.url_delays
	url_tt_edit.text = Settings.url_timetable
	autosave_check.button_pressed = Settings.autosave_log


func _apply() -> void:
	Settings.resolution = Settings.RESOLUTIONS[res_opt.selected]
	Settings.window_mode = mode_opt.selected
	Settings.vsync = vsync_check.button_pressed
	Settings.online_enabled = online_check.button_pressed
	Settings.url_delays = url_delays_edit.text.strip_edges()
	Settings.url_timetable = url_tt_edit.text.strip_edges()
	Settings.autosave_log = autosave_check.button_pressed
	Settings.save_cfg()
	Settings.apply()
