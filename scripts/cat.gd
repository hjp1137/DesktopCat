class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK }

@export var speed: float = 120.0
@export var body_radius: float = 28.0

var current_mode: ControlMode = ControlMode.AUTO
var current_state: CatState = CatState.WALK
var direction: float = 1.0 # 1.0 向右，-1.0 向左
var state_timer: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func _ready() -> void:
	if position == Vector2.ZERO:
		position = _get_viewport_size() / 2.0
	enter_state(CatState.WALK)
	print("[Cat] 初始化完成，模式: AUTO，初始位置: ", position)

func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"):
		_main_node.update_mouse_passthrough(position)

func change_state(new_state: CatState) -> void:
	exit_state(current_state)
	current_state = new_state
	enter_state(new_state)

func enter_state(state: CatState) -> void:
	var sprite := _get_animated_sprite()
	if state == CatState.WALK:
		state_timer = randf_range(3.0, 7.0)
		if sprite:
			sprite.play("walk")
			sprite.flip_h = (direction < 0.0)
	elif state == CatState.IDLE:
		state_timer = randf_range(1.5, 3.5)
		if sprite:
			sprite.play("idle")
	print("[Cat] [%s] 进入状态: %s, 朝向: %s" % [
		"AUTO" if current_mode == ControlMode.AUTO else "COMMAND",
		CatState.keys()[state],
		"左" if direction < 0.0 else "右"
	])

func update_state(delta: float) -> void:
	if current_mode == ControlMode.AUTO:
		state_timer -= delta
		if state_timer <= 0.0:
			if current_state == CatState.WALK:
				change_state(CatState.IDLE)
			else:
				if randf() < 0.5:
					direction = -direction
				change_state(CatState.WALK)
	if current_state == CatState.WALK:
		_move_and_bounce(delta)

func exit_state(_old_state: CatState) -> void:
	pass

func handle_command(command: int, _payload: Dictionary = {}) -> void:
	match command:
		0: # STOP
			current_mode = ControlMode.COMMAND
			change_state(CatState.IDLE)
		1: # WALK_LEFT
			current_mode = ControlMode.COMMAND
			direction = -1.0
			change_state(CatState.WALK)
		2: # WALK_RIGHT
			current_mode = ControlMode.COMMAND
			direction = 1.0
			change_state(CatState.WALK)
		3: # RESUME_AUTO
			current_mode = ControlMode.AUTO
			print("[Cat] 恢复 AUTO 模式")
			change_state(CatState.WALK)

func _move_and_bounce(delta: float) -> void:
	var vp_size := _get_viewport_size()
	position.x += direction * speed * delta
	if position.x >= vp_size.x - body_radius:
		position.x = vp_size.x - body_radius
		direction = -1.0
		_get_animated_sprite().flip_h = true
	elif position.x <= body_radius:
		position.x = body_radius
		direction = 1.0
		_get_animated_sprite().flip_h = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos := get_local_mouse_position()
		if Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0).has_point(local_pos):
			_on_clicked()

func _on_clicked() -> void:
	print("Cat clicked!")
	var sprite := _get_animated_sprite()
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite:
		_animated_sprite = get_node_or_null("AnimatedSprite2D")
	return _animated_sprite

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport():
		var size := get_viewport_rect().size
		if DisplayServer.get_name() != "headless" and size.x > body_radius * 2.0:
			return size
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 640), ProjectSettings.get_setting("display/window/size/viewport_height", 360))
