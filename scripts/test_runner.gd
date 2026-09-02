extends SceneTree

func _init() -> void:
	print("========== 开始执行 T07 自动化自验证 ==========")
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

	# 测试 1: DRAG_START 与抓取偏移保持
	var mouse_p := Vector2(310.0, 290.0)
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, {"mouse_pos": mouse_p})
	assert(cat.current_state == Cat.CatState.DRAG, "应进入 DRAG 状态")
	assert(cat.is_grounded == false, "拖拽中 is_grounded 应为 false")
	assert(cat.drag_offset == Vector2(-10.0, 10.0), "drag_offset 应保持相对偏移")
	print("[PASS] 测试 1: DRAG_START 与 drag_offset 验证成功")

	# 测试 2: DRAG_MOVE 平滑跟随
	var move_p := Vector2(400.0, 150.0)
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_MOVE, {"mouse_pos": move_p})
	assert(cat.position == move_p + Vector2(-10.0, 10.0), "Cat 坐标应跟随鼠标与偏移")
	print("[PASS] 测试 2: DRAG_MOVE 坐标跟随验证成功")

	# 测试 3: DRAG 期间指令忽略保护
	cmd_mgr.send_command(CommandManager.CatCommand.STOP)
	assert(cat.current_state == Cat.CatState.DRAG, "DRAG 期间外部指令不应打断拖拽")
	print("[PASS] 测试 3: DRAG 期间指令忽略保护验证成功")

	# 测试 4: 慢速释放 (Drop) 自由落体与落地恢复
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, {"throw_velocity": Vector2.ZERO})
	assert(cat.current_state == Cat.CatState.FALL, "空中慢速释放应进入 FALL")
	cat.vertical_velocity = 200.0
	cat.position.y = cat.ground_y
	cat.update_state(0.01)
	assert(cat.is_grounded == true, "落地后 is_grounded 应为 true")
	assert(cat.current_state == Cat.CatState.WALK, "落地后应恢复 AUTO WALK")
	print("[PASS] 测试 4: 慢速释放落体与落地恢复验证成功")

	# 测试 5: 快速右上抛掷 (Throw) 抛物线与边界反弹
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, {"mouse_pos": cat.position})
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, {"throw_velocity": Vector2(800.0, -400.0)})
	assert(cat.current_state == Cat.CatState.JUMP, "向上抛掷应进入 JUMP")
	assert(cat.horizontal_throw_speed == 800.0, "水平抛掷速度应正确生效")
	assert(cat.direction == 1.0, "朝向应向右")
	
	# 模拟撞到右边界
	cat.position.x = 640.0
	cat.update_state(0.01)
	assert(cat.horizontal_throw_speed < 0.0, "碰右边界后水平速度应反向")
	assert(cat.direction == -1.0, "朝向应转为向左")
	print("[PASS] 测试 5: 抛掷抛物线与边界反弹验证成功")

	# 测试 6: 顶部边界限制保护
	cat.position.y = 20.0
	cat.vertical_velocity = -300.0
	cat.update_state(0.01)
	assert(cat.position.y >= 30.0, "顶部不应飞出屏幕")
	assert(cat.vertical_velocity >= 0.0, "到达顶部后垂直速度应转为向下")
	print("[PASS] 测试 6: 顶部边界安全保护验证成功")

	cat.queue_free()
	cmd_mgr.queue_free()
	print("========== T07 鼠标拖拽与抛掷交互系统所有单元测试全部通过 ==========")
	quit(0)
