class_name CatMovementCapabilities
extends RefCounted

var gravity: float = 980.0
var jump_velocity: float = -420.0
var walk_speed: float = 120.0
var run_speed: float = 220.0
var body_radius: float = 28.0
var foot_width: float = 56.0
var landing_margin: float = 14.0
var safety_factor: float = 0.90
var max_drop_distance: float = 800.0

func _init(cat_node: Node2D = null) -> void:
	if is_instance_valid(cat_node):
		sync_from_cat(cat_node)

func sync_from_cat(cat_node: Node2D) -> void:
	if not is_instance_valid(cat_node):
		return
	if "gravity" in cat_node: gravity = float(cat_node.gravity)
	if "jump_velocity" in cat_node: jump_velocity = float(cat_node.jump_velocity)
	if "walk_speed" in cat_node: walk_speed = float(cat_node.walk_speed)
	if "run_speed" in cat_node: run_speed = float(cat_node.run_speed)
	if "body_radius" in cat_node:
		body_radius = float(cat_node.body_radius)
		foot_width = body_radius * 2.0
		landing_margin = maxf(4.0, body_radius * 0.5)

func get_max_jump_height() -> float:
	return (jump_velocity * jump_velocity) / (2.0 * gravity)

func get_time_to_apex() -> float:
	return absf(jump_velocity) / gravity

func get_level_flight_time() -> float:
	return (2.0 * absf(jump_velocity)) / gravity

func get_max_walk_jump_distance() -> float:
	return walk_speed * get_level_flight_time() * safety_factor

func get_max_run_jump_distance() -> float:
	return run_speed * get_level_flight_time() * safety_factor

func calc_jump_landing_time(delta_y: float) -> float:
	var disc := (jump_velocity * jump_velocity) + (2.0 * gravity * delta_y)
	if disc < 0.0:
		return -1.0
	var t := (absf(jump_velocity) + sqrt(disc)) / gravity
	return t if t > 0.0 else -1.0

func calc_drop_landing_time(delta_y: float) -> float:
	if delta_y <= 0.0 or delta_y > max_drop_distance:
		return -1.0
	return sqrt((2.0 * delta_y) / gravity)


func sample_jump_trajectory_y(t: float) -> float:
	return (jump_velocity * t) + (0.5 * gravity * t * t)

func sample_drop_trajectory_y(t: float) -> float:
	return 0.5 * gravity * t * t
