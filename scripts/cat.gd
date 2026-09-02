class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK, JUMP, FALL, DRAG }

@export var speed: float = 120.0
@export var body_radius: float = 28.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0

var current_mode: ControlMode = ControlMode.AUTO
var current_state: CatState = CatState.WALK
var command_ground_state: CatState = CatState.WALK
var direction: float = 1.0
var vertical_velocity: float = 0.0
var horizontal_throw_speed: float = 0.0
var ground_y: float = 0.0
var is_grounded: bool = true
var state_timer: float = 0.0
var drag_offset: Vector2 = Vector2.ZERO

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func _ready() -> void:
	ground_y = _get_viewport_size().y - 48.0
	if position.y == 0.0:
		position = Vector2(_get_viewport_size().x / 2.0, ground_y)
	enter_state(CatState.WALK)

func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"):
		_main_node.update_mouse_passthrough(position)

func reset_to_ground(target_pos: Vector2) -> void:
	ground_y = target_pos.y
	position = target_pos
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = true
	change_state(CatState.WALK if current_mode == ControlMode.AUTO else command_ground_state)

func change_state(new_state: CatState) -> void:
	current_state = new_state
	enter_state(new_state)

func enter_state(state: CatState) -> void:
	var sprite := _get_animated_sprite()
	if state == CatState.WALK or state == CatState.JUMP:
		if state == CatState.WALK: state_timer = randf_range(3.0, 7.0)
		if sprite: sprite.play("walk"); sprite.flip_h = (direction < 0.0)
	elif state == CatState.IDLE or state == CatState.FALL or state == CatState.DRAG:
		if state == CatState.IDLE: state_timer = randf_range(1.5, 3.5)
		if sprite: sprite.play("idle"); sprite.flip_h = (direction < 0.0)
	print("[Cat] [%s] 进入状态: %s, 朝向: %s, Y=%.1f" % ["AUTO" if current_mode == ControlMode.AUTO else "COMMAND", CatState.keys()[state], "左" if direction < 0.0 else "右", position.y])

func update_state(delta: float) -> void:
	if current_state == CatState.DRAG: return
	if not is_grounded:
		vertical_velocity += gravity * delta
		position.y += vertical_velocity * delta
		if position.y <= 30.0:
			position.y = 30.0
			vertical_velocity = maxf(0.0, -vertical_velocity * 0.3)
		if current_state == CatState.JUMP and vertical_velocity >= 0.0: change_state(CatState.FALL)
		if horizontal_throw_speed != 0.0: _move_air_throw(delta)
		elif not (current_mode == ControlMode.COMMAND and command_ground_state == CatState.IDLE): _move_and_bounce(delta)
		if position.y >= ground_y:
			position.y = ground_y; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; _on_land()
	elif current_mode == ControlMode.AUTO:
		state_timer -= delta
		if state_timer <= 0.0:
			if current_state == CatState.WALK: change_state(CatState.IDLE)
			else:
				if randf() < 0.5: direction = -direction
				change_state(CatState.WALK)
		if current_state == CatState.WALK: _move_and_bounce(delta)
	elif current_state == CatState.WALK: _move_and_bounce(delta)

func _move_air_throw(delta: float) -> void:
	var vp_size := _get_viewport_size()
	position.x += horizontal_throw_speed * delta
	if position.x >= vp_size.x - body_radius:
		position.x = vp_size.x - body_radius
		horizontal_throw_speed = -horizontal_throw_speed * 0.6
		direction = -1.0
		_get_animated_sprite().flip_h = true
	elif position.x <= body_radius:
		position.x = body_radius
		horizontal_throw_speed = -horizontal_throw_speed * 0.6
		direction = 1.0
		_get_animated_sprite().flip_h = false

func _on_land() -> void:
	horizontal_throw_speed = 0.0
	print("[Cat] 落地着陆 (ground_y=%.1f)" % ground_y)
	change_state(command_ground_state if current_mode == ControlMode.COMMAND else CatState.WALK)

func handle_command(command: int, payload: Dictionary = {}) -> void:
	if current_state == CatState.DRAG and command < 5:
		print("[Cat] DRAG 期间忽略外部指令")
		return
	match command:
		0: current_mode = ControlMode.COMMAND; command_ground_state = CatState.IDLE; if is_grounded: change_state(CatState.IDLE)
		1: current_mode = ControlMode.COMMAND; direction = -1.0; command_ground_state = CatState.WALK; _get_animated_sprite().flip_h = true; if is_grounded: change_state(CatState.WALK)
		2: current_mode = ControlMode.COMMAND; direction = 1.0; command_ground_state = CatState.WALK; _get_animated_sprite().flip_h = false; if is_grounded: change_state(CatState.WALK)
		3: current_mode = ControlMode.AUTO; print("[Cat] 恢复 AUTO 模式"); if is_grounded: change_state(CatState.WALK)
		4:
			if not is_grounded: print("[Cat] JUMP ignored: airborne"); return
			is_grounded = false; vertical_velocity = jump_velocity; change_state(CatState.JUMP)
		5: # DRAG_START
			drag_offset = position - Vector2(payload.get("mouse_pos", position))
			horizontal_throw_speed = 0.0; vertical_velocity = 0.0; is_grounded = false; change_state(CatState.DRAG)
		6: # DRAG_MOVE
			if current_state == CatState.DRAG:
				var vp_size := _get_viewport_size()
				var target_pos: Vector2 = Vector2(payload.get("mouse_pos", position)) + drag_offset
				target_pos.x = clampf(target_pos.x, body_radius, vp_size.x - body_radius)
				target_pos.y = clampf(target_pos.y, 30.0, ground_y + 10.0)
				position = target_pos
		7: # DRAG_END
			var throw_vel: Vector2 = payload.get("throw_velocity", Vector2.ZERO)
			horizontal_throw_speed = throw_vel.x
			if absf(throw_vel.x) > 20.0: direction = 1.0 if throw_vel.x > 0.0 else -1.0; _get_animated_sprite().flip_h = (direction < 0.0)
			if throw_vel.y < -50.0: is_grounded = false; vertical_velocity = throw_vel.y; change_state(CatState.JUMP)
			elif position.y < ground_y - 8.0: is_grounded = false; vertical_velocity = maxf(0.0, throw_vel.y); change_state(CatState.FALL)
			else: position.y = ground_y; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; _on_land()

func _move_and_bounce(delta: float) -> void:
	var vp_size := _get_viewport_size()
	position.x += direction * speed * delta
	if position.x >= vp_size.x - body_radius:
		position.x = vp_size.x - body_radius; direction = -1.0; _get_animated_sprite().flip_h = true
	elif position.x <= body_radius:
		position.x = body_radius; direction = 1.0; _get_animated_sprite().flip_h = false

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
