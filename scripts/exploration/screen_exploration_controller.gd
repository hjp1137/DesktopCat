class_name ScreenExplorationController
extends Node2D

const ExplorationGoalClass = preload("res://scripts/exploration/exploration_goal.gd")
const ExplorationMemoryClass = preload("res://scripts/exploration/exploration_memory.gd")

const EXPLORATION_TRIGGER_PROBABILITY: float = 0.25
const EXPLORATION_COOLDOWN_MIN: float = 4.0
const EXPLORATION_COOLDOWN_MAX: float = 10.0
const ARRIVAL_DWELL_MIN: float = 1.5
const ARRIVAL_DWELL_MAX: float = 4.0
const MAX_EXPLORATION_ROUTE_DEPTH: int = 4
const MAX_EXPLORATION_CANDIDATES: int = 36
const MAX_EXPLORATION_ROUTE_COST: float = 12.0
const FAILED_GOAL_COOLDOWN: float = 18.0
const MAX_CONSECUTIVE_FAILURES: int = 3
const EXPLORATION_BACKOFF_DURATION: float = 15.0
const TOP_K_SELECTION: int = 4
const WORLD_STABILITY_REQUIRED_MS: int = 400

var cat: Node2D = null
var command_manager: CommandManager = null
var platform_navigation_graph: RefCounted = null
var surface_world_model: Node2D = null
var traversal_planner: Node2D = null

var memory: RefCounted = null
var current_goal: RefCounted = null
var current_route: RefCounted = null

var exploration_cooldown_timer: float = 0.0
var arrival_dwell_timer: float = 0.0
var backoff_timer: float = 0.0
var is_dwelling: bool = false
var autonomous_exploration_enabled: bool = true
var debug_draw_enabled: bool = false
var debug_seed: int = 0
var last_candidates: Array = []

var stats: Dictionary = {
	"exploration_decisions": 0,
	"candidate_count": 0,
	"average_candidates": 0.0,
	"goal_selected": 0,
	"goal_success": 0,
	"goal_failure": 0,
	"unique_surfaces_visited": 0,
	"loop_break_count": 0,
	"backoff_count": 0,
	"decision_ms": 0.0
}

func _init(
	p_cat: Node2D = null,
	p_cmd_mgr: CommandManager = null,
	p_graph: RefCounted = null,
	p_world: Node2D = null,
	p_planner: Node2D = null
) -> void:
	cat = p_cat
	command_manager = p_cmd_mgr
	platform_navigation_graph = p_graph
	surface_world_model = p_world
	traversal_planner = p_planner
	memory = ExplorationMemoryClass.new()
	z_index = 100

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	update(delta)
	if debug_draw_enabled:
		queue_redraw()

func _draw() -> void:
	if debug_draw_enabled:
		draw_debug(self)

func update(delta: float) -> void:
	exploration_cooldown_timer = maxf(0.0, exploration_cooldown_timer - delta)
	backoff_timer = maxf(0.0, backoff_timer - delta)

	if is_dwelling:
		arrival_dwell_timer -= delta
		if arrival_dwell_timer <= 0.0:
			is_dwelling = false
			var on_ground: bool = (is_instance_valid(cat) and str(cat.current_surface_id) == "screen:ground")
			exploration_cooldown_timer = randf_range(EXPLORATION_COOLDOWN_MIN, EXPLORATION_COOLDOWN_MAX) if on_ground else randf_range(1.5, 3.5)
			print("[Exploration] Arrival dwell completed, entering cooldown: %.1fs" % exploration_cooldown_timer)

	# 检查是否可以进行自主探索决策
	if autonomous_exploration_enabled and can_start_exploration():
		var on_ground: bool = (is_instance_valid(cat) and str(cat.current_surface_id) == "screen:ground")
		var trigger_p: float = (EXPLORATION_TRIGGER_PROBABILITY * 0.05) if on_ground else (EXPLORATION_TRIGGER_PROBABILITY * 0.25)
		if randf() < trigger_p:
			trigger_exploration_decision()

func can_start_exploration() -> bool:
	if not is_instance_valid(cat) or not is_instance_valid(platform_navigation_graph) or not is_instance_valid(surface_world_model):
		return false
	if int(cat.current_mode) != 0: return false # ControlMode.AUTO == 0
	if not bool(cat.is_grounded): return false
	if int(cat.current_state) in [4, 5, 6, 7, 8, 9, 10, 11]: return false # SLEEP, JUMP, FALL, DRAG, EDGE_HANG, CLIMB_UP, WALL_CLING, WALL_CLIMB
	if bool(cat.has_move_target): return false
	if exploration_cooldown_timer > 0.0 or is_dwelling or backoff_timer > 0.0: return false

	if is_instance_valid(traversal_planner) and "current_phase" in traversal_planner:
		if int(traversal_planner.current_phase) != 0: return false # TraversalPhase.IDLE == 0

	var last_change_t: int = surface_world_model.last_change_time if "last_change_time" in surface_world_model else 0
	if (Time.get_ticks_msec() - last_change_t) < WORLD_STABILITY_REQUIRED_MS: return false
	return true

