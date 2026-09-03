class_name Cat
extends Node2D

enum ControlMode { AUTO, COMMAND }
enum CatState { IDLE, WALK, RUN, SIT, SLEEP, JUMP, FALL, DRAG, EDGE_HANG, CLIMB_UP, WALL_CLING, WALL_CLIMB }
enum ClimbPhase { NONE, PULL_UP, SHIFT_IN, SETTLE }
enum WallClimbDirection { NONE, UP, DOWN }

signal climb_completed(surface_id: String)
signal climb_failed(reason: String)
signal metrics_changed(revision: int)

const GrabbedEdgeClass = preload("res://scripts/world/grabbed_edge.gd")
const ClimbTargetClass = preload("res://scripts/world/climb_target.gd")
const WallAttachmentClass = preload("res://scripts/world/wall_attachment.gd")
const CatMetricsClass = preload("res://scripts/cat/cat_metrics.gd")
const CatBodyProfileClass = preload("res://scripts/cat/cat_body_profile.gd")
const CatAnimationControllerClass = preload("res://scripts/cat/cat_animation_controller.gd")
const CatShadowClass = preload("res://scripts/cat/cat_shadow.gd")
const CatSpriteLoaderClass = preload("res://scripts/cat/cat_sprite_loader.gd")

var metrics: RefCounted = null
var metrics_debug_enabled: bool = false

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

@export var climb_inward_margin: float = 20.0
@export var min_climb_up_platform_length: float = 48.0
@export var climb_pull_up_duration: float = 0.30
@export var climb_shift_in_duration: float = 0.25
@export var climb_clearance_margin: float = 4.0
@export var max_climb_target_delta: float = 150.0
@export var climb_up_timeout: float = 2.0
@export var auto_climb_reaction_delay: float = 0.5
@export var climb_cooldown_time: float = 1.5

var current_climb_phase: ClimbPhase = ClimbPhase.NONE
var current_climb_target: RefCounted = null
var climb_phase_timer: float = 0.0
var climb_total_timer: float = 0.0
var climb_cooldown: float = 0.0
var auto_climb_pause_timer: float = 0.0
var climb_debug_enabled: bool = false
var climb_stats: Dictionary = {
	"climb_attempts": 0, "climb_success": 0, "climb_cancelled": 0
}

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

@export var min_climbable_wall_length: float = 48.0
@export var wall_attach_x_tolerance: float = 14.0
@export var max_wall_attach_vertical_speed: float = 500.0
@export var max_wall_attach_horizontal_speed: float = 280.0
@export var wall_cling_offset_x: float = 14.0
@export var wall_climb_speed: float = 60.0
@export var wall_top_edge_tolerance: float = 8.0
@export var max_wall_attach_delta: float = 150.0
@export var auto_wall_reaction_delay: float = 0.5
@export var auto_max_wall_climb_duration: float = 4.0
@export var wall_cooldown_time: float = 1.0

var is_planned_wall_climb: bool = false
var planned_wall_climb_timeout: float = 6.0

