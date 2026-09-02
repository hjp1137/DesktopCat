class_name Cat
extends Node2D

@export var speed: float = 150.0
@export var body_radius: float = 24.0

var direction: float = 1.0 # 1.0 向右，-1.0 向左

func _ready() -> void:
	# 初始居中放置（若未由外部指定特定坐标）
	if position == Vector2.ZERO:
		position = _get_viewport_size() / 2.0
	print("[Cat] 初始化完成，初始位置: ", position, "，速度: ", speed, " px/s")

func _process(delta: float) -> void:
	_move_and_bounce(delta)

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport():
		var size := get_viewport_rect().size
		if DisplayServer.get_name() != "headless" and size.x > body_radius * 2.0:
			return size
	var w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 640)
	var h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 360)
	return Vector2(w, h)

func _move_and_bounce(delta: float) -> void:
	var vp_size := _get_viewport_size()
	var left_bound := body_radius
	var right_bound := vp_size.x - body_radius

	position.x += direction * speed * delta

	if position.x >= right_bound:
		position.x = right_bound
		direction = -1.0
		scale.x = -abs(scale.x)
		print("[Cat] 触碰右边界并转向向左，坐标: ", position)
	elif position.x <= left_bound:
		position.x = left_bound
		direction = 1.0
		scale.x = abs(scale.x)
		print("[Cat] 触碰左边界并转向向右，坐标: ", position)

func _draw() -> void:
	var body_color := Color(0.98, 0.65, 0.25)
	var ear_color := Color(0.9, 0.55, 0.2)
	var inner_ear_color := Color(0.98, 0.8, 0.8)
	var eye_color := Color(0.12, 0.12, 0.12)
	var nose_color := Color(0.95, 0.45, 0.5)

	# 身体
	draw_circle(Vector2.ZERO, body_radius, body_color)

	# 猫耳 (左耳与右耳)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -14), Vector2(-8, -32), Vector2(0, -18)]), ear_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -16), Vector2(-8, -28), Vector2(-2, -19)]), inner_ear_color)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(8, -32), Vector2(16, -14)]), ear_color)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -19), Vector2(8, -28), Vector2(14, -16)]), inner_ear_color)

	# 眼睛
	draw_circle(Vector2(6, -4), 3.0, eye_color)
	draw_circle(Vector2(-6, -4), 3.0, eye_color)

	# 鼻子
	draw_circle(Vector2(0, 2), 2.5, nose_color)

	# 简易胡须
	draw_line(Vector2(6, 2), Vector2(22, -1), eye_color, 1.5)
	draw_line(Vector2(6, 4), Vector2(22, 6), eye_color, 1.5)
	draw_line(Vector2(-6, 2), Vector2(-22, -1), eye_color, 1.5)
	draw_line(Vector2(-6, 4), Vector2(-22, 6), eye_color, 1.5)
