extends Control
## Menu główne: wybór lokalizacji, trybu gry (losowy / rozkładowy /
## samouczek), ustawienia i wyjście.

var loc_opt: OptionButton
var loc_desc: Label
var settings_dialog: SettingsDialog


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c1117")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(560, 0)
	center.add_child(vb)

	var title := Label.new()
	title.text = "DYŻURNY RUCHU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("2ee56b"))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Symulator Lokalnego Centrum Sterowania"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("9aa7b8"))
	vb.add_child(subtitle)

	vb.add_child(HSeparator.new())

	var loc_lbl := Label.new()
	loc_lbl.text = "Posterunek (lokalizacja):"
	vb.add_child(loc_lbl)
	loc_opt = OptionButton.new()
	for loc in Locations.locations:
		loc_opt.add_item(str(loc.get("name", "?")))
	if loc_opt.item_count == 0:
		loc_opt.add_item("BRAK LOKALIZACJI")
		loc_opt.disabled = true
	loc_opt.item_selected.connect(func(_i): _update_desc())
	vb.add_child(loc_opt)
	loc_desc = Label.new()
	loc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loc_desc.add_theme_font_size_override("font_size", 12)
	loc_desc.add_theme_color_override("font_color", Color("6d7889"))
	vb.add_child(loc_desc)
	_update_desc()

	vb.add_child(HSeparator.new())

	_add_button(vb, "▶  Ruch wg rozkładu jazdy",
		"Prowadź ruch zgodnie z rozkładem — z opóźnieniami aktualizowanymi online.",
		func(): _start(GameState.MODE_TIMETABLE))
	_add_button(vb, "▶  Ruch losowy",
		"Losowo generowane pociągi — natężenie ruchu regulujesz w trakcie gry.",
		func(): _start(GameState.MODE_RANDOM))
	_add_button(vb, "🎓  Tryb nauki (samouczek)",
		"Krok po kroku: przebiegi, dziennik, sygnał zastępczy, manewry.",
		func(): _start(GameState.MODE_TUTORIAL))
	_add_button(vb, "⚙  Ustawienia",
		"Rozdzielczość, tryb okna, adresy aktualizacji online.",
		func(): settings_dialog.popup_centered())
	_add_button(vb, "✕  Zakończ", "", func(): get_tree().quit())

	var ver := Label.new()
	ver.text = "wersja 0.0.1 — silnik Godot 4"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color("475261"))
	vb.add_child(ver)

	settings_dialog = SettingsDialog.new()
	add_child(settings_dialog)


func _add_button(parent: VBoxContainer, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	parent.add_child(b)


func _update_desc() -> void:
	if Locations.locations.is_empty():
		loc_desc.text = ""
		return
	var loc: Dictionary = Locations.locations[loc_opt.selected]
	loc_desc.text = str(loc.get("description", ""))


func _start(mode: String) -> void:
	if Locations.locations.is_empty():
		return
	var loc: Dictionary = Locations.locations[loc_opt.selected]
	GameState.start_simulation(mode, str(loc.get("id", "")))
