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

var current_surface_id: String = "screen:ground"
var current_surface: RefCounted = null
var surface_world_model: Node2D = null
var foot_offset: Vector2 = Vector2.ZERO
var support_margin: float = 4.0
var snap_tolerance: float = 8.0
var max_surface_attach_delta: float = 150.0
var physics_debug_enabled: bool = false
var _prev_foot_y: float = 0.0

var attention_target_pos: Vector2 = Vector2.ZERO
var has_attention_target: bool = false
var move_target_pos: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var move_speed_mode: String = "RUN"
var target_reached_radius: float = 50.0
var pointer_follow_distance: float = 64.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func get_foot_position() -> Vector2:
	return position + foot_offset

func get_current_surface_id() -> String:
	return current_surface_id

func get_current_surface() -> RefCounted:
	return current_surface

func toggle_physics_debug() -> bool:
	physics_debug_enabled = not physics_debug_enabled
	print("[Physics] Debug Physics: %s" % ("ON" if physics_debug_enabled else "OFF"))
	queue_redraw()
	return physics_debug_enabled

func _ready() -> void:
	ground_y = _get_viewport_size().y - 48.0
	if position.y == 0.0: position = Vector2(_get_viewport_size().x / 2.0, ground_y)
	_prev_foot_y = get_foot_position().y
	enter_state(CatState.WALK)


func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"): _main_node.update_mouse_passthrough(position)

func reset_to_ground(target_pos: Vector2) -> void:
	ground_y = target_pos.y; position = target_pos; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; has_move_target = false
	current_surface_id = "screen:ground"
	if is_instance_valid(surface_world_model) and surface_world_model.has_method("get_surface_by_id"):
		current_surface = surface_world_model.get_surface_by_id("screen:ground")
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
	if is_grounded:
		_check_ground_support()
		if not is_grounded: return

	if not is_grounded:
		var prev_y: float = get_foot_position().y
		vertical_velocity += gravity * delta
		var next_y: float = prev_y + vertical_velocity * delta
		position.y = next_y - foot_offset.y
		if position.y <= 30.0: position.y = 30.0; vertical_velocity = maxf(0.0, -vertical_velocity * 0.3)
		if current_state == CatState.JUMP and vertical_velocity >= 0.0: change_state(CatState.FALL)
		if horizontal_throw_speed != 0.0: _move_air_throw(delta)
		elif current_state in [CatState.WALK, CatState.RUN]: _move_and_bounce(delta, run_speed if current_state == CatState.RUN else walk_speed)

		if vertical_velocity >= 0.0:
			var hit_surface: RefCounted = null
			if is_instance_valid(surface_world_model) and surface_world_model.has_method("find_crossed_walkable_surface"):
				hit_surface = surface_world_model.find_crossed_walkable_surface(prev_y, next_y, get_foot_position().x, support_margin)
			if hit_surface != null:
				_land_on_surface(hit_surface)
			elif position.y >= ground_y:
				var sg = surface_world_model.get_surface_by_id("screen:ground") if is_instance_valid(surface_world_model) else null
				if sg != null: _land_on_surface(sg)
				else:
					position.y = ground_y; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; current_surface_id = "screen:ground"; _on_land()
		_prev_foot_y = get_foot_position().y
	elif has_move_target and current_state not in [CatState.SLEEP, CatState.DRAG]:
		_update_target_move(delta)
	elif current_mode == ControlMode.AUTO:
		state_timer -= delta
		if state_timer <= 0.0: _schedule_next_auto_state()
		if current_state == CatState.WALK: _move_and_bounce(delta, walk_speed)
		elif current_state == CatState.RUN: _move_and_bounce(delta, run_speed)
	elif current_state in [CatState.WALK, CatState.RUN]:
		_move_and_bounce(delta, run_speed if current_state == CatState.RUN else walk_speed)


func _update_target_move(delta: float) -> void:
	var vp_w := _get_viewport_size().x
	var target_x: float = move_target_pos.x - pointer_follow_distance if move_target_pos.x > position.x else move_target_pos.x + pointer_follow_distance
	target_x = clampf(target_x, body_radius, vp_w - body_radius)
	var dx: float = target_x - position.x
	if absf(dx) <= target_reached_radius:
		if current_state in [CatState.WALK, CatState.RUN]: change_state(CatState.IDLE)
	else:
		direction = 1.0 if dx > 0.0 else -1.0; _get_animated_sprite().flip_h = (direction < 0.0)
		var spd := run_speed if move_speed_mode == "RUN" else walk_speed
		if current_state != (CatState.RUN if move_speed_mode == "RUN" else CatState.WALK): change_state(CatState.RUN if move_speed_mode == "RUN" else CatState.WALK)
		position.x = clampf(position.x + direction * spd * delta, body_radius, vp_w - body_radius)

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
	horizontal_throw_speed = 0.0; print("[Cat] 落地着陆 (surface=%s, y=%.1f)" % [current_surface_id, position.y])
	if current_mode == ControlMode.COMMAND:
		if command_ground_state == CatState.SLEEP: command_ground_state = CatState.IDLE; sleep_cooldown = 15.0
		change_state(command_ground_state)
	else: change_state(CatState.WALK)

