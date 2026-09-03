class_name VisualWorldModel
extends Node2D

signal visual_world_updated(revision: int)

var geometries_by_id: Dictionary = {}
var latest_revision: int = 0
var debug_draw_enabled: bool = false
var MAX_DEBUG_VISUAL_GEOMETRIES: int = 300
var screen_info: Dictionary = {}

const COLOR_LINE_H: Color = Color(1.0, 0.55, 0.15, 0.9)  # 暖珊瑚橙
const COLOR_LINE_V: Color = Color(1.0, 0.85, 0.2, 0.9)   # 金黄色
const COLOR_RECT: Color = Color(0.85, 0.25, 1.0, 0.85)   # 靓紫红

func clear_geometries() -> void:
	geometries_by_id.clear()
	latest_revision = 0
	queue_redraw()

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[VisualWorld] Debug Visual Geometry: %s" % ("ON" if debug_draw_enabled else "OFF"))
	queue_redraw()
	return debug_draw_enabled

func update_from_snapshot(data: Dictionary) -> bool:
	if int(data.get("v", 0)) != 1 or str(data.get("type", "")) != "visual_snapshot":
		return false
	var rev: int = int(data.get("revision", 0))
	if rev <= latest_revision and latest_revision > 0:
		return false
	var raw_geoms = data.get("geometries", [])
	if typeof(raw_geoms) != TYPE_ARRAY:
		return false
	var new_map: Dictionary = {}
	for item in raw_geoms:
		if typeof(item) != TYPE_DICTIONARY: continue
		var gid: String = str(item.get("id", ""))
		if gid == "": continue
		var gtype: String = str(item.get("type", "")).to_upper()
		if gtype == "LINE":
			var orient: String = str(item.get("orientation", "HORIZONTAL")).to_upper()
			var x1: float = float(item.get("x1", 0.0)); var y1: float = float(item.get("y1", 0.0))
			var x2: float = float(item.get("x2", 0.0)); var y2: float = float(item.get("y2", 0.0))
			if is_nan(x1) or is_nan(y1) or is_nan(x2) or is_nan(y2) or is_inf(x1) or is_inf(y1) or is_inf(x2) or is_inf(y2):
				continue
			new_map[gid] = {
				"id": gid, "type": "LINE", "orientation": orient,
				"p1": Vector2(x1, y1), "p2": Vector2(x2, y2)
			}
		elif gtype == "RECT":
			var x: float = float(item.get("x", 0.0)); var y: float = float(item.get("y", 0.0))
			var w: float = float(item.get("width", 0.0)); var h: float = float(item.get("height", 0.0))
			if is_nan(x) or is_nan(y) or is_nan(w) or is_nan(h) or is_inf(x) or is_inf(y) or is_inf(w) or is_inf(h) or w <= 0.0 or h <= 0.0:
				continue
			new_map[gid] = {
				"id": gid, "type": "RECT", "rect": Rect2(x, y, w, h)
			}
	geometries_by_id = new_map
	latest_revision = rev
	screen_info = data.get("screen", {})
	queue_redraw()
	emit_signal("visual_world_updated", latest_revision)
	return true

func get_all_geometries() -> Array:
	return geometries_by_id.values()

func get_lines() -> Array:
	var res: Array = []
	for g in geometries_by_id.values():
		if g.type == "LINE": res.append(g)
	return res

func get_horizontal_lines() -> Array:
	var res: Array = []
	for g in geometries_by_id.values():
		if g.type == "LINE" and g.orientation == "HORIZONTAL": res.append(g)
	return res

func get_vertical_lines() -> Array:
	var res: Array = []
	for g in geometries_by_id.values():
		if g.type == "LINE" and g.orientation == "VERTICAL": res.append(g)
	return res

func get_rects() -> Array:
	var res: Array = []
	for g in geometries_by_id.values():
		if g.type == "RECT": res.append(g)
	return res

func get_geometries_near(pos: Vector2, radius: float) -> Array:
	var res: Array = []
	var r2: float = radius * radius
	for g in geometries_by_id.values():
		if g.type == "LINE":
			var mid: Vector2 = (g.p1 + g.p2) * 0.5
			if mid.distance_squared_to(pos) <= r2: res.append(g)
		elif g.type == "RECT":
			var center: Vector2 = g.rect.position + g.rect.size * 0.5
			if center.distance_squared_to(pos) <= r2: res.append(g)
	return res

func _draw() -> void:
	if not debug_draw_enabled or geometries_by_id.is_empty():
		return
	var items := geometries_by_id.values()
	var draw_count: int = mini(items.size(), MAX_DEBUG_VISUAL_GEOMETRIES)
	for i in range(draw_count):
		var g: Dictionary = items[i]
		if g.type == "LINE":
			var col: Color = COLOR_LINE_H if g.orientation == "HORIZONTAL" else COLOR_LINE_V
			draw_line(g.p1, g.p2, col, 2.0)
		elif g.type == "RECT":
			draw_rect(g.rect, COLOR_RECT, false, 1.5)
	var header := "[F12 Visual Geometry] Geometries: %d (Showing: %d) | Rev: %d" % [items.size(), draw_count, latest_revision]
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 115.0), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.15, 0.95))

