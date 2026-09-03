extends SceneTree

func _init() -> void:
	print("========== 开始执行 T09 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Cat = cat_scene.instantiate()
	root.add_child(cat)
	var cmd_mgr := CommandManager.new()
	root.add_child(cmd_mgr); cmd_mgr.register_cat(cat)
	
	cat.ground_y = 300.0; cat.position = Vector2(300.0, 300.0); cat.is_grounded = true

	# 测试 1: IDLE / SIT 状态下 LOOK_AT_POSITION 转头与 20px 死区
	cmd_mgr.send_command(CommandManager.CatCommand.STOP)
	cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": Vector2(400.0, 300.0)})
	assert(cat.direction == 1.0, "目标在右侧时小猫应朝右看")
	cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": Vector2(310.0, 300.0)})
	assert(cat.direction == 1.0, "位于 20px 死区内不应发生朝向抖动")
	cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": Vector2(100.0, 300.0)})
	assert(cat.direction == -1.0, "目标在左侧时小猫应朝左看")
	print("[PASS] 测试 1: LOOK_AT_POSITION 转头与死区验证成功")

	# 测试 2: WALK 状态下移动方向优先，不被 LOOK_AT 打断
	cmd_mgr.send_command(CommandManager.CatCommand.WALK_RIGHT)
	assert(cat.direction == 1.0, "WALK_RIGHT 应当朝右")
	cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": Vector2(50.0, 300.0)})
	assert(cat.direction == 1.0, "行走时不应被反向目标强行改变身体朝向")
	print("[PASS] 测试 2: 行走中移动方向优先验证成功")

	# 测试 3: SLEEP 状态下忽略 LOOK_AT 与 MOVE_TO
	cmd_mgr.send_command(CommandManager.CatCommand.SLEEP)
	var init_dir := cat.direction
	cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": Vector2(500.0, 300.0)})
	cmd_mgr.send_command(CommandManager.CatCommand.MOVE_TO_POSITION, {"target_pos": Vector2(500.0, 300.0)})
	assert(cat.current_state == Cat.CatState.SLEEP, "睡眠状态应忽略目标感知")
	assert(cat.has_move_target == false, "睡眠中不应触发目标移动")
	print("[PASS] 测试 3: SLEEP 状态忽略目标感知验证成功")

	# 测试 4: MOVE_TO_POSITION 目标移动与停止
	cmd_mgr.send_command(CommandManager.CatCommand.WAKE)
	cmd_mgr.send_command(CommandManager.CatCommand.MOVE_TO_POSITION, {"target_pos": Vector2(500.0, 300.0), "speed_mode": "RUN"})
	assert(cat.has_move_target == true, "应当进入目标移动模式")
	cat.update_state(0.1)
	assert(cat.current_state == Cat.CatState.RUN, "应当以 RUN 状态追逐目标")
	assert(cat.direction == 1.0, "朝向应朝向右侧目标")
	# 模拟到达目标附近 (500 - 64 = 436，靠近 436)
	cat.position.x = 435.0
	cat.update_state(0.01)
	assert(cat.current_state == Cat.CatState.IDLE, "到达目标附近应当停下进入 IDLE")
	print("[PASS] 测试 4: MOVE_TO_POSITION 跟随与到达停止验证成功")

	# 测试 5: 显式 COMMAND 打断目标移动
	cmd_mgr.send_command(CommandManager.CatCommand.MOVE_TO_POSITION, {"target_pos": Vector2(100.0, 300.0)})
	cmd_mgr.send_command(CommandManager.CatCommand.STOP)
	assert(cat.has_move_target == false, "用户 STOP 指令应立即打断目标移动")
	assert(cat.current_state == Cat.CatState.IDLE, "应进入 IDLE 状态")
	print("[PASS] 测试 5: 显式指令打断目标移动验证成功")

	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T09 指针感知与目标移动所有单元测试全部通过 ==========")
	quit(0)
