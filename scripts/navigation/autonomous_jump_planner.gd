class_name AutonomousJumpPlanner
extends Node2D

const TraversalPlanClass = preload("res://scripts/navigation/traversal_plan.gd")

enum TraversalPhase {

	IDLE,
	APPROACH_TAKEOFF,
	READY_TO_JUMP,
	AIRBORNE,
	VERIFY_LANDING,
	SUCCESS,
	FAILED
}

const TAKEOFF_POSITION_TOLERANCE: float = 12.0
const RUN_JUMP_MIN_APPROACH_DISTANCE: float = 35.0
const WORLD_STABILITY_REQUIRED_MS: int = 300
const FAILED_EDGE_BLACKLIST_DURATION_MS: int = 10000
const RECENT_SURFACE_HISTORY_MAX: int = 4

var cat: Node2D = null
var command_manager: Node = null
var platform_navigation_graph: RefCounted = null
var surface_world_model: Node2D = null

var autonomous_traversal_enabled: bool = true
var auto_trigger_probability: float = 0.35
var cooldown_timer: float = 2.0
var current_phase: int = TraversalPhase.IDLE
var current_plan: RefCounted = null

var recent_surface_history: Array[String] = []
var failed_edges_blacklist: Dictionary = {}
var last_surface_revision: int = 0
var last_world_change_time: int = 0
var debug_draw_enabled: bool = false

var stats: Dictionary = {
	"plans_started": 0, "success": 0, "failed": 0, "cancelled": 0,
	"walk_jump_success": 0, "run_jump_success": 0, "drop_success": 0
}

func _init(p_cat: Node2D = null, p_cmd: Node = null, p_graph: RefCounted = null, p_world: Node2D = null) -> void:
	cat = p_cat
	command_manager = p_cmd
	platform_navigation_graph = p_graph
	surface_world_model = p_world
	last_world_change_time = 0


func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	update(delta)
	if debug_draw_enabled:
		queue_redraw()

