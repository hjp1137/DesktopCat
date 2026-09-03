class_name ExplorationGoal
extends RefCounted

enum GoalType {
	VISIT_SURFACE = 0,
	ASCEND = 1,
	DESCEND = 2,
	LATERAL_EXPLORE = 3
}

var goal_id: String = ""
var target_surface_id: String = ""
var target_position: Vector2 = Vector2.ZERO
var target_region: String = "MID" # "TOP", "MID", "BOTTOM"
var goal_type: GoalType = GoalType.VISIT_SURFACE
var created_time: int = 0
var surface_revision: int = 0
var navigation_revision: int = 0
var score: float = 0.0
var reasons: Array = []
var route_cost: float = 0.0
var attempt_count: int = 0

func _init(
	p_goal_id: String = "",
	p_target_surface_id: String = "",
	p_target_pos: Vector2 = Vector2.ZERO,
	p_goal_type: GoalType = GoalType.VISIT_SURFACE,
	p_score: float = 0.0,
	p_cost: float = 0.0,
	p_reasons: Array = []
) -> void:
	goal_id = p_goal_id if not p_goal_id.is_empty() else "goal_%d" % Time.get_ticks_msec()
	target_surface_id = p_target_surface_id
	target_position = p_target_pos
	goal_type = p_goal_type
	score = p_score
	route_cost = p_cost
	reasons = p_reasons
	created_time = Time.get_ticks_msec()

func get_goal_type_name() -> String:
	match goal_type:
		GoalType.VISIT_SURFACE: return "VISIT_SURFACE"
		GoalType.ASCEND: return "ASCEND"
		GoalType.DESCEND: return "DESCEND"
		GoalType.LATERAL_EXPLORE: return "LATERAL_EXPLORE"
		_: return "UNKNOWN"

func to_dict() -> Dictionary:
	return {
		"goal_id": goal_id,
		"target_surface_id": target_surface_id,
		"target_position": { "x": target_position.x, "y": target_position.y },
		"target_region": target_region,
		"goal_type": get_goal_type_name(),
		"score": score,
		"route_cost": route_cost,
		"reasons": reasons,
		"created_time": created_time,
		"attempt_count": attempt_count
	}
