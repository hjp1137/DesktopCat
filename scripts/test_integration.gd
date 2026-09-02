extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var clicked_tested: bool = false

func _init() -> void:
	print("========== 开始执行 T04 主场景与动画集成测试 ==========")
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
	
	# 运行 0.5 秒后模拟鼠标点击 Cat 所在坐标
	if not clicked_tested and elapsed_time > 0.5 and cat:
		clicked_tested = true
		print("========== 模拟向小猫发送鼠标左键点击事件 ==========")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = cat.position
		cat._unhandled_input(ev)
	
	# 运行 1.8 秒后模拟发送 ESC 键以验证退出机制
	if elapsed_time > 1.8:
		print("========== 模拟触发 ESC 按键事件 ==========")
		var ev_esc := InputEventKey.new()
		ev_esc.keycode = KEY_ESCAPE
		ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
