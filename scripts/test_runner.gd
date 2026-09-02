extends SceneTree

func _init() -> void:
	print("========== 开始执行 T08 自动化自验证 ==========")
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

	# 测试 1: RUN 指令与速度验证
	assert(cat.run_speed > cat.walk_speed, "run_speed 应显著大于 walk_speed")
	cmd_mgr.send_command(CommandManager.CatCommand.RUN_LEFT)
	assert(cat.current_state == Cat.CatState.RUN, "应进入 RUN 状态")
	assert(cat.direction == -1.0, "朝向应向左")
	print("[PASS] 测试 1: RUN 指令验证成功")

	# 测试 2: SIT 指令验证
	cmd_mgr.send_command(CommandManager.CatCommand.SIT)
	assert(cat.current_state == Cat.CatState.SIT, "应进入 SIT 状态")
	print("[PASS] 测试 2: SIT 指令验证成功")

	# 测试 3: SLEEP 与 WAKE 指令验证
	cmd_mgr.send_command(CommandManager.CatCommand.SLEEP)
	assert(cat.current_state == Cat.CatState.SLEEP, "应进入 SLEEP 状态")
	cmd_mgr.send_command(CommandManager.CatCommand.WAKE)
	assert(cat.current_state == Cat.CatState.IDLE, "唤醒后应进入 IDLE 状态")
	print("[PASS] 测试 3: SLEEP 与 WAKE 指令验证成功")

	# 测试 4: 睡眠状态收到 JUMP (唤醒并起跳)
	cmd_mgr.send_command(CommandManager.CatCommand.SLEEP)
	cmd_mgr.send_command(CommandManager.CatCommand.JUMP)
	assert(cat.current_state == Cat.CatState.JUMP, "睡眠中 JUMP 应自动唤醒并起跳")
	assert(cat.is_grounded == false, "起跳后应在空中")
	print("[PASS] 测试 4: 睡眠中 JUMP 自动唤醒起跳验证成功")

	# 测试 5: 睡眠状态被 Drag 抓取
	cat.position.y = cat.ground_y
	cat.update_state(0.01) # 触发落地
	cmd_mgr.send_command(CommandManager.CatCommand.SLEEP)
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, {"mouse_pos": cat.position})
	assert(cat.current_state == Cat.CatState.DRAG, "应进入 DRAG 状态")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, {"throw_velocity": Vector2.ZERO})
	cat.vertical_velocity = 200.0
	cat.position.y = cat.ground_y
	cat.update_state(0.01) # 触发落地
	assert(cat.current_state == Cat.CatState.IDLE, "被抓起打断睡眠后落地应恢复 IDLE")
	assert(cat.sleep_cooldown > 0.0, "打断睡眠后应进入 sleep_cooldown")
	print("[PASS] 测试 5: 睡眠中 Drag 打断与落地恢复验证成功")

	# 测试 6: 自主调度器状态转移
	cat.current_mode = Cat.ControlMode.AUTO
	cat.current_state = Cat.CatState.IDLE
	cat.state_timer = 0.0
	cat._schedule_next_auto_state()
	assert(cat.current_state in [Cat.CatState.WALK, Cat.CatState.SIT, Cat.CatState.RUN, Cat.CatState.IDLE, Cat.CatState.SLEEP], "调度器应切换至合法生活状态")
	print("[PASS] 测试 6: 自主生活行为调度器验证成功")

	cat.queue_free()
	cmd_mgr.queue_free()
	print("========== T08 生活行为系统所有单元测试全部通过 ==========")
	quit(0)
