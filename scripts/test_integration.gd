extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0

func _init() -> void:
	print("========== 开始执行 T07 主场景拖拽与抛掷集成测试 ==========")
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
	var mouse_ctrl: MouseController = main_scene.mouse_controller
	
	if step_idx == 0 and elapsed_time > 0.2:
		step_idx = 1
		print("========== 阶段 1: 模拟在 Cat 区域单击交互 ==========")
		var ev_down := InputEventMouseButton.new()
		ev_down.button_index = MOUSE_BUTTON_LEFT
		ev_down.pressed = true
		ev_down.position = cat.position
		mouse_ctrl._unhandled_input(ev_down)
		
		var ev_up := InputEventMouseButton.new()
		ev_up.button_index = MOUSE_BUTTON_LEFT
		ev_up.pressed = false
		ev_up.position = cat.position
		mouse_ctrl._unhandled_input(ev_up)

	elif step_idx == 1 and elapsed_time > 0.6:
		step_idx = 2
		print("========== 阶段 2: 模拟开始拖拽并移动小猫 ==========")
		var ev_down := InputEventMouseButton.new()
		ev_down.button_index = MOUSE_BUTTON_LEFT
		ev_down.pressed = true
		ev_down.position = cat.position
		mouse_ctrl._unhandled_input(ev_down)
		
		var ev_move := InputEventMouseMotion.new()
		ev_move.position = cat.position + Vector2(60.0, -100.0)
		mouse_ctrl._unhandled_input(ev_move)

	elif step_idx == 2 and elapsed_time > 1.0:
		step_idx = 3
		print("========== 阶段 3: 模拟向右上方甩动鼠标并释放 (Throw) ==========")
		var ev_move := InputEventMouseMotion.new()
		ev_move.position = cat.position + Vector2(120.0, -160.0)
		mouse_ctrl._unhandled_input(ev_move)
		
		var ev_up := InputEventMouseButton.new()
		ev_up.button_index = MOUSE_BUTTON_LEFT
		ev_up.pressed = false
		ev_up.position = cat.position + Vector2(120.0, -160.0)
		mouse_ctrl._unhandled_input(ev_up)

	elif step_idx == 3 and elapsed_time > 2.2:
		step_idx = 4
		print("========== 阶段 4: 模拟触发 ESC 按键安全退出 ==========")
		var ev_esc := InputEventKey.new()
		ev_esc.keycode = KEY_ESCAPE
		ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
