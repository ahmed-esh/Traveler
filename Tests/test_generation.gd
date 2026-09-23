extends SceneTree
## Run: godot --headless --path . --script res://Tests/test_generation.gd
const Generator = preload("res://Src/region_generator.gd")

func _initialize() -> void:
	var map = Generator.new()
	var layouts: Dictionary = {}
	for seed_value in range(1, 201):
		map.generate(seed_value)
		layouts[var_to_str([map.ruin, map.gate, map.landmarks])] = true
		for cells in [map.water, map.roads, map.walls, map.bridges, map.reserved]:
			for cell in cells:
				if not Rect2i(Vector2i.ZERO, map.SIZE).has_point(cell):
					fail("Cell outside map bounds", seed_value)
					return
		var visited: Dictionary = {map.gate: true}
		var pending: Array[Vector2i] = [map.gate]
		while not pending.is_empty():
			var current: Vector2i = pending.pop_back()
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = current + direction
				if map.roads.has(neighbor) and not visited.has(neighbor):
					visited[neighbor] = true
					pending.append(neighbor)
		if visited.size() != map.roads.size():
			fail("Disconnected trail", seed_value)
			return
		for landmark in map.landmarks:
			if not visited.has(landmark):
				fail("Unreachable landmark", seed_value)
				return
		for cell in map.roads:
			if map.walls.has(cell) or (map.water.has(cell) and not map.bridges.has(cell)):
				fail("Blocked trail", seed_value)
				return
		for item in map.decorations:
			if map.water.has(item.p) or map.roads.has(item.p) or map.walls.has(item.p):
				fail("Decoration obstructs terrain", seed_value)
				return
		var snapshot = var_to_str([map.water, map.roads, map.walls, map.decorations])
		map.generate(seed_value)
		if snapshot != var_to_str([map.water, map.roads, map.walls, map.decorations]):
			fail("Seed did not reproduce map", seed_value)
			return
	if layouts.size() < 180:
		fail("Insufficient large-scale layout variety", 0)
		return
	print("PASS: 200 regions, bounds, connected paths, clear bridges, deterministic replay and layout variety.")
	quit()

func fail(message: String, seed_value: int) -> void:
	push_error("%s (seed %s)" % [message, seed_value])
	quit(1)
