extends SceneTree

var elapsed_time: float = 0.0
var main_scene: Node = null
var step_idx: int = 0
var tcp_client: StreamPeerTCP = null

func _init() -> void:
	print("========== 开始执行 T11 主场景与 WindowWorldModel 集成测试 ==========")
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
		print("========== 阶段 3: 发送 window_snapshot, ui_snapshot 与 visual_snapshot 快照 ==========")
		var snap_str := "{\"v\":1,\"type\":\"window_snapshot\",\"revision\":1,\"screen\":{\"index\":0,\"width\":1920,\"height\":1080},\"windows\":[{\"id\":\"0x30094\",\"title\":\"Chrome\",\"x\":200.0,\"y\":150.0,\"width\":1000.0,\"height\":700.0,\"is_foreground\":true,\"z_order\":0}]}\n"
		tcp_client.put_data(snap_str.to_utf8_buffer())
		var ui_snap_str := "{\"v\":1,\"type\":\"ui_snapshot\",\"revision\":1,\"screen\":{\"index\":0,\"width\":1920,\"height\":1080},\"elements\":[{\"id\":\"0x30094:btn1\",\"window_id\":\"0x30094\",\"control_type\":\"Button\",\"x\":250.0,\"y\":160.0,\"width\":90.0,\"height\":32.0}]}\n"
		tcp_client.put_data(ui_snap_str.to_utf8_buffer())
		var vis_snap_str := "{\"v\":1,\"type\":\"visual_snapshot\",\"revision\":1,\"screen\":{\"index\":0,\"width\":1920,\"height\":1080},\"geometries\":[{\"id\":\"vg_lh_1\",\"type\":\"LINE\",\"orientation\":\"HORIZONTAL\",\"x1\":200.0,\"y1\":250.0,\"x2\":600.0,\"y2\":250.0}]}\n"
		tcp_client.put_data(vis_snap_str.to_utf8_buffer())

	elif step_idx == 3 and elapsed_time > 1.3:
		step_idx = 4
		print("========== 阶段 4: 验证 WindowWorldModel、SurfaceWorldModel、UIElementWorldModel 与 VisualWorldModel 同步 ==========")
		assert(main_scene.surface_world_model.surfaces_by_id.has("0x30094:top"), "SurfaceWorldModel 应生成 0x30094:top")
		assert(main_scene.surface_world_model.surfaces_by_id.has("screen:ground"), "SurfaceWorldModel 应生成 screen:ground")
		assert(main_scene.ui_element_world_model.elements_by_id.has("0x30094:btn1"), "UIElementWorldModel 应生成 0x30094:btn1")
		assert(main_scene.visual_world_model.geometries_by_id.has("vg_lh_1"), "VisualWorldModel 应生成 vg_lh_1")
		print("========== 阶段 4b: 触发 F8、F9、F10、F11 与 F12 切换 Debug 绘制 ==========")
		var ev_f8 := InputEventKey.new(); ev_f8.keycode = KEY_F8; ev_f8.pressed = true
		main_scene._input(ev_f8)
		assert(main_scene.window_world_model.debug_draw_enabled == true, "F8 应成功开启 Window Debug")
		var ev_f9 := InputEventKey.new(); ev_f9.keycode = KEY_F9; ev_f9.pressed = true
		main_scene._input(ev_f9)
		assert(main_scene.surface_world_model.debug_draw_enabled == true, "F9 应成功开启 Surface Debug")
		var ev_f10 := InputEventKey.new(); ev_f10.keycode = KEY_F10; ev_f10.pressed = true
		main_scene._input(ev_f10)
		assert(main_scene.cat.physics_debug_enabled == true, "F10 应成功开启 Physics Debug")
		var ev_f11 := InputEventKey.new(); ev_f11.keycode = KEY_F11; ev_f11.pressed = true
		main_scene._input(ev_f11)
		assert(main_scene.ui_element_world_model.debug_draw_enabled == true, "F11 应成功开启 UI Debug")
		var ev_f12 := InputEventKey.new(); ev_f12.keycode = KEY_F12; ev_f12.pressed = true
		main_scene._input(ev_f12)
		assert(main_scene.visual_world_model.debug_draw_enabled == true, "F12 应成功开启 Visual Debug")

		print("========== 阶段 4c: 验证小猫下落着陆到 Chrome 顶边 ==========")
		main_scene.cat.position = Vector2(400.0, 100.0)
		main_scene.cat.vertical_velocity = 800.0


		main_scene.cat.is_grounded = false
		main_scene.cat.change_state(Cat.CatState.FALL)

	elif step_idx == 4 and elapsed_time > 1.7:
		step_idx = 5
		assert(main_scene.cat.is_grounded == true, "小猫下落后应当着陆")
		assert(main_scene.cat.current_surface_id == "0x30094:top", "应当着陆在 Chrome 顶边 0x30094:top")
		assert(absf(main_scene.cat.position.y - 150.0) < 0.5, "着陆点 Y 坐标应与 Chrome 顶边 150 一致")
		print("========== 阶段 5: 断开连接 ==========")
		tcp_client.disconnect_from_host()
		tcp_client = null

	elif step_idx == 5 and elapsed_time > 2.2:
		step_idx = 6
		print("========== 阶段 6: 触发 ESC 安全退出 ==========")
		var ev_esc := InputEventKey.new(); ev_esc.keycode = KEY_ESCAPE; ev_esc.pressed = true
		main_scene._input(ev_esc)
		return true
	return false


