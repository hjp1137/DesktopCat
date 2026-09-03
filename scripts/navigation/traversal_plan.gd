class_name TraversalPlan
extends RefCounted

var source_surface_id: String = ""
var target_surface_id: String = ""
var action_type: int = 0
var direction: int = 1
var speed_mode: String = "WALK"

var takeoff_x: float = 0.0
var landing_target_x: float = 0.0

var takeoff_x_min: float = 0.0
var takeoff_x_max: float = 0.0
var landing_x_min: float = 0.0
var landing_x_max: float = 0.0

var expected_flight_time: float = 0.0
var expected_target_y: float = 0.0
var plan_created_revision: int = 0
var timeout: float = 2.5
var elapsed_airborne: float = 0.0
var fail_reason: String = ""

func _init(p_src: String = "", p_tgt: String = "", p_act: int = 0, p_dir: int = 1, p_spd: String = "WALK", p_tx: float = 0.0, p_lx: float = 0.0, p_t_min: float = 0.0, p_t_max: float = 0.0, p_l_min: float = 0.0, p_l_max: float = 0.0, p_flight_t: float = 0.0, p_tgt_y: float = 0.0, p_rev: int = 0) -> void:
	source_surface_id = p_src
	target_surface_id = p_tgt
	action_type = p_act
	direction = p_dir
	speed_mode = p_spd
	takeoff_x = p_tx
	landing_target_x = p_lx
	takeoff_x_min = p_t_min
	takeoff_x_max = p_t_max
	landing_x_min = p_l_min
	landing_x_max = p_l_max
	expected_flight_time = p_flight_t
	expected_target_y = p_tgt_y
	plan_created_revision = p_rev
	timeout = maxf(1.8, (p_flight_t * 2.0) + 0.8)

func to_dict() -> Dictionary:
	return {
		"source": source_surface_id,
		"target": target_surface_id,
		"action": "JUMP_RUN" if action_type == 1 else ("DROP" if action_type == 2 else "JUMP_WALK"),
		"direction": "RIGHT" if direction > 0 else "LEFT",
		"speed_mode": speed_mode,
		"takeoff_x": takeoff_x,
		"landing_target_x": landing_target_x,
		"flight_time": expected_flight_time,
		"target_y": expected_target_y
	}
