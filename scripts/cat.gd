class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK, RUN, SIT, SLEEP, JUMP, FALL, DRAG }

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
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
var sleep_cooldown: float = 0.0
var run_cooldown: float = 0.0
var drag_offset: Vector2 = Vector2.ZERO

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func _ready() -> void:
	ground_y = _get_viewport_size().y - 48.0
	if position.y == 0.0: position = Vector2(_get_viewport_size().x / 2.0, ground_y)
	enter_state(CatState.WALK)

func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"): _main_node.update_mouse_passthrough(position)

func reset_to_ground(target_pos: Vector2) -> void:
	ground_y = target_pos.y; position = target_pos; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true
	change_state(CatState.WALK if current_mode == ControlMode.AUTO else command_ground_state)

func change_state(new_state: CatState) -> void:
	current_state = new_state; enter_state(new_state)

func enter_state(state: CatState) -> void:
	var sprite := _get_animated_sprite()
	match state:
		CatState.WALK: state_timer = randf_range(3.0, 7.0); if sprite: sprite.play("walk"); sprite.flip_h = (direction < 0.0)
		CatState.RUN: state_timer = randf_range(2.0, 4.5); if sprite: sprite.play("run"); sprite.flip_h = (direction < 0.0)
		CatState.IDLE: state_timer = randf_range(1.5, 4.0); if sprite: sprite.play("idle"); sprite.flip_h = (direction < 0.0)
		CatState.SIT: state_timer = randf_range(3.0, 8.0); if sprite: sprite.play("sit"); sprite.flip_h = (direction < 0.0)
		CatState.SLEEP: state_timer = randf_range(8.0, 16.0); if sprite: sprite.play("sleep"); sprite.flip_h = (direction < 0.0)
		CatState.JUMP: if sprite: sprite.play("run" if command_ground_state == CatState.RUN else "walk"); sprite.flip_h = (direction < 0.0)
		CatState.FALL, CatState.DRAG: if sprite: sprite.play("idle"); sprite.flip_h = (direction < 0.0)
	print("[Cat] [%s] 进入状态: %s, 朝向: %s, Y=%.1f" % ["AUTO" if current_mode == ControlMode.AUTO else "COMMAND", CatState.keys()[state], "左" if direction < 0.0 else "右", position.y])

func update_state(delta: float) -> void:
	sleep_cooldown = maxf(0.0, sleep_cooldown - delta); run_cooldown = maxf(0.0, run_cooldown - delta)
	if current_state == CatState.DRAG: return
	if not is_grounded:
		vertical_velocity += gravity * delta; position.y += vertical_velocity * delta
		if position.y <= 30.0: position.y = 30.0; vertical_velocity = maxf(0.0, -vertical_velocity * 0.3)
		if current_state == CatState.JUMP and vertical_velocity >= 0.0: change_state(CatState.FALL)
		if horizontal_throw_speed != 0.0: _move_air_throw(delta)
		elif current_state in [CatState.WALK, CatState.RUN]: _move_and_bounce(delta, run_speed if current_state == CatState.RUN else walk_speed)
		if position.y >= ground_y: position.y = ground_y; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; _on_land()
	elif current_mode == ControlMode.AUTO:
		state_timer -= delta
		if state_timer <= 0.0: _schedule_next_auto_state()
		if current_state == CatState.WALK: _move_and_bounce(delta, walk_speed)
		elif current_state == CatState.RUN: _move_and_bounce(delta, run_speed)
	elif current_state in [CatState.WALK, CatState.RUN]:
		_move_and_bounce(delta, run_speed if current_state == CatState.RUN else walk_speed)

func _schedule_next_auto_state() -> void:
	if current_state == CatState.SLEEP: sleep_cooldown = 15.0; change_state(CatState.IDLE); return
	if current_state == CatState.RUN: run_cooldown = 6.0; change_state(CatState.IDLE); return
	var vp_w := _get_viewport_size().x
	if position.x > vp_w * 0.75: direction = -1.0 if randf() < 0.8 else 1.0
	elif position.x < vp_w * 0.25: direction = 1.0 if randf() < 0.8 else -1.0
	elif randf() < 0.5: direction = -direction
	
	var r := randf()
	if r < 0.40: change_state(CatState.WALK)
	elif r < 0.65: change_state(CatState.SIT)
	elif r < 0.80: change_state(CatState.IDLE)
	elif r < 0.95 and run_cooldown <= 0.0: change_state(CatState.RUN)
	elif sleep_cooldown <= 0.0: change_state(CatState.SLEEP)
	else: change_state(CatState.WALK)

