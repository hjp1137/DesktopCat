class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK, RUN, SIT, SLEEP, JUMP, FALL, DRAG, EDGE_HANG }

const GrabbedEdgeClass = preload("res://scripts/world/grabbed_edge.gd")

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
@export var body_radius: float = 28.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -420.0

@export var edge_grab_x_tolerance: float = 14.0
@export var edge_grab_y_tolerance: float = 20.0
@export var max_edge_grab_vertical_speed: float = 600.0
@export var max_edge_grab_horizontal_speed: float = 280.0
@export var edge_hang_offset_x: float = 6.0
@export var edge_hang_offset_y: float = 18.0
@export var auto_edge_hang_duration_min: float = 2.0
@export var auto_edge_hang_duration_max: float = 3.5
@export var max_edge_hang_safety_time: float = 60.0
@export var grab_point_offset_x: float = 12.0
@export var grab_point_offset_y: float = -20.0

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

var grabbed_edge: RefCounted = null
var grabbed_surface_id: String = ""
var edge_grab_debug_enabled: bool = false
var auto_edge_hang_timer: float = 0.0
var _prev_grab_left: Vector2 = Vector2.ZERO
var _prev_grab_right: Vector2 = Vector2.ZERO
var edge_grab_stats: Dictionary = {
	"grab_attempts": 0, "grab_success": 0, "rejected_speed": 0,
	"released": 0, "surface_lost": 0, "rebound_edge": 0
}

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

func get_left_grab_point() -> Vector2:
	return position + Vector2(-grab_point_offset_x, grab_point_offset_y)

func get_right_grab_point() -> Vector2:
	return position + Vector2(grab_point_offset_x, grab_point_offset_y)

func toggle_edge_grab_debug() -> bool:
	edge_grab_debug_enabled = not edge_grab_debug_enabled
	print("[EdgeGrab] Debug View: %s" % ("ON" if edge_grab_debug_enabled else "OFF"))
	queue_redraw()
	return edge_grab_debug_enabled

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
	_prev_grab_left = get_left_grab_point()
	_prev_grab_right = get_right_grab_point()
	enter_state(CatState.WALK)


func _process(delta: float) -> void:
	update_state(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"): _main_node.update_mouse_passthrough(position)

func reset_to_ground(target_pos: Vector2) -> void:
	ground_y = target_pos.y; position = target_pos; vertical_velocity = 0.0; horizontal_throw_speed = 0.0; is_grounded = true; has_move_target = false
	current_surface_id = "screen:ground"
	grabbed_edge = null
	grabbed_surface_id = ""
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
		CatState.EDGE_HANG:
			state_timer = auto_edge_hang_timer
			if sprite:
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("edge_hang"):
					sprite.play("edge_hang")
				else:
					sprite.play("idle")
				sprite.flip_h = (direction < 0.0)
	print("[Cat] [%s] 进入状态: %s, 朝向: %s, Y=%.1f" % ["AUTO" if current_mode == ControlMode.AUTO else "COMMAND", CatState.keys()[state], "左" if direction < 0.0 else "右", position.y])

func update_state(delta: float) -> void:
	sleep_cooldown = maxf(0.0, sleep_cooldown - delta); run_cooldown = maxf(0.0, run_cooldown - delta)
	if current_state == CatState.DRAG: return
	if current_state == CatState.EDGE_HANG:
		_update_edge_hang(delta)
		return
	if is_grounded:
		_check_ground_support()
		if not is_grounded: return

	if not is_grounded:
		var prev_y: float = get_foot_position().y
		var prev_grab_l := get_left_grab_point()
		var prev_grab_r := get_right_grab_point()
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
			elif current_state == CatState.FALL:
				_check_edge_grab(prev_grab_l, get_left_grab_point(), prev_grab_r, get_right_grab_point())
		_prev_foot_y = get_foot_position().y
		_prev_grab_left = get_left_grab_point()
		_prev_grab_right = get_right_grab_point()
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
	var sg = surface_world_model.get_surface_by_id("screen:ground") if is_instance_valid(surface_world_model) else null
	ground_y = sg.y1 if sg != null else (_get_viewport_size().y - 48.0)
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

func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)

