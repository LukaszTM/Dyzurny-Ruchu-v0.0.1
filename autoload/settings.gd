extends Node
## Ustawienia gry: rozdzielczość, tryb okna, adresy aktualizacji online.
## Zapisywane do user://settings.cfg.

const CFG_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const WINDOW_MODE_NAMES := ["Okno", "Pełny ekran", "Okno bez ramki"]

var resolution: Vector2i = Vector2i(1600, 900)
var window_mode: int = 0 # 0 okno, 1 pełny ekran, 2 bez ramki
var vsync: bool = true
var online_enabled: bool = true
var url_delays: String = "https://raw.githubusercontent.com/LukaszTM/Dyzurny-Ruchu-v0.0.1/main/data/online/delays.json"
var url_timetable: String = "https://raw.githubusercontent.com/LukaszTM/Dyzurny-Ruchu-v0.0.1/main/data/online/timetable_warszawa_wschodnia.json"
var autosave_log: bool = true


func _ready() -> void:
	load_cfg()
	apply()


func load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	var res: Variant = cfg.get_value("display", "resolution", resolution)
	if res is Vector2i:
		resolution = res
	window_mode = int(cfg.get_value("display", "window_mode", window_mode))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	online_enabled = bool(cfg.get_value("online", "enabled", online_enabled))
	url_delays = str(cfg.get_value("online", "url_delays", url_delays))
	url_timetable = str(cfg.get_value("online", "url_timetable", url_timetable))
	autosave_log = bool(cfg.get_value("log", "autosave", autosave_log))


func save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("online", "enabled", online_enabled)
	cfg.set_value("online", "url_delays", url_delays)
	cfg.set_value("online", "url_timetable", url_timetable)
	cfg.set_value("log", "autosave", autosave_log)
	cfg.save(CFG_PATH)


func apply() -> void:
	var win := get_window()
	match window_mode:
		1:
			win.mode = Window.MODE_FULLSCREEN
		2:
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			win.size = resolution
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			win.size = resolution
	if window_mode != 1:
		var scr_size := DisplayServer.screen_get_size(win.current_screen)
		var scr_pos := DisplayServer.screen_get_position(win.current_screen)
		win.position = scr_pos + (scr_size - win.size) / 2
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
