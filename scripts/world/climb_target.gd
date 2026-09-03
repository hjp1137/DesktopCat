class_name ClimbTarget
extends RefCounted

## T20: 边缘翻越目标数据结构 (Climb Target)
## 保存从抓边位置到平台顶部的两段式受控轨迹与目标脚底坐标

var surface_id: String = ""
var edge_side: int = -1 # -1 = LEFT, 1 = RIGHT
var edge_position: Vector2 = Vector2.ZERO
var target_foot_x: float = 0.0
var target_foot_y: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var pull_up_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var surface_revision_at_start: int = 0

func _init(
	p_surface_id: String = "",
	p_edge_side: int = -1,
	p_edge_pos: Vector2 = Vector2.ZERO,
	p_target_foot_x: float = 0.0,
	p_target_foot_y: float = 0.0,
	p_start_pos: Vector2 = Vector2.ZERO,
	p_pull_up_pos: Vector2 = Vector2.ZERO,
	p_target_pos: Vector2 = Vector2.ZERO,
	p_rev: int = 0
) -> void:
	surface_id = p_surface_id
	edge_side = p_edge_side
	edge_position = p_edge_pos
	target_foot_x = p_target_foot_x
	target_foot_y = p_target_foot_y
	start_position = p_start_pos
	pull_up_position = p_pull_up_pos
	target_position = p_target_pos
	surface_revision_at_start = p_rev

func get_landing_foot_position() -> Vector2:
	return Vector2(target_foot_x, target_foot_y)

func get_side_name() -> String:
	return "LEFT" if edge_side == -1 else "RIGHT"

func to_dict() -> Dictionary:
	return {
		"surface_id": surface_id,
		"edge_side": get_side_name(),
		"edge_position": { "x": edge_position.x, "y": edge_position.y },
		"target_foot_x": target_foot_x,
		"target_foot_y": target_foot_y,
		"start_position": { "x": start_position.x, "y": start_position.y },
		"pull_up_position": { "x": pull_up_position.x, "y": pull_up_position.y },
		"target_position": { "x": target_position.x, "y": target_position.y },
		"surface_revision_at_start": surface_revision_at_start
	}
