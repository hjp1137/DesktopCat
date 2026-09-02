class_name Cat
extends Node2D

enum State { IDLE, WALK }

@export var speed: float = 120.0
@export var body_radius: float = 28.0

var direction: float = 1.0 # 1.0 向右，-1.0 向左
var current_state: State = State.WALK
var state_timer: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _main_node: Node = get_parent()

func _ready() -> void:
	if position == Vector2.ZERO:
		position = _get_viewport_size() / 2.0
	_enter_state(State.WALK)
	print("[Cat] 初始化完成，初始位置: ", position, "，速度: ", speed, " px/s")

func _process(delta: float) -> void:
	_update_state_machine(delta)
	if _main_node and _main_node.has_method("update_mouse_passthrough"):
		_main_node.update_mouse_passthrough(position)

func _update_state_machine(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		if current_state == State.WALK:
			_enter_state(State.IDLE)
		else:
			# 随机决定下一次行走方向
			if randf() < 0.5:
				direction = -direction
			_enter_state(State.WALK)

	if current_state == State.WALK:
		_move_and_bounce(delta)

func _get_animated_sprite() -> AnimatedSprite2D:
	if not _animated_sprite:
		_animated_sprite = get_node_or_null("AnimatedSprite2D")
	return _animated_sprite

func _enter_state(new_state: State) -> void:
	current_state = new_state
	var sprite := _get_animated_sprite()
	if current_state == State.WALK:
		state_timer = randf_range(3.0, 7.0)
		if sprite:
			sprite.play("walk")
			sprite.flip_h = (direction < 0.0)
	else:
		state_timer = randf_range(1.5, 3.5)
		if sprite:
			sprite.play("idle")
	print("[Cat] 状态切换为: %s，持续 %.1f 秒，朝向: %s" % [
		"WALK" if current_state == State.WALK else "IDLE",
		state_timer,
		"左" if direction < 0.0 else "右"
	])

func _move_and_bounce(delta: float) -> void:
	var vp_size := _get_viewport_size()
	var left_bound := body_radius
	var right_bound := vp_size.x - body_radius

	position.x += direction * speed * delta

	if position.x >= right_bound:
		position.x = right_bound
		direction = -1.0
		if _animated_sprite:
			_animated_sprite.flip_h = true
		print("[Cat] 触碰右边界并转向向左，坐标: ", position)
	elif position.x <= left_bound:
		position.x = left_bound
		direction = 1.0
		if _animated_sprite:
			_animated_sprite.flip_h = false
		print("[Cat] 触碰左边界并转向向右，坐标: ", position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos := get_local_mouse_position()
		var click_rect := Rect2(-body_radius, -body_radius, body_radius * 2.0, body_radius * 2.0)
		if click_rect.has_point(local_pos):
			_on_clicked()

func _on_clicked() -> void:
	print("Cat clicked!")
	if _animated_sprite:
		var tween := create_tween()
		tween.tween_property(_animated_sprite, "position:y", -16.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_animated_sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _get_viewport_size() -> Vector2:
	if is_inside_tree() and get_viewport():
		var size := get_viewport_rect().size
		if DisplayServer.get_name() != "headless" and size.x > body_radius * 2.0:
			return size
	var w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 640)
	var h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 360)
	return Vector2(w, h)
