extends RefCounted
## 10 px atlas coordinates are zero based. All colors are applied to the original white art.
const ATLAS = preload("res://Full-no-bg.png")
const SIZE = Vector2i(80, 46)
const TILE = 10
const ORIGIN = Vector2.ZERO
const SOIL = Color("211407")
const PATH = Color("8c6440")
const STONE = Color("9caaa1")
const WATER = Color("578af0")
const GREEN = Color("43ad35")
const WOOD = Color("a8652d")
const CREAM = Color("f8e5ac")
const WALL_TILE = Vector2i(7, 5)
const TREE_TILES = [Vector2i(26, 1), Vector2i(27, 1), Vector2i(28, 1)]

var starting_seed: int = 0 ## Zero chooses a fresh seed on launch.
## 0 keeps the original layout; 1 allows broad changes to placement, size and orientation.
var layout_variation: float = 1.0
var map_seed: int
var generation: int = 0
var rng = RandomNumberGenerator.new()
var water: Dictionary = {}
var roads: Dictionary = {}
var walls: Dictionary = {}
var bridges: Dictionary = {}
var reserved: Dictionary = {}
var decorations: Array[Dictionary] = []
var landmarks: Array[Vector2i] = []
var ruin: Rect2i
var gate: Vector2i
var river_x: Array[int] = []
var cell_cache: Dictionary = {}
var art_by_cell: Dictionary = {}

func generate(new_seed: int) -> void:
	cell_cache.clear()
	art_by_cell.clear()
	map_seed = new_seed
	rng.seed = map_seed
	generation += 1
	for cells in [water, roads, walls, bridges, reserved]:
		cells.clear()
	decorations.clear()
	landmarks.clear()
	river_x.clear()
	# A continuous river stays east of the settlement.
	var phase = rng.randf_range(0.0, TAU)
	var river_center = varied_int(61, 71, 64)
	var river_width = varied_int(2, 6, 4)
	var river_bend = lerpf(4.0, rng.randf_range(1.0, 6.0), layout_variation)
	for y in range(SIZE.y):
		var rx = river_center + int(sin(y * 0.16 + phase) * river_bend)
		river_x.append(rx)
		for x in range(rx, mini(rx + river_width, SIZE.x)):
			water[Vector2i(x, y)] = true
	# Rectangular moat surrounds a walled courtyard, with a single southern entrance.
	ruin = Rect2i(varied_int(4, 25, 14), varied_int(3, 13, 7), varied_int(12, 25, 19), varied_int(10, 19, 14))
	var moat = ruin.grow(2)
	for y in range(moat.position.y, moat.end.y):
		for x in range(moat.position.x, moat.end.x):
			var cell = Vector2i(x, y)
			reserved[cell] = true
			if not ruin.has_point(cell):
				water[cell] = true
			elif x == ruin.position.x or x == ruin.end.x - 1 or y == ruin.position.y or y == ruin.end.y - 1:
				walls[cell] = true
	gate = Vector2i(ruin.get_center().x, ruin.end.y - 1)
	walls.erase(gate)
	var junction = Vector2i(gate.x, varied_int(maxi(ruin.end.y + 4, 28), 40, 34))
	var camp = Vector2i(varied_int(maxi(ruin.end.x + 4, 48), 55, 51), varied_int(5, 28, 27))
	var crossing_y = varied_int(junction.y, 43, 38)
	carve_path(gate, junction)
	carve_path(junction, Vector2i(0, junction.y))
	carve_path(junction, Vector2i(gate.x, SIZE.y - 1))
	carve_path(junction, Vector2i(camp.x, junction.y))
	carve_path(Vector2i(camp.x, junction.y), camp)
	carve_path(Vector2i(camp.x, junction.y), Vector2i(camp.x, crossing_y))
	carve_path(Vector2i(camp.x, crossing_y), Vector2i(SIZE.x - 1, crossing_y))
	landmarks.assign([gate, junction, camp, Vector2i(SIZE.x - 1, crossing_y)])
	# Treasure and bones belong inside the ruin.
	add_art(ruin.position + Vector2i(3, 3), Vector2i(18, 2), WOOD)
	add_art(Vector2i(ruin.end.x - 4, ruin.position.y + 3), Vector2i(18, 2), WOOD)
	for i in range(9):
		var p = Vector2i(rng.randi_range(ruin.position.x + 2, ruin.end.x - 3), rng.randi_range(ruin.position.y + 5, ruin.end.y - 3))
		add_art(p, Vector2i(1 + i % 2, 1), CREAM)
	# Ordered crops beside the road, away from the moat.
	var farm_left = varied_int(3, maxi(4, gate.x - 8), 6)
	for y in range(junction.y - 6, junction.y - 1, 2):
		for x in range(farm_left, farm_left + varied_int(6, 14, 10), 2):
			var p = Vector2i(x, y)
			if not water.has(p) and not roads.has(p) and not reserved.has(p):
				add_art(p, Vector2i(26, 8), GREEN if rng.randf() > 0.2 else WOOD)
				reserved[p] = true
	for offset in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(2, 1)]:
		var p: Vector2i = camp + offset
		if not water.has(p) and not roads.has(p) and not reserved.has(p):
			add_art(p, Vector2i(16, 1), WOOD)
			reserved[p] = true
	# Smooth noise makes groves and clearings instead of uniformly random trees.
	var forest = FastNoiseLite.new()
	forest.seed = int(map_seed % 2147483647)
	forest.frequency = lerpf(0.085, rng.randf_range(0.035, 0.14), layout_variation)
	var forest_threshold = lerpf(-0.08, rng.randf_range(-0.25, 0.18), layout_variation)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var p = Vector2i(x, y)
			if water.has(p) or roads.has(p) or walls.has(p) or reserved.has(p):
				continue
			if near_road(p):
				continue
			var density = forest.get_noise_2d(x, y)
			if density > forest_threshold and rng.randf() < 0.64:
				add_art(p, TREE_TILES[rng.randi_range(0, 2)], GREEN.darkened(rng.randf_range(0.0, 0.25)))
			elif rng.randf() < 0.15:
				add_art(p, Vector2i(29, 6), GREEN.darkened(0.2))
			elif rng.randf() < 0.035:
				add_art(p, Vector2i(4, 1), STONE.darkened(0.25))
	# Reflect cell positions, not artwork: trees remain upright in every layout.
	reflect_layout(rng.randf() < layout_variation * 0.5, rng.randf() < layout_variation * 0.5)
	for item in decorations:
		if not art_by_cell.has(item.p):
			art_by_cell[item.p] = []
		art_by_cell[item.p].append({"tile": item.tile, "tint": item.tint})



