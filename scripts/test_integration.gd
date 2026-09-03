extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0

func _init() -> void:
	print("========== 开始执行 T09 主场景指针感知与目标移动集成测试 ==========")
	var scene_res = load("res://scenes/main.tscn")
	if not scene_res: printerr("无法加载主场景 res://scenes/main.tscn"); quit(1); return
	main_scene = scene_res.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	elapsed_time += delta
	if not is_instance_valid(main_scene) or not ("command_manager" in main_scene) or not main_scene.command_manager:
		return false
	var cat: Node2D = main_scene.get_node_or_null("Cat")
	var cmd_mgr: CommandManager = main_scene.command_manager
	
	if step_idx == 0 and elapsed_time > 0.2:
		step_idx = 1
		print("========== 阶段 1: 模拟发送 LOOK_AT_POSITION 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": cat.position + Vector2(200.0, 0.0)})

	elif step_idx == 1 and elapsed_time > 0.6:
		step_idx = 2
		print("========== 阶段 2: 模拟触发 C 按键开启 Debug Follow 模式 ==========")
		var ev_c := InputEventKey.new(); ev_c.keycode = KEY_C; ev_c.pressed = true
		main_scene._unhandled_input(ev_c)

	elif step_idx == 2 and elapsed_time > 1.2:
		step_idx = 3
		print("========== 阶段 3: 模拟触发 C 按键关闭 Debug Follow 并恢复 AUTO ==========")
		var ev_c := InputEventKey.new(); ev_c.keycode = KEY_C; ev_c.pressed = true
		main_scene._unhandled_input(ev_c)

	elif step_idx == 3 and elapsed_time > 2.0:
		step_idx = 4
		print("========== 阶段 4: 模拟触发 ESC 按键安全退出 ==========")
		var ev_esc := InputEventKey.new(); ev_esc.keycode = KEY_ESCAPE; ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
