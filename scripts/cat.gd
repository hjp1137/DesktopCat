class_name Cat
extends Node2D

@export var speed: float = 150.0
@export var body_radius: float = 24.0

var direction: float = 1.0 # 1.0 向右，-1.0 向左
var bounce_offset_y: float = 0.0
var _main_node: Node = null

func _ready() -> void:
	_main_node = get_parent()
	if position == Vector2.ZERO:
		position = _get_viewport_size() / 2.0
	print("[Cat] 初始化完成，初始位置: ", position, "，速度: ", speed, " px/s")

func _process(delta: float) -> void:
	_move_and_bounce(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"):
		_main_node.update_mouse_passthrough(position)
	if bounce_offset_y != 0.0:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos := get_local_mouse_position()
		var click_rect := Rect2(-32, -36, 64, 64)
		if click_rect.has_point(local_pos):
			_on_clicked()

func _on_clicked() -> void:
	print("Cat clicked!")
	var tween := create_tween()
	tween.tween_property(self, "bounce_offset_y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "bounce_offset_y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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
	var offset := Vector2(0, bounce_offset_y)

	draw_circle(offset, body_radius, body_color)
	draw_colored_polygon(PackedVector2Array([offset + Vector2(-16, -14), offset + Vector2(-8, -32), offset + Vector2(0, -18)]), ear_color)
	draw_colored_polygon(PackedVector2Array([offset + Vector2(-14, -16), offset + Vector2(-8, -28), offset + Vector2(-2, -19)]), inner_ear_color)
	draw_colored_polygon(PackedVector2Array([offset + Vector2(0, -18), offset + Vector2(8, -32), offset + Vector2(16, -14)]), ear_color)
	draw_colored_polygon(PackedVector2Array([offset + Vector2(2, -19), offset + Vector2(8, -28), offset + Vector2(14, -16)]), inner_ear_color)

	draw_circle(offset + Vector2(6, -4), 3.0, eye_color)
	draw_circle(offset + Vector2(-6, -4), 3.0, eye_color)
	draw_circle(offset + Vector2(0, 2), 2.5, nose_color)

	draw_line(offset + Vector2(6, 2), offset + Vector2(22, -1), eye_color, 1.5)
	draw_line(offset + Vector2(6, 4), offset + Vector2(22, 6), eye_color, 1.5)
	draw_line(offset + Vector2(-6, 2), offset + Vector2(-22, -1), eye_color, 1.5)
	draw_line(offset + Vector2(-6, 4), offset + Vector2(-22, 6), eye_color, 1.5)
