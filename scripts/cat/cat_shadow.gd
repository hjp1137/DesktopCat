class_name CatShadow
extends Node2D

var cat: Node2D = null

func _init() -> void:
	name = "CatShadow"
	z_index = -1 # 始终处于小猫身躯下方

func setup(p_cat: Node2D) -> void:
	cat = p_cat

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if cat == null: return
	var cstate: int = int(cat.get("current_state"))
	# 悬挂、爬墙或被拖拽时弱化/不显示
	if cstate == 8 or cstate == 9 or cstate == 10 or cstate == 11 or cstate == 7:
		return
	
	var is_grounded: bool = bool(cat.get("is_grounded"))
	var base_rx: float = 16.0
	var base_ry: float = 4.5
	var alpha: float = 0.28
	
	if not is_grounded:
		# 滞空状态随高度调整 (可适度淡化变小)
		base_rx = 11.0
		base_ry = 3.0
		alpha = 0.14
	
	var shadow_color = Color(0.05, 0.05, 0.08, alpha)
	# 脚底中心位于局部坐标 (0, 0)
	draw_ellipse_custom(Vector2(0, 0), base_rx, base_ry, shadow_color)

func draw_ellipse_custom(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points = PackedVector2Array()
	var segs = 16
	for i in range(segs):
		var rad = i * TAU / segs
		points.append(center + Vector2(cos(rad) * rx, sin(rad) * ry))
	draw_colored_polygon(points, color)
