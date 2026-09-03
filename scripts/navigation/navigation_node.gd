class_name NavigationNode
extends RefCounted

var node_id: String = ""
var surface_id: String = ""
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

func _init(p_surface: RefCounted = null, p_landing_margin: float = 14.0) -> void:
	if p_surface == null:
		return
	surface_id = str(p_surface.id)
	node_id = surface_id
	source_type = str(p_surface.source_type)
	x1 = minf(float(p_surface.x1), float(p_surface.x2))
	x2 = maxf(float(p_surface.x1), float(p_surface.x2))
	y = float(p_surface.y1)
	dynamic = bool(p_surface.dynamic)
	priority = int(p_surface.priority)
	length = x2 - x1


	if source_type == "SCREEN":
		safe_x1 = x1
		safe_x2 = x2
		navigable = true
	else:
		safe_x1 = x1 + p_landing_margin
		safe_x2 = x2 - p_landing_margin
		navigable = (safe_x2 - safe_x1) >= 4.0

func get_center() -> Vector2:
	return Vector2((x1 + x2) * 0.5, y)

func get_safe_center() -> Vector2:
	return Vector2((safe_x1 + safe_x2) * 0.5, y)

func to_dict() -> Dictionary:
	return {
		"node_id": node_id, "surface_id": surface_id, "source_type": source_type,
		"x1": x1, "x2": x2, "y": y, "safe_x1": safe_x1, "safe_x2": safe_x2,
		"navigable": navigable, "dynamic": dynamic, "priority": priority, "length": length
	}
