class_name PlatformNavigationGraph
extends RefCounted

const NavigationNodeClass = preload("res://scripts/navigation/navigation_node.gd")
const NavigationEdgeClass = preload("res://scripts/navigation/navigation_edge.gd")
const CatMovementCapabilitiesClass = preload("res://scripts/navigation/cat_movement_capabilities.gd")

class NavGraphDrawer extends Node2D:
	var graph: RefCounted = null
	func _process(delta: float) -> void:
		if is_instance_valid(graph):
			graph.update(delta)
	func _draw() -> void:
		if is_instance_valid(graph) and graph.debug_draw_enabled:
			graph.draw_debug(self)


const MAX_NAV_NODES: int = 400
const NAV_GRAPH_DEBOUNCE_SEC: float = 0.15 # 150ms
const NAV_REACHABILITY_SAFETY_FACTOR: float = 0.90
const NAV_LANDING_MARGIN: float = 14.0
const MAX_NAV_DROP_DISTANCE: float = 800.0

var surface_world_model: Node2D = null
var cat: Node2D = null
var capabilities: RefCounted = null
var drawer: NavGraphDrawer = null

var nodes: Dictionary = {} # node_id -> NavigationNode
var outgoing_edges: Dictionary = {} # source_surface_id -> Array
var all_edges: Array = []

var navigation_revision: int = 0
var source_surface_revision: int = 0
var pending_build: bool = false
var debounce_timer: float = 0.0
var debug_draw_enabled: bool = false

var stats: Dictionary = {
	"nodes": 0, "candidates": 0, "prefilter_rejected": 0,
	"ballistic_checked": 0, "edges": 0, "build_ms": 0.0
}

func _init(p_cat: Node2D = null) -> void:
	cat = p_cat
	capabilities = CatMovementCapabilitiesClass.new(cat)

func create_drawer() -> Node2D:
	if drawer == null:
		drawer = NavGraphDrawer.new()
		drawer.graph = self
	return drawer

func request_rebuild() -> void:
	pending_build = true
	debounce_timer = NAV_GRAPH_DEBOUNCE_SEC

func update(delta: float) -> void:
	if pending_build:
		debounce_timer -= delta
		if debounce_timer <= 0.0:
			pending_build = false
			rebuild_graph()

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[NavGraph] Debug Draw (F14): %s" % ("ON" if debug_draw_enabled else "OFF"))
	if is_instance_valid(drawer):
		drawer.queue_redraw()
	return debug_draw_enabled

func get_node(surface_id: String) -> RefCounted:
	return nodes.get(surface_id, null)


func get_nav_node(surface_id: String) -> RefCounted:
	return nodes.get(surface_id, null)

func get_edges_from(surface_id: String) -> Array:
	return outgoing_edges.get(surface_id, [])

func get_reachable_surfaces(surface_id: String) -> Array[String]:
	var res: Array[String] = []
	for edge in get_edges_from(surface_id):
		if not res.has(edge.target_surface_id):
			res.append(edge.target_surface_id)
	return res

func get_edge(source_id: String, target_id: String) -> RefCounted:
	for edge in get_edges_from(source_id):
		if edge.target_surface_id == target_id:
			return edge
	return null

func get_jump_edges_from(surface_id: String) -> Array:
	var res: Array = []
	for edge in get_edges_from(surface_id):
		if edge.action_type == NavigationEdgeClass.ActionType.JUMP_WALK or edge.action_type == NavigationEdgeClass.ActionType.JUMP_RUN:
			res.append(edge)
	return res

func get_drop_edges_from(surface_id: String) -> Array:
	var res: Array = []
	for edge in get_edges_from(surface_id):
		if edge.action_type == NavigationEdgeClass.ActionType.DROP:
			res.append(edge)
	return res

func find_nearest_node(pos: Vector2) -> RefCounted:
	var best_node: RefCounted = null
	var min_dist_sq := INF
	for node in nodes.values():
		var c = node.get_center()
		var d_sq = pos.distance_squared_to(c)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			best_node = node
	return best_node


