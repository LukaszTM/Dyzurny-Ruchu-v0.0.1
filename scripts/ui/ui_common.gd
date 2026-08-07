class_name UICommon
extends RefCounted
## Wspólne elementy interfejsu.

const COL_TLO := Color("0b0f14")
const COL_AKCENT := Color("00c8d7")
const COL_TEKST := Color("d7dee8")
const COL_SZARY := Color("8b96a5")

# paleta wykazu pociągów (jasny styl jak w SimRail)
const WYK_TLO := Color("f2f1e6")
const WYK_WIERSZ := Color("fdfbd0")
const WYK_WIERSZ2 := Color("f6f4c8")
const WYK_ZAZN := Color("7a1f7a")
const WYK_HDR_OLIWKA := Color("8a8a4a")
const WYK_HDR_CZERW := Color("8b1a1a")
const WYK_HDR_CYJAN := Color("3a8ca0")
const WYK_HDR_ZIEL := Color("4a7c4e")
const WYK_HDR_ZOLTY := Color("b8b83a")
const WYK_HDR_FIOLET := Color("5f5f8f")
const WYK_HDR_NIEB := Color("4a6aa8")
const WYK_HDR_SZARY := Color("8a8a8a")
const WYK_KOM_NIEB := Color("cfe0f0")
const WYK_KOM_ROZ := Color("f5e6dc")
const WYK_KOM_POM := Color("f0c060")
const WYK_KOM_PH := Color("ddebf5")


static func make_background(parent: Control, col := COL_TLO) -> void:
	var bg := ColorRect.new()
	bg.color = col
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## Nagłówek ekranu pomocniczego: powrót do pulpitu, tytuł, zegar.
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


static func _flat(bg: Color, border: Color, radius := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Przycisk polecenia pulpitu w stylu SimRail: szary, a po wybraniu biały.
static func style_cmd_button(b: Button, active: bool) -> void:
	if active:
		b.add_theme_stylebox_override("normal", _flat(Color("f0f0f0"), Color("ffffff")))
		b.add_theme_stylebox_override("hover", _flat(Color("ffffff"), Color("ffffff")))
		b.add_theme_stylebox_override("pressed", _flat(Color("ffffff"), Color("ffffff")))
		b.add_theme_color_override("font_color", Color("101010"))
		b.add_theme_color_override("font_hover_color", Color("101010"))
		b.add_theme_color_override("font_pressed_color", Color("101010"))
	else:
		b.add_theme_stylebox_override("normal", _flat(Color("3c3c3c"), Color("5a5a5a")))
		b.add_theme_stylebox_override("hover", _flat(Color("4a4a4a"), Color("6a6a6a")))
		b.add_theme_stylebox_override("pressed", _flat(Color("2e2e2e"), Color("5a5a5a")))
		b.add_theme_color_override("font_color", Color("c8c8c8"))
		b.add_theme_color_override("font_hover_color", Color("e8e8e8"))
		b.add_theme_color_override("font_pressed_color", Color("c8c8c8"))


## Przycisk menu sygnalizatora: biały / czerwony (grupa Sz) / szary nieczynny.
static func style_signal_button(b: Button, enabled: bool, czerwony: bool) -> void:
	b.disabled = not enabled
	if not enabled:
		b.add_theme_stylebox_override("normal", _flat(Color("262626"), Color("3a3a3a")))
		b.add_theme_stylebox_override("disabled", _flat(Color("262626"), Color("3a3a3a")))
		b.add_theme_color_override("font_disabled_color", Color("5a5a5a"))
	elif czerwony:
		b.add_theme_stylebox_override("normal", _flat(Color("c01818"), Color("e05050")))
		b.add_theme_stylebox_override("hover", _flat(Color("d82020"), Color("ff6060")))
		b.add_theme_stylebox_override("pressed", _flat(Color("a01010"), Color("e05050")))
		b.add_theme_color_override("font_color", Color("ffffff"))
		b.add_theme_color_override("font_hover_color", Color("ffffff"))
	else:
		b.add_theme_stylebox_override("normal", _flat(Color("f0f0f0"), Color("ffffff")))
		b.add_theme_stylebox_override("hover", _flat(Color("ffffff"), Color("ffffff")))
		b.add_theme_stylebox_override("pressed", _flat(Color("d8d8d8"), Color("ffffff")))
		b.add_theme_color_override("font_color", Color("101010"))
		b.add_theme_color_override("font_hover_color", Color("101010"))


## Mały przycisk nawigacyjny w rogu pulpitu.
static func style_nav_button(b: Button, alarm := false) -> void:
	var bg := Color("1c1c1c") if not alarm else Color("5a1c0a")
	var border := Color("3a3a3a") if not alarm else Color("d08000")
	b.add_theme_stylebox_override("normal", _flat(bg, border))
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.1), border.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.2), border))
	b.add_theme_color_override("font_color", Color("d08000") if alarm else Color("9a9a9a"))
	b.add_theme_color_override("font_hover_color", Color("f0a020") if alarm else Color("d0d0d0"))
	b.add_theme_font_size_override("font_size", 11)
