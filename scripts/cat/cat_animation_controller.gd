class_name CatAnimationController
extends Node2D

var cat: Node2D = null
var visual_root: Node2D = null
var animated_sprite: AnimatedSprite2D = null

# 调试与展示模式
var debug_draw_enabled: bool = false
var anim_showcase_mode: bool = false
var showcase_timer: float = 0.0
var showcase_index: int = 0
const SHOWCASE_ANIMS: Array[String] = [
	"idle", "walk", "run", "sit", "sleep", "wake", "jump", "fall",
	"land", "edge_grab", "edge_hang", "climb_up", "wall_cling",
	"wall_climb_up", "wall_climb_down", "dragged"
]

# 瞬态过渡状态
var current_anim_name: String = ""
var is_landing_trans: bool = false
var landing_timer: float = 0.0
var is_wake_trans: bool = false
var wake_timer: float = 0.0
var is_edge_grab_trans: bool = false
var edge_grab_timer: float = 0.0

# Visual Squash & Stretch
var squash_timer: float = 0.0
var squash_duration: float = 0.15
var squash_scale: Vector2 = Vector2.ONE

func _init() -> void:
	name = "CatAnimationController"

func setup(p_cat: Node2D, p_visual_root: Node2D, p_sprite: AnimatedSprite2D) -> void:
	cat = p_cat
	visual_root = p_visual_root
	animated_sprite = p_sprite
	if cat != null and cat.has_signal("landed"):
		if not cat.is_connected("landed", Callable(self, "_on_cat_landed")):
			cat.connect("landed", Callable(self, "_on_cat_landed"))

func _process(delta: float) -> void:
	if anim_showcase_mode:
		_process_showcase(delta)
		return
	_process_squash(delta)
	_process_transitions(delta)
	update_animation()
	if debug_draw_enabled:
		queue_redraw()

func _draw() -> void:
	draw_debug(self)

func _process_squash(delta: float) -> void:
	if squash_timer > 0.0:
		squash_timer = maxf(0.0, squash_timer - delta)
		var progress: float = 1.0 - (squash_timer / squash_duration)
		# 从 (1.18, 0.82) 平滑弹回 (1.0, 1.0)
		var cur_sx: float = lerpf(1.18, 1.0, progress)
		var cur_sy: float = lerpf(0.82, 1.0, progress)
		squash_scale = Vector2(cur_sx, cur_sy)
	else:
		squash_scale = Vector2.ONE
	if visual_root != null:
		var f_scale: float = float(cat.metrics.final_scale) if cat != null and cat.metrics != null else 1.0
		visual_root.scale = Vector2(f_scale, f_scale) * squash_scale

func _process_transitions(delta: float) -> void:
	if is_landing_trans:
		landing_timer = maxf(0.0, landing_timer - delta)
		if landing_timer <= 0.0: is_landing_trans = false
	if is_wake_trans:
		wake_timer = maxf(0.0, wake_timer - delta)
		if wake_timer <= 0.0: is_wake_trans = false
	if is_edge_grab_trans:
		edge_grab_timer = maxf(0.0, edge_grab_timer - delta)
		if edge_grab_timer <= 0.0: is_edge_grab_trans = false

func _on_cat_landed(_surface_id: String = "") -> void:
	trigger_landing_squash()

func trigger_landing_squash() -> void:
	is_landing_trans = true
	landing_timer = 0.22
	squash_timer = squash_duration