func update(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	_clean_expired_blacklist()
	_track_world_stability()
	if not is_instance_valid(cat) or not is_instance_valid(command_manager): return

	match current_phase:
		TraversalPhase.IDLE:
			_update_idle(delta)
		TraversalPhase.APPROACH_TAKEOFF:
			_update_approach(delta)
		TraversalPhase.READY_TO_JUMP:
			_update_ready_to_jump(delta)
		TraversalPhase.AIRBORNE:
			_update_airborne(delta)
		TraversalPhase.VERIFY_LANDING:
			_update_verify_landing(delta)

func _clean_expired_blacklist() -> void:
	var now := Time.get_ticks_msec()
	var to_erase: Array = []
	for k in failed_edges_blacklist:
		if now >= int(failed_edges_blacklist[k]): to_erase.append(k)
	for k in to_erase: failed_edges_blacklist.erase(k)

func _track_world_stability() -> void:
	if not is_instance_valid(surface_world_model): return
	var cur_rev: int = int(surface_world_model.surface_revision)
	if cur_rev != last_surface_revision:
		last_surface_revision = cur_rev
		last_world_change_time = Time.get_ticks_msec()

func can_plan_traversal() -> bool:
	if not autonomous_traversal_enabled or cooldown_timer > 0.0: return false
	if not is_instance_valid(cat) or not bool(cat.is_grounded): return false
	if int(cat.current_mode) != 0: return false # ControlMode.AUTO == 0
	if int(cat.current_state) in [4, 5, 7]: return false # SLEEP(4), JUMP(5), DRAG(7)
	if bool(cat.has_move_target): return false
	if (Time.get_ticks_msec() - last_world_change_time) < WORLD_STABILITY_REQUIRED_MS: return false
	if not is_instance_valid(platform_navigation_graph): return false
	var edges: Array = platform_navigation_graph.get_edges_from(str(cat.current_surface_id))
	return edges.size() > 0

func _update_idle(_delta: float) -> void:
	if not can_plan_traversal(): return
	if randf() < (auto_trigger_probability * 0.05):
		try_plan_traversal()

func try_plan_traversal() -> bool:
	if not is_instance_valid(cat) or not is_instance_valid(platform_navigation_graph) or not is_instance_valid(surface_world_model):
		return false
	var cur_surf_id := str(cat.current_surface_id)
	var all_edges: Array = platform_navigation_graph.get_edges_from(cur_surf_id)
	if all_edges.is_empty(): return false

	var src_surf = surface_world_model.get_surface_by_id(cur_surf_id)
	if src_surf == null: return false
	var src_x1: float = minf(float(src_surf.x1), float(src_surf.x2))
	var src_x2: float = maxf(float(src_surf.x1), float(src_surf.x2))

	var candidates: Array = []
	var now := Time.get_ticks_msec()

	for e in all_edges:
		var tgt_id := str(e.target_surface_id)
		if failed_edges_blacklist.has(tgt_id) and now < int(failed_edges_blacklist[tgt_id]):
			continue

		if int(e.action_type) == 1: # JUMP_RUN
			var tx_center: float = (float(e.takeoff_x_min) + float(e.takeoff_x_max)) * 0.5
			if int(e.direction) > 0:
				if (tx_center - src_x1) < RUN_JUMP_MIN_APPROACH_DISTANCE: continue
			else:
				if (src_x2 - tx_center) < RUN_JUMP_MIN_APPROACH_DISTANCE: continue

		var weight: float = 100.0
		if int(e.action_type) == 1: weight = 60.0
		elif int(e.action_type) == 2: weight = 20.0
		weight -= float(e.cost) * 12.0

		if float(e.vertical_delta) < -10.0: weight *= 1.3
		elif float(e.vertical_delta) > 50.0: weight *= 0.8


		if recent_surface_history.has(tgt_id):
			weight *= 0.2

		weight = maxf(1.0, weight)
		candidates.append({ "edge": e, "weight": weight })

	if candidates.is_empty(): return false

	candidates.sort_custom(func(a, b): return float(a.weight) > float(b.weight))

	var top_n_count: int = mini(3, candidates.size())
	var total_w := 0.0
	for i in range(top_n_count): total_w += float(candidates[i].weight)

	var pick_val := randf_range(0.0, total_w)
	var chosen_edge = candidates[0].edge
	var acc := 0.0
	for i in range(top_n_count):
		acc += float(candidates[i].weight)
		if pick_val <= acc:
			chosen_edge = candidates[i].edge
			break

	return _execute_chosen_edge(chosen_edge)

func _execute_chosen_edge(e: RefCounted) -> bool:
	var t_span: float = float(e.takeoff_x_max) - float(e.takeoff_x_min)
	var tx: float = lerp(float(e.takeoff_x_min), float(e.takeoff_x_max), 0.5) + randf_range(-0.15, 0.15) * t_span
	var lx: float = lerp(float(e.landing_x_min), float(e.landing_x_max), 0.5)

	var tgt_s = surface_world_model.get_surface_by_id(str(e.target_surface_id))
	var tgt_y: float = float(tgt_s.y1) if tgt_s != null else 0.0
	var cur_rev: int = int(surface_world_model.surface_revision) if is_instance_valid(surface_world_model) else 0

	current_plan = TraversalPlanClass.new(
		str(e.source_surface_id), str(e.target_surface_id), int(e.action_type),

		int(e.direction), str(e.required_speed_mode), tx, lx,

		float(e.takeoff_x_min), float(e.takeoff_x_max), float(e.landing_x_min), float(e.landing_x_max),
		float(e.flight_time), tgt_y, cur_rev
	)

	current_phase = TraversalPhase.APPROACH_TAKEOFF
	stats["plans_started"] = int(stats["plans_started"]) + 1
	print("[Planner] Selected %s -> %s (%s, tx=%.1f, lx=%.1f)" % [current_plan.source_surface_id, current_plan.target_surface_id, current_plan.speed_mode, tx, lx])
	return true

func _update_approach(_delta: float) -> void:
	if current_plan == null: cancel_plan("NO_PLAN"); return
	if int(cat.current_mode) != 0 or int(cat.current_state) in [4, 7]:
		cancel_plan("USER_INTERRUPTED"); return
	if not bool(cat.is_grounded):
		cancel_plan("SURFACE_LOST"); return

	var tgt_s = surface_world_model.get_surface_by_id(current_plan.target_surface_id)
	if tgt_s == null:
		cancel_plan("TARGET_DISAPPEARED"); return

	var dx: float = current_plan.takeoff_x - float(cat.position.x)
	if absf(dx) <= TAKEOFF_POSITION_TOLERANCE:
		current_phase = TraversalPhase.READY_TO_JUMP
		return

	if dx > 0.0:
		if current_plan.speed_mode == "RUN":
			if float(cat.direction) != 1.0 or int(cat.current_state) != 1:
				command_manager.send_command(CommandManager.CatCommand.RUN_RIGHT, { "source": "planner" })
		else:
			if float(cat.direction) != 1.0 or int(cat.current_state) != 0:
				command_manager.send_command(CommandManager.CatCommand.WALK_RIGHT, { "source": "planner" })
	else:
		if current_plan.speed_mode == "RUN":
			if float(cat.direction) != -1.0 or int(cat.current_state) != 1:
				command_manager.send_command(CommandManager.CatCommand.RUN_LEFT, { "source": "planner" })
		else:
			if float(cat.direction) != -1.0 or int(cat.current_state) != 0:
				command_manager.send_command(CommandManager.CatCommand.WALK_LEFT, { "source": "planner" })

func _update_ready_to_jump(_delta: float) -> void:
	if current_plan == null: cancel_plan("NO_PLAN"); return
	if int(cat.current_mode) != 0 or int(cat.current_state) in [4, 7]:
		cancel_plan("USER_INTERRUPTED"); return

	var edge = platform_navigation_graph.get_edge(current_plan.source_surface_id, current_plan.target_surface_id)
	if edge == null:
		cancel_plan("EDGE_INVALIDATED"); return
	var tgt_s = surface_world_model.get_surface_by_id(current_plan.target_surface_id)
	if tgt_s == null:
		cancel_plan("TARGET_DISAPPEARED"); return

	var req_dir: float = float(current_plan.direction)
	if float(cat.direction) != req_dir:
		if current_plan.speed_mode == "RUN":
			command_manager.send_command(CommandManager.CatCommand.RUN_RIGHT if req_dir > 0.0 else CommandManager.CatCommand.RUN_LEFT, { "source": "planner" })
		else:
			command_manager.send_command(CommandManager.CatCommand.WALK_RIGHT if req_dir > 0.0 else CommandManager.CatCommand.WALK_LEFT, { "source": "planner" })

	if current_plan.action_type in [0, 1]:
		command_manager.send_command(CommandManager.CatCommand.JUMP, { "source": "planner", "speed_mode": current_plan.speed_mode })
		current_phase = TraversalPhase.AIRBORNE
		current_plan.elapsed_airborne = 0.0
		print("[Planner] Jump triggered: %s -> %s (%s, dir=%d)" % [current_plan.source_surface_id, current_plan.target_surface_id, current_plan.speed_mode, current_plan.direction])
	else:
		if not bool(cat.is_grounded):
			current_phase = TraversalPhase.AIRBORNE
			current_plan.elapsed_airborne = 0.0
			print("[Planner] Drop started: %s -> %s" % [current_plan.source_surface_id, current_plan.target_surface_id])
		else:
			command_manager.send_command(CommandManager.CatCommand.WALK_RIGHT if req_dir > 0.0 else CommandManager.CatCommand.WALK_LEFT, { "source": "planner" })


func _update_airborne(delta: float) -> void:
	if current_plan == null: cancel_plan("NO_PLAN"); return
	current_plan.elapsed_airborne += delta

	if current_plan.elapsed_airborne > float(current_plan.timeout):
		fail_plan("AIRBORNE_TIMEOUT"); return

	if bool(cat.is_grounded):
		current_phase = TraversalPhase.VERIFY_LANDING

func _update_verify_landing(_delta: float) -> void:
	if current_plan == null: cancel_plan("NO_PLAN"); return
	var landed_id := str(cat.current_surface_id)
	var is_success: bool = (landed_id == current_plan.target_surface_id)

	if not is_success:
		var tgt_s = surface_world_model.get_surface_by_id(current_plan.target_surface_id)
		if tgt_s != null:
			var foot_x := float(cat.get_foot_position().x) if cat.has_method("get_foot_position") else float(cat.position.x)
			var foot_y := float(cat.get_foot_position().y) if cat.has_method("get_foot_position") else float(cat.position.y)
			var sx1: float = minf(float(tgt_s.x1), float(tgt_s.x2)) - 14.0
			var sx2: float = maxf(float(tgt_s.x1), float(tgt_s.x2)) + 14.0
			if absf(foot_y - float(tgt_s.y1)) <= 12.0 and foot_x >= sx1 and foot_x <= sx2:
				is_success = true

	if is_success:
		complete_plan_success()
	else:
		fail_plan("MISSED_TARGET")

func complete_plan_success() -> void:
	if current_plan == null: return
	stats["success"] = int(stats["success"]) + 1
	if current_plan.action_type == 0: stats["walk_jump_success"] = int(stats["walk_jump_success"]) + 1
	elif current_plan.action_type == 1: stats["run_jump_success"] = int(stats["run_jump_success"]) + 1
	else: stats["drop_success"] = int(stats["drop_success"]) + 1

	recent_surface_history.append(current_plan.target_surface_id)
	while recent_surface_history.size() > RECENT_SURFACE_HISTORY_MAX:
		recent_surface_history.pop_front()

	print("[Planner] Traversal SUCCESS: -> %s" % current_plan.target_surface_id)
	cooldown_timer = randf_range(3.5, 7.0)
	current_phase = TraversalPhase.IDLE
	current_plan = null
	if is_instance_valid(command_manager):
		command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)

