extends Node2D
## cells 10*10 px
const Region = preload("res://Src/region_generator.gd")
const ATLAS = preload("res://Full-no-bg.png")
const FIRE = preload("res://fire asset red floored.png")
const SIZE = Vector2i(500, 500)
const TILE = 10
const FIRE_FRAMES = 8
const FIRE_FPS = 12.0
const FIRE_DURATION = FIRE_FRAMES / FIRE_FPS
const MAX_CACHED_REGIONS = 24

@export var starting_seed: int = 0
@export_range(0.0, 1.0, 0.05) var layout_variation: float = 1.0
var map_seed: int
var generation: int = 0
var burned: Dictionary = {}
var burning: Dictionary = {}
var regions: Dictionary = {}
var visible_cells = Rect2i()
var elapsed: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generate(starting_seed if starting_seed != 0 else int(Time.get_unix_time_from_system()))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_X:
			generate(randi())
		elif event.physical_keycode == KEY_R:
			generate(map_seed)

func generate(new_seed: int) -> void:
	if burned.size() == SIZE.x * SIZE.y:
		return
	map_seed = new_seed
	generation += 1
	regions.clear()
	queue_redraw()

func in_bounds(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, SIZE).has_point(cell)

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2.ONE * TILE * 0.5

func get_cell(cell: Vector2i) -> Dictionary:
	if burned.has(cell):
		return burned[cell]
	var region_position = Vector2i(floori(float(cell.x) / Region.SIZE.x), floori(float(cell.y) / Region.SIZE.y))
	if not regions.has(region_position):
		if regions.size() >= MAX_CACHED_REGIONS:
			regions.erase(regions.keys()[0])
		var region = Region.new()
		region.layout_variation = layout_variation
		region.generate(absi(hash(Vector3i(region_position.x, region_position.y, int(map_seed % 2147483647)))))
		regions[region_position] = region
	return regions[region_position].cell_data(cell - region_position * Region.SIZE)

func burn_cell(cell: Vector2i) -> bool:
	if not in_bounds(cell) or burned.has(cell):
		return false

	burned[cell] = get_cell(cell).duplicate(true)
	burning[cell] = elapsed
	queue_redraw()
	return true

func _process(delta: float) -> void:
	elapsed += delta
	var fire_changed = not burning.is_empty()
	for cell in burning.keys():
		if elapsed - float(burning[cell]) >= FIRE_DURATION:
			burning.erase(cell)
	var inverse = get_canvas_transform().affine_inverse()
	var screen = get_viewport_rect()
	var start = inverse * screen.position
	var finish = inverse * screen.end
	var top_left = Vector2i(floori(start.x / TILE) - 1, floori(start.y / TILE) - 1).clamp(Vector2i.ZERO, SIZE)
	var bottom_right = Vector2i(ceili(finish.x / TILE) + 1, ceili(finish.y / TILE) + 1).clamp(Vector2i.ZERO, SIZE)
	var next_visible = Rect2i(top_left, bottom_right - top_left)
	if next_visible != visible_cells or fire_changed:
		visible_cells = next_visible
		queue_redraw()

func cell_color(color: Color, monochrome: bool) -> Color:
	if not monochrome:
		return color
	var gray = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(gray, gray, gray, color.a)

func _draw() -> void:
	for y in range(visible_cells.position.y, visible_cells.end.y):
		for x in range(visible_cells.position.x, visible_cells.end.x):
			var cell = Vector2i(x, y)
			draw_cell(cell, get_cell(cell), burned.has(cell) and not burning.has(cell))
	for cell in burning:
		if visible_cells.has_point(cell):
			var frame = mini(int((elapsed - float(burning[cell])) * FIRE_FPS), FIRE_FRAMES - 1)
			# The sheet has eight 240 × 144 frames with substantial transparent padding.
			# Crop around the flame within each frame so it remains legible at tile scale.
			var source = Rect2(frame * 240 + 56, 64, 48, 56)
			draw_texture_rect_region(FIRE, Rect2(Vector2(cell * TILE) + Vector2(-1, -5), Vector2(12, 15)), source)

func draw_cell(cell: Vector2i, data: Dictionary, monochrome: bool) -> void:
	var rect = Rect2(Vector2(cell * TILE), Vector2.ONE * TILE)
	var soil = cell_color(Region.SOIL, monochrome)
	draw_rect(rect, soil)
	var h: int = data.fleck
	if h % 3 == 0:
		draw_rect(Rect2(rect.position + Vector2(h % 7, h % 5), Vector2.ONE), cell_color(Color("664427"), monochrome))
	if data.water:
		draw_rect(rect, cell_color(Region.WATER, monochrome))
		if data.ripple:
			draw_line(rect.position + Vector2(2, 5), rect.position + Vector2(6, 5), cell_color(Color("88b1ff"), monochrome))
	if data.road:
		draw_rect(rect, cell_color(Region.PATH, monochrome))
		draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(1, 2)), soil)
		draw_rect(Rect2(rect.position + Vector2(7, 7), Vector2(2, 1)), soil)
	if data.bridge:
		draw_rect(rect, cell_color(Region.WOOD.darkened(0.3), monochrome))
		for i in range(1, 10, 3):
			draw_line(rect.position + Vector2(1, i), rect.position + Vector2(9, i), cell_color(Region.WOOD, monochrome), 2)
	if data.wall:
		draw_texture_rect_region(ATLAS, rect, Rect2(Vector2(Region.WALL_TILE * TILE), Vector2.ONE * TILE), cell_color(Region.STONE, monochrome))
	for item in data.art:
		draw_texture_rect_region(ATLAS, rect, Rect2(Vector2(item.tile * TILE), Vector2.ONE * TILE), cell_color(item.tint, monochrome))