func _check_edge_grab(prev_l: Vector2, curr_l: Vector2, prev_r: Vector2, curr_r: Vector2) -> void:
	if not is_instance_valid(surface_world_model):
		return
	var cur_vx: float = horizontal_throw_speed if horizontal_throw_speed != 0.0 else (direction * (run_speed if current_state == CatState.RUN else walk_speed))
	if vertical_velocity > max_edge_grab_vertical_speed:
		edge_grab_stats["rejected_speed"] = int(edge_grab_stats["rejected_speed"]) + 1
		return
	if absf(cur_vx) > max_edge_grab_horizontal_speed:
		edge_grab_stats["rejected_speed"] = int(edge_grab_stats["rejected_speed"]) + 1
		return

	var min_chk_x: float = minf(minf(prev_l.x, curr_l.x), minf(prev_r.x, curr_r.x)) - edge_grab_x_tolerance - 12.0
	var max_chk_x: float = maxf(maxf(prev_l.x, curr_l.x), maxf(prev_r.x, curr_r.x)) + edge_grab_x_tolerance + 12.0
	var min_chk_y: float = minf(minf(prev_l.y, curr_l.y), minf(prev_r.y, curr_r.y)) - edge_grab_y_tolerance - 12.0
	var max_chk_y: float = maxf(maxf(prev_l.y, curr_l.y), maxf(prev_r.y, curr_r.y)) + edge_grab_y_tolerance + 12.0
	var query_rect := Rect2(min_chk_x, min_chk_y, max_chk_x - min_chk_x, max_chk_y - min_chk_y)

	var candidates: Array = surface_world_model.get_grabbable_edges_in_rect(query_rect)
	if candidates.is_empty():
		return

	var best_cand: Dictionary = {}
	var best_dist: float = INF

	for cand in candidates:
		edge_grab_stats["grab_attempts"] = int(edge_grab_stats["grab_attempts"]) + 1
		var side: int = int(cand.side)
		var ex: float = float(cand.x)
		var ey: float = float(cand.y)
		var e_pos: Vector2 = cand.pos

		if side == -1:
			if position.x > (ex + 10.0):
				continue
		else:
			if position.x < (ex - 10.0):
				continue

		var pts_to_check: Array = []
		if cur_vx >= 0.0:
			pts_to_check.append({ "prev": prev_r, "curr": curr_r })
			pts_to_check.append({ "prev": prev_l, "curr": curr_l })
		else:
			pts_to_check.append({ "prev": prev_l, "curr": curr_l })
			pts_to_check.append({ "prev": prev_r, "curr": curr_r })

		for p_pair in pts_to_check:
			var p0: Vector2 = p_pair.prev
			var p1: Vector2 = p_pair.curr
			var min_dx: float = minf(absf(p0.x - ex), absf(p1.x - ex))
			var min_dy: float = minf(absf(p0.y - ey), absf(p1.y - ey))
			var seg_dist: float = _point_to_segment_distance(e_pos, p0, p1)
			if min_dx <= edge_grab_x_tolerance and min_dy <= edge_grab_y_tolerance and seg_dist <= (edge_grab_y_tolerance + 4.0):
				if seg_dist < best_dist:
					best_dist = seg_dist
					best_cand = cand
				break

	if not best_cand.is_empty():
		_grab_edge(best_cand)

func _grab_edge(cand: Dictionary) -> void:
	edge_grab_stats["grab_success"] = int(edge_grab_stats["grab_success"]) + 1
	grabbed_surface_id = str(cand.surface_id)
	var side: int = int(cand.side)
	var ex: float = float(cand.x)
	var ey: float = float(cand.y)
	grabbed_edge = GrabbedEdgeClass.new(grabbed_surface_id, side, ex, ey)

	if side == -1:
		direction = 1.0
	else:
		direction = -1.0
	if _get_animated_sprite():
		_get_animated_sprite().flip_h = (direction < 0.0)

	position.x = ex + (-edge_hang_offset_x if side == -1 else edge_hang_offset_x)
	position.y = ey + edge_hang_offset_y

	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	current_surface_id = ""
	current_surface = null

	if current_mode == ControlMode.AUTO:
		auto_edge_hang_timer = randf_range(auto_edge_hang_duration_min, auto_edge_hang_duration_max)
	else:
		auto_edge_hang_timer = max_edge_hang_safety_time

	change_state(CatState.EDGE_HANG)
	print("[EdgeGrab] Grabbed surface=%s side=%s" % [grabbed_surface_id, "LEFT" if side == -1 else "RIGHT"])

