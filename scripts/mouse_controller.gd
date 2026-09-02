class_name MouseController
extends Node

var command_manager: CommandManager = null
var cat: Node2D = null
var main_node: Node = null

var is_mouse_down: bool = false
var is_dragging: bool = false
var press_start_pos: Vector2 = Vector2.ZERO
var drag_threshold: float = 8.0
var max_throw_speed_x: float = 1200.0
var max_throw_speed_y: float = 1000.0
var sample_history: Array[Dictionary] = []

func _process(_delta: float) -> void:
	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag(cat.position if is_instance_valid(cat) else Vector2.ZERO)
		is_mouse_down = false
		is_dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_instance_valid(cat):
				var local_pos := cat.get_local_mouse_position()
				if Rect2(-28, -28, 56, 56).has_point(local_pos):
					is_mouse_down = true
					is_dragging = false
					press_start_pos = event.position
					sample_history.clear()
					_record_sample(event.position)
		else:
			if is_dragging:
				_finish_drag(event.position)
			elif is_mouse_down:
				if is_instance_valid(cat) and cat.has_method("_on_clicked"):
					cat._on_clicked()
			is_mouse_down = false
			is_dragging = false
	elif event is InputEventMouseMotion and is_mouse_down:
		_record_sample(event.position)
		if not is_dragging:
			if event.position.distance_to(press_start_pos) >= drag_threshold:
				is_dragging = true
				if DisplayServer.get_name() != "headless":
					DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
				if command_manager:
					command_manager.send_command(CommandManager.CatCommand.DRAG_START, {"mouse_pos": event.position})
		if is_dragging and command_manager:
			command_manager.send_command(CommandManager.CatCommand.DRAG_MOVE, {"mouse_pos": event.position})

func _record_sample(pos: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	sample_history.append({"pos": pos, "time": now})
	while sample_history.size() > 1 and now - sample_history[0]["time"] > 0.12:
		sample_history.remove_at(0)

func _finish_drag(_pos: Vector2) -> void:
	var throw_vel := Vector2.ZERO
	if sample_history.size() >= 2:
		var oldest: Dictionary = sample_history[0]
		var latest: Dictionary = sample_history[sample_history.size() - 1]
		var dt: float = float(latest["time"]) - float(oldest["time"])
		if dt > 0.008:
			throw_vel = (Vector2(latest["pos"]) - Vector2(oldest["pos"])) / dt
			throw_vel.x = clampf(throw_vel.x, -max_throw_speed_x, max_throw_speed_x)
			throw_vel.y = clampf(throw_vel.y, -max_throw_speed_y, max_throw_speed_y)
	if command_manager:
		command_manager.send_command(CommandManager.CatCommand.DRAG_END, {"throw_velocity": throw_vel})
	if main_node and is_instance_valid(cat) and main_node.has_method("update_mouse_passthrough"):
		main_node.update_mouse_passthrough(cat.position)

func cancel_drag() -> void:
	if is_dragging:
		is_dragging = false
		is_mouse_down = false
		if command_manager:
			command_manager.send_command(CommandManager.CatCommand.DRAG_END, {"throw_velocity": Vector2.ZERO})
		if main_node and is_instance_valid(cat) and main_node.has_method("update_mouse_passthrough"):
			main_node.update_mouse_passthrough(cat.position)
