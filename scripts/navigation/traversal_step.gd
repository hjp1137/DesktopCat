class_name TraversalStep
extends RefCounted

var step_index: int = 0
var action_type: int = 0 # NavigationEdge.ActionType
var from_surface_id: String = ""
var to_surface_id: String = ""
var parameters: Dictionary = {}
var timeout: float = 4.0
var elapsed_time: float = 0.0
var completed: bool = false
var failed: bool = false
var fail_reason: String = ""

func _init(p_idx: int = 0, p_action: int = 0, p_from: String = "", p_to: String = "", p_params: Dictionary = {}, p_timeout: float = 4.0) -> void:
	step_index = p_idx
	action_type = p_action
	from_surface_id = p_from
	to_surface_id = p_to
	parameters = p_params
	timeout = p_timeout
	elapsed_time = 0.0
	completed = false
	failed = false
	fail_reason = ""

func get_action_name() -> String:
	match action_type:
		0: return "JUMP_WALK"
		1: return "JUMP_RUN"
		2: return "DROP"
		3: return "JUMP_TO_WALL"
		4: return "DROP_TO_WALL"
		5: return "WALL_TO_PLATFORM"
	return "UNKNOWN"

func to_dict() -> Dictionary:
	return {
		"step_index": step_index,
		"action": get_action_name(),
		"from": from_surface_id,
		"to": to_surface_id,
		"parameters": parameters,
		"timeout": timeout,
		"elapsed_time": elapsed_time,
		"completed": completed,
		"failed": failed,
		"fail_reason": fail_reason
	}
