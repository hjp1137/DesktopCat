class_name FloatingHeart
extends Node2D

var lifetime: float = 0.85
var elapsed: float = 0.0

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	elapsed += delta
	position.y -= 38.0 * delta
	position.x += sin(elapsed * 8.0) * 12.0 * delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()

func _draw() -> void:
	var progress: float = elapsed / lifetime
	var alpha: float = clampf(1.0 - progress * progress, 0.0, 1.0)
	var scale_factor: float = sin(progress * PI * 0.8) * 1.3
	if scale_factor <= 0.01: return
	
	var col_heart := Color(1.0, 0.38, 0.58, alpha)
	var col_outline := Color(0.9, 0.2, 0.4, alpha * 0.8)
	
	# 绘制粉红萌系心形 (左右两个饱满圆瓣 + 底部倒三角形)
	var r: float = 4.2 * scale_factor
	draw_circle(Vector2(-3.2, -2.0) * scale_factor, r, col_heart)
	draw_circle(Vector2(3.2, -2.0) * scale_factor, r, col_heart)
	var pts := PackedVector2Array([
		Vector2(-6.8, -1.0) * scale_factor,
		Vector2(6.8, -1.0) * scale_factor,
		Vector2(0.0, 7.2) * scale_factor
	])
	draw_polygon(pts, PackedColorArray([col_heart, col_heart, col_heart]))
