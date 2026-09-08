class_name NavigationNode
extends RefCounted

enum NodeType { PLATFORM = 0, WALL = 1 }

var node_id: String = ""
var surface_id: String = ""
var node_type: int = NodeType.PLATFORM
var source_type: String = "WINDOW"
var x1: float = 0.0
var x2: float = 0.0
var y: float = 0.0
var safe_x1: float = 0.0
var safe_x2: float = 0.0
var navigable: bool = true
var dynamic: bool = true
var priority: int = 0
var length: float = 0.0

var wall_x: float = 0.0
var wall_y1: float = 0.0
var wall_y2: float = 0.0
var orientation: int = 0
var attach_side: int = 0
var safe_climb_y1: float = 0.0
var safe_climb_y2: float = 0.0

func _init(p_surface: RefCounted = null, p_margin: float = 14.0) -> void:
	if p_surface == null:
		return
	surface_id = str(p_surface.id)
	node_id = surface_id
	source_type = str(p_surface.source_type)
	dynamic = bool(p_surface.dynamic)
	priority = int(p_surface.priority)

	var s_type: int = int(p_surface.surface_type)
	if s_type == 1: # SurfaceType.WALL
		node_type = NodeType.WALL
		wall_x = float(p_surface.x1)
		wall_y1 = minf(float(p_surface.y1), float(p_surface.y2))
		wall_y2 = maxf(float(p_surface.y1), float(p_surface.y2))
		length = wall_y2 - wall_y1
		orientation = int(p_surface.orientation)
		if orientation == 2: # LEFT
			attach_side = -1
		elif orientation == 3: # RIGHT
			attach_side = 1
		else:
			attach_side = 0
		safe_climb_y1 = wall_y1 + p_margin * 0.8
		safe_climb_y2 = wall_y2 - p_margin
		navigable = (safe_climb_y2 - safe_climb_y1) >= 4.0
		x1 = wall_x; x2 = wall_x; y = wall_y1
	else:
		node_type = NodeType.PLATFORM
		x1 = minf(float(p_surface.x1), float(p_surface.x2))
		x2 = maxf(float(p_surface.x1), float(p_surface.x2))
		y = float(p_surface.y1)
		length = x2 - x1
		if source_type == "SCREEN":
			safe_x1 = x1
			safe_x2 = x2
			navigable = true
		else:
			var m := p_margin
			if (source_type == "VISUAL" or source_type == "UIA") and length < (2.0 * p_margin + 4.0):
				m = maxf(1.0, (length - 4.0) * 0.5)
			safe_x1 = x1 + m
			safe_x2 = x2 - m
			navigable = (safe_x2 - safe_x1) >= 4.0

func get_center() -> Vector2:
	if node_type == NodeType.WALL:
		return Vector2(wall_x, (wall_y1 + wall_y2) * 0.5)
	return Vector2((x1 + x2) * 0.5, y)

func get_safe_center() -> Vector2:
	if node_type == NodeType.WALL:
		return Vector2(wall_x, (safe_climb_y1 + safe_climb_y2) * 0.5)
	return Vector2((safe_x1 + safe_x2) * 0.5, y)

func to_dict() -> Dictionary:
	return {
		"node_id": node_id, "surface_id": surface_id, "node_type": "WALL" if node_type == NodeType.WALL else "PLATFORM",
		"source_type": source_type, "x1": x1, "x2": x2, "y": y, "safe_x1": safe_x1, "safe_x2": safe_x2,
		"wall_x": wall_x, "wall_y1": wall_y1, "wall_y2": wall_y2, "attach_side": attach_side,
		"safe_climb_y1": safe_climb_y1, "safe_climb_y2": safe_climb_y2,
		"navigable": navigable, "dynamic": dynamic, "priority": priority, "length": length
	}
