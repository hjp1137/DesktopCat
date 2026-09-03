class_name WallAttachment
extends RefCounted

var wall_surface_id: String = ""
var wall_x: float = 0.0
var wall_y1: float = 0.0
var wall_y2: float = 0.0
var wall_orientation: int = 2 # Surface.Orientation.LEFT
var attach_side: int = -1 # -1: 挂在墙左侧, +1: 挂在墙右侧
var anchor_y: float = 0.0
var surface_revision_at_attach: int = 0

func _init(p_surf_id: String = "", p_x: float = 0.0, p_y1: float = 0.0, p_y2: float = 0.0,
		p_orient: int = 2, p_side: int = -1, p_anchor_y: float = 0.0, p_rev: int = 0) -> void:
	wall_surface_id = p_surf_id
	wall_x = p_x
	wall_y1 = minf(p_y1, p_y2)
	wall_y2 = maxf(p_y1, p_y2)
	wall_orientation = p_orient
	attach_side = p_side
	anchor_y = p_anchor_y
	surface_revision_at_attach = p_rev

func update_geometry(new_x: float, new_y1: float, new_y2: float) -> void:
	wall_x = new_x
	wall_y1 = minf(new_y1, new_y2)
	wall_y2 = maxf(new_y1, new_y2)

func to_dict() -> Dictionary:
	return {
		"wall_surface_id": wall_surface_id,
		"wall_x": wall_x,
		"wall_y1": wall_y1,
		"wall_y2": wall_y2,
		"wall_orientation": wall_orientation,
		"attach_side": "LEFT" if attach_side == -1 else "RIGHT",
		"anchor_y": anchor_y,
		"surface_revision_at_attach": surface_revision_at_attach
	}
