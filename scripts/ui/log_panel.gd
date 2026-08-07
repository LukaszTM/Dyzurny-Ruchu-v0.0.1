class_name LogPanel
extends VBoxContainer
## Dziennik ruchu dyżurnego: wpisy automatyczne + ręczne, zapis do pliku.

var sim = null
var rtl: RichTextLabel
var input: LineEdit
var info: Label


func setup(p_sim) -> void:
	sim = p_sim
	rtl = RichTextLabel.new()
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.scroll_following = true
	rtl.bbcode_enabled = true
	rtl.add_theme_font_size_override("normal_font_size", 12)
	add_child(rtl)
	var hb := HBoxContainer.new()
	input = LineEdit.new()
	input.placeholder_text = "Własny wpis do dziennika…"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(func(_t): _add_manual())
	hb.add_child(input)
	var btn := Button.new()
	btn.text = "Dodaj"
	btn.pressed.connect(_add_manual)
	hb.add_child(btn)
	add_child(hb)
	var hb2 := HBoxContainer.new()
	var save_btn := Button.new()
	save_btn.text = "Zapisz do pliku"
	save_btn.pressed.connect(func():
		var path: String = sim.dlog.save_to_file()
		info.text = "Zapisano: %s" % path if path != "" else "Błąd zapisu!")
	hb2.add_child(save_btn)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 11)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb2.add_child(info)
	add_child(hb2)
	EventBus.log_added.connect(_on_entry)
	for e in sim.dlog.entries:
		_on_entry(e)


func _add_manual() -> void:
	var txt := input.text.strip_edges()
	if txt == "":
		return
	sim.dlog.add(sim.sim_time, "Dyżurny", txt)
	input.text = ""


func _on_entry(e: Dictionary) -> void:
	if not is_instance_valid(rtl):
		return
	var cat_col := "9aa7b8"
	match str(e["cat"]):
		"Zdarzenie":
			cat_col = "f59e0b"
		"Dyżurny":
			cat_col = "22d3ee"
		"Przebieg":
			cat_col = "37d67a"
	rtl.append_text("[color=#5b6675]%s[/color] [color=#%s][%s][/color] %s\n" % [
		SimUtil.fmt_time(e["t"]), cat_col, e["cat"], str(e["text"])])