func _land_on_surface(s: RefCounted) -> void:
	position.y = s.y1 - foot_offset.y
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = true
	current_surface_id = s.id
	current_surface = s
	ground_y = s.y1
	print("[Physics] Landed: %s (y=%.1f)" % [s.id, s.y1])
	_on_land()

func _lose_ground_support() -> void:
	is_grounded = false
	current_surface_id = ""
	current_surface = null
	vertical_velocity = 0.0
	change_state(CatState.FALL)

func _check_ground_support() -> void:
	if not is_instance_valid(surface_world_model):
		return
	var s: RefCounted = null
	if current_surface_id != "":
		s = surface_world_model.get_surface_by_id(current_surface_id)
	if s == null:
		var foot_pos := get_foot_position()
		s = surface_world_model.find_support_surface_at(foot_pos.x, foot_pos.y, 8.0, support_margin)
		if s != null:
			current_surface_id = s.id
			current_surface = s
			ground_y = s.y1
			print("[Physics] Rebound support: %s" % s.id)
		else:
			print("[Physics] Surface lost: %s" % current_surface_id)
			_lose_ground_support()
			return

	current_surface = s
	ground_y = s.y1
	if s.source_type != "SCREEN":
		var fx := get_foot_position().x
		if fx < (s.x1 - support_margin) or fx > (s.x2 + support_margin):
			print("[Physics] Fell off surface edge: %s" % current_surface_id)
			_lose_ground_support()
			return
	position.y = s.y1 - foot_offset.y


func on_surface_world_updated(_rev: int = 0) -> void:
	if not is_grounded or current_surface == null or not is_instance_valid(surface_world_model):
		return
	if current_surface.dynamic and current_surface.source_type == "WINDOW":
		var wid: String = current_surface.source_id
		var delta_pos: Vector2 = surface_world_model.get_window_delta(wid)
		if delta_pos != Vector2.ZERO:
			if delta_pos.length() <= max_surface_attach_delta:
				position += delta_pos
				var foot_pos := get_foot_position()
				var re_s = surface_world_model.find_support_surface_at(foot_pos.x, foot_pos.y, 8.0, support_margin)
				if re_s != null:
					current_surface_id = re_s.id
					current_surface = re_s
					ground_y = re_s.y1
					position.y = re_s.y1 - foot_offset.y
				else:
					_check_ground_support()
			else:
				print("[Physics] Window delta (%.1f, %.1f) exceeded max delta %.1f, detaching" % [delta_pos.x, delta_pos.y, max_surface_attach_delta])
				_lose_ground_support()
	else:
		_check_ground_support()


