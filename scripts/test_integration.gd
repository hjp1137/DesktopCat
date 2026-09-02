extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0

func _init() -> void:
	print("========== 开始执行 T08 主场景生活行为系统集成测试 ==========")
	var scene_res = load("res://scenes/main.tscn")
	if not scene_res: printerr("无法加载主场景 res://scenes/main.tscn"); quit(1); return
	main_scene = scene_res.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	elapsed_time += delta
	var cmd_mgr: CommandManager = main_scene.command_manager
	
	if step_idx == 0 and elapsed_time > 0.2:
		step_idx = 1
		print("========== 阶段 1: 模拟发送 RUN_RIGHT 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.RUN_RIGHT)

	elif step_idx == 1 and elapsed_time > 0.5:
		step_idx = 2
		print("========== 阶段 2: 模拟在 RUN 中发送 JUMP 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.JUMP)

	elif step_idx == 2 and elapsed_time > 1.3:
		step_idx = 3
		print("========== 阶段 3: 模拟发送 SIT 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.SIT)

	elif step_idx == 3 and elapsed_time > 1.7:
		step_idx = 4
		print("========== 阶段 4: 模拟发送 SLEEP 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.SLEEP)

	elif step_idx == 4 and elapsed_time > 2.1:
		step_idx = 5
		print("========== 阶段 5: 模拟发送 WAKE 指令 ==========")
		cmd_mgr.send_command(CommandManager.CatCommand.WAKE)

	elif step_idx == 5 and elapsed_time > 2.5:
		step_idx = 6
		print("========== 阶段 6: 模拟触发 ESC 按键安全退出 ==========")
		var ev_esc := InputEventKey.new()
		ev_esc.keycode = KEY_ESCAPE
		ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
