class_name UIElementWorldModel
extends Node2D

signal ui_world_updated(revision: int)

var elements_by_id: Dictionary = {}
var latest_revision: int = 0
var debug_draw_enabled: bool = false
var MAX_DEBUG_UI_ELEMENTS: int = 300
var screen_info: Dictionary = {}

const COLOR_MAP: Dictionary = {
	"Button": Color(0.2, 0.9, 1.0, 0.85),
	"Edit": Color(1.0, 0.75, 0.2, 0.85),
	"Text": Color(0.4, 1.0, 0.4, 0.85),
	"Image": Color(1.0, 0.4, 0.8, 0.85),
	"Hyperlink": Color(0.2, 0.5, 1.0, 0.85),
	"Document": Color(0.8, 0.6, 1.0, 0.65),
	"List": Color(0.9, 0.9, 0.3, 0.75),
	"ListItem": Color(0.9, 0.9, 0.5, 0.75),
	"Tab": Color(0.3, 1.0, 0.8, 0.75),
	"TabItem": Color(0.4, 1.0, 0.9, 0.75),
	"Pane": Color(0.65, 0.65, 0.65, 0.45),
	"Group": Color(0.6, 0.7, 0.8, 0.45),
	"Custom": Color(0.7, 0.9, 0.7, 0.6)
}
const DEFAULT_COLOR: Color = Color(0.6, 0.6, 0.6, 0.4)

func clear_elements() -> void:
	elements_by_id.clear()
	latest_revision = 0
	queue_redraw()

func toggle_debug_draw() -> bool:
	debug_draw_enabled = not debug_draw_enabled
	print("[UIWorld] Debug UI Automation: %s" % ("ON" if debug_draw_enabled else "OFF"))
	queue_redraw()
	return debug_draw_enabled

func update_from_snapshot(data: Dictionary) -> bool:
	if int(data.get("v", 0)) != 1 or str(data.get("type", "")) != "ui_snapshot":
		return false
	var rev: int = int(data.get("revision", 0))
	if rev <= latest_revision and latest_revision > 0:
		return false
	var raw_elements = data.get("elements", [])
	if typeof(raw_elements) != TYPE_ARRAY:
		return false
	var new_map: Dictionary = {}
	for item in raw_elements:
		if typeof(item) != TYPE_DICTIONARY: continue
		var eid: String = str(item.get("id", ""))
		if eid == "": continue
		var wid: String = str(item.get("window_id", ""))
		var ctype: String = str(item.get("control_type", "Other"))
		var x: float = float(item.get("x", 0.0))
		var y: float = float(item.get("y", 0.0))
		var w: float = float(item.get("width", 0.0))
		var h: float = float(item.get("height", 0.0))
		if w < 4.0 or h < 4.0: continue
		new_map[eid] = {
			"id": eid,
			"window_id": wid,
			"control_type": ctype,
			"rect": Rect2(x, y, w, h)
		}
	elements_by_id = new_map
	latest_revision = rev
	screen_info = data.get("screen", {})
	queue_redraw()
	emit_signal("ui_world_updated", latest_revision)
	return true

func get_all_elements() -> Array:
	return elements_by_id.values()

func get_elements_by_type(ctype: String) -> Array:
	var res: Array = []
	for e in elements_by_id.values():
		if e.control_type == ctype: res.append(e)
	return res

func get_elements_near(pos: Vector2, radius: float) -> Array:
	var res: Array = []
	var r2: float = radius * radius
	for e in elements_by_id.values():
		var r: Rect2 = e.rect
		var center := r.position + r.size * 0.5
		if center.distance_squared_to(pos) <= r2:
			res.append(e)
	return res

func _draw() -> void:
	if not debug_draw_enabled or elements_by_id.is_empty():
		return
	var items := elements_by_id.values()
	var draw_count: int = mini(items.size(), MAX_DEBUG_UI_ELEMENTS)
	for i in range(draw_count):
		var elem: Dictionary = items[i]
		var r: Rect2 = elem.rect
		var ctype: String = elem.control_type
		var col: Color = COLOR_MAP.get(ctype, DEFAULT_COLOR)
		draw_rect(r, col, false, 1.5)
		if r.size.x >= 32.0 and r.size.y >= 14.0:
			draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 3.0, r.position.y + 11.0), ctype, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	var header := "[F11 UI Automation] Elements: %d (Showing: %d) | Rev: %d" % [items.size(), draw_count, latest_revision]
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 95.0), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.9, 1.0, 0.95))