func collect_candidates() -> Array:
	var candidates: Array = []
	if not is_instance_valid(cat) or not is_instance_valid(platform_navigation_graph): return candidates
	var cur_surf_id: String = str(cat.current_surface_id)
	if cur_surf_id.is_empty(): return candidates

	var start_node = platform_navigation_graph.get_node(cur_surf_id)
	if start_node == null: return candidates

	# 有界广度搜索 (Bounded BFS)
	var queue: Array = [{ "node_id": cur_surf_id, "depth": 0, "cost": 0.0, "edge_types": [] }]
	var visited: Dictionary = { cur_surf_id: 0.0 }

	while not queue.is_empty():
		var curr = queue.pop_front()
		var curr_id: String = str(curr.node_id)
		var depth: int = int(curr.depth)
		var cost: float = float(curr.cost)

		if depth >= MAX_EXPLORATION_ROUTE_DEPTH or cost > MAX_EXPLORATION_ROUTE_COST:
			continue

		var out_edges: Array = platform_navigation_graph.get_edges_from(curr_id)
		for e in out_edges:
			var tgt_id: String = str(e.target_surface_id)
			var tgt_node = platform_navigation_graph.get_node(tgt_id)
			if tgt_node == null: continue

			var next_cost: float = cost + float(e.cost)
			if visited.has(tgt_id) and float(visited[tgt_id]) <= next_cost:
				continue
			visited[tgt_id] = next_cost

			var next_edge_types = curr.edge_types.duplicate()
			next_edge_types.append(int(e.action_type))

			# 候选平台（排除起始表面和非平台节点）
			if tgt_id != cur_surf_id and int(tgt_node.node_type) == 0:
				candidates.append({
					"target_surface_id": tgt_id,
					"depth": depth + 1,
					"cost": next_cost,
					"edge_types": next_edge_types,
					"target_node": tgt_node
				})
				if candidates.size() >= MAX_EXPLORATION_CANDIDATES:
					break
			if candidates.size() >= MAX_EXPLORATION_CANDIDATES:
				break

			queue.append({ "node_id": tgt_id, "depth": depth + 1, "cost": next_cost, "edge_types": next_edge_types })
	return candidates

