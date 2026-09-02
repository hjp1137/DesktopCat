extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0

func _init() -> void:
	print("========== 开始执行 T05 主场景与Command系统集成测试 ==========")
	var scene_res = load("res://scenes/main.tscn")
	if not scene_res:
		printerr("无法加载主场景 res://scenes/main.tscn")
		quit(1)
		return
	main_scene = scene_res.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	elapsed_time += delta
	var cat: Node2D = main_scene.get_node_or_null("Cat")
	var cmd_mgr: CommandManager = main_scene.command_manager
	
	if step_idx == 0 and elapsed_time > 0.3:
		step_idx = 1
		print("========== 阶段 1: 模拟发送 WALK_LEFT 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.WALK_LEFT)
	
	elif step_idx == 1 and elapsed_time > 0.7:
		step_idx = 2
		print("========== 阶段 2: 模拟小猫点击交互 ==========")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = cat.position
		cat._unhandled_input(ev)

	elif step_idx == 2 and elapsed_time > 1.1:
		step_idx = 3
		print("========== 阶段 3: 模拟发送 STOP 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.STOP)

	elif step_idx == 3 and elapsed_time > 1.5:
		step_idx = 4
		print("========== 阶段 4: 模拟发送 RESUME_AUTO 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.RESUME_AUTO)
	
	elif step_idx == 4 and elapsed_time > 1.9:
		step_idx = 5
		print("========== 阶段 5: 模拟触发 ESC 按键事件安全退出 ==========")
		var ev_esc := InputEventKey.new()
		ev_esc.keycode = KEY_ESCAPE
		ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
