class_name SurfaceWorldModel
extends Node2D

const SurfaceClass = preload("res://scripts/world/surface.gd")

signal surface_world_updated(revision: int)


const MAX_SURFACES: int = 2048
const MIN_PLATFORM_LENGTH: float = 48.0
const MIN_WALL_LENGTH: float = 48.0
const MIN_EDGE_GRAB_SURFACE_LENGTH: float = 32.0
const MIN_CLIMBABLE_WALL_LENGTH: float = 48.0

var surface_revision: int = 0
var surfaces_by_id: Dictionary = {}
var debug_draw_enabled: bool = false
var last_geometry_signature: String = ""
var previous_window_positions: Dictionary = {}
var window_deltas: Dictionary = {}

func clear_surfaces() -> void:
	surfaces_by_id.clear()
	last_geometry_signature = ""
	surface_revision = 0
	previous_window_positions.clear()
	window_deltas.clear()
	queue_redraw()


func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[SurfaceWorld] Debug Surface World: %s" % ("ON" if debug_draw_enabled else "OFF"))
	queue_redraw()
	return debug_draw_enabled

func _create_screen_surfaces(overlay_sz: Vector2, ground_y: float) -> Array:
	var list: Array = []
	var sx: float = maxf(overlay_sz.x, 1920.0)
	var sy: float = maxf(overlay_sz.y, 1080.0)
	list.append(SurfaceClass.new("screen:ground", "screen", "SCREEN", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, -5000.0, ground_y, sx + 5000.0, ground_y, true, false))
	list.append(SurfaceClass.new("screen:left", "screen", "SCREEN", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 0.0, 0.0, 0.0, sy, false, false))
	list.append(SurfaceClass.new("screen:right", "screen", "SCREEN", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, sx, 0.0, sx, sy, false, false))
	list.append(SurfaceClass.new("screen:top", "screen", "SCREEN", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.BOTTOM, 0.0, 0.0, sx, 0.0, false, false))
	return list



func _subtract_interval(intervals: Array, ox1: float, ox2: float) -> Array:
	var result: Array = []
	for inv in intervals:
		var ix1: float = inv[0]; var ix2: float = inv[1]
		if ox2 <= ix1 or ox1 >= ix2:
			result.append(inv)
		else:
			if ox1 > ix1:
				result.append([ix1, ox1])
			if ox2 < ix2:
				result.append([ox2, ix2])
	return result

func rebuild_from_windows(windows: Dictionary, overlay_sz: Vector2, ground_y: float) -> bool:
	var new_surfaces: Dictionary = {}
	var screen_surfs := _create_screen_surfaces(overlay_sz, ground_y)
	for s in screen_surfs:
		new_surfaces[s.id] = s

	var win_list := windows.values()
	var new_positions: Dictionary = {}
	var new_deltas: Dictionary = {}
	for win in win_list:
		var wid: String = str(win.get("id", ""))
		var wpos: Vector2 = win.get("rect", Rect2()).position
		new_positions[wid] = wpos
		if previous_window_positions.has(wid):
			new_deltas[wid] = wpos - previous_window_positions[wid]
		else:
			new_deltas[wid] = Vector2.ZERO
		_extract_window_surfaces(win, win_list, new_surfaces)
		if new_surfaces.size() >= MAX_SURFACES:
			break
	previous_window_positions = new_positions
	return commit_surfaces(new_surfaces, new_deltas)

func commit_surfaces(new_surfaces: Dictionary, new_window_deltas: Dictionary = {}) -> bool:
	window_deltas = new_window_deltas


	var sig_parts: Array[String] = []
	var keys := new_surfaces.keys()
	keys.sort()
	for k in keys:
		var s = new_surfaces[k]
		sig_parts.append("%s:%.1f,%.1f->%.1f,%.1f" % [s.id, s.x1, s.y1, s.x2, s.y2])
	var sig := ";".join(sig_parts)

	if sig != last_geometry_signature:
		last_geometry_signature = sig
		surfaces_by_id = new_surfaces
		surface_revision += 1
		emit_signal("surface_world_updated", surface_revision)
		queue_redraw()
		return true
	return false