func score_candidates(candidates: Array) -> Array:
	var scored: Array = []
	if candidates.is_empty(): return scored
	var vp_h: float = cat.get_viewport_rect().size.y if (is_instance_valid(cat) and cat.is_inside_tree()) else 1080.0
	var cur_y: float = cat.position.y if is_instance_valid(cat) else 500.0
	var cur_norm_y: float = clampf(cur_y / vp_h, 0.0, 1.0)
	var loop_info: Dictionary = memory.detect_loop()
	var is_stuck: bool = memory.detect_stuck(candidates.size())

	for cand in candidates:
		var tgt_id: String = str(cand.target_surface_id)
		var tgt_node = cand.target_node
		var tgt_y: float = float(tgt_node.get_center().y)
		var reasons: Array = []

		# 1. Novelty
		var decayed_visits: float = memory.get_decayed_visit_count(tgt_id)
		var novelty: float = maxf(0.0, 10.0 - (decayed_visits * 3.5))
		if is_stuck and decayed_visits < 0.5: novelty *= 1.8; reasons.append("STUCK_BOOST")
		elif decayed_visits < 0.1: reasons.append("NOVEL")

		# 2. Vertical Interest
		var dy: float = cur_y - tgt_y # dy > 0 目标在上方
		var vert_bonus: float = 0.0
		var g_type = ExplorationGoalClass.GoalType.VISIT_SURFACE
		var region_str: String = "TOP" if (tgt_y / vp_h) < 0.33 else ("BOTTOM" if (tgt_y / vp_h) > 0.66 else "MID")

		if cur_norm_y > 0.70 and dy > 30.0:
			vert_bonus = 2.5; g_type = ExplorationGoalClass.GoalType.ASCEND; reasons.append("UPWARD")
		elif cur_norm_y < 0.30:
			if dy < -30.0: vert_bonus = 2.2; g_type = ExplorationGoalClass.GoalType.DESCEND; reasons.append("DOWNWARD")
			elif absf(dy) <= 30.0: vert_bonus = 1.8; g_type = ExplorationGoalClass.GoalType.LATERAL_EXPLORE; reasons.append("LATERAL")
		else:
			if absf(dy) <= 50.0: g_type = ExplorationGoalClass.GoalType.LATERAL_EXPLORE
			elif dy > 50.0: g_type = ExplorationGoalClass.GoalType.ASCEND
			else: g_type = ExplorationGoalClass.GoalType.DESCEND

		# 3. Size Safety
		var size_bonus: float = clampf((float(tgt_node.length) - 60.0) * 0.015, 0.0, 3.5)
		if size_bonus > 1.5: reasons.append("SAFE_WIDE")

		# 4. Route Cost & Risk
		var cost_pen: float = float(cand.cost) * 0.85
		var risk_pen: float = 0.0
		var climb_bonus: float = 0.0
		for etype in cand.edge_types:
			if etype == 2: risk_pen += 1.2
			elif etype in [3, 4, 5]:
				climb_bonus += 2.0
				reasons.append("CLIMB_INTEREST")

		# 5. Penalties (Recent, Loop, Failed)
		var recent_pen: float = 0.0
		var rec_size: int = memory.recent_surfaces.size()
		for i in range(rec_size):
			if memory.recent_surfaces[rec_size - 1 - i] == tgt_id:
				recent_pen = maxf(recent_pen, 7.0 / (float(i) + 1.0))
		var loop_pen: float = 0.0
		if bool(loop_info.get("is_loop", false)):
			var loop_surfs: Array = loop_info.get("surfaces", [])
			if loop_surfs.has(tgt_id):
				loop_pen = 12.0; reasons.append("LOOP_PENALTY")
				stats["loop_break_count"] = int(stats["loop_break_count"]) + 1

		var fail_pen: float = 8.0 if memory.is_goal_failed_recently(tgt_id) else 0.0
		if fail_pen > 0.0: reasons.append("RECENT_FAIL")

		var total_score: float = novelty + vert_bonus + size_bonus + climb_bonus - cost_pen - risk_pen - recent_pen - loop_pen - fail_pen
		var goal = ExplorationGoalClass.new(
			"goal_%d_%s" % [Time.get_ticks_msec(), tgt_id],
			tgt_id, tgt_node.get_safe_center(), g_type, total_score, float(cand.cost), reasons
		)
		goal.target_region = region_str
		scored.append(goal)

	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored

func select_goal(scored_goals: Array) -> RefCounted:
	if scored_goals.is_empty(): return null
	var k: int = mini(TOP_K_SELECTION, scored_goals.size())
	var pool: Array = []
	var weights: Array = []
	var min_s: float = float(scored_goals[k - 1].score)
	var base_shift: float = maxf(0.1, -min_s + 1.0) if min_s <= 0.0 else 0.0
	var total_w: float = 0.0

	for i in range(k):
		var g = scored_goals[i]
		pool.append(g)
		var w: float = maxf(0.1, float(g.score) + base_shift)
		weights.append(w)
		total_w += w

	var rng_val: float = 0.0
	if debug_seed != 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = debug_seed
		debug_seed += 1
		rng_val = rng.randf_range(0.0, total_w)
	else:
		rng_val = randf_range(0.0, total_w)

	var acc: float = 0.0
	for i in range(k):
		acc += weights[i]
		if rng_val <= acc:
			return pool[i]
	return pool[0]

func trigger_exploration_decision(force: bool = false) -> bool:
	if not force and not can_start_exploration():
		return false
	if not is_instance_valid(cat) or not is_instance_valid(platform_navigation_graph):
		return false

	var t_start := Time.get_ticks_usec()
	var cur_id: String = str(cat.current_surface_id)
	var candidates = collect_candidates()
	stats["exploration_decisions"] = int(stats["exploration_decisions"]) + 1
	stats["candidate_count"] = int(stats["candidate_count"]) + candidates.size()
	stats["average_candidates"] = float(stats["candidate_count"]) / maxf(1.0, float(stats["exploration_decisions"]))

	if candidates.is_empty():
		print("[Exploration] No reachable candidates found from %s" % cur_id)
		last_candidates.clear()
		return false

	var scored_goals = score_candidates(candidates)
	last_candidates = scored_goals.duplicate()
	var chosen_goal = select_goal(scored_goals)
	if chosen_goal == null:
		return false

	# 请求 T22 路线搜索进行二次确认
	var route = platform_navigation_graph.find_route(cur_id, chosen_goal.target_surface_id)
	if route == null or route.steps.is_empty():
		print("[Exploration] Route search failed for goal: %s" % chosen_goal.target_surface_id)
		return false

	current_goal = chosen_goal
	current_route = route
	stats["goal_selected"] = int(stats["goal_selected"]) + 1
	stats["decision_ms"] = float(Time.get_ticks_usec() - t_start) / 1000.0

	print("[Exploration] Goal selected: %s -> %s (Score: %.2f, Cost: %.2f, Reasons: %s)" % [
		cur_id, chosen_goal.target_surface_id, chosen_goal.score, chosen_goal.route_cost, str(chosen_goal.reasons)
	])

	# 委派给 TraversalPlanner 执行
	if is_instance_valid(traversal_planner) and traversal_planner.has_method("_start_route"):
		traversal_planner.set("current_goal", chosen_goal)
		return traversal_planner._start_route(route)
	return false

