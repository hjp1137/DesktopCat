class_name GrabbedEdge
extends RefCounted

enum Side {
	LEFT = -1,
	RIGHT = 1
}

var surface_id: String = ""
var edge_side: int = Side.LEFT
var edge_x: float = 0.0
var edge_y: float = 0.0

func _init(p_surf_id: String = "", p_side: int = Side.LEFT, p_x: float = 0.0, p_y: float = 0.0) -> void:
	surface_id = p_surf_id
	edge_side = p_side
	edge_x = p_x
	edge_y = p_y

func get_edge_position() -> Vector2:
	return Vector2(edge_x, edge_y)

func get_side_name() -> String:
	return "LEFT" if edge_side == Side.LEFT else "RIGHT"

func to_dict() -> Dictionary:
	return {
		"surface_id": surface_id,
		"edge_side": get_side_name(),
		"edge_x": edge_x,
		"edge_y": edge_y
	}
