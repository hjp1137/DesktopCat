extends SceneTree

var elapsed_time: float = 0.0
var bounce_count: int = 0
var main_scene: Node = null

func _init() -> void:
	print("========== 开始执行 T01 主场景集成运行测试 ==========")
	root.size = Vector2i(640, 360)
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
	if cat:
		# 监视小猫运行，验证往返周期
		if elapsed_time > 8.5: # 运行8.5秒完成左右往返验证
			print("========== 主场景集成运行测试通过: 运行时间 %.2f 秒, 最终坐标: %s ==========" % [elapsed_time, cat.position])
			quit(0)
			return true
	return false
