extends SceneTree

const SurfaceClass = preload("res://scripts/world/surface.gd")
const SurfaceWorldModelClass = preload("res://scripts/world/surface_world_model.gd")

func _init() -> void:
	print("========== 开始执行 T12 Surface World 自动化自验证 ==========")
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

	# 测试 7: Surface 基础数据结构与屏幕表面
	var surf_model = SurfaceWorldModelClass.new()
	root.add_child(surf_model)
	surf_model.rebuild_from_windows({}, Vector2(1920, 1080), 1000.0)
	assert(surf_model.surfaces_by_id.has("screen:ground"), "应包含 screen:ground")
	assert(surf_model.surfaces_by_id.has("screen:left"), "应包含 screen:left")
	assert(surf_model.surfaces_by_id.has("screen:right"), "应包含 screen:right")
	assert(surf_model.surfaces_by_id.has("screen:top"), "应包含 screen:top")
	var g_surf = surf_model.get_surface_by_id("screen:ground")
	assert(g_surf.walkable == true and g_surf.dynamic == false and g_surf.y1 == 1000.0, "地面属性正确")
	print("[PASS] 测试 7: 屏幕边界表面创建与属性正确")

	# 测试 8: 单窗口转换为 4 条 Surface 与稳定 ID
	var mock_windows = {
		"winA": {"id": "winA", "rect": Rect2(100, 100, 400, 300), "z_order": 0}
	}
	surf_model.rebuild_from_windows(mock_windows, Vector2(1920, 1080), 1000.0)
	assert(surf_model.surfaces_by_id.has("winA:top"), "应有 winA:top")
	assert(surf_model.surfaces_by_id.has("winA:bottom"), "应有 winA:bottom")
	assert(surf_model.surfaces_by_id.has("winA:left"), "应有 winA:left")
	assert(surf_model.surfaces_by_id.has("winA:right"), "应有 winA:right")
	var top_surf = surf_model.get_surface_by_id("winA:top")
	assert(top_surf.walkable == true and top_surf.dynamic == true, "窗口顶边应当可站立且为动态")
	print("[PASS] 测试 8: 窗口转 4 条 Surface 及稳定 ID 验证成功")

	# 测试 9: 顶边遮挡切分与全遮挡剔除
	var occluded_windows = {
		"winA": {"id": "winA", "rect": Rect2(100, 100, 600, 400), "z_order": 1},
		"winB": {"id": "winB", "rect": Rect2(250, 50, 200, 300), "z_order": 0}
	}
	surf_model.rebuild_from_windows(occluded_windows, Vector2(1920, 1080), 1000.0)
	assert(surf_model.surfaces_by_id.has("winA:top:0") and surf_model.surfaces_by_id.has("winA:top:1"), "winA 顶边应当被切分为两个子平台")
	var p0 = surf_model.get_surface_by_id("winA:top:0")
	var p1 = surf_model.get_surface_by_id("winA:top:1")
	assert(abs(p0.x1 - 100.0) < 0.5 and abs(p0.x2 - 250.0) < 0.5, "子平台 0 坐标正确")
	assert(abs(p1.x1 - 450.0) < 0.5 and abs(p1.x2 - 700.0) < 0.5, "子平台 1 坐标正确")
	
	# 完全遮挡
	var fully_occluded = {
		"winA": {"id": "winA", "rect": Rect2(100, 100, 200, 200), "z_order": 1},
		"winB": {"id": "winB", "rect": Rect2(50, 50, 300, 300), "z_order": 0}
	}
	surf_model.rebuild_from_windows(fully_occluded, Vector2(1920, 1080), 1000.0)
	assert(not surf_model.surfaces_by_id.has("winA:top") and not surf_model.surfaces_by_id.has("winA:top:0"), "完全遮挡时可站立顶边应当消失")
	print("[PASS] 测试 9: 顶边遮挡切分与全遮挡剔除验证成功")


	# 测试 10: 最小可用长度过滤与空间查询 API
	var small_win = {
		"small": {"id": "small", "rect": Rect2(100, 100, 30, 30), "z_order": 0}
	}
	surf_model.rebuild_from_windows(small_win, Vector2(1920, 1080), 1000.0)
	assert(not surf_model.surfaces_by_id.has("small:top") and not surf_model.surfaces_by_id.has("small:left"), "小于 48px 窗口边不生成 Surface")
	
	var all_s = surf_model.get_all_surfaces()
	var walk_s = surf_model.get_walkable_surfaces()
	var walls = surf_model.get_walls()
	assert(all_s.size() >= 4 and walk_s.size() >= 1 and walls.size() >= 2, "查询 API 结果正常")
	var near_ground = surf_model.get_walkable_surfaces_near_y(1000.0, 5.0)
	assert(near_ground.size() == 1 and near_ground[0].id == "screen:ground", "near_y 空间查询正确")
	print("[PASS] 测试 10: 最小长度过滤与空间查询 API 验证成功")

	surf_model.queue_free()
	bridge.stop_server(); bridge.queue_free()
	world_model.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T12 Surface World 所有单元测试全部通过 ==========")
	quit(0)