func _update_edge_hang(delta: float) -> void:
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	if grabbed_edge == null:
		release_edge()
		return

	if not is_instance_valid(surface_world_model):
		return

	var s = surface_world_model.get_surface_by_id(grabbed_surface_id)
	if s != null:
		var cur_pos: Vector2 = Vector2(minf(s.x1, s.x2), s.y1) if grabbed_edge.edge_side == -1 else Vector2(maxf(s.x1, s.x2), s.y1)
		var delta_pos: Vector2 = cur_pos - grabbed_edge.get_edge_position()
		if delta_pos.length() > max_surface_attach_delta:
			print("[EdgeGrab] Detached: large delta (%.1f > %.1f)" % [delta_pos.length(), max_surface_attach_delta])
			release_edge()
			return
		elif delta_pos != Vector2.ZERO:
			position += delta_pos
			grabbed_edge.edge_x = cur_pos.x
			grabbed_edge.edge_y = cur_pos.y
	else:
		var re_edge: Dictionary = surface_world_model.find_equivalent_edge_near(grabbed_edge.get_edge_position(), grabbed_edge.edge_side, 16.0)
		if not re_edge.is_empty():
			grabbed_surface_id = str(re_edge.surface_id)
			grabbed_edge.surface_id = grabbed_surface_id
			grabbed_edge.edge_x = float(re_edge.x)
			grabbed_edge.edge_y = float(re_edge.y)
			edge_grab_stats["rebound_edge"] = int(edge_grab_stats["rebound_edge"]) + 1
			print("[EdgeGrab] Rebound edge: %s" % grabbed_surface_id)
		else:
			edge_grab_stats["surface_lost"] = int(edge_grab_stats["surface_lost"]) + 1
			print("[EdgeGrab] Surface lost: %s -> FALL" % grabbed_surface_id)
			release_edge()
			return

	if current_mode == ControlMode.AUTO:
		auto_edge_hang_timer -= delta
		if auto_edge_hang_timer <= 0.0:
			print("[EdgeGrab] AUTO hang duration ended, releasing")
			release_edge()
			return

func release_edge() -> void:
	if current_state != CatState.EDGE_HANG and grabbed_edge == null:
		return
	edge_grab_stats["released"] = int(edge_grab_stats["released"]) + 1
	grabbed_edge = null
	grabbed_surface_id = ""
	is_grounded = false
	current_surface_id = ""
	current_surface = null
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	var sg = surface_world_model.get_surface_by_id("screen:ground") if is_instance_valid(surface_world_model) else null
	ground_y = sg.y1 if sg != null else (_get_viewport_size().y - 48.0)
	change_state(CatState.FALL)
	print("[EdgeGrab] Released")

func on_surface_world_updated(_rev: int = 0) -> void:
	if current_state == CatState.EDGE_HANG:
		_update_edge_hang(0.0)
		return
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
	if current_state == CatState.EDGE_HANG:
		if command == 16: # RELEASE_EDGE
			release_edge()
			return
		elif command == 5: # DRAG_START
			grabbed_edge = null
			grabbed_surface_id = ""
		elif command == 4: # JUMP
			print("[Cat] JUMP ignored while EDGE_HANG")
			return
		elif command in [0, 1, 2, 8, 9, 10, 11, 12, 14]:
			return
	var from_planner: bool = (str(payload.get("source", "")) == "planner")
	if command < 13 and not from_planner: has_move_target = false
	match command:
		0: if not from_planner: current_mode = ControlMode.COMMAND; command_ground_state = CatState.IDLE; if is_grounded: change_state(CatState.IDLE)
		1: if not from_planner: current_mode = ControlMode.COMMAND; direction = -1.0; if not from_planner: command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		2: if not from_planner: current_mode = ControlMode.COMMAND; direction = 1.0; if not from_planner: command_ground_state = CatState.WALK; if is_grounded: change_state(CatState.WALK)
		3: current_mode = ControlMode.AUTO; print("[Cat] 恢复 AUTO 模式"); if is_grounded: change_state(CatState.WALK)

		4:
			if current_state == CatState.SLEEP: change_state(CatState.IDLE); sleep_cooldown = 15.0
			if not is_grounded: print("[Cat] JUMP ignored: airborne"); return
			is_grounded = false; current_surface_id = ""; current_surface = null
			var req_spd_mode: String = payload.get("speed_mode", "")
			if req_spd_mode == "RUN" or current_state == CatState.RUN or command_ground_state == CatState.RUN:
				horizontal_throw_speed = direction * run_speed
			elif req_spd_mode == "WALK" or current_state == CatState.WALK or command_ground_state == CatState.WALK:
				horizontal_throw_speed = direction * walk_speed
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

		8: if not from_planner: current_mode = ControlMode.COMMAND; direction = -1.0; if not from_planner: command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)
		9: if not from_planner: current_mode = ControlMode.COMMAND; direction = 1.0; if not from_planner: command_ground_state = CatState.RUN; if is_grounded: change_state(CatState.RUN)

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
		16: # RELEASE_EDGE
			release_edge()

