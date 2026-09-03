class_name SurfaceWorldModel
extends Node2D

const SurfaceClass = preload("res://scripts/world/surface.gd")

signal surface_world_updated(revision: int)


const MAX_SURFACES: int = 2048
const MIN_PLATFORM_LENGTH: float = 48.0
const MIN_WALL_LENGTH: float = 48.0

var surface_revision: int = 0
var surfaces_by_id: Dictionary = {}
var debug_draw_enabled: bool = false
var last_geometry_signature: String = ""

func clear_surfaces() -> void:
	surfaces_by_id.clear()
	last_geometry_signature = ""
	surface_revision = 0
	queue_redraw()

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[SurfaceWorld] Debug Surface World: %s" % ("ON" if debug_draw_enabled else "OFF"))
	queue_redraw()
	return debug_draw_enabled

func _create_screen_surfaces(overlay_sz: Vector2, ground_y: float) -> Array:
	var list: Array = []
	list.append(SurfaceClass.new("screen:ground", "screen", "SCREEN", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 0.0, ground_y, overlay_sz.x, ground_y, true, false))
	list.append(SurfaceClass.new("screen:left", "screen", "SCREEN", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 0.0, 0.0, 0.0, overlay_sz.y, false, false))
	list.append(SurfaceClass.new("screen:right", "screen", "SCREEN", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, overlay_sz.x, 0.0, overlay_sz.x, overlay_sz.y, false, false))
	list.append(SurfaceClass.new("screen:top", "screen", "SCREEN", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.BOTTOM, 0.0, 0.0, overlay_sz.x, 0.0, false, false))
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
	for win in win_list:
		_extract_window_surfaces(win, win_list, new_surfaces)
		if new_surfaces.size() >= MAX_SURFACES:
			break

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
		var l_surf = SurfaceClass.new(wid + ":left", wid, "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, r.position.x, r.position.y, r.position.x, r.end.y, false, true)
		out_dict[l_surf.id] = l_surf
		var r_surf = SurfaceClass.new(wid + ":right", wid, "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, r.end.x, r.position.y, r.end.x, r.end.y, false, true)
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


