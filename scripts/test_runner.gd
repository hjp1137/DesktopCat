extends SceneTree

func _init() -> void:
	print("========== 开始执行 T06 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Cat = cat_scene.instantiate()
	root.add_child(cat)
	
	var cmd_mgr := CommandManager.new()
	root.add_child(cmd_mgr)
	cmd_mgr.register_cat(cat)
	
	cat.ground_y = 300.0
	cat.position = Vector2(300.0, 300.0)
	cat.is_grounded = true

	# 测试 1: 地面起跳
	assert(cat.is_grounded == true, "初始应当在地面")
	cmd_mgr.send_command(CommandManager.CatCommand.JUMP)
	assert(cat.current_state == Cat.CatState.JUMP, "起跳后状态应为 JUMP")
	assert(cat.is_grounded == false, "起跳后 is_grounded 应为 false")
	assert(cat.vertical_velocity < 0.0, "起跳速度应为负数")
	print("[PASS] 测试 1: 地面起跳验证成功")

	# 测试 2: 空中防二段跳
	var v_before: float = cat.vertical_velocity
	cmd_mgr.send_command(CommandManager.CatCommand.JUMP)
	assert(cat.vertical_velocity == v_before, "空中再次发送 JUMP 不应被二次重置")
	print("[PASS] 测试 2: 空中防二段跳验证成功")

	# 测试 3: 最高点 JUMP -> FALL 切换
	cat.position.y = 200.0
	cat.vertical_velocity = 10.0
	cat.update_state(0.01)
	assert(cat.current_state == Cat.CatState.FALL, "垂直速度>=0时应切换为 FALL")
	assert(cat.is_grounded == false, "下落过程中应保持空中")
	print("[PASS] 测试 3: 最高点切换与空中下落验证成功")

	# 测试 4: 落地与 AUTO 模式恢复
	cat.vertical_velocity = 200.0
	cat.position.y = cat.ground_y
	cat.update_state(0.01)
	assert(cat.is_grounded == true, "落地后 is_grounded 应为 true")
	assert(cat.position.y == cat.ground_y, "落地后 position.y 应等于 ground_y")
	assert(cat.vertical_velocity == 0.0, "落地后 vertical_velocity 应为 0")
	assert(cat.current_state == Cat.CatState.WALK, "落地后应恢复 WALK")
	print("[PASS] 测试 4: 落地与恢复验证成功")

	# 测试 5: COMMAND WALK_LEFT 模式下的跳跃与落地恢复
	cmd_mgr.send_command(CommandManager.CatCommand.WALK_LEFT)
	cmd_mgr.send_command(CommandManager.CatCommand.JUMP)
	assert(cat.current_state == Cat.CatState.JUMP, "应进入 JUMP")
	cat.vertical_velocity = 200.0 # 模拟下落到达地面
	cat.position.y = cat.ground_y
	cat.update_state(0.01)
	assert(cat.current_state == Cat.CatState.WALK, "COMMAND模式落地应恢复 WALK")
	assert(cat.direction == -1.0, "朝向应保持向左")
	print("[PASS] 测试 5: COMMAND 模式跳跃与落地恢复验证成功")

	# 测试 6: 空中点击不破坏物理
	cmd_mgr.send_command(CommandManager.CatCommand.JUMP)
	var real_y: float = cat.position.y
	var real_v: float = cat.vertical_velocity
	cat._on_clicked()
	assert(cat.position.y == real_y, "点击不应修改真实的 position.y")
	assert(cat.vertical_velocity == real_v, "点击不应修改真实的 vertical_velocity")
	print("[PASS] 测试 6: 点击反馈与物理分离验证成功")

	cat.queue_free()
	cmd_mgr.queue_free()
	print("========== T06 垂直物理与跳跃系统所有单元测试全部通过 ==========")
	quit(0)
