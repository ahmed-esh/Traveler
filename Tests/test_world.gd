extends SceneTree
const Scene = preload("res://Src/main.tscn")
var errors: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		errors += 1

func key(player: Node, code: Key, echo: bool = false) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	player._unhandled_key_input(event)

func run() -> void:
	var world = Scene.instantiate()
	world.starting_seed = 42
	root.add_child(world)
	var player = world.get_node("Player Node")
	await process_frame
	check(world.SIZE * world.TILE == Vector2i(5000, 5000), "World must be 5000 × 5000 pixels")
	var initial: Vector2i = player.cell
	key(player, KEY_D)
	key(player, KEY_W)
	await create_timer(0.2).timeout
	check(player.cell == initial + Vector2i.RIGHT, "One keypress must move exactly one tile; concurrent moves ignored")
	key(player, KEY_D, true)
	await create_timer(0.15).timeout
	check(player.cell == initial + Vector2i.RIGHT, "Key echo must not repeat movement")
	var cell: Vector2i = player.cell
	var original = var_to_str(world.get_cell(cell))
	key(player, KEY_F)
	check(world.burned.has(cell) and world.burning.has(cell), "F must immediately lock the standing cell and start fire")
	world.generate(99)
	check(var_to_str(world.get_cell(cell)) == original, "Regeneration during fire must preserve snapshot")
	await create_timer(0.8).timeout
	check(not world.burning.has(cell), "Fire must finish")
	check(not world.burn_cell(cell), "Repeated F must not replace a burned cell")
	var gray: Color = world.cell_color(Color(1, 0.4, 0), true)
	check(is_equal_approx(gray.r, gray.g) and is_equal_approx(gray.g, gray.b), "Burned colors must be grayscale")
	world.generate(345)
	check(var_to_str(world.get_cell(cell)) == original, "Completed burned cell must survive further regeneration")
	var changed = false
	for x in range(10):
		var probe = Vector2i(x, 1)
		var before = var_to_str(world.get_cell(probe))
		world.generate(700 + x)
		changed = changed or before != var_to_str(world.get_cell(probe))
	check(changed, "Unburned cells must still regenerate")
	for i in range(30):
		world.get_cell(Vector2i((i % 6) * 80, (i / 6) * 46))
	check(world.regions.size() <= world.MAX_CACHED_REGIONS, "Region cache must remain bounded")
	player.cell = Vector2i.ZERO
	player.position = world.cell_center(player.cell)
	check(not player.try_step(Vector2i.LEFT), "Player must not leave world")
	check(not player.try_step(Vector2i(1, 1)), "No diagonal steps")
	check(not world.burn_cell(Vector2i(-1, 0)), "No burning outside world")
	# Fill all coordinates to exercise the all-burned no-op without animating 250,000 fires.
	var snapshot: Dictionary = world.burned[cell]
	for y in range(world.SIZE.y):
		for x in range(world.SIZE.x):
			world.burned[Vector2i(x, y)] = snapshot
	var old_seed: int = world.map_seed
	var old_generation: int = world.generation
	world.generate(999)
	check(world.map_seed == old_seed and world.generation == old_generation, "Fully burned world regeneration must be a no-op")
	world.queue_free()
	await process_frame
	if errors == 0:
		print("PASS: movement, boundaries, burning, animation completion, frozen snapshots, regeneration and bounded cache.")
	quit(1 if errors else 0)
