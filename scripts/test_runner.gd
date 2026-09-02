extends SceneTree

func _init() -> void:
	print("========== 开始执行 T05 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Node2D = cat_scene.instantiate()
	root.add_child(cat)
	
	var cmd_mgr := CommandManager.new()
	root.add_child(cmd_mgr)
	cmd_mgr.register_cat(cat)
	
	# 测试 1: 默认 AUTO 模式
	assert(cat.current_mode == Cat.ControlMode.AUTO, "初始模式应当为 AUTO")
	print("[PASS] 测试 1: 初始 AUTO 模式验证成功")

	# 测试 2: STOP 命令测试
	cmd_mgr.send_command(CommandManager.CatCommand.STOP)
	assert(cat.current_mode == Cat.ControlMode.COMMAND, "执行 STOP 后应进入 COMMAND 模式")
	assert(cat.current_state == Cat.CatState.IDLE, "执行 STOP 后状态应为 IDLE")
	print("[PASS] 测试 2: STOP 指令测试成功")

	# 测试 3: WALK_LEFT 命令测试
	cmd_mgr.send_command(CommandManager.CatCommand.WALK_LEFT)
	assert(cat.current_mode == Cat.ControlMode.COMMAND, "执行 WALK_LEFT 应保持 COMMAND 模式")
	assert(cat.current_state == Cat.CatState.WALK, "状态应为 WALK")
	assert(cat.direction == -1.0, "朝向应为左 (-1.0)")
	assert(cat._get_animated_sprite().flip_h == true, "flip_h 应为 true")
	print("[PASS] 测试 3: WALK_LEFT 指令测试成功")

	# 测试 4: WALK_RIGHT 命令测试
	cmd_mgr.send_command(CommandManager.CatCommand.WALK_RIGHT)
	assert(cat.current_mode == Cat.ControlMode.COMMAND, "执行 WALK_RIGHT 应保持 COMMAND 模式")
	assert(cat.current_state == Cat.CatState.WALK, "状态应为 WALK")
	assert(cat.direction == 1.0, "朝向应为右 (1.0)")
	assert(cat._get_animated_sprite().flip_h == false, "flip_h 应为 false")
	print("[PASS] 测试 4: WALK_RIGHT 指令测试成功")

	# 测试 5: RESUME_AUTO 命令测试
	cmd_mgr.send_command(CommandManager.CatCommand.RESUME_AUTO)
	assert(cat.current_mode == Cat.ControlMode.AUTO, "执行 RESUME_AUTO 后应恢复 AUTO 模式")
	print("[PASS] 测试 5: RESUME_AUTO 指令测试成功")

	# 测试 6: 点击不破坏状态与模式
	cmd_mgr.send_command(CommandManager.CatCommand.WALK_LEFT)
	cat._on_clicked()
	assert(cat.current_mode == Cat.ControlMode.COMMAND, "点击后不应改变模式")
	assert(cat.current_state == Cat.CatState.WALK, "点击后不应改变状态")
	assert(cat.direction == -1.0, "点击后不应改变方向")
	print("[PASS] 测试 6: 点击不干扰命令与状态机验证成功")

	cat.queue_free()
	cmd_mgr.queue_free()
	print("========== T05 状态机与命令系统所有单元测试全部通过 ==========")
	quit(0)
