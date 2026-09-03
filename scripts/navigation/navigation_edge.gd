class_name NavigationEdge
extends RefCounted

enum ActionType {
	JUMP_WALK = 0,
	JUMP_RUN = 1,
	DROP = 2,
	JUMP_TO_WALL = 3,
	DROP_TO_WALL = 4,
	WALL_TO_PLATFORM = 5
}

var source_surface_id: String = ""
var target_surface_id: String = ""
var action_type: int = ActionType.JUMP_WALK
var direction: int = 1 # -1: LEFT, 1: RIGHT, 0: DOWN
var required_speed_mode: String = "WALK" # "WALK", "RUN", "NONE"
var takeoff_x_min: float = 0.0
var takeoff_x_max: float = 0.0
var landing_x_min: float = 0.0
var landing_x_max: float = 0.0
var flight_time: float = 0.0
var horizontal_distance: float = 0.0
var vertical_delta: float = 0.0
var cost: float = 1.0
var difficulty: float = 0.0

var attach_side: int = 0
var attach_y_min: float = 0.0
var attach_y_max: float = 0.0
var estimated_climb_time: float = 0.0
var execution_sequence: Array = []

func _init(p_src: String = "", p_tgt: String = "", p_action: int = ActionType.JUMP_WALK,
		p_dir: int = 1, p_speed_mode: String = "WALK", p_t_min: float = 0.0,
		p_t_max: float = 0.0, p_l_min: float = 0.0, p_l_max: float = 0.0,
		p_time: float = 0.0, p_h_dist: float = 0.0, p_v_delta: float = 0.0,
		p_cost: float = 1.0, p_diff: float = 0.0) -> void:
	source_surface_id = p_src
	target_surface_id = p_tgt
	action_type = p_action
	direction = p_dir
	required_speed_mode = p_speed_mode
	takeoff_x_min = p_t_min
	takeoff_x_max = p_t_max
	landing_x_min = p_l_min
	landing_x_max = p_l_max
	flight_time = p_time
	horizontal_distance = p_h_dist
	vertical_delta = p_v_delta
	cost = p_cost
	difficulty = p_diff

func get_action_name() -> String:
	match action_type:
		ActionType.JUMP_WALK: return "JUMP_WALK"
		ActionType.JUMP_RUN: return "JUMP_RUN"
		ActionType.DROP: return "DROP"
		ActionType.JUMP_TO_WALL: return "JUMP_TO_WALL"
		ActionType.DROP_TO_WALL: return "DROP_TO_WALL"
		ActionType.WALL_TO_PLATFORM: return "WALL_TO_PLATFORM"
	return "UNKNOWN"

func to_dict() -> Dictionary:
	return {
		"source": source_surface_id, "target": target_surface_id,
		"action": get_action_name(), "direction": direction,
		"speed_mode": required_speed_mode,
		"takeoff_x_min": takeoff_x_min, "takeoff_x_max": takeoff_x_max,
		"landing_x_min": landing_x_min, "landing_x_max": landing_x_max,
		"flight_time": flight_time, "horizontal_distance": horizontal_distance,
		"vertical_delta": vertical_delta, "cost": cost, "difficulty": difficulty,
		"attach_side": attach_side, "attach_y_min": attach_y_min, "attach_y_max": attach_y_max,
		"estimated_climb_time": estimated_climb_time, "execution_sequence": execution_sequence
	}