func print_current_nav_summary() -> void:
	var cur_id: String = ""
	if is_instance_valid(cat) and "current_surface_id" in cat:
		cur_id = str(cat.current_surface_id)
	var node := get_node(cur_id)

	if node == null and is_instance_valid(cat):
		node = find_nearest_node(cat.position)
		if node != null: cur_id = node.surface_id
	var edges := get_edges_from(cur_id)
	print("[Nav] current=%s | reachable=%d" % [cur_id, edges.size()])
	for i in range(mini(edges.size(), 8)):
		var e: RefCounted = edges[i]
		print("  - %s [%s] (time: %.2fs, cost: %.2f)" % [e.target_surface_id, e.get_action_name(), e.flight_time, e.cost])


func _check_jump_edge(src: RefCounted, tgt: RefCounted, all_surfs: Array) -> RefCounted:
	var delta_y: float = float(tgt.y) - float(src.y)
	var max_h: float = capabilities.get_max_jump_height()
	if delta_y < 0.0 and absf(delta_y) > max_h:
		return null
	var t_land: float = capabilities.calc_jump_landing_time(delta_y)
	if t_land <= 0.0:
		return null

	var d_walk: float = capabilities.walk_speed * t_land * capabilities.safety_factor
	var d_run: float = capabilities.run_speed * t_land * capabilities.safety_factor


	# 尝试向右跳与向左跳
	for dir in [1, -1]:
		var t_min := 0.0; var t_max := 0.0
		var l_min := 0.0; var l_max := 0.0
		var min_gap := 0.0
		if dir == 1:
			if tgt.safe_x2 < src.x1: continue
			t_min = maxf(src.x1, tgt.safe_x1 - d_run)
			t_max = minf(src.x2, tgt.safe_x2)
			if t_min > t_max: continue
			l_min = maxf(tgt.safe_x1, t_min)
			l_max = minf(tgt.safe_x2, t_max + d_run)
			min_gap = maxf(0.0, tgt.safe_x1 - src.x2)
		else:
			if tgt.safe_x1 > src.x2: continue
			t_min = maxf(src.x1, tgt.safe_x1)
			t_max = minf(src.x2, tgt.safe_x2 + d_run)
			if t_min > t_max: continue
			l_min = maxf(tgt.safe_x1, t_min - d_run)
			l_max = minf(tgt.safe_x2, t_max)
			min_gap = maxf(0.0, src.x1 - tgt.safe_x2)

		if l_min > l_max: continue
		var speed_mode := "WALK" if min_gap <= d_walk else "RUN"
		var action := NavigationEdgeClass.ActionType.JUMP_WALK if speed_mode == "WALK" else NavigationEdgeClass.ActionType.JUMP_RUN

		# 弹道轨迹中间平台拦截检测
		var x0 := (t_min + t_max) * 0.5; var x1 := (l_min + l_max) * 0.5
		if _is_trajectory_occluded(x0, src.y, x1, tgt.y, t_land, src.surface_id, tgt.surface_id, all_surfs):
			continue

		var h_dist := absf(x1 - x0)
		var cost := 1.0 + (h_dist / maxf(1.0, d_run)) * 0.5 + (0.8 if speed_mode == "RUN" else 0.0) + maxf(0.0, -delta_y / max_h) * 0.6
		var diff := (h_dist / maxf(1.0, d_run)) * 0.6 + maxf(0.0, -delta_y / max_h) * 0.4
		return NavigationEdgeClass.new(src.surface_id, tgt.surface_id, action, dir, speed_mode, t_min, t_max, l_min, l_max, t_land, h_dist, delta_y, cost, diff)
	return null

