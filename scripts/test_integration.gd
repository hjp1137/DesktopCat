extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null

func _init() -> void:
	print("========== 开始执行 T02 主场景与ESC退出集成运行测试 ==========")
	var scene_res = load("res://scenes/main.tscn")
	if not scene_res:
		printerr("无法加载主场景 res://scenes/main.tscn")
		quit(1)
		return
	main_scene = scene_res.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	elapsed_time += delta
	var cat = main_scene.get_node_or_null("Cat")
	
	# 运行 1.5 秒后模拟发送 ESC 键以验证退出机制
	if elapsed_time > 1.5:
		print("========== 模拟触发 ESC 按键事件 ==========")
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = true
		main_scene._unhandled_input(ev)
		# 若成功调用 quit 则将退出
		return true
	return false
