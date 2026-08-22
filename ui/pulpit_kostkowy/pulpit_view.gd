class_name PulpitView
extends Control
## Widok pulpitu kostkowego: buduje siatkę kafelków z sekcji `panel` pliku
## stacji (docs/03-model-danych.md §5) i rysuje tło pulpitu z fugami
## (assets-spec/20 §1). Tylko wyświetla stan rdzenia i przekazuje akcje
## przycisków dalej (docs/02-architektura.md).

## Akcja przycisku pulpitu w formacie "polecenie:argument" z JSON.
signal action_requested(action: String)

const TILE: float = 48.0
## Rama pulpitu wokół planu (w px).
const FRAME: float = 16.0

const COL_TILE_BG := Color("C9C5B9")
const COL_GROUT := Color("B8B4A8")
const COL_FRAME := Color("6E6A60")

var _grid: Vector2i = Vector2i.ZERO
var _tiles: Array[PulpitTile] = []
var _blink_on: bool = true


## Buduje pulpit z definicji stacji. Wołane raz po wczytaniu stacji.
func build(station: StationData, interlocking: Interlocking,
		blocks: Dictionary = {}, world: SimWorld = null) -> void:
	for tile: PulpitTile in _tiles:
		tile.queue_free()
	_tiles.clear()
	var panel: Dictionary = station.panel
	var grid: Array = panel.get("grid", [8, 4])
	_grid = Vector2i(int(grid[0]), int(grid[1]))
	custom_minimum_size = Vector2(
		_grid.x * TILE + 2.0 * FRAME, _grid.y * TILE + 2.0 * FRAME
	)
	for tile_def: Variant in (panel.get("tiles", []) as Array):
		var def: Dictionary = tile_def
		var tile := PulpitTile.new()
		tile.setup(def, station.graph, interlocking, blocks, world)
		var xy: Array = def.get("xy", [0, 0])
		tile.position = Vector2(FRAME + int(xy[0]) * TILE, FRAME + int(xy[1]) * TILE)
		tile.button_activated.connect(_on_tile_button)
		add_child(tile)
		_tiles.append(tile)
	queue_redraw()


## Odświeżenie lampek po ticku rdzenia (per tick zmieniają się tylko lampki —
## kafelki są lekkie, pełny redraw kafelka jest tani przy tej skali).
func refresh() -> void:
	for tile: PulpitTile in _tiles:
		tile.blink_on = _blink_on
		tile.queue_redraw()


func _process(_delta: float) -> void:
	# Miganie 1 Hz, 50% wypełnienia (assets-spec/20 §6); faza z zegara
	# ściennego, żeby lampki migały też w pauzie symulacji.
	var phase_on := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
	if phase_on != _blink_on:
		_blink_on = phase_on
		refresh()


func _draw() -> void:
	# Rama pulpitu i tło kostek (assets-spec/20 §1). Ze skórką: pusta kostka
	# PNG w każdym polu siatki; bez niej: płaskie tło z fugami 1 px.
	draw_rect(Rect2(Vector2.ZERO, size), COL_FRAME)
	var plan := Rect2(Vector2(FRAME, FRAME), Vector2(_grid.x * TILE, _grid.y * TILE))
	var kostka := PulpitTile.skin_texture("kostka")
	if kostka != null:
		draw_rect(plan, COL_GROUT)
		for x: int in _grid.x:
			for y: int in _grid.y:
				draw_texture_rect(kostka,
					Rect2(FRAME + x * TILE, FRAME + y * TILE, TILE, TILE), false)
		return
	draw_rect(plan, COL_TILE_BG)
	for x: int in _grid.x + 1:
		var line_x := FRAME + x * TILE
		draw_line(
			Vector2(line_x, FRAME), Vector2(line_x, FRAME + _grid.y * TILE), COL_GROUT, 1.0
		)
	for y: int in _grid.y + 1:
		var line_y := FRAME + y * TILE
		draw_line(
			Vector2(FRAME, line_y), Vector2(FRAME + _grid.x * TILE, line_y), COL_GROUT, 1.0
		)


func _on_tile_button(action: String) -> void:
	action_requested.emit(action)