func _check_drop_edge(src: RefCounted, tgt: RefCounted, all_surfs: Array) -> RefCounted:
	var delta_y: float = float(tgt.y) - float(src.y)
	if delta_y <= 0.0 or delta_y > MAX_NAV_DROP_DISTANCE:

		return null
	var t_drop: float = capabilities.calc_drop_landing_time(delta_y)
	if t_drop <= 0.0:
		return null


	# 测试从左边缘走落或从右边缘走落
	for drop_x in [src.x1, src.x2]:
		if drop_x >= (tgt.safe_x1 - 8.0) and drop_x <= (tgt.safe_x2 + 8.0):
			# 验证垂直下落过程中首个相交的 walkable 表面必须是 tgt
			var first_surf: RefCounted = null
			var min_sy := INF
			for s in all_surfs:
				if not bool(s.walkable): continue
				var sy: float = float(s.y1)
				if sy > src.y and sy <= (tgt.y + 4.0):
					var sx1: float = minf(float(s.x1), float(s.x2)) - 8.0
					var sx2: float = maxf(float(s.x1), float(s.x2)) + 8.0
					if drop_x >= sx1 and drop_x <= sx2:
						if sy < min_sy:
							min_sy = sy
							first_surf = s
			if first_surf != null and str(first_surf.id) == tgt.surface_id:
				var cost := 0.8 + (delta_y / MAX_NAV_DROP_DISTANCE) * 0.5
				var diff := (delta_y / MAX_NAV_DROP_DISTANCE) * 0.3
				return NavigationEdgeClass.new(src.surface_id, tgt.surface_id, NavigationEdgeClass.ActionType.DROP, 0, "NONE", drop_x, drop_x, drop_x, drop_x, t_drop, 0.0, delta_y, cost, diff)
	return null

func _is_trajectory_occluded(x0: float, y0: float, x1: float, y1: float, total_t: float, src_id: String, tgt_id: String, all_surfs: Array) -> bool:
	var vx: float = (x1 - x0) / maxf(0.001, total_t)
	var samples := 10
	var prev_px := x0
	var prev_py := y0
	for k in range(1, samples + 1):
		var tau := total_t * (float(k) / float(samples))
		var px: float = x0 + vx * tau
		var py: float = y0 + float(capabilities.sample_jump_trajectory_y(tau))
		var vy: float = float(capabilities.jump_velocity) + float(capabilities.gravity) * tau
		if vy > 0.0:
			for s in all_surfs:
				if not bool(s.walkable): continue
				var sid := str(s.id)
				if sid == src_id or sid == tgt_id: continue
				var sy: float = float(s.y1)
				if sy < (y1 - 2.0) and prev_py <= (sy + 2.0) and py >= (sy - 2.0):
					var f := clampf((sy - prev_py) / maxf(0.001, py - prev_py), 0.0, 1.0)
					var cx := prev_px + f * (px - prev_px)
					var sx1: float = minf(float(s.x1), float(s.x2)) - 4.0
					var sx2: float = maxf(float(s.x1), float(s.x2)) + 4.0
					if cx >= sx1 and cx <= sx2:
						return true
		prev_px = px
		prev_py = py
	return false



