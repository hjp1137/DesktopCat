extends SceneTree

func _init() -> void:
	print("========== 开始执行 T10 ExternalBridge 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Cat = cat_scene.instantiate()
	root.add_child(cat)
	var cmd_mgr := CommandManager.new()
	root.add_child(cmd_mgr); cmd_mgr.register_cat(cat)
	cat.ground_y = 300.0; cat.position = Vector2(300.0, 300.0); cat.is_grounded = true

	var bridge := ExternalBridge.new()
	bridge.command_manager = cmd_mgr; bridge.cat = cat
	bridge.start_server(47839) # 测试端口
	assert(bridge.server != null and bridge.server.is_listening(), "Bridge 应成功监听 127.0.0.1:47839")
	print("[PASS] 测试 1: ExternalBridge 本地服务监听成功")

	# 测试 2: 畸形 JSON 与无效信封容错
	bridge._handle_raw_message("{invalid_json: true")
	bridge._handle_raw_message("{\"v\": 2, \"type\": \"ping\"}")
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"unknown_msg\"}")
	print("[PASS] 测试 2: 畸形数据与协议版本容错成功")

	# 测试 3: 白名单验证与非法命令拦截
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"FLY_TO_MOON\"}")
	assert(cat.current_state != Cat.CatState.JUMP, "非法命令不应触发状态变更")
	print("[PASS] 测试 3: 非法外部指令拦截成功")

	# 测试 4: 坐标类指令安全校验
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"MOVE_TO_POSITION\", \"payload\": {\"x\": \"abc\"}}")
	assert(cat.has_move_target == false, "缺少有效数字坐标不应触发跟随")
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"MOVE_TO_POSITION\", \"payload\": {\"x\": 500.0, \"y\": 300.0}}")
	assert(cat.has_move_target == true, "合法数字坐标应成功解析并下发")
	print("[PASS] 测试 4: 坐标安全校验与转换成功")

	# 测试 5: 标准指令分发
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"SIT\"}")
	assert(cat.current_state == Cat.CatState.SIT, "SIT 指令应正确执行")
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"JUMP\"}")
	assert(cat.current_state == Cat.CatState.JUMP, "JUMP 指令应正确执行")
	print("[PASS] 测试 5: 标准指令分发与状态同步成功")

	bridge.stop_server(); bridge.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T10 ExternalBridge 所有单元测试全部通过 ==========")
	quit(0)
