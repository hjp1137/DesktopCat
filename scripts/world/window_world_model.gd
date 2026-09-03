class_name WindowWorldModel
extends Node2D

signal window_world_updated(revision: int)

var latest_revision: int = 0
var screen_size: Vector2 = Vector2(1920, 1080)
var windows_by_id: Dictionary = {}
var debug_draw_enabled: bool = false

func apply_snapshot(data: Dictionary) -> bool:
	var rev: int = int(data.get("revision", 0))
	if rev <= latest_revision and latest_revision > 0:
		return false
	latest_revision = rev
	windows_by_id.clear()
	var raw_windows = data.get("windows", [])
	if typeof(raw_windows) == TYPE_ARRAY:
		for item in raw_windows:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var wid: String = str(item.get("id", ""))
			var x: float = float(item.get("x", 0.0))
			var y: float = float(item.get("y", 0.0))
			var w: float = float(item.get("width", 0.0))
			var h: float = float(item.get("height", 0.0))
			var fg: bool = bool(item.get("is_foreground", false))
			var zo: int = int(item.get("z_order", 0))
			var title: String = str(item.get("title", ""))
			windows_by_id[wid] = {
				"id": wid,
				"rect": Rect2(x, y, w, h),
				"is_foreground": fg,
				"z_order": zo,
				"title": title
			}
	print("[World] Window snapshot revision %d: %d windows" % [latest_revision, windows_by_id.size()])
	queue_redraw()
	emit_signal("window_world_updated", latest_revision)
	return true

func clear_windows() -> void:
	windows_by_id.clear()
	latest_revision = 0
	queue_redraw()
	emit_signal("window_world_updated", 0)


func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[World] Debug Window Geometry: %s" % ("ON" if debug_draw_enabled else "OFF"))
	queue_redraw()
	return debug_draw_enabled

func _draw() -> void:
	if not debug_draw_enabled:
		return
	var font := ThemeDB.fallback_font
	var banner_text := "[F8 Debug] Window Geometry: ON | Windows: %d" % windows_by_id.size()
	if windows_by_id.is_empty():
		banner_text += " (0 windows - please run: python tools/perception/window_perception.py)"
	draw_string(font, Vector2(24.0, 36.0), banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 1.0, 0.4, 0.95))

	var font_size := 12
	for win in windows_by_id.values():
		var r: Rect2 = win.rect
		var is_fg: bool = win.is_foreground
		var border_col := Color(1.0, 0.45, 0.2, 0.9) if is_fg else Color(0.2, 0.8, 1.0, 0.75)
		draw_rect(r, border_col, false, 2.0)
		var label := "[%s] %s" % [win.id, win.title.substr(0, 20)]
		draw_string(font, r.position + Vector2(6.0, 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_col)

