class_name CatBodyProfile
extends RefCounted

var raw_width: float = 64.0
var raw_height: float = 64.0

var normalized_body_width: float = 0.82
var normalized_body_height: float = 0.75

var normalized_grab_x: float = 0.22
var normalized_grab_y_height: float = 0.32
var normalized_edge_hang_x: float = 0.11
var normalized_edge_hang_y: float = 0.30

var normalized_wall_contact_x: float = 0.25
var normalized_wall_contact_y_height: float = 0.30

var normalized_hitbox_width: float = 0.90
var normalized_hitbox_height: float = 0.90
var normalized_hitbox_top: float = 0.85
var normalized_hitbox_bottom: float = 0.10

var platform_min_length_ratio: float = 0.85
var climbable_wall_min_length_ratio: float = 0.85
var edge_grab_min_length_ratio: float = 0.60
var landing_margin_ratio: float = 0.25
var snap_tolerance_ratio: float = 0.15
var climb_inward_margin_ratio: float = 0.38
var climb_clearance_margin_ratio: float = 0.08

func to_dict() -> Dictionary:
	return {
		"raw_width": raw_width, "raw_height": raw_height,
		"normalized_body_width": normalized_body_width,
		"normalized_body_height": normalized_body_height,
		"normalized_grab_x": normalized_grab_x,
		"normalized_grab_y_height": normalized_grab_y_height,
		"normalized_wall_contact_x": normalized_wall_contact_x,
		"normalized_wall_contact_y_height": normalized_wall_contact_y_height
	}