func _extract_window_surfaces(win: Dictionary, all_windows: Array, out_dict: Dictionary) -> void:
	var wid: String = win.id
	var r: Rect2 = win.rect
	if r.size.x >= MIN_PLATFORM_LENGTH:
		var b_surf = SurfaceClass.new(wid + ":bottom", wid, "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.BOTTOM, r.position.x, r.end.y, r.end.x, r.end.y, false, true)
		out_dict[b_surf.id] = b_surf
		var intervals: Array = [[r.position.x, r.end.x]]
		for other in all_windows:
			if other.id == wid: continue
			if other.z_order < win.z_order:
				var or_rect: Rect2 = other.rect
				if or_rect.position.y <= r.position.y and or_rect.end.y >= r.position.y:
					intervals = _subtract_interval(intervals, or_rect.position.x, or_rect.end.x)
		var valid_intervals: Array = []
		for inv in intervals:
			if (inv[1] - inv[0]) >= MIN_PLATFORM_LENGTH:
				valid_intervals.append(inv)
		if valid_intervals.size() == 1 and absf(valid_intervals[0][0] - r.position.x) < 0.5 and absf(valid_intervals[0][1] - r.end.x) < 0.5:
			var s = SurfaceClass.new(wid + ":top", wid, "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, valid_intervals[0][0], r.position.y, valid_intervals[0][1], r.position.y, true, true)
			out_dict[s.id] = s
		else:
			for i in range(valid_intervals.size()):
				var inv = valid_intervals[i]
				var sid := "%s:top:%d" % [wid, i]
				var s = SurfaceClass.new(sid, wid, "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, inv[0], r.position.y, inv[1], r.position.y, true, true)
				out_dict[s.id] = s

	if r.size.y >= MIN_WALL_LENGTH:
		var can_climb: bool = r.size.y >= MIN_CLIMBABLE_WALL_LENGTH and wid != "screen" and not wid.begins_with("screen:")
		var l_surf = SurfaceClass.new(wid + ":left", wid, "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, r.position.x, r.position.y, r.position.x, r.end.y, false, true, can_climb)
		out_dict[l_surf.id] = l_surf
		var r_surf = SurfaceClass.new(wid + ":right", wid, "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, r.end.x, r.position.y, r.end.x, r.end.y, false, true, can_climb)
		out_dict[r_surf.id] = r_surf


func get_all_surfaces() -> Array:
	return surfaces_by_id.values()

func get_walkable_surfaces() -> Array:
	var res: Array = []
	for s in surfaces_by_id.values():
		if s.walkable: res.append(s)
	return res

func get_walls() -> Array:
	var res: Array = []
	for s in surfaces_by_id.values():
		if s.surface_type == SurfaceClass.SurfaceType.WALL: res.append(s)
	return res

func get_surface_by_id(p_id: String) -> RefCounted:
	return surfaces_by_id.get(p_id, null)


func get_walkable_surfaces_near_y(target_y: float, tolerance: float = 8.0) -> Array:
	var res: Array = []
	for s in surfaces_by_id.values():
		if s.walkable and absf(s.y1 - target_y) <= tolerance:
			res.append(s)
	return res

func find_surfaces_in_rect(query_rect: Rect2) -> Array:
	var res: Array = []
	for s in surfaces_by_id.values():
		if query_rect.intersects(s.get_rect()):
			res.append(s)
	return res

func get_window_delta(wid: String) -> Vector2:
	return window_deltas.get(wid, Vector2.ZERO)

func find_support_surface_at(foot_x: float, foot_y: float, tol_y: float = 8.0, tol_x: float = 4.0) -> RefCounted:
	for s in surfaces_by_id.values():
		if s.walkable and absf(s.y1 - foot_y) <= tol_y:
			if (s.x1 - tol_x) <= foot_x and foot_x <= (s.x2 + tol_x):
				return s
	return null

func find_crossed_walkable_surface(prev_foot_y: float, next_foot_y: float, foot_x: float, margin: float = 4.0) -> RefCounted:
	var best_surf: RefCounted = null
	var min_y: float = INF
	for s in surfaces_by_id.values():
		if not s.walkable:
			continue
		var sy: float = s.y1
		if prev_foot_y <= sy + 1.0 and next_foot_y >= sy:
			if (s.x1 - margin) <= foot_x and foot_x <= (s.x2 + margin):
				if sy < min_y:
					min_y = sy
					best_surf = s
	return best_surf

func get_grabbable_edges_in_rect(query_rect: Rect2) -> Array:
	var results: Array = []
	for s in surfaces_by_id.values():
		if not s.walkable or s.surface_type != SurfaceClass.SurfaceType.PLATFORM or s.orientation != SurfaceClass.Orientation.TOP:
			continue
		if s.source_type == "SCREEN" or s.id.begins_with("screen:"):
			continue
		var surf_len: float = absf(s.x2 - s.x1)
		if surf_len < MIN_EDGE_GRAB_SURFACE_LENGTH:
			continue
		var p_left := Vector2(minf(s.x1, s.x2), s.y1)
		var p_right := Vector2(maxf(s.x1, s.x2), s.y1)
		if query_rect.has_point(p_left) or query_rect.grow(12.0).has_point(p_left):
			results.append({ "surface": s, "surface_id": s.id, "side": -1, "x": p_left.x, "y": p_left.y, "pos": p_left })
		if query_rect.has_point(p_right) or query_rect.grow(12.0).has_point(p_right):
			results.append({ "surface": s, "surface_id": s.id, "side": 1, "x": p_right.x, "y": p_right.y, "pos": p_right })
	return results

func find_equivalent_edge_near(old_pos: Vector2, side: int, tolerance: float = 16.0) -> Dictionary:
	var best_edge: Dictionary = {}
	var min_dist: float = tolerance
	for s in surfaces_by_id.values():
		if not s.walkable or s.surface_type != SurfaceClass.SurfaceType.PLATFORM or s.orientation != SurfaceClass.Orientation.TOP:
			continue
		if s.source_type == "SCREEN" or s.id.begins_with("screen:"):
			continue
		if absf(s.x2 - s.x1) < MIN_EDGE_GRAB_SURFACE_LENGTH:
			continue
		var edge_pos: Vector2 = Vector2(minf(s.x1, s.x2), s.y1) if side == -1 else Vector2(maxf(s.x1, s.x2), s.y1)
		var d := edge_pos.distance_to(old_pos)
		if d <= min_dist:
			min_dist = d
			best_edge = { "surface": s, "surface_id": s.id, "side": side, "x": edge_pos.x, "y": edge_pos.y, "pos": edge_pos }
	return best_edge

func get_climbable_walls_in_rect(query_rect: Rect2) -> Array:
	var results: Array = []
	var r_exp := query_rect.grow(16.0)
	for s in surfaces_by_id.values():
		if s.surface_type != SurfaceClass.SurfaceType.WALL: continue
		if s.source_type == "SCREEN" or s.id.begins_with("screen:"): continue
		var h: float = absf(s.y2 - s.y1)
		if h < MIN_CLIMBABLE_WALL_LENGTH: continue
		if not s.climbable and h < MIN_CLIMBABLE_WALL_LENGTH: continue
		var wx: float = s.x1
		var wy1: float = minf(s.y1, s.y2)
		var wy2: float = maxf(s.y1, s.y2)
		if r_exp.position.x <= wx and wx <= r_exp.end.x:
			if not (r_exp.end.y < wy1 or r_exp.position.y > wy2):
				results.append(s)
	return results

func find_equivalent_wall_near(old_x: float, old_y1: float, old_y2: float, orient: int, x_tol: float = 16.0, y_tol: float = 24.0) -> Dictionary:
	var best_wall: Dictionary = {}
	var min_dist: float = x_tol + y_tol
	for s in surfaces_by_id.values():
		if s.surface_type != SurfaceClass.SurfaceType.WALL: continue
		if s.source_type == "SCREEN" or s.id.begins_with("screen:"): continue
		if absf(s.y2 - s.y1) < MIN_CLIMBABLE_WALL_LENGTH: continue
		if orient != -1 and s.orientation != orient and s.orientation != SurfaceClass.Orientation.TOP and s.orientation != SurfaceClass.Orientation.BOTTOM:
			continue
		var dx := absf(s.x1 - old_x)
		var dy := absf(s.y1 - old_y1)
		if dx <= x_tol and dy <= y_tol:
			var d := dx + dy
			if d < min_dist:
				min_dist = d
				best_wall = { "surface": s, "surface_id": s.id, "x": s.x1, "y1": s.y1, "y2": s.y2 }
	return best_wall

func find_platform_connected_to_wall_top(wall_surf, tolerance: float = 8.0) -> Dictionary:
	if wall_surf == null: return {}
	var wx: float = wall_surf.x1
	var wy: float = minf(wall_surf.y1, wall_surf.y2)
	var best_plat: Dictionary = {}
	var best_score: float = 9999.0
	for s in surfaces_by_id.values():
		if s.surface_type != SurfaceClass.SurfaceType.PLATFORM or not s.walkable: continue
		if s.source_type == "SCREEN" or s.id.begins_with("screen:"): continue
		if absf(s.y1 - wy) > tolerance: continue
		var sx_left := minf(s.x1, s.x2)
		var sx_right := maxf(s.x1, s.x2)
		var d_left := absf(sx_left - wx)
		var d_right := absf(sx_right - wx)
		var side := 0
		var min_d := tolerance + 1.0
		if wall_surf.orientation == SurfaceClass.Orientation.LEFT or d_left < d_right:
			if d_left <= tolerance:
				side = -1
				min_d = d_left
		elif wall_surf.orientation == SurfaceClass.Orientation.RIGHT or d_right <= d_left:
			if d_right <= tolerance:
				side = 1
				min_d = d_right
		if side != 0 and min_d <= tolerance:
			var score := min_d
			if s.source_id == wall_surf.source_id: score -= 100.0
			if score < best_score:
				best_score = score
				var ep := Vector2(sx_left if side == -1 else sx_right, s.y1)
				best_plat = { "platform": s, "platform_id": s.id, "edge_side": side, "edge_pos": ep }
	return best_plat

func _draw() -> void:

	if not debug_draw_enabled:
		return
	var font := ThemeDB.fallback_font
	var walkable_count := 0
	var wall_count := 0
	for s in surfaces_by_id.values():
		if s.walkable: walkable_count += 1
		elif s.surface_type == SurfaceClass.SurfaceType.WALL: wall_count += 1
	var banner_text := "[F9 Debug] Surface World: ON | Surfaces: %d (Walkable: %d, Walls: %d)" % [surfaces_by_id.size(), walkable_count, wall_count]

	draw_string(font, Vector2(24.0, 56.0), banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.9, 0.9, 0.95))

	for s in surfaces_by_id.values():
		var p1 := Vector2(s.x1, s.y1); var p2 := Vector2(s.x2, s.y2)
		if s.walkable:
			draw_line(p1, p2, Color(0.2, 1.0, 0.3, 0.95), 3.0)
		elif s.surface_type == SurfaceClass.SurfaceType.WALL:
			draw_line(p1, p2, Color(1.0, 0.85, 0.2, 0.85), 2.0)

		else:
			draw_line(p1, p2, Color(0.3, 0.7, 1.0, 0.65), 2.0)


