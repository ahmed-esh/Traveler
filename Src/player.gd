extends Node2D
@export_range(0.04, 0.4, 0.01) var step_duration: float = 0.10
var cell = Vector2i(250, 250)
var moving: bool = false
@onready var world = get_parent()

func _ready() -> void:
	position = world.cell_center(cell)
	$Camera2D.reset_smoothing()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var direction = Vector2i.ZERO
	match event.physical_keycode:
		KEY_W: direction = Vector2i.UP
		KEY_A: direction = Vector2i.LEFT
		KEY_S: direction = Vector2i.DOWN
		KEY_D: direction = Vector2i.RIGHT
		KEY_F:
			if not moving:
				world.burn_cell(cell)
			get_viewport().set_input_as_handled()
			return
	if direction != Vector2i.ZERO:
		try_step(direction)
		get_viewport().set_input_as_handled()

func try_step(direction: Vector2i) -> bool:
	if moving or absi(direction.x) + absi(direction.y) != 1:
		return false
	var target = cell + direction
	if not world.in_bounds(target):
		return false
	moving = true
	var tween = create_tween()
	tween.tween_property(self, "position", world.cell_center(target), step_duration)
	tween.tween_callback(func() -> void:
		cell = target
		moving = false
	)
	return true
