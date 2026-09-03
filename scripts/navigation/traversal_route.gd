class_name TraversalRoute
extends RefCounted

var route_id: String = ""
var source_surface_id: String = ""
var goal_surface_id: String = ""
var steps: Array = [] # Array of TraversalStep
var current_step_index: int = 0
var total_cost: float = 0.0
var surface_revision_at_plan: int = 0
var metrics_revision_at_plan: int = 0
var creation_time_ms: int = 0
var status: String = "PENDING"
var fail_reason: String = ""

func _init(p_src: String = "", p_goal: String = "", p_steps: Array = [], p_cost: float = 0.0, p_s_rev: int = 0, p_m_rev: int = 0) -> void:
	source_surface_id = p_src
	goal_surface_id = p_goal
	steps = p_steps
	total_cost = p_cost
	surface_revision_at_plan = p_s_rev
	metrics_revision_at_plan = p_m_rev
	current_step_index = 0
	creation_time_ms = Time.get_ticks_msec()
	route_id = "route_%s_%s_%d" % [p_src, p_goal, creation_time_ms]
	status = "PENDING"
	fail_reason = ""

func get_current_step() -> RefCounted:
	if current_step_index >= 0 and current_step_index < steps.size():
		return steps[current_step_index]
	return null

func is_last_step() -> bool:
	return current_step_index == (steps.size() - 1)

func advance_step() -> bool:
	if current_step_index < steps.size() - 1:
		current_step_index += 1
		return true
	return false

func to_dict() -> Dictionary:
	var step_dicts: Array = []
	for s in steps:
		step_dicts.append(s.to_dict() if s != null and s.has_method("to_dict") else {})
	return {
		"route_id": route_id,
		"source": source_surface_id,
		"goal": goal_surface_id,
		"current_step_index": current_step_index,
		"total_steps": steps.size(),
		"total_cost": total_cost,
		"status": status,
		"fail_reason": fail_reason,
		"steps": step_dicts
	}