func rebuild_graph() -> bool:
	if not is_instance_valid(surface_world_model): return false
	var t0 := Time.get_ticks_usec()
	capabilities.sync_from_cat(cat)

	var all_surfs: Array = surface_world_model.get_walkable_surfaces()
	var new_nodes: Dictionary = {}
	for s in all_surfs:
		var node = NavigationNodeClass.new(s, capabilities.landing_margin)
		if node.navigable or node.source_type == "SCREEN":
			new_nodes[node.node_id] = node
		if new_nodes.size() >= MAX_NAV_NODES: break

	var candidate_pairs := 0; var prefilter_rejected := 0; var ballistic_checked := 0
	var new_outgoing: Dictionary = {}
	var new_all_edges: Array = []
	var node_list := new_nodes.values()

	var max_jump_h: float = capabilities.get_max_jump_height()
	var max_h_range: float = capabilities.get_max_run_jump_distance()


	for src in node_list:
		new_outgoing[src.surface_id] = []
		for tgt in node_list:
			if src.surface_id == tgt.surface_id: continue
			candidate_pairs += 1
			var dy: float = float(tgt.y) - float(src.y)
			if dy < 0.0 and absf(dy) > max_jump_h:
				prefilter_rejected += 1; continue
			if dy > MAX_NAV_DROP_DISTANCE:
				prefilter_rejected += 1; continue
			var min_dx: float = maxf(0.0, maxf(float(tgt.safe_x1) - float(src.x2), float(src.x1) - float(tgt.safe_x2)))
			if min_dx > (max_h_range + 300.0):
				prefilter_rejected += 1; continue


			ballistic_checked += 1
			var jump_edge = _check_jump_edge(src, tgt, all_surfs)
			if jump_edge != null:
				new_outgoing[src.surface_id].append(jump_edge)
				new_all_edges.append(jump_edge); continue
			var drop_edge = _check_drop_edge(src, tgt, all_surfs)
			if drop_edge != null:
				new_outgoing[src.surface_id].append(drop_edge)
				new_all_edges.append(drop_edge)

	nodes = new_nodes; outgoing_edges = new_outgoing; all_edges = new_all_edges
	navigation_revision += 1
	source_surface_revision = surface_world_model.surface_revision if "surface_revision" in surface_world_model else 0
	stats["nodes"] = nodes.size(); stats["candidates"] = candidate_pairs
	stats["prefilter_rejected"] = prefilter_rejected; stats["ballistic_checked"] = ballistic_checked
	stats["edges"] = all_edges.size(); stats["build_ms"] = (Time.get_ticks_usec() - t0) / 1000.0

	if debug_draw_enabled and is_instance_valid(drawer):
		drawer.queue_redraw()
	return true

func draw_debug(ci: CanvasItem) -> void:
	if not debug_draw_enabled or ci == null: return
	var font := ThemeDB.fallback_font
	var cur_id: String = ""
	if is_instance_valid(cat) and "current_surface_id" in cat:
		cur_id = str(cat.current_surface_id)
	var cur_node := get_node(cur_id)

	if cur_node == null and is_instance_valid(cat):
		cur_node = find_nearest_node(cat.position)
		if cur_node != null: cur_id = cur_node.surface_id
	var cur_edges := get_edges_from(cur_id)

	var banner := "[F14 Nav Graph] Rev=%d | Nodes=%d, Edges=%d | Current: %s (Out: %d) | Build: %.2f ms" % [navigation_revision, nodes.size(), all_edges.size(), cur_id, cur_edges.size(), stats["build_ms"]]
	ci.draw_string(font, Vector2(24.0, 120.0), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.9, 1.0, 0.95))

	for node in nodes.values():
		ci.draw_line(Vector2(node.safe_x1, node.y), Vector2(node.safe_x2, node.y), Color(0.2, 0.8, 1.0, 0.5), 2.0)
		ci.draw_circle(node.get_center(), 3.0, Color(0.2, 0.9, 1.0, 0.8))

	for e in cur_edges:
		var tgt_node: RefCounted = get_node(e.target_surface_id)
		if tgt_node == null: continue

		var p_from := Vector2((e.takeoff_x_min + e.takeoff_x_max) * 0.5, cur_node.y if cur_node else 0.0)
		var p_to := Vector2((e.landing_x_min + e.landing_x_max) * 0.5, tgt_node.y)
		var color := Color(0.2, 1.0, 0.4, 0.9)
		var tag := "J"
		if e.action_type == NavigationEdgeClass.ActionType.JUMP_RUN:
			color = Color(0.2, 0.7, 1.0, 0.9); tag = "R"
		elif e.action_type == NavigationEdgeClass.ActionType.DROP:
			color = Color(1.0, 0.6, 0.2, 0.9); tag = "D"
		ci.draw_line(p_from, p_to, color, 2.5)
		ci.draw_circle(p_to, 4.0, color)
		ci.draw_string(font, (p_from + p_to) * 0.5 + Vector2(0.0, -4.0), tag, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)