func notify_route_completed(landed_surface_id: String) -> void:
	if current_goal == null: return
	var target_id: String = current_goal.target_surface_id
	var is_target: bool = (landed_surface_id == target_id or landed_surface_id.split(":")[0] == target_id.split(":")[0])

	if is_target:
		stats["goal_success"] = int(stats["goal_success"]) + 1
		memory.record_visit(landed_surface_id, current_goal.target_region, "%s->%s" % [cat.current_surface_id, target_id])
		print("[Exploration] Goal reached SUCCESS: %s" % landed_surface_id)
	else:
		# 意外落点容错吸收 (Unexpected Landing Recovery)
		print("[Exploration] Landed on unexpected surface: %s (goal was %s), recorded as valid visit" % [landed_surface_id, target_id])
		memory.record_visit(landed_surface_id)

	stats["unique_surfaces_visited"] = memory.surface_visit_count.size()
	current_goal = null
	current_route = null
	is_dwelling = true
	arrival_dwell_timer = randf_range(ARRIVAL_DWELL_MIN, ARRIVAL_DWELL_MAX)

func notify_route_failed(reason: String) -> void:
	var target_id: String = current_goal.target_surface_id if current_goal != null else "target"
	memory.record_failure(target_id, FAILED_GOAL_COOLDOWN)
	stats["goal_failure"] = int(stats["goal_failure"]) + 1
	print("[Exploration] Goal failed: %s (%s)" % [target_id, reason])
	if memory.consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
		backoff_timer = EXPLORATION_BACKOFF_DURATION
		stats["backoff_count"] = int(stats["backoff_count"]) + 1
		print("[Exploration] Consecutive failures exceeded (%d), entering backoff: %.1fs" % [memory.consecutive_failures, backoff_timer])
	current_goal = null
	current_route = null
	exploration_cooldown_timer = randf_range(2.0, 4.0)

func notify_route_cancelled(reason: String) -> void:
	print("[Exploration] Goal cancelled: %s" % reason)
	current_goal = null
	current_route = null
	exploration_cooldown_timer = 2.0

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	queue_redraw()
	print("[Exploration] Debug Draw (F21): %s" % ("ON" if debug_draw_enabled else "OFF"))
	return debug_draw_enabled

func draw_debug(ci: CanvasItem) -> void:
	if not debug_draw_enabled or ci == null: return
	var font := ThemeDB.fallback_font

	var state_str := "IDLE"
	if current_goal != null: state_str = "EXPLORING (%s)" % current_goal.target_surface_id
	elif is_dwelling: state_str = "DWELLING (%.1fs)" % arrival_dwell_timer
	elif backoff_timer > 0.0: state_str = "BACKOFF (%.1fs)" % backoff_timer
	elif exploration_cooldown_timer > 0.0: state_str = "COOLDOWN (%.1fs)" % exploration_cooldown_timer

	var banner := "[F21 Exploration] State: %s | Decisions: %d | Goals S/F: %d/%d | Visited: %d | Breaks: %d | Backoffs: %d" % [
		state_str, stats["exploration_decisions"], stats["goal_success"], stats["goal_failure"],
		stats["unique_surfaces_visited"], stats["loop_break_count"], stats["backoff_count"]
	]
	ci.draw_string(font, Vector2(24.0, 160.0), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.8, 0.2, 0.95))

	var rec_str := "Recent: %s" % str(memory.recent_surfaces)
	ci.draw_string(font, Vector2(24.0, 180.0), rec_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8, 0.85))

	# 标注 Top 5 候选目标位置
	var show_count := mini(5, last_candidates.size())
	for i in range(show_count):
		var g = last_candidates[i]
		var pos: Vector2 = g.target_position
		var col := Color(0.2, 1.0, 0.4, 0.9) if (current_goal != null and current_goal.target_surface_id == g.target_surface_id) else Color(1.0, 0.6, 0.1, 0.8)
		ci.draw_circle(pos, 5.0, col)
		var label := "#%d: %.1f (%s)" % [i + 1, g.score, g.target_surface_id]
		if current_goal != null and current_goal.target_surface_id == g.target_surface_id:
			label = "[G] " + label
		ci.draw_string(font, pos + Vector2(8.0, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
