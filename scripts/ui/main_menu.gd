extends Control
## Menu główne — wybór posterunku i trybu pracy.

var loc_opt: OptionButton
var loc_desc: Label
var settings_dialog: SettingsDialog


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("070a0e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(620, 0)
	center.add_child(vb)

	var title := Label.new()
	title.text = "DYŻURNY RUCHU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color("22c55e"))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Symulator Lokalnego Centrum Sterowania"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", UICommon.COL_SZARY)
	vb.add_child(sub)
	vb.add_child(HSeparator.new())

	var ll := Label.new()
	ll.text = "Posterunek ruchu:"
	vb.add_child(ll)
	loc_opt = OptionButton.new()
	for loc in Locations.locations:
		loc_opt.add_item(str(loc.get("name", "?")))
	if loc_opt.item_count == 0:
		loc_opt.add_item("BRAK ZAINSTALOWANYCH LOKALIZACJI")
		loc_opt.disabled = true
	loc_opt.item_selected.connect(func(_i): _update_desc())
	vb.add_child(loc_opt)
	loc_desc = UICommon.small("")
	vb.add_child(loc_desc)
	_update_desc()
	vb.add_child(HSeparator.new())

	_btn(vb, "▶   RUCH WG ROZKŁADU JAZDY",
		"Prowadzenie ruchu zgodnie z rozkładem; opóźnienia aktualizowane online.",
		func(): _start(GameState.MODE_TIMETABLE))
	_btn(vb, "▶   RUCH LOSOWY",
		"Pociągi generowane losowo; natężenie ruchu ustawiasz w Ustawieniach.",
		func(): _start(GameState.MODE_RANDOM))
	_btn(vb, "🎓   TRYB NAUKI",
		"Samouczek krok po kroku: zapowiadanie, przebiegi, EDR, usterki, manewry.",
		func(): _start(GameState.MODE_TUTORIAL))
	_btn(vb, "⚙   USTAWIENIA",
		"Rozdzielczość, natężenie ruchu, praca manewrowa, zdarzenia, aktualizacje online.",
		func(): settings_dialog.popup_centered())
	_btn(vb, "✕   ZAKOŃCZ", "", func(): get_tree().quit())

	var ver := Label.new()
	ver.text = "wersja 0.1.0 — silnik Godot 4"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color("475261"))
	vb.add_child(ver)

	settings_dialog = SettingsDialog.new()
	add_child(settings_dialog)


func _btn(parent: VBoxContainer, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	parent.add_child(b)


func _update_desc() -> void:
	if Locations.locations.is_empty():
		loc_desc.text = ""
		return
	loc_desc.text = str(Locations.locations[loc_opt.selected].get("description", ""))


func _start(mode: String) -> void:
	if Locations.locations.is_empty():
		return
	GameState.start_simulation(mode, str(Locations.locations[loc_opt.selected].get("id", "")))
