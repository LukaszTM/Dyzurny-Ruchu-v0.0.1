class_name EventsPanel
extends VBoxContainer
## Zdarzenia losowe: suwak częstotliwości + lista aktywnych zdarzeń
## z potwierdzaniem przyjęcia do wiadomości.

var sim = null
var freq_slider: HSlider
var freq_label: Label
var list_box: VBoxContainer
var hist_label: Label


func setup(p_sim) -> void:
	sim = p_sim
	freq_label = Label.new()
	freq_label.add_theme_font_size_override("font_size", 12)
	add_child(freq_label)
	freq_slider = HSlider.new()
	freq_slider.min_value = 0
	freq_slider.max_value = 45
	freq_slider.step = 1
	freq_slider.value = sim.events.freq_min
	freq_slider.tooltip_text = "0 = zdarzenia wyłączone; inaczej średni odstęp między zdarzeniami w minutach."
	freq_slider.value_changed.connect(func(v):
		sim.events.freq_min = v
		sim.events.schedule_next(sim.sim_time)
		_update_freq_label())
	add_child(freq_slider)
	add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = "Aktywne zdarzenia:"
	add_child(hdr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	add_child(scroll)
	hist_label = Label.new()
	hist_label.add_theme_font_size_override("font_size", 11)
	add_child(hist_label)
	_update_freq_label()
	refresh()


func _update_freq_label() -> void:
	if sim.events.freq_min <= 0:
		freq_label.text = "Częstotliwość zdarzeń losowych: WYŁĄCZONE"
	else:
		freq_label.text = "Częstotliwość zdarzeń losowych: śr. co ~%d min" % int(sim.events.freq_min)


func refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for ev in sim.events.active:
		var panel := PanelContainer.new()
		var vb := VBoxContainer.new()
		var title := Label.new()
		title.text = ("⚠ " if not ev["ack"] else "✓ ") + str(ev["title"])
		title.add_theme_color_override("font_color",
			Color("f59e0b") if not ev["ack"] else Color("9aa7b8"))
		vb.add_child(title)
		var desc := Label.new()
		desc.text = str(ev["desc"])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		vb.add_child(desc)
		var remain := Label.new()
		remain.text = "Przewidywane ustąpienie: %s" % SimUtil.fmt_hm(ev["until"])
		remain.add_theme_font_size_override("font_size", 10)
		vb.add_child(remain)
		if not ev["ack"]:
			var btn := Button.new()
			btn.text = "Potwierdź przyjęcie"
			var ev_id: int = ev["id"]
			btn.pressed.connect(func():
				sim.events.ack(ev_id)
				refresh())
			vb.add_child(btn)
		panel.add_child(vb)
		list_box.add_child(panel)
	if sim.events.active.is_empty():
		var none := Label.new()
		none.text = "Brak aktywnych zdarzeń."
		none.add_theme_font_size_override("font_size", 11)
		list_box.add_child(none)
	hist_label.text = "Zdarzeń obsłużonych: %d" % sim.events.history_count
