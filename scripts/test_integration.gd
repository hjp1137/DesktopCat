extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0
var tcp_client: StreamPeerTCP = null

func _init() -> void:
	print("========== 开始执行 T10 主场景与 ExternalBridge 集成测试 ==========")
	var scene_res = load("res://scenes/main.tscn")
	if not scene_res: printerr("无法加载主场景 res://scenes/main.tscn"); quit(1); return
	main_scene = scene_res.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	elapsed_time += delta
	if not is_instance_valid(main_scene) or not ("external_bridge" in main_scene) or not main_scene.external_bridge:
		return false
	
	if step_idx == 0 and elapsed_time > 0.2:
		step_idx = 1
		print("========== 阶段 1: 连接本地 Bridge 47831 ==========")
		tcp_client = StreamPeerTCP.new()
		var err := tcp_client.connect_to_host("127.0.0.1", 47831)
		if err != OK: printerr("无法连接 Bridge"); quit(1); return true

	elif step_idx == 1 and elapsed_time > 0.5:
		tcp_client.poll()
		if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			step_idx = 2
			print("========== 阶段 2: 验证连接成功并发送 PING ==========")
			tcp_client.put_data("{\"v\":1,\"type\":\"ping\"}\n".to_utf8_buffer())

	elif step_idx == 2 and elapsed_time > 0.9:
		step_idx = 3
		print("========== 阶段 3: 发送外部 JUMP 指令 ==========")
		tcp_client.put_data("{\"v\":1,\"type\":\"command\",\"name\":\"JUMP\",\"payload\":{}}\n".to_utf8_buffer())

	elif step_idx == 3 and elapsed_time > 1.4:
		step_idx = 4
		print("========== 阶段 4: 断开连接 ==========")
		tcp_client.disconnect_from_host()
		tcp_client = null

	elif step_idx == 4 and elapsed_time > 2.0:
		step_idx = 5
		print("========== 阶段 5: 触发 ESC 安全退出 ==========")
		var ev_esc := InputEventKey.new(); ev_esc.keycode = KEY_ESCAPE; ev_esc.pressed = true
		main_scene._unhandled_input(ev_esc)
		return true
	return false