var current_wall_attachment: RefCounted = null
var current_wall_climb_dir: WallClimbDirection = WallClimbDirection.NONE
var auto_wall_pause_timer: float = 0.0
var auto_wall_climb_timer: float = 0.0
var wall_cooldown: float = 0.0
var wall_debug_enabled: bool = false
var _prev_wall_contact: Vector2 = Vector2.ZERO
var wall_stats: Dictionary = {
	"wall_attach_attempts": 0, "wall_attach_success": 0, "wall_climb_started": 0,
	"wall_top_reached": 0, "wall_released": 0, "wall_surface_lost": 0, "wall_rebind_success": 0
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

var _visual_root: Node2D = null
var visual_root: Node2D:
	get:
		if _visual_root == null: _visual_root = get_node_or_null("VisualRoot")
		return _visual_root
	set(v): _visual_root = v

var _cat_shadow: Node2D = null
var cat_shadow: Node2D:
	get:
		if _cat_shadow == null:
			_cat_shadow = get_node_or_null("CatShadow")
			if _cat_shadow and _cat_shadow.has_method("setup"): _cat_shadow.setup(self)
		return _cat_shadow
	set(v): _cat_shadow = v

var _anim_controller: Node2D = null
var anim_controller: Node2D:
	get:
		if _anim_controller == null:
			_anim_controller = get_node_or_null("CatAnimationController")
			if _anim_controller == null:
				_anim_controller = CatAnimationControllerClass.new()
				add_child(_anim_controller)
				var sprite := _get_animated_sprite()
				_anim_controller.setup(self, visual_root if visual_root != null else self, sprite)
		return _anim_controller
	set(v): _anim_controller = v

var _animated_sprite: AnimatedSprite2D = null
@onready var _main_node: Node = get_parent()

func _init() -> void:
	if metrics == null:
		metrics = CatMetricsClass.new()
	_sync_metrics_properties()

func _sync_metrics_properties() -> void:
	if metrics == null: return
	foot_offset = metrics.foot_offset
	body_radius = metrics.body_radius
	support_margin = metrics.support_margin
	snap_tolerance = metrics.snap_tolerance
	edge_grab_x_tolerance = metrics.edge_grab_x_tolerance
	edge_grab_y_tolerance = metrics.edge_grab_y_tolerance
	edge_hang_offset_x = metrics.edge_hang_offset_x
	edge_hang_offset_y = metrics.edge_hang_offset_y
	grab_point_offset_x = metrics.grab_point_offset_x
	grab_point_offset_y = metrics.grab_point_offset_y
	climb_inward_margin = metrics.climb_inward_margin
	climb_clearance_margin = metrics.climb_clearance_margin
	min_climb_up_platform_length = metrics.min_platform_length
	min_climbable_wall_length = metrics.min_climbable_wall_length
	wall_attach_x_tolerance = metrics.wall_attach_x_tolerance
	wall_cling_offset_x = metrics.wall_cling_offset_x
	wall_top_edge_tolerance = metrics.wall_top_edge_tolerance

func recalculate_for_display(screen_h: float) -> void:
	if metrics == null: metrics = CatMetricsClass.new()
	var b_scale: float = CatMetricsClass.calc_base_scale_from_screen_height(screen_h)
	metrics.update_scales(b_scale, metrics.user_scale)
	_apply_metrics_change()

func set_user_scale(val: float) -> void:
	if metrics == null: metrics = CatMetricsClass.new()
	metrics.update_scales(metrics.base_scale, val)
	_apply_metrics_change()

func adjust_user_scale(delta: float) -> void:
	if metrics == null: metrics = CatMetricsClass.new()
	set_user_scale(metrics.user_scale + delta)

func reset_user_scale() -> void:
	if metrics == null: metrics = CatMetricsClass.new()
	set_user_scale(CatMetricsClass.DEFAULT_USER_SCALE)

func _apply_metrics_change() -> void:
	_sync_metrics_properties()
	if visual_root != null:
		visual_root.scale = Vector2(metrics.final_scale, metrics.final_scale)
	else:
		var sprite := _get_animated_sprite()
		if sprite:
			sprite.scale = Vector2(metrics.final_scale, metrics.final_scale)
	var col_shape: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D")
	if col_shape and col_shape.shape is RectangleShape2D:
		col_shape.shape.size = metrics.hitbox_size

	if current_state in [CatState.EDGE_HANG, CatState.CLIMB_UP, CatState.WALL_CLING, CatState.WALL_CLIMB]:
		if current_state in [CatState.WALL_CLING, CatState.WALL_CLIMB]:
			release_wall("SCALE_CHANGED")
		elif current_state == CatState.CLIMB_UP:
			cancel_climb("SCALE_CHANGED")
		elif current_state == CatState.EDGE_HANG:
			release_edge()
	elif is_grounded and current_surface != null:
		position.y = current_surface.y1 - foot_offset.y

	metrics_changed.emit(metrics.metrics_revision)
	queue_redraw()
	print("[Cat] Metrics updated: rev=%d final_scale=%.3f (visual %.0fx%.0f, body %.0fx%.0f)" % [
		metrics.metrics_revision, metrics.final_scale, metrics.visual_width, metrics.visual_height,
		metrics.body_width, metrics.body_height
	])

func get_foot_position() -> Vector2:
	return position + foot_offset

func get_left_grab_point() -> Vector2:
	return position + Vector2(-grab_point_offset_x, grab_point_offset_y)

func get_right_grab_point() -> Vector2:
	return position + Vector2(grab_point_offset_x, grab_point_offset_y)

func get_wall_contact_point() -> Vector2:
	var side_x: float = wall_cling_offset_x if direction >= 0.0 else -wall_cling_offset_x
	return position + Vector2(side_x, grab_point_offset_y * 0.9)

func toggle_metrics_debug() -> bool:
	metrics_debug_enabled = not metrics_debug_enabled
	print("[Metrics] Debug View (F19): %s" % ("ON" if metrics_debug_enabled else "OFF"))
	queue_redraw()
	return metrics_debug_enabled

func toggle_edge_grab_debug() -> bool:
	edge_grab_debug_enabled = not edge_grab_debug_enabled
	print("[EdgeGrab] Debug View (F16): %s" % ("ON" if edge_grab_debug_enabled else "OFF"))
	queue_redraw()
	return edge_grab_debug_enabled

func toggle_climb_debug() -> bool:
	climb_debug_enabled = not climb_debug_enabled
	print("[Climb] Debug View (F17): %s" % ("ON" if climb_debug_enabled else "OFF"))
	queue_redraw()
	return climb_debug_enabled

func toggle_wall_debug() -> bool:
	wall_debug_enabled = not wall_debug_enabled
	print("[Wall] Debug View (F18): %s" % ("ON" if wall_debug_enabled else "OFF"))
	queue_redraw()
	return wall_debug_enabled

func get_current_surface_id() -> String:
	return current_surface_id

func get_current_surface() -> RefCounted:
	return current_surface

func toggle_physics_debug() -> bool:
	physics_debug_enabled = not physics_debug_enabled
	print("[Physics] Debug Physics: %s" % ("ON" if physics_debug_enabled else "OFF"))
	queue_redraw()
	return physics_debug_enabled

func _enter_tree() -> void:
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot")
	if cat_shadow == null:
		cat_shadow = get_node_or_null("CatShadow")
		if cat_shadow and cat_shadow.has_method("setup"):
			cat_shadow.setup(self)
	var sprite := _get_animated_sprite()
	if sprite != null and (sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("jump")):
		sprite.sprite_frames = CatSpriteLoaderClass.load_cat_sprite_frames()
	if anim_controller == null:
		anim_controller = CatAnimationControllerClass.new()
		add_child(anim_controller)
		anim_controller.setup(self, visual_root if visual_root != null else self, sprite)

func _ready() -> void:
	if metrics == null: metrics = CatMetricsClass.new()
	if visual_root == null: visual_root = get_node_or_null("VisualRoot")
	if cat_shadow == null:
		cat_shadow = get_node_or_null("CatShadow")
		if cat_shadow and cat_shadow.has_method("setup"):
			cat_shadow.setup(self)

	var vp_size := _get_viewport_size()
	var b_scale: float = CatMetricsClass.calc_base_scale_from_screen_height(vp_size.y)
	metrics.update_scales(b_scale, metrics.user_scale)
	_apply_metrics_change()

	var sprite := _get_animated_sprite()
	if sprite != null and (sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("jump")):
		sprite.sprite_frames = CatSpriteLoaderClass.load_cat_sprite_frames()

	if anim_controller == null:
		anim_controller = CatAnimationControllerClass.new()
		add_child(anim_controller)
		anim_controller.setup(self, visual_root if visual_root != null else self, sprite)

	ground_y = vp_size.y - 48.0
	if position.y == 0.0: position = Vector2(vp_size.x / 2.0, ground_y)
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
		CatState.WALL_CLING:
			if sprite:
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("wall_cling"):
					sprite.play("wall_cling")
				elif sprite.sprite_frames and sprite.sprite_frames.has_animation("edge_hang"):
					sprite.play("edge_hang")
				else:
					sprite.play("idle")
				sprite.flip_h = (direction < 0.0)
		CatState.WALL_CLIMB:
			if sprite:
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("wall_climb"):
					sprite.play("wall_climb")
				else:
					sprite.play("walk")
				sprite.flip_h = (direction < 0.0)
	print("[Cat] [%s] 进入状态: %s, 朝向: %s, Y=%.1f" % ["AUTO" if current_mode == ControlMode.AUTO else "COMMAND", CatState.keys()[state], "左" if direction < 0.0 else "右", position.y])

func update_state(delta: float) -> void:
	if climb_cooldown > 0.0:
		climb_cooldown -= delta
	if wall_cooldown > 0.0:
		wall_cooldown -= delta
	sleep_cooldown = maxf(0.0, sleep_cooldown - delta); run_cooldown = maxf(0.0, run_cooldown - delta)
	if current_state == CatState.DRAG: return
	if current_state == CatState.CLIMB_UP:
		_update_climb(delta)
		return
	if current_state == CatState.EDGE_HANG:
		_update_edge_hang(delta)
		return
	if current_state == CatState.WALL_CLING or current_state == CatState.WALL_CLIMB:
		_update_wall_behavior(delta)
		return
	if is_grounded:
		_check_ground_support()
		if not is_grounded: return

	if not is_grounded:
		var prev_y: float = get_foot_position().y
		var prev_grab_l := get_left_grab_point()
		var prev_grab_r := get_right_grab_point()
		var prev_pos := position
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
				if current_state == CatState.FALL and wall_cooldown <= 0.0:
					_check_wall_attach(prev_pos, position)
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
		auto_climb_pause_timer = 0.0
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
		auto_climb_pause_timer += delta
		if auto_climb_pause_timer >= auto_climb_reaction_delay:
			if start_climb():
				return
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

func can_climb_up_surface(s: RefCounted, edge_side: int) -> Dictionary:
	if s == null or not bool(s.walkable):
		return { "feasible": false, "reason": "SURFACE_LOST" }
	if not is_instance_valid(surface_world_model):
		return { "feasible": false, "reason": "NO_SURFACE_MODEL" }
	var surf_len: float = absf(float(s.x2) - float(s.x1))
	var min_len: float = min_climb_up_platform_length
	if metrics != null and "min_platform_length" in metrics:
		min_len = float(metrics.min_platform_length)
	if surf_len < min_len:
		return { "feasible": false, "reason": "NO_LANDING_SPACE" }
	var target_foot_x: float = (minf(float(s.x1), float(s.x2)) + climb_inward_margin) if edge_side == -1 else (maxf(float(s.x1), float(s.x2)) - climb_inward_margin)
	var target_foot_y: float = float(s.y1)
	var chk_box := Rect2(target_foot_x - 18.0 - climb_clearance_margin, target_foot_y - 36.0 - climb_clearance_margin, 36.0 + climb_clearance_margin * 2.0, 34.0)
	for other_s in surface_world_model.surfaces_by_id.values():
		if str(other_s.id) == str(s.id): continue
		if int(other_s.surface_type) == 0 and int(other_s.orientation) == 0:
			var oy: float = float(other_s.y1)
			if oy < target_foot_y and oy >= target_foot_y - 36.0:
				var ox_min: float = minf(float(other_s.x1), float(other_s.x2))
				var ox_max: float = maxf(float(other_s.x1), float(other_s.x2))
				if ox_max > chk_box.position.x and ox_min < chk_box.end.x:
					return { "feasible": false, "reason": "CLEARANCE_BLOCKED" }
	return { "feasible": true, "surface": s, "target_foot_x": target_foot_x, "target_foot_y": target_foot_y }

func check_climb_feasibility() -> Dictionary:
	if grabbed_edge == null or grabbed_surface_id == "":
		return { "feasible": false, "reason": "NO_GRABBED_EDGE" }
	if not is_instance_valid(surface_world_model):
		return { "feasible": false, "reason": "NO_SURFACE_MODEL" }
	var s = surface_world_model.get_surface_by_id(grabbed_surface_id)
	return can_climb_up_surface(s, grabbed_edge.edge_side)

func start_climb() -> bool:
	if current_state == CatState.CLIMB_UP: return true
	if current_state != CatState.EDGE_HANG: return false
	var feas := check_climb_feasibility()
	if not feas.feasible:
		print("[Climb] Cannot climb: %s" % feas.reason)
		return false
	var s = feas.surface
	var target_pos := Vector2(float(feas.target_foot_x) - foot_offset.x, float(feas.target_foot_y) - foot_offset.y)
	var start_pos := position
	var pull_up_pos := Vector2(start_pos.x, target_pos.y)
	current_climb_target = ClimbTargetClass.new(
		s.id, grabbed_edge.edge_side, grabbed_edge.get_edge_position(),
		float(feas.target_foot_x), float(feas.target_foot_y),
		start_pos, pull_up_pos, target_pos,
		surface_world_model.world_revision if "world_revision" in surface_world_model else 0
	)
	current_climb_phase = ClimbPhase.PULL_UP
	climb_phase_timer = 0.0
	climb_total_timer = 0.0
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	current_surface_id = ""
	current_surface = null
	climb_stats["climb_attempts"] = int(climb_stats["climb_attempts"]) + 1
	change_state(CatState.CLIMB_UP)
	print("[Climb] Start surface=%s side=%s" % [s.id, "LEFT" if grabbed_edge.edge_side == -1 else "RIGHT"])
	return true

func cancel_climb(reason: String) -> void:
	if current_state != CatState.CLIMB_UP and current_climb_phase == ClimbPhase.NONE: return
	climb_stats["climb_cancelled"] = int(climb_stats["climb_cancelled"]) + 1
	print("[Climb] Failed: %s -> FALL" % reason)
	climb_failed.emit(reason)
	current_climb_target = null
	current_climb_phase = ClimbPhase.NONE
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

func _update_climb(delta: float) -> void:
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	if current_climb_target == null or grabbed_surface_id == "":
		cancel_climb("NO_CLIMB_TARGET")
		return
	climb_total_timer += delta
	if climb_total_timer > climb_up_timeout:
		cancel_climb("TIMEOUT")
		return
	if not is_instance_valid(surface_world_model):
		return
	var s = surface_world_model.get_surface_by_id(grabbed_surface_id)
	if s == null:
		var re_edge: Dictionary = surface_world_model.find_equivalent_edge_near(current_climb_target.edge_position, current_climb_target.edge_side, 16.0)
		if not re_edge.is_empty():
			grabbed_surface_id = str(re_edge.surface_id)
			current_climb_target.surface_id = grabbed_surface_id
			s = surface_world_model.get_surface_by_id(grabbed_surface_id)
		else:
			cancel_climb("SURFACE_LOST")
			return
	# 动态位移校准
	var cur_edge_pos: Vector2 = Vector2(minf(s.x1, s.x2), s.y1) if current_climb_target.edge_side == -1 else Vector2(maxf(s.x1, s.x2), s.y1)
	var delta_edge: Vector2 = cur_edge_pos - current_climb_target.edge_position
	if delta_edge.length() > max_climb_target_delta:
		cancel_climb("TARGET_MOVED_TOO_FAR")
		return
	elif delta_edge != Vector2.ZERO:
		current_climb_target.edge_position = cur_edge_pos
		current_climb_target.start_position += delta_edge
		current_climb_target.pull_up_position += delta_edge
		current_climb_target.target_position += delta_edge
		position += delta_edge

	climb_phase_timer += delta
	if current_climb_phase == ClimbPhase.PULL_UP:
		var t := clampf(climb_phase_timer / climb_pull_up_duration, 0.0, 1.0)
		var smooth_t := t * t * (3.0 - 2.0 * t)
		position = current_climb_target.start_position.lerp(current_climb_target.pull_up_position, smooth_t)
		if t >= 1.0:
			current_climb_phase = ClimbPhase.SHIFT_IN
			climb_phase_timer = 0.0
			print("[Climb] Phase SHIFT_IN")
	elif current_climb_phase == ClimbPhase.SHIFT_IN:
		var t := clampf(climb_phase_timer / climb_shift_in_duration, 0.0, 1.0)
		var smooth_t := t * t * (3.0 - 2.0 * t)
		position = current_climb_target.pull_up_position.lerp(current_climb_target.target_position, smooth_t)
		if t >= 1.0:
			current_climb_phase = ClimbPhase.SETTLE
			complete_climb()

func complete_climb() -> void:
	if current_climb_target == null: return
	position = current_climb_target.target_position
	var s = surface_world_model.get_surface_by_id(grabbed_surface_id) if is_instance_valid(surface_world_model) else null
	if s == null or not s.walkable:
		cancel_climb("SURFACE_LOST")
		return
	var finished_id := grabbed_surface_id
	current_surface_id = s.id
	current_surface = s
	ground_y = s.y1
	is_grounded = true
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	grabbed_edge = null
	grabbed_surface_id = ""
	current_climb_target = null
	current_climb_phase = ClimbPhase.NONE
	climb_cooldown = climb_cooldown_time
	climb_stats["climb_success"] = int(climb_stats["climb_success"]) + 1
	print("[Climb] Completed on %s" % finished_id)
	climb_completed.emit(finished_id)
	state_timer = 0.5
	if current_mode == ControlMode.COMMAND:
		command_ground_state = CatState.IDLE
	change_state(CatState.IDLE)

func _check_wall_attach(prev_pos: Vector2, curr_pos: Vector2) -> void:
	if not is_instance_valid(surface_world_model): return
	if not surface_world_model.has_method("get_climbable_walls_in_rect"): return
	if absf(vertical_velocity) > max_wall_attach_vertical_speed: return
	if absf(horizontal_throw_speed) > max_wall_attach_horizontal_speed: return
	if vertical_velocity < 0.0: return

	var q_min_x := minf(prev_pos.x, curr_pos.x) - 32.0
	var q_max_x := maxf(prev_pos.x, curr_pos.x) + 32.0
	var q_min_y := minf(prev_pos.y, curr_pos.y) - 48.0
	var q_max_y := maxf(prev_pos.y, curr_pos.y) + 48.0
	var query_rect := Rect2(q_min_x, q_min_y, q_max_x - q_min_x, q_max_y - q_min_y)
	var candidate_walls: Array = surface_world_model.get_climbable_walls_in_rect(query_rect)
	if candidate_walls.is_empty(): return

	wall_stats["wall_attach_attempts"] = int(wall_stats.get("wall_attach_attempts", 0)) + 1
	var best_wall = null
	var best_side: int = 0
	var best_anchor_y: float = 0.0
	var min_dist: float = 9999.0

	for s in candidate_walls:
		var wx: float = s.x1
		var wy1: float = minf(s.y1, s.y2)
		var wy2: float = maxf(s.y1, s.y2)
		var orient: int = s.orientation

		var side := 0
		if orient == 2: # Orientation.LEFT
			if curr_pos.x <= wx + 6.0: side = -1
		elif orient == 3: # Orientation.RIGHT
			if curr_pos.x >= wx - 6.0: side = 1
		else:
			side = -1 if curr_pos.x <= wx else 1
		if side == 0: continue

		var curr_claw_x: float = curr_pos.x + (wall_cling_offset_x if side == -1 else -wall_cling_offset_x)
		var prev_claw_x: float = prev_pos.x + (wall_cling_offset_x if side == -1 else -wall_cling_offset_x)
		var claw_y: float = curr_pos.y - 18.0

		if claw_y < wy1 + 4.0 or claw_y > wy2 - 8.0:
			continue

		var dx := absf(curr_claw_x - wx)
		var swept_crossed: bool = (prev_claw_x - wx) * (curr_claw_x - wx) <= 0.0
		if dx <= wall_attach_x_tolerance or swept_crossed:
			var d := dx
			if d < min_dist:
				min_dist = d
				best_wall = s
				best_side = side
				best_anchor_y = claw_y

	if best_wall != null:
		_attach_wall(best_wall, best_side, best_anchor_y)

func _attach_wall(s, side: int, anchor_y: float) -> void:
	wall_stats["wall_attach_success"] = int(wall_stats.get("wall_attach_success", 0)) + 1
	var rev: int = surface_world_model.surface_revision if is_instance_valid(surface_world_model) and "surface_revision" in surface_world_model else 0
	current_wall_attachment = WallAttachmentClass.new(s.id, s.x1, s.y1, s.y2, s.orientation, side, anchor_y, rev)
	direction = 1.0 if side == -1 else -1.0
	if _get_animated_sprite():
		_get_animated_sprite().flip_h = (direction < 0.0)

	position.x = s.x1 + (-wall_cling_offset_x if side == -1 else wall_cling_offset_x)
	position.y = anchor_y + 18.0

	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	current_surface_id = ""
	current_surface = null
	grabbed_edge = null
	grabbed_surface_id = ""

	current_wall_climb_dir = WallClimbDirection.NONE
	auto_wall_pause_timer = auto_wall_reaction_delay
	auto_wall_climb_timer = 0.0

	change_state(CatState.WALL_CLING)
	print("[Wall] Attached surface=%s side=%s Y=%.1f" % [s.id, "LEFT" if side == -1 else "RIGHT", position.y])

func release_wall(reason: String = "MANUAL") -> void:
	if current_state != CatState.WALL_CLING and current_state != CatState.WALL_CLIMB: return
	wall_stats["wall_released"] = int(wall_stats.get("wall_released", 0)) + 1
	print("[Wall] Released: %s -> FALL" % reason)
	current_wall_attachment = null
	current_wall_climb_dir = WallClimbDirection.NONE
	is_planned_wall_climb = false
	wall_cooldown = wall_cooldown_time
	is_grounded = false
	current_surface_id = ""
	current_surface = null
	vertical_velocity = 10.0
	horizontal_throw_speed = 0.0
	var sg = surface_world_model.get_surface_by_id("screen:ground") if is_instance_valid(surface_world_model) else null
	ground_y = sg.y1 if sg != null else (_get_viewport_size().y - 48.0)
	change_state(CatState.FALL)

func _update_wall_behavior(delta: float) -> void:
	vertical_velocity = 0.0
	horizontal_throw_speed = 0.0
	is_grounded = false
	if current_wall_attachment == null:
		release_wall("NO_ATTACHMENT")
		return

	if not is_instance_valid(surface_world_model): return
	var s = surface_world_model.get_surface_by_id(current_wall_attachment.wall_surface_id)
	if s == null:
		var re_wall = surface_world_model.find_equivalent_wall_near(
			current_wall_attachment.wall_x, current_wall_attachment.wall_y1, current_wall_attachment.wall_y2,
			current_wall_attachment.wall_orientation, 16.0, 24.0
		)
		if not re_wall.is_empty():
			wall_stats["wall_rebind_success"] = int(wall_stats.get("wall_rebind_success", 0)) + 1
			current_wall_attachment.wall_surface_id = str(re_wall.surface_id)
			current_wall_attachment.update_geometry(float(re_wall.x), float(re_wall.y1), float(re_wall.y2))
			s = re_wall.surface
			print("[Wall] Rebind successful: -> %s" % current_wall_attachment.wall_surface_id)
		else:
			wall_stats["wall_surface_lost"] = int(wall_stats.get("wall_surface_lost", 0)) + 1
			release_wall("SURFACE_LOST")
			return

	var dx: float = absf(s.x1 - current_wall_attachment.wall_x)
	var dy: float = s.y1 - current_wall_attachment.wall_y1
	if dx > max_wall_attach_delta or absf(dy) > max_wall_attach_delta:
		release_wall("WALL_MOVED_TOO_FAR")
		return
	elif dx != 0.0 or dy != 0.0:
		current_wall_attachment.anchor_y += dy
		current_wall_attachment.update_geometry(s.x1, s.y1, s.y2)

	if current_mode == ControlMode.AUTO:
		if current_state == CatState.WALL_CLING:
			auto_wall_pause_timer -= delta
			if auto_wall_pause_timer <= 0.0:
				current_wall_climb_dir = WallClimbDirection.UP
				change_state(CatState.WALL_CLIMB)
				print("[Wall] AUTO climb UP started")
		elif current_state == CatState.WALL_CLIMB:
			auto_wall_climb_timer += delta
			var climb_timeout := auto_max_wall_climb_duration
			if is_planned_wall_climb:
				climb_timeout = clampf(planned_wall_climb_timeout, 4.0, 15.0)
			if auto_wall_climb_timer > climb_timeout:
				print("[Wall] AUTO climb duration exceeded (%.1fs) -> release" % climb_timeout)
				release_wall("AUTO_TIMEOUT")
				return

	if current_state == CatState.WALL_CLIMB:
		var move_d := 0.0
		if current_wall_climb_dir == WallClimbDirection.UP: move_d = -wall_climb_speed * delta
		elif current_wall_climb_dir == WallClimbDirection.DOWN: move_d = wall_climb_speed * delta
		current_wall_attachment.anchor_y += move_d

		if current_wall_climb_dir == WallClimbDirection.UP:
			if current_wall_attachment.anchor_y <= current_wall_attachment.wall_y1 + wall_top_edge_tolerance:
				wall_stats["wall_top_reached"] = int(wall_stats.get("wall_top_reached", 0)) + 1
				var plat_info = surface_world_model.find_platform_connected_to_wall_top(s, 12.0)
				if not plat_info.is_empty():
					var p_surf = plat_info.platform
					var p_side: int = int(plat_info.edge_side)
					var p_pos: Vector2 = plat_info.edge_pos
					print("[Wall] Reached top of %s -> transition to EDGE_HANG on %s" % [s.id, p_surf.id])
					current_wall_attachment = null
					current_wall_climb_dir = WallClimbDirection.NONE
					is_planned_wall_climb = false
					_grab_edge({ "surface_id": p_surf.id, "side": p_side, "x": p_pos.x, "y": p_pos.y })
					if current_mode == ControlMode.AUTO: auto_climb_pause_timer = 0.0
					return
				else:
					current_wall_attachment.anchor_y = current_wall_attachment.wall_y1 + 4.0
					current_wall_climb_dir = WallClimbDirection.NONE
					change_state(CatState.WALL_CLING)
		elif current_wall_climb_dir == WallClimbDirection.DOWN:
			if current_wall_attachment.anchor_y >= current_wall_attachment.wall_y2 - 8.0:
				current_wall_attachment.anchor_y = current_wall_attachment.wall_y2 - 8.0
				current_wall_climb_dir = WallClimbDirection.NONE
				change_state(CatState.WALL_CLING)

	position.x = current_wall_attachment.wall_x + (-wall_cling_offset_x if current_wall_attachment.attach_side == -1 else wall_cling_offset_x)
	position.y = current_wall_attachment.anchor_y + 18.0

func on_surface_world_updated(_rev: int = 0) -> void:
	if current_state == CatState.WALL_CLING or current_state == CatState.WALL_CLIMB:
		_update_wall_behavior(0.0)
		return
	if current_state == CatState.CLIMB_UP:
		_update_climb(0.0)
		return
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
	if current_state == CatState.CLIMB_UP:
		if command == 16: # RELEASE_EDGE
			cancel_climb("USER_RELEASED")
			return
		elif command == 5: # DRAG_START
			cancel_climb("DRAG_INTERRUPTED")
		elif command in [0, 1, 2, 4, 8, 9, 10, 11, 12, 14, 17]:
			return
	if current_state == CatState.WALL_CLING or current_state == CatState.WALL_CLIMB:
		if command == 20 or command == 16: # WALL_RELEASE 或 RELEASE_EDGE
			release_wall("USER_RELEASED")
			return
		elif command == 5: # DRAG_START
			release_wall("DRAG_INTERRUPTED")
		elif command == 18: # WALL_CLIMB_UP
			current_wall_climb_dir = WallClimbDirection.UP
			change_state(CatState.WALL_CLIMB)
			return
		elif command == 19: # WALL_CLIMB_DOWN
			current_wall_climb_dir = WallClimbDirection.DOWN
			change_state(CatState.WALL_CLIMB)
			return
		elif command == 0: # STOP
			current_wall_climb_dir = WallClimbDirection.NONE
			change_state(CatState.WALL_CLING)
			return
		elif command in [1, 2, 4, 8, 9, 10, 11, 12, 14, 17]:
			return
	if current_state == CatState.EDGE_HANG:
		if command == 17: # CLIMB_UP
			start_climb()
			return
		elif command == 16 or command == 20: # RELEASE_EDGE 或 WALL_RELEASE
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
	if current_state not in [CatState.EDGE_HANG, CatState.CLIMB_UP, CatState.WALL_CLING, CatState.WALL_CLIMB]:
		var sprite := _get_animated_sprite()
		if sprite: var tw := create_tween(); tw.tween_property(sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); tw.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var main_p := get_parent()
	if main_p and "mouse_perception_controller" in main_p and main_p.mouse_perception_controller: main_p.mouse_perception_controller.suppress_curiosity()

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite:
		_animated_sprite = get_node_or_null("VisualRoot/AnimatedSprite2D")
		if not _animated_sprite:
			_animated_sprite = get_node_or_null("AnimatedSprite2D")
	if _animated_sprite and (_animated_sprite.sprite_frames == null or not _animated_sprite.sprite_frames.has_animation("jump")):
		_animated_sprite.sprite_frames = CatSpriteLoaderClass.load_cat_sprite_frames()
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

	if climb_debug_enabled:
		if current_climb_target != null:
			var p_start := to_local(current_climb_target.start_position)
			var p_pull := to_local(current_climb_target.pull_up_position)
			var p_end := to_local(current_climb_target.target_position)
			draw_circle(p_start, 5.0, Color(0.3, 0.8, 1.0, 0.9))
			draw_circle(p_pull, 5.0, Color(1.0, 0.8, 0.2, 0.9))
			draw_circle(p_end, 5.0, Color(0.2, 1.0, 0.4, 0.9))
			draw_line(p_start, p_pull, Color(0.2, 0.9, 1.0, 0.8), 2.5)
			draw_line(p_pull, p_end, Color(0.2, 1.0, 0.5, 0.8), 2.5)
			# 绘制 Clearance 检查框
			var foot_land := to_local(current_climb_target.get_landing_foot_position())
			var c_box := Rect2(foot_land.x - 18.0 - climb_clearance_margin, foot_land.y - 36.0 - climb_clearance_margin, 36.0 + climb_clearance_margin * 2.0, 34.0)
			draw_rect(c_box, Color(1.0, 0.5, 0.2, 0.35), false, 1.5)
		var phase_name: String = ["NONE", "PULL_UP", "SHIFT_IN", "SETTLE"][current_climb_phase]
		var cl_info := "[F17 Climb] Phase: %s | Target: %s | Success: %d" % [phase_name, grabbed_surface_id if grabbed_surface_id != "" else "NONE", int(climb_stats["climb_success"])]
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -66.0), cl_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.5, 0.95))

	if wall_debug_enabled:
		if is_instance_valid(surface_world_model) and surface_world_model.has_method("get_climbable_walls_in_rect"):
			var q_rect := Rect2(position.x - 300.0, position.y - 300.0, 600.0, 600.0)
			var walls: Array = surface_world_model.get_climbable_walls_in_rect(q_rect)
			for w in walls:
				var p1 := to_local(Vector2(w.x1, w.y1))
				var p2 := to_local(Vector2(w.x1, w.y2))
				draw_line(p1, p2, Color(0.9, 0.8, 0.1, 0.8), 2.5)
				draw_string(ThemeDB.fallback_font, p1 + Vector2(4.0, 4.0), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.1, 0.9))
				draw_string(ThemeDB.fallback_font, p2 + Vector2(4.0, -4.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.1, 0.9))
		if current_wall_attachment != null:
			var wp1 := to_local(Vector2(current_wall_attachment.wall_x, current_wall_attachment.wall_y1))
			var wp2 := to_local(Vector2(current_wall_attachment.wall_x, current_wall_attachment.wall_y2))
			draw_line(wp1, wp2, Color(1.0, 0.1, 0.6, 0.95), 4.0)
			var claw_pt := to_local(get_wall_contact_point())
			draw_circle(claw_pt, 5.0, Color(1.0, 0.5, 0.0, 0.95))
		var dir_str: String = ["NONE", "UP", "DOWN"][current_wall_climb_dir]
		var wid_str: String = current_wall_attachment.wall_surface_id if current_wall_attachment != null else "NONE"
		var w_info := "[F18 Wall] State: %s | Wall: %s | Dir: %s | Attach: %d" % [CatState.keys()[current_state], wid_str, dir_str, int(wall_stats["wall_attach_success"])]
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -80.0), w_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.8, 0.2, 0.95))

	if metrics_debug_enabled and metrics != null:
		var body_box := Rect2(-metrics.half_body_width, -metrics.half_body_height, metrics.body_width, metrics.body_height)
		draw_rect(body_box, Color(0.2, 0.8, 1.0, 0.4), false, 2.0)
		var hit_box := Rect2(-metrics.hit_region_half_w, -metrics.hit_region_top_h, metrics.hit_region_half_w * 2.0, metrics.hit_region_top_h + metrics.hit_region_bottom_h)
		draw_rect(hit_box, Color(1.0, 0.2, 0.8, 0.35), false, 1.5)

		var f_local := foot_offset
		draw_circle(f_local, 4.0, Color(0.2, 1.0, 0.4, 0.95))
		draw_line(f_local + Vector2(-metrics.foot_width * 0.5, 0.0), f_local + Vector2(metrics.foot_width * 0.5, 0.0), Color(0.2, 1.0, 0.4, 0.8), 2.5)

		var gl := to_local(get_left_grab_point())
		var gr := to_local(get_right_grab_point())
		draw_circle(gl, 4.0, Color(0.1, 0.9, 1.0, 0.95))
		draw_circle(gr, 4.0, Color(1.0, 0.8, 0.1, 0.95))

		var wc := to_local(get_wall_contact_point())
		draw_circle(wc, 5.0, Color(1.0, 0.5, 0.0, 0.95))

		var m_info := "[F19 Metrics] Scale: base=%.2f user=%.2f final=%.2f | Visual: %.0fx%.0f | Body: %.0fx%.0f" % [
			metrics.base_scale, metrics.user_scale, metrics.final_scale,
			metrics.visual_width, metrics.visual_height, metrics.body_width, metrics.body_height
		]
		draw_string(ThemeDB.fallback_font, Vector2(-60.0, -94.0), m_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 1.0, 0.8, 0.95))