func update_animation() -> void:
	if cat == null or animated_sprite == null: return
	var cstate: int = int(cat.get("current_state"))
	var target_anim: String = "idle"
	
	# 优先级匹配
	match cstate:
		Cat.CatState.IDLE:
			if is_wake_trans: target_anim = "wake"
			elif is_landing_trans: target_anim = "land"
			else: target_anim = "idle"
		Cat.CatState.WALK: target_anim = "walk"
		Cat.CatState.RUN: target_anim = "run"
		Cat.CatState.SIT: target_anim = "sit"
		Cat.CatState.SLEEP: target_anim = "sleep"
		Cat.CatState.JUMP:
			var vy: float = float(cat.get("vertical_velocity")) if cat.get("vertical_velocity") != null else 0.0
			target_anim = "jump" if vy <= 0.0 else "fall"
		Cat.CatState.FALL:
			target_anim = "fall"
		Cat.CatState.DRAG: target_anim = "dragged"
		Cat.CatState.EDGE_HANG:
			target_anim = "edge_grab" if is_edge_grab_trans else "edge_hang"
		Cat.CatState.CLIMB_UP: target_anim = "climb_up"
		Cat.CatState.WALL_CLING: target_anim = "wall_cling"
		Cat.CatState.WALL_CLIMB:
			var vy2: float = float(cat.get("vertical_velocity")) if cat.get("vertical_velocity") != null else 0.0
			target_anim = "wall_climb_up" if vy2 <= 0.0 else "wall_climb_down"
		_: target_anim = "idle"

	# 朝向翻转逻辑
	var flip: bool = false
	if cstate == Cat.CatState.WALL_CLING or cstate == Cat.CatState.WALL_CLIMB: # 挂墙/爬墙状态依据附着法线
		var wall_att = cat.get("wall_attachment")
		if wall_att != null:
			flip = (wall_att.normal.x > 0.0) # 贴左墙面向右(不翻转)，贴右墙面向左(翻转)
		else:
			flip = (float(cat.get("direction")) < 0.0)
	elif cstate == Cat.CatState.EDGE_HANG or cstate == Cat.CatState.CLIMB_UP: # 抓边/翻越状态依据边缘侧向
		var gr_edge = cat.get("grabbed_edge")
		if gr_edge != null:
			flip = (gr_edge.edge_side == 0) # LEFT 翻转，RIGHT 不翻转
		else:
			flip = (float(cat.get("direction")) < 0.0)
	else:
		flip = (float(cat.get("direction")) < 0.0)

	animated_sprite.flip_h = flip
	play_anim(target_anim)

func play_anim(anim_name: String) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null: return
	var actual_name: String = anim_name
	if not animated_sprite.sprite_frames.has_animation(actual_name):
		# 安全 Fallback
		actual_name = "idle"
	if animated_sprite.animation != actual_name or not animated_sprite.is_playing():
		animated_sprite.play(actual_name)
		current_anim_name = actual_name

func _process_showcase(delta: float) -> void:
	showcase_timer += delta
	if showcase_timer >= 1.5:
		showcase_timer = 0.0
		showcase_index = (showcase_index + 1) % SHOWCASE_ANIMS.size()
	var anim: String = SHOWCASE_ANIMS[showcase_index]
	play_anim(anim)

func toggle_showcase() -> void:
	anim_showcase_mode = not anim_showcase_mode
	showcase_timer = 0.0
	showcase_index = 0
	print("[AnimController] Animation showcase mode: %s" % ("ON" if anim_showcase_mode else "OFF"))

func toggle_debug() -> void:
	debug_draw_enabled = not debug_draw_enabled
	print("[AnimController] Debug draw (F22): %s" % ("ON" if debug_draw_enabled else "OFF"))

func draw_debug(ci: CanvasItem) -> void:
	if not debug_draw_enabled or cat == null or animated_sprite == null: return
	var font = ThemeDB.fallback_font
	var c_pos: Vector2 = cat.global_position
	# 绘制状态与动画 HUD
	var txt1 = "CatState: %s  Anim: %s (Frame %d)" % [
		cat.get_state_name(int(cat.get("current_state"))),
		animated_sprite.animation,
		animated_sprite.frame
	]
	var txt2 = "Squash: (%.2f, %.2f)  Showcase: %s" % [
		squash_scale.x, squash_scale.y,
		"ON" if anim_showcase_mode else "OFF"
	]
	ci.draw_string(font, Vector2(-60, -50), txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.9, 0.2))
	ci.draw_string(font, Vector2(-60, -38), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.8, 0.8))
	# 绘制脚底锚点十字标 (局部原点 0, 0)
	ci.draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.2, 1.0, 0.2), 1.5)
	ci.draw_line(Vector2(0, -6), Vector2(0, 6), Color(0.2, 1.0, 0.2), 1.5)
