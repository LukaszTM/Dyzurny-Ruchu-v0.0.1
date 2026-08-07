class_name TrafficPanel
extends VBoxContainer
## Panel ruchu: natężenie ruchu losowego, lista aktywnych pociągów,
## zlecenia manewrowe, statystyki dyżuru.

var sim = null
var intensity_label: Label
var intensity_slider: HSlider
var trains_list: ItemList
var jobs_box: VBoxContainer
var stats_label: Label


func setup(p_sim) -> void:
	sim = p_sim
	var mode_lbl := Label.new()
	mode_lbl.text = "Tryb: %s" % GameState.mode_name()
	add_child(mode_lbl)
	intensity_label = Label.new()
	intensity_label.add_theme_font_size_override("font_size", 12)
	add_child(intensity_label)
	intensity_slider = HSlider.new()
	intensity_slider.min_value = 4
	intensity_slider.max_value = 40
	intensity_slider.step = 1
	intensity_slider.value = sim.gen.intensity
	intensity_slider.editable = sim.gen.enabled
	intensity_slider.tooltip_text = "Natężenie ruchu losowego (pociągi na godzinę)."
	intensity_slider.value_changed.connect(func(v):
		sim.gen.intensity = v
		_update_intensity_label())
	add_child(intensity_slider)
	_update_intensity_label()
	add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = "Pociągi w obsłudze:"
	add_child(hdr)
	trains_list = ItemList.new()
	trains_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trains_list.add_theme_font_size_override("font_size", 12)
	add_child(trains_list)
	var hdr2 := Label.new()
	hdr2.text = "Zlecenia manewrowe:"
	add_child(hdr2)
	jobs_box = VBoxContainer.new()
	add_child(jobs_box)
	add_child(HSeparator.new())
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(stats_label)
	refresh()


func _update_intensity_label() -> void:
	if sim.gen.enabled:
		intensity_label.text = "Natężenie ruchu: %d poc./h" % int(sim.gen.intensity)
	else:
		intensity_label.text = "Natężenie ruchu: wg rozkładu jazdy"


func refresh() -> void:
	trains_list.clear()
	for t in sim.trains.values():
		if t.state == Train.State.DONE:
			continue
		var txt := "%s  |  %s  |  %s" % [t.title(), t.rel_text(), t.state_text()]
		if t.delay_min > 0:
			txt += "  (+%d min)" % t.delay_min
		trains_list.add_item(txt, null, false)
	for c in jobs_box.get_children():
		c.queue_free()
	var open_jobs := 0
	for job in sim.shunt_jobs:
		if job["done"]:
			continue
		open_jobs += 1
		var lbl := Label.new()
		lbl.text = "• " + str(job["desc"])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color("f0b429"))
		jobs_box.add_child(lbl)
	if open_jobs == 0:
		var none := Label.new()
		none.text = "Brak oczekujących manewrów."
		none.add_theme_font_size_override("font_size", 11)
		jobs_box.add_child(none)
	var punct := 100.0
	if sim.stats["dep_count"] > 0:
		punct = 100.0 * float(sim.stats["punctual"]) / float(sim.stats["dep_count"])
	stats_label.text = "Obsłużone pociągi: %d   Odjazdy: %d   Punktualność: %.0f%%\nZwolnienia doraźne/Sz: %d" % [
		sim.stats["handled"], sim.stats["dep_count"], punct, sim.stats["irregular"]]
