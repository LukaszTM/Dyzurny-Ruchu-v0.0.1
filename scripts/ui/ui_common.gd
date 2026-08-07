class_name UICommon
extends RefCounted
## Wspólne elementy interfejsu ekranów pomocniczych.

const COL_TLO := Color("0b0f14")
const COL_AKCENT := Color("00c8d7")
const COL_TEKST := Color("d7dee8")
const COL_SZARY := Color("8b96a5")


static func make_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = COL_TLO
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Nagłówek ekranu: powrót do pulpitu, tytuł, zegar. Zwraca pasek do rozbudowy.
static func make_header(parent: Control, title: String, sim) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.text = "◀  PULPIT  (Esc)"
	back.pressed.connect(func(): GameState.back_to_panel())
	hb.add_child(back)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_AKCENT)
	hb.add_child(lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var post := Label.new()
	post.text = "%s   •   dyżurny ruchu: %s" % [
		sim.layout.station_name if sim != null else "", Settings.dyzurny_name]
	post.add_theme_color_override("font_color", COL_SZARY)
	hb.add_child(post)
	var clock := Label.new()
	clock.name = "Zegar"
	clock.add_theme_font_size_override("font_size", 22)
	clock.add_theme_color_override("font_color", Color("22c55e"))
	hb.add_child(clock)
	panel.add_child(hb)
	parent.add_child(panel)
	return hb


static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", COL_AKCENT)
	return l


static func small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_SZARY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
