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

	# ========== T13 Multi-Surface Cat Physics 单元测试 ==========
	cat.surface_world_model = surf_model
	surf_model.surface_world_updated.connect(cat.on_surface_world_updated)

	# 测试 11: 窗口顶边着陆与 Swept Landing
	var test_win = {
		"win1": {"id": "win1", "rect": Rect2(100, 200, 400, 300), "z_order": 0}
	}
	surf_model.rebuild_from_windows(test_win, Vector2(1920, 1080), 1000.0)
	cat.position = Vector2(300.0, 180.0)
	cat.vertical_velocity = 300.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.1)
	assert(cat.is_grounded == true, "小猫应当成功着陆在窗口顶边")
	assert(cat.current_surface_id == "win1:top", "着陆表面应为 win1:top")
	assert(absf(cat.position.y - 200.0) < 0.1, "接触点高度应当与窗口顶边一致")
	print("[PASS] 测试 11: 窗口顶边正常下落 Swept Landing 成功")

	# 测试 12: 高速下落防穿透 (3000px/s 跨帧下落)
	cat.position = Vector2(300.0, 50.0)
	cat.vertical_velocity = 3000.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.1)
	assert(cat.is_grounded == true and cat.current_surface_id == "win1:top", "高速下落不应穿透平台")
	assert(absf(cat.position.y - 200.0) < 0.1, "高速着陆点精度正确")
	print("[PASS] 测试 12: 高速下落防穿透测试成功")

	# 测试 13: 多层窗口选择最高/首个相交平台
	var multi_win = {
		"winA": {"id": "winA", "rect": Rect2(100, 300, 400, 200), "z_order": 0},
		"winB": {"id": "winB", "rect": Rect2(100, 450, 400, 200), "z_order": 1}
	}
	surf_model.rebuild_from_windows(multi_win, Vector2(1920, 1080), 1000.0)
	cat.position = Vector2(300.0, 200.0)
	cat.vertical_velocity = 2000.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.1)
	assert(cat.is_grounded == true and cat.current_surface_id == "winA:top", "多候选平台应优先停留在最先相交的winA")
	print("[PASS] 测试 13: 多层窗口候选优先选择首个交叉平台成功")

	# 测试 14: 从下往上跳跃穿过平台 (One-Way Platform)
	cat.position = Vector2(300.0, 350.0)
	cat.vertical_velocity = -400.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.JUMP)
	cat.update_state(0.1)
	assert(cat.is_grounded == false, "从下往上跳跃不应阻挡或粘连平台")
	assert(cat.current_state == Cat.CatState.JUMP, "应继续保持 JUMP 状态")
	print("[PASS] 测试 14: 从下往上跳跃穿过平台验证成功")

	# 测试 15: 走出平台边缘自动下落
	cat.position = Vector2(498.0, 300.0)
	cat.vertical_velocity = 0.0
	cat.is_grounded = true
	cat.direction = 1.0
	cat.current_surface_id = "winA:top"
	cat.change_state(Cat.CatState.WALK)
	cat.update_state(0.1)
	cat.update_state(0.016)
	assert(cat.is_grounded == false, "超出平台边缘应当立即失去支撑")
	assert(cat.current_state == Cat.CatState.FALL, "失去支撑后应当切换为 FALL 状态")
	print("[PASS] 测试 15: 走出平台边缘自动下落验证成功")


	# 测试 16: 动态窗口移动时小猫跟随
	cat.position = Vector2(250.0, 300.0)
	cat.is_grounded = true
	cat.current_surface_id = "winA:top"
	cat.current_surface = surf_model.get_surface_by_id("winA:top")
	cat.change_state(Cat.CatState.SIT)
	var moved_win = {
		"winA": {"id": "winA", "rect": Rect2(140, 320, 400, 200), "z_order": 0}
	}
	surf_model.rebuild_from_windows(moved_win, Vector2(1920, 1080), 1000.0)
	assert(absf(cat.position.x - 290.0) < 0.5 and absf(cat.position.y - 320.0) < 0.5, "小猫应当跟随窗口平移")
	assert(cat.current_state == Cat.CatState.SIT, "跟随窗口不应破坏 SIT 生活状态")
	print("[PASS] 测试 16: 动态窗口移动跟随验证成功")

	# 测试 17: 窗口关闭/平台消失后小猫下落
	surf_model.rebuild_from_windows({}, Vector2(1920, 1080), 1000.0)
	cat.update_state(0.016)
	assert(cat.is_grounded == false and cat.current_state == Cat.CatState.FALL, "平台消失后小猫应当失去支撑坠落")
	print("[PASS] 测试 17: 窗口关闭/平台消失自动下落验证成功")

	# ========== T14 UI Automation Element Perception 单元测试 ==========
	var UIElementWorldModelClass = load("res://scripts/world/ui_element_world_model.gd")
	var ui_model = UIElementWorldModelClass.new()
	root.add_child(ui_model)
	bridge.ui_element_world_model = ui_model

	# 测试 18: UI 快照解析与属性提取
	var sample_ui_snap = {
		"v": 1,
		"type": "ui_snapshot",
		"revision": 1,
		"screen": {"index": 0, "width": 1920, "height": 1080},
		"elements": [
			{"id": "0x100:1", "window_id": "0x100", "control_type": "Button", "x": 100.0, "y": 200.0, "width": 80.0, "height": 30.0},
			{"id": "0x100:2", "window_id": "0x100", "control_type": "Edit", "x": 200.0, "y": 200.0, "width": 150.0, "height": 30.0},
			{"id": "0x100:3", "window_id": "0x100", "control_type": "Text", "x": 100.0, "y": 150.0, "width": 120.0, "height": 20.0}
		]
	}
	var update_res: bool = ui_model.update_from_snapshot(sample_ui_snap)
	assert(update_res == true, "UI 快照应成功更新")
	assert(ui_model.elements_by_id.size() == 3, "应提取 3 个有效 UI 元素")
	var btn = ui_model.elements_by_id["0x100:1"]
	assert(btn.control_type == "Button" and btn.rect == Rect2(100.0, 200.0, 80.0, 30.0), "Button 属性提取正确")
	print("[PASS] 测试 18: UI 快照解析与属性提取验证成功")

	# 测试 19: 版本防倒退
	var old_ui_snap = {
		"v": 1, "type": "ui_snapshot", "revision": 1, "elements": []
	}
	assert(ui_model.update_from_snapshot(old_ui_snap) == false, "旧或相同版本号快照应当被忽略")
	assert(ui_model.elements_by_id.size() == 3, "元素数据不应被倒退版本覆盖")
	print("[PASS] 测试 19: UI 版本防倒退验证成功")

	# 测试 20: 极小尺寸元素过滤 (<4px)
	var tiny_ui_snap = {
		"v": 1, "type": "ui_snapshot", "revision": 2,
		"elements": [
			{"id": "0x100:good", "window_id": "0x100", "control_type": "Pane", "x": 50.0, "y": 50.0, "width": 100.0, "height": 100.0},
			{"id": "0x100:tiny", "window_id": "0x100", "control_type": "Other", "x": 10.0, "y": 10.0, "width": 2.0, "height": 2.0}
		]
	}
	assert(ui_model.update_from_snapshot(tiny_ui_snap) == true, "新版本快照更新成功")
	assert(ui_model.elements_by_id.has("0x100:good") and not ui_model.elements_by_id.has("0x100:tiny"), "极小尺寸元素应被过滤")
	print("[PASS] 测试 20: 极小尺寸元素过滤验证成功")

	# 测试 21: 空间与类型查询 API
	var all_elems = ui_model.get_all_elements()
	var panes = ui_model.get_elements_by_type("Pane")
	var near_elems = ui_model.get_elements_near(Vector2(100.0, 100.0), 30.0)
	assert(all_elems.size() == 1 and panes.size() == 1 and near_elems.size() == 1, "查询 API 返回正确")

	print("[PASS] 测试 21: 空间与类型查询 API 验证成功")

	# 测试 22: F11 调试开关
	assert(ui_model.debug_draw_enabled == false, "默认 Debug Draw 为关闭")
	ui_model.toggle_debug_draw()
	assert(ui_model.debug_draw_enabled == true, "toggle 后 Debug Draw 应开启")
	ui_model.toggle_debug_draw()
	assert(ui_model.debug_draw_enabled == false, "再次 toggle 后 Debug Draw 应关闭")
	print("[PASS] 测试 22: F11 调试开关验证成功")

	ui_model.queue_free()
	surf_model.queue_free()
	bridge.stop_server(); bridge.queue_free()
	world_model.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T14 UI Automation Perception 单元测试全部通过 ==========")
	quit(0)