func handle_command(command: int, payload: Dictionary = {}) -> void:
	if current_state == CatState.DRAG and command < 5: print("[Cat] DRAG 期间忽略指令"); return
	if command < 13: has_move_target = false
	match command:
		0: current_mode = ControlMode.COMMAND; command_ground_state = CatState.IDLE; if is_grounded: change_state(CatState.IDLE)
		1: current_mode = ControlMode.COMMAND; direction = -1.0; command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		2: current_mode = ControlMode.COMMAND; direction = 1.0; command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		3: current_mode = ControlMode.AUTO; print("[Cat] 恢复 AUTO 模式"); if is_grounded: change_state(CatState.WALK)
		4:
			if current_state == CatState.SLEEP: change_state(CatState.IDLE); sleep_cooldown = 15.0
			if not is_grounded: print("[Cat] JUMP ignored: airborne"); return
			is_grounded = false; current_surface_id = ""; current_surface = null
			vertical_velocity = jump_velocity; change_state(CatState.JUMP)
		5: # DRAG_START
			if current_state == CatState.SLEEP: sleep_cooldown = 15.0; command_ground_state = CatState.IDLE
			drag_offset = position - Vector2(payload.get("mouse_pos", position)); horizontal_throw_speed = 0.0; vertical_velocity = 0.0
			is_grounded = false; current_surface_id = ""; current_surface = null; change_state(CatState.DRAG)
		6: # DRAG_MOVE
			if current_state == CatState.DRAG:
				var vp := _get_viewport_size(); var t: Vector2 = Vector2(payload.get("mouse_pos", position)) + drag_offset
				position = Vector2(clampf(t.x, body_radius, vp.x - body_radius), clampf(t.y, 30.0, vp.y - 30.0))
		7: # DRAG_END
			var tv: Vector2 = payload.get("throw_velocity", Vector2.ZERO); horizontal_throw_speed = tv.x
			if absf(tv.x) > 20.0: direction = 1.0 if tv.x > 0.0 else -1.0; _get_animated_sprite().flip_h = (direction < 0.0)
			if tv.y < -50.0:
				is_grounded = false; current_surface_id = ""; current_surface = null
				vertical_velocity = tv.y; change_state(CatState.JUMP)
			else:
				var snap_s: RefCounted = null
				if is_instance_valid(surface_world_model) and surface_world_model.has_method("find_support_surface_at"):
					snap_s = surface_world_model.find_support_surface_at(get_foot_position().x, get_foot_position().y, snap_tolerance, support_margin)
				if snap_s != null:
					_land_on_surface(snap_s)
				else:
					is_grounded = false; current_surface_id = ""; current_surface = null
					vertical_velocity = maxf(0.0, tv.y); change_state(CatState.FALL)

		8: current_mode = ControlMode.COMMAND; direction = -1.0; command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)
		9: current_mode = ControlMode.COMMAND; direction = 1.0; command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)
		10: current_mode = ControlMode.COMMAND; command_ground_state = CatState.SIT; if is_grounded: change_state(CatState.SIT)
		11: current_mode = ControlMode.COMMAND; command_ground_state = CatState.SLEEP; if is_grounded: change_state(CatState.SLEEP)
		12: if current_state == CatState.SLEEP: sleep_cooldown = 15.0; change_state(CatState.IDLE); print("[Cat] 被唤醒并进入 IDLE")
		13: # LOOK_AT_POSITION
			if current_state in [CatState.SLEEP, CatState.DRAG]: return
			attention_target_pos = payload.get("target_pos", Vector2.ZERO); has_attention_target = true
			if current_state in [CatState.IDLE, CatState.SIT] and absf(attention_target_pos.x - position.x) > 20.0:
				direction = 1.0 if attention_target_pos.x > position.x else -1.0; _get_animated_sprite().flip_h = (direction < 0.0)
		14: # MOVE_TO_POSITION
			if current_state in [CatState.SLEEP, CatState.DRAG] or not is_grounded: return
			move_target_pos = payload.get("target_pos", Vector2.ZERO); move_speed_mode = payload.get("speed_mode", "RUN"); has_move_target = true
		15: # CLEAR_TARGET
			has_attention_target = false; has_move_target = false

func _move_and_bounce(delta: float, cur_speed: float) -> void:
	var vp_w := _get_viewport_size().x; position.x += direction * cur_speed * delta
	if position.x >= vp_w - body_radius: position.x = vp_w - body_radius; direction = -1.0; _get_animated_sprite().flip_h = true
	elif position.x <= body_radius: position.x = body_radius; direction = 1.0; _get_animated_sprite().flip_h = false

func _on_clicked() -> void:
	print("Cat clicked!"); var sprite := _get_animated_sprite()
	if sprite: var tw := create_tween(); tw.tween_property(sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); tw.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var main_p := get_parent()
	if main_p and "mouse_perception_controller" in main_p and main_p.mouse_perception_controller: main_p.mouse_perception_controller.suppress_curiosity()

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite: _animated_sprite = get_node_or_null("AnimatedSprite2D")
	return _animated_sprite

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport() and DisplayServer.get_name() != "headless":
		var s := get_viewport_rect().size; if s.x > body_radius * 2.0: return s
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 640), ProjectSettings.get_setting("display/window/size/viewport_height", 360))

func _draw() -> void:
	if not physics_debug_enabled:
		return
	draw_circle(foot_offset, 5.0, Color(1.0, 0.2, 0.2, 0.95))
	if current_surface != null:
		var p1 := to_local(Vector2(current_surface.x1, current_surface.y1))
		var p2 := to_local(Vector2(current_surface.x2, current_surface.y2))
		draw_line(p1, p2, Color(1.0, 0.2, 0.8, 0.95), 4.0)
	var info := "[F10 Physics] Surface: %s | Grounded: %s | State: %s" % [current_surface_id if current_surface_id != "" else "AIRBORNE", "YES" if is_grounded else "NO", CatState.keys()[current_state]]
	draw_string(ThemeDB.fallback_font, Vector2(-60.0, -38.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.2, 0.95))

