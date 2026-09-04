class_name CatGym
extends Node2D

const SurfaceClass = preload("res://scripts/world/surface.gd")

var base_x: float = 260.0
var ground_y: float = 800.0
var visible_gym: bool = true
var is_active: bool = true

# 视觉色彩方案 (日系温馨原木与麻绳配色)
const COLOR_WOOD = Color(0.82, 0.65, 0.46, 0.92)       # 暖原木板材
const COLOR_WOOD_DARK = Color(0.66, 0.48, 0.32, 0.95)  # 边缘与深色木纹
const COLOR_ROPE = Color(0.88, 0.80, 0.64, 0.95)       # 粗麻绳缠绕色
const COLOR_ROPE_STRIPE = Color(0.74, 0.64, 0.48, 0.9) # 麻绳阴影横纹
const COLOR_CUSHION = Color(0.96, 0.94, 0.90, 0.95)    # 绒毛米白软垫
const COLOR_ACCENT = Color(0.95, 0.60, 0.55, 0.95)     # 可爱粉萌爪印

func setup(p_base_x: float, p_ground_y: float) -> void:
	base_x = p_base_x
	ground_y = p_ground_y
	queue_redraw()

func _draw() -> void:
	if not visible_gym: return
	
	# 1. 原木底座 (宽 180, 厚 16)
	var base_rect := Rect2(base_x - 90.0, ground_y - 16.0, 180.0, 16.0)
	draw_rect(base_rect, COLOR_WOOD)
	draw_rect(base_rect, COLOR_WOOD_DARK, false, 2.0)
	
	# 2. 粗麻绳主攀爬柱 (高 404, 宽 26)
	var post_top_y: float = ground_y - 420.0
	var post_rect := Rect2(base_x - 13.0, post_top_y, 26.0, 404.0)
	draw_rect(post_rect, COLOR_ROPE)
	# 细密麻绳横纹
	var y_step: float = post_top_y
	while y_step < ground_y - 16.0:
		draw_line(Vector2(base_x - 13.0, y_step), Vector2(base_x + 13.0, y_step), COLOR_ROPE_STRIPE, 1.5)
		y_step += 8.0
	draw_rect(post_rect, COLOR_WOOD_DARK, false, 1.5)

	# 3. 第一层跳台 (左伸, Y = ground_y - 130)
	_draw_shelf(base_x - 120.0, base_x + 5.0, ground_y - 130.0, 12.0)
	
	# 4. 第二层跳台 (右伸, Y = ground_y - 260)
	_draw_shelf(base_x - 5.0, base_x + 125.0, ground_y - 260.0, 12.0)
	
	# 5. 第三层顶层大跳台 (居中, Y = ground_y - 420)
	_draw_top_perch(base_x - 85.0, base_x + 85.0, post_top_y, 14.0)

func _draw_shelf(x1: float, x2: float, y: float, thickness: float) -> void:
	var r := Rect2(x1, y, x2 - x1, thickness)
	draw_rect(r, COLOR_WOOD)
	draw_rect(r, COLOR_WOOD_DARK, false, 1.5)
	# 白色软垫
	draw_rect(Rect2(x1 + 4.0, y - 4.0, (x2 - x1) - 8.0, 4.0), COLOR_CUSHION)

func _draw_top_perch(x1: float, x2: float, y: float, thickness: float) -> void:
	var r := Rect2(x1, y, x2 - x1, thickness)
	draw_rect(r, COLOR_WOOD)
	draw_rect(r, COLOR_WOOD_DARK, false, 1.8)
	draw_rect(Rect2(x1 + 6.0, y - 5.0, (x2 - x1) - 12.0, 5.0), COLOR_CUSHION)
	# 顶台小爪印
	draw_circle(Vector2(base_x, y + thickness * 0.5), 3.0, COLOR_ACCENT)
	draw_circle(Vector2(base_x - 4.0, y + thickness * 0.3), 1.5, COLOR_ACCENT)
	draw_circle(Vector2(base_x, y + thickness * 0.2), 1.5, COLOR_ACCENT)
	draw_circle(Vector2(base_x + 4.0, y + thickness * 0.3), 1.5, COLOR_ACCENT)

func generate_surfaces() -> Array:
	var list: Array = []
	var post_top_y: float = ground_y - 420.0
	
	# 底座平台 (y = ground_y - 16)
	list.append(SurfaceClass.new("gym:base:top", "gym", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, base_x - 90.0, ground_y - 16.0, base_x + 90.0, ground_y - 16.0, true, false, false))
	
	# 主爬柱左右抓壁 (垂直高度 404px，贯穿全程，climbable = true)
	list.append(SurfaceClass.new("gym:post:left", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, base_x - 13.0, post_top_y, base_x - 13.0, ground_y - 16.0, false, false, true))
	list.append(SurfaceClass.new("gym:post:right", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, base_x + 13.0, post_top_y, base_x + 13.0, ground_y - 16.0, false, false, true))
	
	# 第一层跳台 (y = ground_y - 130)
	var s1_y: float = ground_y - 130.0
	list.append(SurfaceClass.new("gym:shelf_1:top", "gym", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, base_x - 120.0, s1_y, base_x + 5.0, s1_y, true, false, false))
	list.append(SurfaceClass.new("gym:shelf_1:left", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, base_x - 120.0, s1_y, base_x - 120.0, s1_y + 80.0, false, false, true))
	
	# 第二层跳台 (y = ground_y - 260)
	var s2_y: float = ground_y - 260.0
	list.append(SurfaceClass.new("gym:shelf_2:top", "gym", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, base_x - 5.0, s2_y, base_x + 125.0, s2_y, true, false, false))
	list.append(SurfaceClass.new("gym:shelf_2:right", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, base_x + 125.0, s2_y, base_x + 125.0, s2_y + 80.0, false, false, true))
	
	# 第三层顶层跳台 (y = post_top_y)
	list.append(SurfaceClass.new("gym:top_perch:top", "gym", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, base_x - 85.0, post_top_y, base_x + 85.0, post_top_y, true, false, false))
	list.append(SurfaceClass.new("gym:top_perch:left", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, base_x - 85.0, post_top_y, base_x - 85.0, post_top_y + 80.0, false, false, true))
	list.append(SurfaceClass.new("gym:top_perch:right", "gym", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, base_x + 85.0, post_top_y, base_x + 85.0, post_top_y + 80.0, false, false, true))
	
	return list