func varied_int(low: int, high: int, baseline: int) -> int:
	return clampi(roundi(lerpf(float(baseline), float(rng.randi_range(low, high)), layout_variation)), low, high)

func reflected(p: Vector2i, horizontal: bool, vertical: bool) -> Vector2i:
	return Vector2i(SIZE.x - 1 - p.x if horizontal else p.x, SIZE.y - 1 - p.y if vertical else p.y)

func reflect_layout(horizontal: bool, vertical: bool) -> void:
	for cells in [water, roads, walls, bridges, reserved]:
		var transformed: Dictionary = {}
		for p in cells:
			transformed[reflected(p, horizontal, vertical)] = cells[p]
		cells.clear()
		cells.merge(transformed)
	for item in decorations:
		item.p = reflected(item.p, horizontal, vertical)
	for i in range(landmarks.size()):
		landmarks[i] = reflected(landmarks[i], horizontal, vertical)
	gate = reflected(gate, horizontal, vertical)
	var corner = reflected(ruin.position, horizontal, vertical)
	ruin.position = corner - Vector2i(ruin.size.x - 1 if horizontal else 0, ruin.size.y - 1 if vertical else 0)
	if vertical:
		river_x.reverse()
	if horizontal:
		for i in range(river_x.size()):
			# river_x tracks the left bank, including variable river widths.
			var old_left = river_x[i]
			var new_left = SIZE.x - 1 - old_left
			while water.has(Vector2i(new_left - 1, i)):
				new_left -= 1
			river_x[i] = new_left

func carve_path(from: Vector2i, to: Vector2i) -> void:
	var p = from
	stamp_path(p)
	while p != to:
		if p.x != to.x:
			p.x += 1 if to.x > p.x else -1
		else:
			p.y += 1 if to.y > p.y else -1
		stamp_path(p)

func stamp_path(p: Vector2i) -> void:
	roads[p] = true
	if water.has(p):
		bridges[p] = true

func near_road(p: Vector2i) -> bool:
	for d in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if roads.has(p + d):
			return true
	return false

func add_art(p: Vector2i, tile: Vector2i, tint: Color) -> void:
	decorations.append({"p": p, "tile": tile, "tint": tint})

func cell_data(p: Vector2i) -> Dictionary:
	if not cell_cache.has(p):
		cell_cache[p] = {
			"fleck": absi(hash(Vector3i(p.x, p.y, int(map_seed % 100000)))),
			"water": water.has(p), "road": roads.has(p),
			"bridge": bridges.has(p), "wall": walls.has(p),
			"ripple": (p.x * 7 + p.y * 3) % 13 == 0,
			"art": art_by_cell.get(p, [])
		}
	return cell_cache[p]
