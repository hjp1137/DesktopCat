extends SceneTree

func _init() -> void:
	print("========== 开始执行 T11 Window Geometry 自动化自验证 ==========")
	var cat_scene: PackedScene = load("res://scenes/cat.tscn")
	assert(cat_scene != null, "应当能够加载 scenes/cat.tscn")
	var cat: Cat = cat_scene.instantiate()
	root.add_child(cat)
	var cmd_mgr := CommandManager.new()
	root.add_child(cmd_mgr); cmd_mgr.register_cat(cat)
	cat.ground_y = 300.0; cat.position = Vector2(300.0, 300.0); cat.is_grounded = true

	var world_model := WindowWorldModel.new()
	root.add_child(world_model)

	var bridge := ExternalBridge.new()
	bridge.command_manager = cmd_mgr; bridge.cat = cat
	bridge.window_world_model = world_model
	bridge.start_server(47839) # 测试端口
	assert(bridge.server != null and bridge.server.is_listening(), "Bridge 应成功监听 127.0.0.1:47839")
	print("[PASS] 测试 1: ExternalBridge 本地服务监听成功")

	# 测试 2: 畸形数据与非法命令拦截
	bridge._handle_raw_message("{invalid_json: true")
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"FLY_TO_MOON\"}")
	assert(cat.current_state != Cat.CatState.JUMP, "非法命令不应触发状态变更")
	print("[PASS] 测试 2: 畸形数据与非法命令拦截成功")

	# 测试 3: 标准指令分发
	bridge._handle_raw_message("{\"v\": 1, \"type\": \"command\", \"name\": \"SIT\"}")
	assert(cat.current_state == Cat.CatState.SIT, "SIT 指令应正确执行")
	print("[PASS] 测试 3: 标准指令分发成功")

	# 测试 4: WindowWorldModel 基础操作与 Debug 切换
	assert(world_model.debug_draw_enabled == false, "Debug 默认应为关闭状态")
	var dbg_on = world_model.toggle_debug_draw()
	assert(dbg_on == true and world_model.debug_draw_enabled == true, "F8 应能开启 Debug 渲染")
	world_model.toggle_debug_draw()
	assert(world_model.debug_draw_enabled == false, "再次触发应关闭 Debug 渲染")
	print("[PASS] 测试 4: WindowWorldModel 调试线框开关正常")

	# 测试 5: window_snapshot 协议校验与存储
	var bad_snap = "{\"v\": 1, \"type\": \"window_snapshot\", \"revision\": 1, \"windows\": [{\"id\": \"0x1\", \"x\": \"invalid\"}]}"
	bridge._handle_raw_message(bad_snap)
	assert(world_model.windows_by_id.is_empty(), "非法窗口几何应当被拒绝")

	var valid_snap = "{\"v\": 1, \"type\": \"window_snapshot\", \"revision\": 1, \"windows\": [{\"id\": \"0x30094\", \"title\": \"Chrome\", \"x\": 100.0, \"y\": 50.0, \"width\": 800.0, \"height\": 600.0, \"is_foreground\": true, \"z_order\": 0}]}"
	bridge._handle_raw_message(valid_snap)
	assert(world_model.windows_by_id.has("0x30094"), "有效快照应当成功存入世界模型")
	assert(world_model.latest_revision == 1, "快照版本应当为 1")
	var win_data = world_model.windows_by_id["0x30094"]
	assert(win_data.rect.size.x == 800.0 and win_data.is_foreground == true, "几何尺寸与前台状态解析正确")

	# 测试 6: 旧版本快照防护
	var old_snap = "{\"v\": 1, \"type\": \"window_snapshot\", \"revision\": 1, \"windows\": []}"
	var applied = world_model.apply_snapshot({"revision": 1, "windows": []})
	assert(applied == false, "不应被旧的或相同的 revision 覆盖")
	print("[PASS] 测试 5/6: window_snapshot 校验、存储与版本防倒退验证成功")

	bridge.stop_server(); bridge.queue_free()
	world_model.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T11 Window Geometry 所有单元测试全部通过 ==========")
	quit(0)
