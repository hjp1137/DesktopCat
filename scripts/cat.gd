class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK, JUMP, FALL }

@export var speed: float = 120.0
@export var body_radius: float = 28.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0

var current_mode: ControlMode = ControlMode.AUTO
var current_state: CatState = CatState.WALK
var command_ground_state: CatState = CatState.WALK
var direction: float = 1.0
var vertical_velocity: float = 0.0
var ground_y: float = 0.0
var is_grounded: bool = true
var state_timer: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func _ready() -> void:
	ground_y = _get_viewport_size().y - 48.0
	if position.y == 0.0:
		position = Vector2(_get_viewport_size().x / 2.0, ground_y)
	enter_state(CatState.WALK)
	print("[Cat] 初始化完成，模式: AUTO，ground_y: ", ground_y)

func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"):
		_main_node.update_mouse_passthrough(position)

func reset_to_ground(target_pos: Vector2) -> void:
	ground_y = target_pos.y
	position = target_pos
	vertical_velocity = 0.0
	is_grounded = true
	change_state(CatState.WALK if current_mode == ControlMode.AUTO else command_ground_state)

func change_state(new_state: CatState) -> void:
	current_state = new_state
	enter_state(new_state)

func enter_state(state: CatState) -> void:
	var sprite := _get_animated_sprite()
	if state == CatState.WALK or state == CatState.JUMP:
		if state == CatState.WALK:
			state_timer = randf_range(3.0, 7.0)
		if sprite:
			sprite.play("walk")
			sprite.flip_h = (direction < 0.0)
	elif state == CatState.IDLE or state == CatState.FALL:
		if state == CatState.IDLE:
			state_timer = randf_range(1.5, 3.5)
		if sprite:
			sprite.play("idle")
			sprite.flip_h = (direction < 0.0)
	print("[Cat] [%s] 进入状态: %s, 朝向: %s, Y=%.1f" % ["AUTO" if current_mode == ControlMode.AUTO else "COMMAND", CatState.keys()[state], "左" if direction < 0.0 else "右", position.y])

func update_state(delta: float) -> void:
	if not is_grounded:
		vertical_velocity += gravity * delta
		position.y += vertical_velocity * delta
		if current_state == CatState.JUMP and vertical_velocity >= 0.0:
			change_state(CatState.FALL)
		if position.y >= ground_y:
			position.y = ground_y
			vertical_velocity = 0.0
			is_grounded = true
			_on_land()
	elif current_mode == ControlMode.AUTO:
		state_timer -= delta
		if state_timer <= 0.0:
			if current_state == CatState.WALK:
				change_state(CatState.IDLE)
			else:
				if randf() < 0.5:
					direction = -direction
				change_state(CatState.WALK)
	
	var can_move := (current_state == CatState.WALK or not is_grounded) and not (current_mode == ControlMode.COMMAND and command_ground_state == CatState.IDLE)
	if can_move:
		_move_and_bounce(delta)

func _on_land() -> void:
	print("[Cat] 落地着陆 (ground_y=%.1f)" % ground_y)
	if current_mode == ControlMode.COMMAND:
		change_state(command_ground_state)
	else:
		change_state(CatState.WALK)

func handle_command(command: int, _payload: Dictionary = {}) -> void:
	match command:
		0: # STOP
			current_mode = ControlMode.COMMAND
			command_ground_state = CatState.IDLE
			if is_grounded: change_state(CatState.IDLE)
		1: # WALK_LEFT
			current_mode = ControlMode.COMMAND
			direction = -1.0
			command_ground_state = CatState.WALK
			_get_animated_sprite().flip_h = true
			if is_grounded: change_state(CatState.WALK)
		2: # WALK_RIGHT
			current_mode = ControlMode.COMMAND
			direction = 1.0
			command_ground_state = CatState.WALK
			_get_animated_sprite().flip_h = false
			if is_grounded: change_state(CatState.WALK)
		3: # RESUME_AUTO
			current_mode = ControlMode.AUTO
			print("[Cat] 恢复 AUTO 模式")
			if is_grounded: change_state(CatState.WALK)
		4: # JUMP
			if not is_grounded:
				print("[Cat] JUMP ignored: airborne")
				return
			is_grounded = false
			vertical_velocity = jump_velocity
			change_state(CatState.JUMP)

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
		if Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0).has_point(get_local_mouse_position()):
			_on_clicked()

func _on_clicked() -> void:
	print("Cat clicked!")
	var sprite := _get_animated_sprite()
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite: _animated_sprite = get_node_or_null("AnimatedSprite2D")
	return _animated_sprite

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport():
		var size := get_viewport_rect().size
		if DisplayServer.get_name() != "headless" and size.x > body_radius * 2.0: return size
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 640), ProjectSettings.get_setting("display/window/size/viewport_height", 360))
