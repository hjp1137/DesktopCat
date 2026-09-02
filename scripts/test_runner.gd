extends SceneTree

func _init() -> void:
	print("========== 开始执行 T04 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Node2D = cat_scene.instantiate()
	root.add_child(cat)
	
	# 测试 1: 初始参数与 AnimatedSprite2D
	var sprite: AnimatedSprite2D = cat.get_node_or_null("AnimatedSprite2D")
	assert(sprite != null, "Cat 下应当存在 AnimatedSprite2D")
	assert(sprite.sprite_frames.has_animation("idle"), "应当包含 idle 动画")
	assert(sprite.sprite_frames.has_animation("walk"), "应当包含 walk 动画")
	assert(is_equal_approx(sprite.sprite_frames.get_animation_speed("idle"), 4.0), "idle 动画速度应当为 4 FPS")
	assert(is_equal_approx(sprite.sprite_frames.get_animation_speed("walk"), 10.0), "walk 动画速度应当为 10 FPS")
	print("[PASS] 测试 1: AnimatedSprite2D 与动画帧配置验证成功")

	# 测试 2: 状态机 WALK 与 IDLE 切换
	cat._enter_state(Cat.State.WALK)
	assert(cat.current_state == Cat.State.WALK, "当前状态应当为 WALK")
	assert(sprite.animation == "walk", "WALK 状态下应播放 walk 动画")
	
	cat._enter_state(Cat.State.IDLE)
	assert(cat.current_state == Cat.State.IDLE, "当前状态应当为 IDLE")
	assert(sprite.animation == "idle", "IDLE 状态下应播放 idle 动画")
	print("[PASS] 测试 2: 状态机与动画关联验证成功")

	# 测试 3: 左右翻转 flip_h
	cat.direction = 1.0
	cat._enter_state(Cat.State.WALK)
	assert(sprite.flip_h == false, "向右移动时 flip_h 应当为 false")
	cat.direction = -1.0
	cat._enter_state(Cat.State.WALK)
	assert(sprite.flip_h == true, "向左移动时 flip_h 应当为 true")
	print("[PASS] 测试 3: 左右 flip_h 翻转验证成功")

	# 测试 4: 点击与跳跃反馈
	cat._on_clicked()
	print("[PASS] 测试 4: 点击反馈 _on_clicked() 调用成功")

	cat.queue_free()
	print("========== T04 表现层与动画逻辑所有单元测试全部通过 ==========")
	quit(0)
