class_name CatMetrics
extends RefCounted

const CatBodyProfileClass = preload("res://scripts/cat/cat_body_profile.gd")

const CAT_SCREEN_HEIGHT_RATIO: float = 0.10
const MIN_CAT_VISUAL_HEIGHT: float = 85.0
const MAX_CAT_VISUAL_HEIGHT: float = 180.0
const MIN_USER_SCALE: float = 0.70
const MAX_USER_SCALE: float = 1.60
const DEFAULT_USER_SCALE: float = 1.00

var profile: RefCounted = null
var metrics_revision: int = 0

var base_scale: float = 1.0
var user_scale: float = 1.0
var final_scale: float = 1.0

var visual_width: float = 64.0
var visual_height: float = 64.0
var body_width: float = 52.0
var body_height: float = 48.0
var half_body_width: float = 26.0
var half_body_height: float = 24.0
var body_radius: float = 26.0
var foot_width: float = 52.0

var foot_offset: Vector2 = Vector2.ZERO
var support_margin: float = 4.0
var snap_tolerance: float = 8.0

var edge_grab_x_tolerance: float = 14.0
var edge_grab_y_tolerance: float = 20.0
var edge_hang_offset_x: float = 7.0
var edge_hang_offset_y: float = 19.0
var grab_point_offset_x: float = 14.0
var grab_point_offset_y: float = -20.0

var climb_inward_margin: float = 20.0
var climb_clearance_margin: float = 4.0
var min_platform_length: float = 44.0
var min_edge_grab_length: float = 31.0
var min_climbable_wall_length: float = 44.0

var wall_attach_x_tolerance: float = 14.0
var wall_cling_offset_x: float = 16.0
var wall_top_edge_tolerance: float = 8.0

var hitbox_size: Vector2 = Vector2(56.0, 56.0)
var hit_region_half_w: float = 32.0
var hit_region_top_h: float = 36.0
var hit_region_bottom_h: float = 28.0

func _init(p_profile: RefCounted = null) -> void:
	profile = p_profile if p_profile != null else CatBodyProfileClass.new()
	recalculate_metrics()

static func calc_base_scale_from_screen_height(screen_height: float, raw_h: float = 64.0) -> float:
	var target_h: float = clampf(screen_height * CAT_SCREEN_HEIGHT_RATIO, MIN_CAT_VISUAL_HEIGHT, MAX_CAT_VISUAL_HEIGHT)
	return target_h / raw_h

func update_scales(p_base_scale: float, p_user_scale: float) -> void:
	var safe_user_scale: float = p_user_scale
	if is_nan(safe_user_scale) or is_inf(safe_user_scale):
		safe_user_scale = DEFAULT_USER_SCALE
	safe_user_scale = clampf(safe_user_scale, MIN_USER_SCALE, MAX_USER_SCALE)

	var safe_base_scale := p_base_scale
	if is_nan(safe_base_scale) or is_inf(safe_base_scale) or safe_base_scale <= 0.01:
		safe_base_scale = 1.0

	base_scale = safe_base_scale
	user_scale = safe_user_scale
	final_scale = base_scale * user_scale
	recalculate_metrics()

func recalculate_metrics() -> void:
	if profile == null:
		profile = CatBodyProfileClass.new()
	visual_width = profile.raw_width * final_scale
	visual_height = profile.raw_height * final_scale
	body_width = profile.raw_width * profile.normalized_body_width * final_scale
	body_height = profile.raw_height * profile.normalized_body_height * final_scale
	half_body_width = body_width * 0.5
	half_body_height = body_height * 0.5
	body_radius = half_body_width * 0.95
	foot_width = body_width

	foot_offset = Vector2.ZERO
	support_margin = clampf(body_width * profile.landing_margin_ratio, 3.0, 16.0)
	snap_tolerance = clampf(body_height * profile.snap_tolerance_ratio, 6.0, 20.0)

	edge_grab_x_tolerance = clampf(body_width * 0.28, 10.0, 26.0)
	edge_grab_y_tolerance = clampf(body_height * 0.42, 14.0, 36.0)
	edge_hang_offset_x = profile.raw_width * profile.normalized_edge_hang_x * final_scale
	edge_hang_offset_y = profile.raw_height * profile.normalized_edge_hang_y * final_scale
	grab_point_offset_x = profile.raw_width * profile.normalized_grab_x * final_scale
	grab_point_offset_y = -profile.raw_height * profile.normalized_grab_y_height * final_scale

	climb_inward_margin = profile.raw_width * profile.climb_inward_margin_ratio * final_scale
	climb_clearance_margin = profile.raw_width * profile.climb_clearance_margin_ratio * final_scale
	min_platform_length = body_width * profile.platform_min_length_ratio
	min_edge_grab_length = body_width * profile.edge_grab_min_length_ratio
	min_climbable_wall_length = body_height * profile.climbable_wall_min_length_ratio

	wall_attach_x_tolerance = clampf(body_width * 0.28, 10.0, 24.0)
	wall_cling_offset_x = profile.raw_width * profile.normalized_wall_contact_x * final_scale
	wall_top_edge_tolerance = clampf(body_height * 0.16, 6.0, 18.0)

	var hb_w: float = profile.raw_width * profile.normalized_hitbox_width * final_scale
	var hb_h: float = profile.raw_height * profile.normalized_hitbox_height * final_scale
	hitbox_size = Vector2(hb_w, hb_h)
	hit_region_half_w = hb_w * 0.55
	hit_region_top_h = profile.raw_height * profile.normalized_hitbox_top * final_scale
	hit_region_bottom_h = profile.raw_height * profile.normalized_hitbox_bottom * final_scale

	metrics_revision += 1

func get_mouse_passthrough_polygon(cat_pos: Vector2) -> PackedVector2Array:
	var p1 := cat_pos + Vector2(-hit_region_half_w, -hit_region_top_h)
	var p2 := cat_pos + Vector2(hit_region_half_w, -hit_region_top_h)
	var p3 := cat_pos + Vector2(hit_region_half_w, hit_region_bottom_h)
	var p4 := cat_pos + Vector2(-hit_region_half_w, hit_region_bottom_h)
	return PackedVector2Array([p1, p2, p3, p4])

func to_dict() -> Dictionary:
	return {
		"metrics_revision": metrics_revision, "base_scale": base_scale,
		"user_scale": user_scale, "final_scale": final_scale,
		"visual_width": visual_width, "visual_height": visual_height,
		"body_width": body_width, "body_height": body_height,
		"body_radius": body_radius, "foot_offset_y": foot_offset.y,
		"edge_hang_offset": [edge_hang_offset_x, edge_hang_offset_y],
		"grab_point_offset": [grab_point_offset_x, grab_point_offset_y],
		"wall_cling_offset_x": wall_cling_offset_x,
		"min_platform_length": min_platform_length
	}