func fail_plan(reason: String) -> void:
	stats["failed"] = int(stats["failed"]) + 1
	var tgt_id: String = current_plan.target_surface_id if current_plan else ""
	if not tgt_id.is_empty():
		failed_edges_blacklist[tgt_id] = Time.get_ticks_msec() + FAILED_EDGE_BLACKLIST_DURATION_MS
	print("[Planner] Traversal FAILED: %s (target=%s)" % [reason, tgt_id])

	cooldown_timer = randf_range(2.5, 4.5)
	current_phase = TraversalPhase.IDLE
	current_plan = null
	if is_instance_valid(command_manager):
		command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)

func cancel_plan(reason: String) -> void:
	stats["cancelled"] = int(stats["cancelled"]) + 1
	print("[Planner] Traversal CANCELLED: %s" % reason)
	cooldown_timer = 1.5
	current_phase = TraversalPhase.IDLE
	current_plan = null
	if is_instance_valid(cat) and bool(cat.is_grounded) and is_instance_valid(command_manager):
		command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	queue_redraw()
	print("[Planner] Debug Draw (F15): %s" % ("ON" if debug_draw_enabled else "OFF"))
	return debug_draw_enabled

func _draw() -> void:
	if not debug_draw_enabled: return
	var font := ThemeDB.fallback_font
	var font_size := 14
	var phase_names := ["IDLE", "APPROACH_TAKEOFF", "READY_TO_JUMP", "AIRBORNE", "VERIFY_LANDING", "SUCCESS", "FAILED"]
	var phase_str: String = phase_names[current_phase] if current_phase >= 0 and current_phase < phase_names.size() else "UNKNOWN"

	var hud_text := "[F15 Traversal] Phase: %s | CD: %.1fs | Plans: %d (Win: %d, Fail: %d, Cancel: %d)" % [
		phase_str, cooldown_timer, stats["plans_started"], stats["success"], stats["failed"], stats["cancelled"]
	]
	draw_string(font, Vector2(20.0, 75.0), hud_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.8, 0.2))

	if current_plan != null:
		var plan_text := "Target: %s | Action: %s (%s) | tx: %.1f -> lx: %.1f" % [
			current_plan.target_surface_id,
			"RUN_JUMP" if current_plan.action_type == 1 else ("DROP" if current_plan.action_type == 2 else "WALK_JUMP"),
			current_plan.speed_mode, current_plan.takeoff_x, current_plan.landing_target_x
		]
		draw_string(font, Vector2(20.0, 95.0), plan_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.4, 1.0, 0.4))

		var src_s = surface_world_model.get_surface_by_id(current_plan.source_surface_id) if is_instance_valid(surface_world_model) else null
		var sy: float = float(src_s.y1) if src_s != null else float(cat.position.y)
		draw_circle(Vector2(current_plan.takeoff_x, sy), 5.0, Color(1.0, 0.2, 0.2))
		draw_string(font, Vector2(current_plan.takeoff_x - 5.0, sy - 10.0), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.2, 0.2))

		draw_line(Vector2(current_plan.landing_x_min, current_plan.expected_target_y), Vector2(current_plan.landing_x_max, current_plan.expected_target_y), Color(0.2, 0.8, 1.0), 3.0)
		draw_circle(Vector2(current_plan.landing_target_x, current_plan.expected_target_y), 5.0, Color(0.2, 1.0, 0.4))
		draw_string(font, Vector2(current_plan.landing_target_x - 5.0, current_plan.expected_target_y - 10.0), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 1.0, 0.4))

		if current_plan.action_type in [0, 1] and is_instance_valid(platform_navigation_graph):
			var cap = platform_navigation_graph.capabilities
			var total_t: float = float(current_plan.expected_flight_time)
			var vx: float = (float(current_plan.landing_target_x) - float(current_plan.takeoff_x)) / maxf(0.001, total_t)
			var pts: PackedVector2Array = []
			var steps := 16
			for i in range(steps + 1):
				var tau := total_t * (float(i) / float(steps))
				var px: float = float(current_plan.takeoff_x) + vx * tau
				var py: float = sy + float(cap.sample_jump_trajectory_y(tau))
				pts.append(Vector2(px, py))
			if pts.size() >= 2:
				draw_polyline(pts, Color(1.0, 1.0, 0.0, 0.8), 2.0)