func _move_and_bounce(delta: float, cur_speed: float) -> void:
	var vp_w := _get_viewport_size().x; position.x += direction * cur_speed * delta
	if position.x >= vp_w - body_radius: position.x = vp_w - body_radius; direction = -1.0; _get_animated_sprite().flip_h = true
	elif position.x <= body_radius: position.x = body_radius; direction = 1.0; _get_animated_sprite().flip_h = false

func _on_clicked() -> void:
	print("Cat clicked!")
	if current_state != CatState.EDGE_HANG:
		var sprite := _get_animated_sprite()
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
	if physics_debug_enabled:
		draw_circle(foot_offset, 5.0, Color(1.0, 0.2, 0.2, 0.95))
		if current_surface != null:
			var p1 := to_local(Vector2(current_surface.x1, current_surface.y1))
			var p2 := to_local(Vector2(current_surface.x2, current_surface.y2))
			draw_line(p1, p2, Color(1.0, 0.2, 0.8, 0.95), 4.0)
		var info := "[F10 Physics] Surface: %s | Grounded: %s | State: %s" % [current_surface_id if current_surface_id != "" else "AIRBORNE", "YES" if is_grounded else "NO", CatState.keys()[current_state]]
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -38.0), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.2, 0.95))

	if edge_grab_debug_enabled:
		var pl := to_local(get_left_grab_point())
		var pr := to_local(get_right_grab_point())
		draw_circle(pl, 4.0, Color(0.1, 0.9, 1.0, 0.95))
		draw_circle(pr, 4.0, Color(1.0, 0.8, 0.1, 0.95))
		if is_instance_valid(surface_world_model) and surface_world_model.has_method("get_grabbable_edges_in_rect"):
			var q_rect := Rect2(position.x - 300.0, position.y - 250.0, 600.0, 500.0)
			var edges_near: Array = surface_world_model.get_grabbable_edges_in_rect(q_rect)
			for e in edges_near:
				var eloc := to_local(Vector2(e.x, e.y))
				var r_box := Rect2(eloc - Vector2(edge_grab_x_tolerance, edge_grab_y_tolerance), Vector2(edge_grab_x_tolerance * 2.0, edge_grab_y_tolerance * 2.0))
				draw_rect(r_box, Color(0.2, 0.9, 1.0, 0.35), false, 1.5)
				draw_string(ThemeDB.fallback_font, eloc + Vector2(-4.0, -8.0), "L" if int(e.side) == -1 else "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 1.0, 0.2, 0.95))
		if current_state == CatState.EDGE_HANG and grabbed_edge != null:
			var pe := to_local(grabbed_edge.get_edge_position())
			draw_circle(pe, 6.0, Color(1.0, 0.1, 0.6, 0.95))
			draw_line(Vector2.ZERO, pe, Color(1.0, 0.1, 0.6, 0.8), 2.0)
		var eg_info := "[F16 EdgeGrab] State: %s | Edge: %s (%s) | Success: %d" % [CatState.keys()[current_state], grabbed_surface_id if grabbed_surface_id != "" else "NONE", grabbed_edge.get_side_name() if grabbed_edge else "-", int(edge_grab_stats["grab_success"])]
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -52.0), eg_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 1.0, 0.8, 0.95))