func _move_air_throw(delta: float) -> void:
	var vp_w := _get_viewport_size().x; position.x += horizontal_throw_speed * delta
	if position.x >= vp_w - body_radius: position.x = vp_w - body_radius; horizontal_throw_speed = -horizontal_throw_speed * 0.6; direction = -1.0; _get_animated_sprite().flip_h = true
	elif position.x <= body_radius: position.x = body_radius; horizontal_throw_speed = -horizontal_throw_speed * 0.6; direction = 1.0; _get_animated_sprite().flip_h = false

func _on_land() -> void:
	horizontal_throw_speed = 0.0; print("[Cat] 落地着陆 (ground_y=%.1f)" % ground_y)
	if current_mode == ControlMode.COMMAND:
		if command_ground_state == CatState.SLEEP: command_ground_state = CatState.IDLE; sleep_cooldown = 15.0
		change_state(command_ground_state)
	else:
		change_state(CatState.WALK)

func handle_command(command: int, payload: Dictionary = {}) -> void:
	if current_state == CatState.DRAG and command < 5: print("[Cat] DRAG 期间忽略指令"); return
	match command:
		0: current_mode = ControlMode.COMMAND; command_ground_state = CatState.IDLE; if is_grounded: change_state(CatState.IDLE)
		1: current_mode = ControlMode.COMMAND; direction = -1.0; command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		2: current_mode = ControlMode.COMMAND; direction = 1.0; command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		3: current_mode = ControlMode.AUTO; print("[Cat] 恢复 AUTO 模式"); if is_grounded: change_state(CatState.WALK)
		4:
			if current_state == CatState.SLEEP: change_state(CatState.IDLE); sleep_cooldown = 15.0
			if not is_grounded: print("[Cat] JUMP ignored: airborne"); return
			is_grounded = false; vertical_velocity = jump_velocity; change_state(CatState.JUMP)
		5: # DRAG_START
			if current_state == CatState.SLEEP: sleep_cooldown = 15.0; command_ground_state = CatState.IDLE
			drag_offset = position - Vector2(payload.get("mouse_pos", position)); horizontal_throw_speed = 0.0; vertical_velocity = 0.0; is_grounded = false; change_state(CatState.DRAG)
		6: # DRAG_MOVE
			if current_state == CatState.DRAG:
				var vp := _get_viewport_size(); var t: Vector2 = Vector2(payload.get("mouse_pos", position)) + drag_offset
				position = Vector2(clampf(t.x, body_radius, vp.x - body_radius), clampf(t.y, 30.0, ground_y + 10.0))
		7: # DRAG_END
			var tv: Vector2 = payload.get("throw_velocity", Vector2.ZERO); horizontal_throw_speed = tv.x
			if absf(tv.x) > 20.0: direction = 1.0 if tv.x > 0.0 else -1.0; _get_animated_sprite().flip_h = (direction < 0.0)
			if tv.y < -50.0: is_grounded = false; vertical_velocity = tv.y; change_state(CatState.JUMP)
			elif position.y < ground_y - 8.0: is_grounded = false; vertical_velocity = maxf(0.0, tv.y); change_state(CatState.FALL)
			else: position.y = ground_y; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; _on_land()
		8: current_mode = ControlMode.COMMAND; direction = -1.0; command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)
		9: current_mode = ControlMode.COMMAND; direction = 1.0; command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)
		10: current_mode = ControlMode.COMMAND; command_ground_state = CatState.SIT; if is_grounded: change_state(CatState.SIT)
		11: current_mode = ControlMode.COMMAND; command_ground_state = CatState.SLEEP; if is_grounded: change_state(CatState.SLEEP)
		12: if current_state == CatState.SLEEP: sleep_cooldown = 15.0; change_state(CatState.IDLE); print("[Cat] 被唤醒并进入 IDLE")

func _move_and_bounce(delta: float, cur_speed: float) -> void:
	var vp_w := _get_viewport_size().x; position.x += direction * cur_speed * delta
	if position.x >= vp_w - body_radius: position.x = vp_w - body_radius; direction = -1.0; _get_animated_sprite().flip_h = true
	elif position.x <= body_radius: position.x = body_radius; direction = 1.0; _get_animated_sprite().flip_h = false

func _on_clicked() -> void:
	print("Cat clicked!"); var sprite := _get_animated_sprite()
	if sprite: var tw := create_tween(); tw.tween_property(sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); tw.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite: _animated_sprite = get_node_or_null("AnimatedSprite2D")
	return _animated_sprite

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport() and DisplayServer.get_name() != "headless":
		var s := get_viewport_rect().size; if s.x > body_radius * 2.0: return s
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 640), ProjectSettings.get_setting("display/window/size/viewport_height", 360))
