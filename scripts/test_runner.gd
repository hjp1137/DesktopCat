extends SceneTree

const SurfaceClass = preload("res://scripts/world/surface.gd")
const SurfaceWorldModelClass = preload("res://scripts/world/surface_world_model.gd")
const TraversalPlanClass = preload("res://scripts/navigation/traversal_plan.gd")
const AutonomousJumpPlannerClass = preload("res://scripts/navigation/autonomous_jump_planner.gd")

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
	var test_port: int = 47839
	var port_ok: bool = false
	for p_try in [47839, 47840, 47841, 47842, 47843]:
		bridge.start_server(p_try)
		if bridge.server != null and bridge.server.is_listening():
			test_port = p_try
			port_ok = true
			break
	assert(port_ok, "Bridge 应成功监听本地测试端口")
	print("[PASS] 测试 1: ExternalBridge 本地服务监听成功 (端口 %d)" % test_port)

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
	cat.update_state(0.2)
	cat.update_state(0.016)
	assert(cat.is_grounded == false, "超出平台边缘应当立即失去支撑")
	assert(cat.current_state in [Cat.CatState.FALL, Cat.CatState.EDGE_HANG], "失去支撑后应当切换为 FALL 或抓边状态")
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

	# ========== T15 Lightweight Visual Geometry Perception 单元测试 ==========
	var VisualWorldModelClass = load("res://scripts/world/visual_world_model.gd")
	var vis_model = VisualWorldModelClass.new()
	root.add_child(vis_model)
	bridge.visual_world_model = vis_model

	# 测试 23: visual_snapshot 接收与几何解析
	var sample_vis_snap = {
		"v": 1,
		"type": "visual_snapshot",
		"revision": 1,
		"screen": {"index": 0, "width": 1920, "height": 1080},
		"geometries": [
			{"id": "vg_lh_1", "type": "LINE", "orientation": "HORIZONTAL", "x1": 100.0, "y1": 300.0, "x2": 400.0, "y2": 300.0},
			{"id": "vg_lv_1", "type": "LINE", "orientation": "VERTICAL", "x1": 100.0, "y1": 300.0, "x2": 100.0, "y2": 500.0},
			{"id": "vg_rect_1", "type": "RECT", "x": 200.0, "y": 200.0, "width": 150.0, "height": 100.0}
		]
	}
	assert(vis_model.update_from_snapshot(sample_vis_snap) == true, "视觉快照应更新成功")
	assert(vis_model.geometries_by_id.size() == 3, "应解析出 3 个有效几何")
	assert(vis_model.geometries_by_id["vg_lh_1"].type == "LINE" and vis_model.geometries_by_id["vg_lh_1"].orientation == "HORIZONTAL", "水平线解析正确")
	assert(vis_model.geometries_by_id["vg_rect_1"].type == "RECT" and vis_model.geometries_by_id["vg_rect_1"].rect == Rect2(200.0, 200.0, 150.0, 100.0), "矩形解析正确")
	print("[PASS] 测试 23: 视觉快照接收与几何解析验证成功")

	# 测试 24: 视觉版本防倒退
	var old_vis_snap = {"v": 1, "type": "visual_snapshot", "revision": 1, "geometries": []}
	assert(vis_model.update_from_snapshot(old_vis_snap) == false, "旧或相同版本号快照应当被忽略")
	assert(vis_model.geometries_by_id.size() == 3, "几何数据不应被倒退版本覆盖")
	print("[PASS] 测试 24: 视觉版本防倒退验证成功")

	# 测试 25: 非法数值与无效几何过滤 (NaN, Inf, 负尺寸)
	var invalid_vis_snap = {
		"v": 1, "type": "visual_snapshot", "revision": 2,
		"geometries": [
			{"id": "vg_valid", "type": "LINE", "orientation": "HORIZONTAL", "x1": 50.0, "y1": 50.0, "x2": 250.0, "y2": 50.0},
			{"id": "vg_bad_rect", "type": "RECT", "x": 10.0, "y": 10.0, "width": -5.0, "height": 20.0},
			{"id": "vg_bad_line", "type": "LINE", "orientation": "VERTICAL", "x1": NAN, "y1": 0.0, "x2": 0.0, "y2": 100.0}
		]
	}
	assert(vis_model.update_from_snapshot(invalid_vis_snap) == true, "新版本快照应更新成功")
	assert(vis_model.geometries_by_id.has("vg_valid") and not vis_model.geometries_by_id.has("vg_bad_rect") and not vis_model.geometries_by_id.has("vg_bad_line"), "非法几何应被过滤")
	print("[PASS] 测试 25: 非法数值与无效几何过滤验证成功")

	# 测试 26: 视觉几何分类与空间查询 API
	var all_lines = vis_model.get_lines()
	var h_lines = vis_model.get_horizontal_lines()
	var v_lines = vis_model.get_vertical_lines()
	var near_geoms = vis_model.get_geometries_near(Vector2(150.0, 50.0), 30.0)
	assert(all_lines.size() == 1 and h_lines.size() == 1 and v_lines.size() == 0 and near_geoms.size() == 1, "分类与空间查询返回正确")
	print("[PASS] 测试 26: 视觉几何分类与空间查询 API 验证成功")

	# 测试 27: F12 调试开关
	assert(vis_model.debug_draw_enabled == false, "默认 Debug Draw 为关闭")
	vis_model.toggle_debug_draw()
	assert(vis_model.debug_draw_enabled == true, "toggle 后 Debug Draw 应开启")
	vis_model.toggle_debug_draw()
	assert(vis_model.debug_draw_enabled == false, "再次 toggle 后 Debug Draw 应关闭")
	print("[PASS] 测试 27: F12 调试开关验证成功")

	# ========== T16 Unified Surface Fusion 单元测试 ==========
	var SurfaceClass = load("res://scripts/world/surface.gd")
	var SurfaceCandidateClass = load("res://scripts/world/surface_candidate.gd")
	var SurfaceFusionBuilderClass = load("res://scripts/world/surface_fusion_builder.gd")
	var fusion_builder = SurfaceFusionBuilderClass.new()
	fusion_builder.window_world_model = world_model
	fusion_builder.ui_element_world_model = ui_model
	fusion_builder.visual_world_model = vis_model
	fusion_builder.surface_world_model = surf_model
	fusion_builder.cat = cat
	root.add_child(fusion_builder)

	# 测试 28: UI 容器类型过滤 (Pane/Group/Document 过滤，Button/Text 保留)
	var ui_test_data = {
		"v": 1, "type": "ui_snapshot", "revision": 10,
		"elements": [
			{"id": "doc1", "control_type": "Document", "x": 100.0, "y": 100.0, "width": 800.0, "height": 600.0},
			{"id": "pane1", "control_type": "Pane", "x": 120.0, "y": 120.0, "width": 700.0, "height": 500.0},
			{"id": "btn1", "control_type": "Button", "x": 150.0, "y": 200.0, "width": 120.0, "height": 40.0}
		]
	}
	ui_model.update_from_snapshot(ui_test_data)
	var uia_cands = fusion_builder._extract_uia_candidates(ui_model.elements_by_id, {})
	assert(uia_cands.size() == 1 and uia_cands[0].source_id == "btn1", "容器应被过滤，仅保留 Button 平台")
	print("[PASS] 测试 28: UI 容器类型过滤验证成功")

	# 测试 29: 文本片段同行自动合并
	var text_merge_data = {
		"v": 1, "type": "ui_snapshot", "revision": 11,
		"elements": [
			{"id": "t1", "window_id": "w1", "control_type": "Text", "x": 200.0, "y": 300.0, "width": 60.0, "height": 20.0},
			{"id": "t2", "window_id": "w1", "control_type": "Text", "x": 265.0, "y": 301.0, "width": 80.0, "height": 20.0}
		]
	}
	ui_model.update_from_snapshot(text_merge_data)
	var text_cands = fusion_builder._extract_uia_candidates(ui_model.elements_by_id, {})
	assert(text_cands.size() == 1, "同行近邻文本片段应合并为一个平台")
	assert(text_cands[0].x1 <= 200.0 and text_cands[0].x2 >= 345.0, "文本平台应覆盖合并后区间")
	print("[PASS] 测试 29: 文本片段同行自动合并验证成功")

	# 测试 30: 跨 Provider 重叠去重 (UIA 优先于 Visual)
	var cand_uia = SurfaceCandidateClass.new("uia:b1:top", "UIA", "b1", "Button", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 400.0, 250.0, 400.0, true, true, 80)
	var cand_vis = SurfaceCandidateClass.new("vg:line1", "VISUAL", "l1", "VisualLine", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 90.0, 401.0, 260.0, 401.0, true, true, 60)
	var deduped = fusion_builder._deduplicate_platforms([cand_uia, cand_vis])
	assert(deduped.size() == 1, "重叠平台应去重")
	assert(deduped[0].source_type == "UIA", "应保留优先级更高的 UIA 来源")
	assert(deduped[0].x1 <= 90.0 and deduped[0].x2 >= 260.0, "应扩展并集范围")
	assert(deduped[0].source_aliases.has("vg:line1"), "应记录别名")
	print("[PASS] 测试 30: 跨 Provider 重叠去重与范围扩展验证成功")

	# 测试 31: 近共线线段合并
	var l_a = SurfaceCandidateClass.new("l_a", "VISUAL", "1", "Line", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 500.0, 200.0, 500.0, true, true, 60)
	var l_b = SurfaceCandidateClass.new("l_b", "VISUAL", "2", "Line", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 210.0, 501.0, 320.0, 501.0, true, true, 60)
	var collinear_res = fusion_builder._deduplicate_platforms([l_a, l_b])
	assert(collinear_res.size() == 1 and collinear_res[0].x2 >= 320.0, "近共线短间距应合并")
	print("[PASS] 测试 31: 近共线线段合并验证成功")


	# 测试 32: 窗口遮挡裁剪 UI 平台
	var win_w1 = {"id": "w1", "z_order": 1, "rect": Rect2(100.0, 100.0, 600.0, 400.0)}
	var win_w0 = {"id": "w0", "z_order": 0, "rect": Rect2(200.0, 50.0, 200.0, 500.0)} # 高Z遮挡
	var clipped_inv = fusion_builder._clip_by_windows([[150.0, 550.0]], 200.0, "w1", [win_w1, win_w0])
	assert(clipped_inv.size() == 2, "被顶层窗口遮挡的中间段应被裁剪为前后两段")
	print("[PASS] 测试 32: 窗口遮挡裁剪 UI 平台验证成功")

	# 测试 33: 多源全流程融合提交与版本防抖
	world_model.windows_by_id = {"w1": win_w1}
	ui_model.elements_by_id = {"btn1": {"id": "btn1", "window_id": "w1", "control_type": "Button", "rect": Rect2(150.0, 200.0, 100.0, 40.0)}}
	vis_model.geometries_by_id = {"vg1": {"id": "vg1", "type": "LINE", "orientation": "HORIZONTAL", "p1": Vector2(120.0, 350.0), "p2": Vector2(300.0, 350.0)}}
	assert(fusion_builder.execute_fusion() == true, "全流程融合更新应生效")
	var prev_rev = surf_model.surface_revision
	assert(surf_model.surfaces_by_id.has("screen:ground"), "应包含地面")
	assert(surf_model.surfaces_by_id.has("w1:top"), "应包含窗口顶边")
	assert(surf_model.surfaces_by_id.has("uia:btn1:top"), "应包含按钮顶边")
	assert(surf_model.surfaces_by_id.has("vg:vg1"), "应包含视觉横线")
	assert(fusion_builder.execute_fusion() == false, "无几何变动时不应增加 revision")
	assert(surf_model.surface_revision == prev_rev, "revision 保持稳定")
	print("[PASS] 测试 33: 多源全流程融合与版本防抖验证成功")

	# 测试 34: 丢失 Grace 保护期
	ui_model.elements_by_id = {} # 模拟 UI 短暂漏检
	fusion_builder.execute_fusion()
	assert(surf_model.surfaces_by_id.has("uia:btn1:top"), "在 Grace 保护期内丢失的表面仍应保留")
	print("[PASS] 测试 34: 丢失 Grace 保护期验证成功")

	# ========== T17 Platform Navigation Graph 单元测试 ==========
	var CatMovementCapabilitiesClass = load("res://scripts/navigation/cat_movement_capabilities.gd")
	var NavigationNodeClass = load("res://scripts/navigation/navigation_node.gd")
	var NavigationEdgeClass = load("res://scripts/navigation/navigation_edge.gd")
	var PlatformNavigationGraphClass = load("res://scripts/navigation/platform_navigation_graph.gd")

	# 测试 35: CatMovementCapabilities 参数获取与理论弹道极值推导
	var cap = CatMovementCapabilitiesClass.new(cat)
	assert(absf(cap.gravity - 980.0) < 0.1, "Gravity 应为 980.0")
	assert(absf(cap.jump_velocity - (-420.0)) < 0.1, "Jump Velocity 应为 -420.0")
	var max_h = cap.get_max_jump_height()
	assert(absf(max_h - 90.0) < 0.5, "理论最大跳高应约等于 90.0px")
	var flight_t = cap.get_level_flight_time()
	assert(absf(flight_t - 0.857) < 0.01, "同高水平飞行时间应约等于 0.857s")
	var max_walk_d = cap.get_max_walk_jump_distance()
	var max_run_d = cap.get_max_run_jump_distance()
	assert(max_walk_d > 80.0 and max_walk_d < 110.0, "Walk 跳跃距离范围正确")
	assert(max_run_d > 150.0 and max_run_d < 190.0, "Run 跳跃距离范围正确")
	print("[PASS] 测试 35: CatMovementCapabilities 参数推导验证成功")

	# 测试 36: 动力学方程 Landing Solution 与 One-Way 语义 (下落解有效，向上解排除)
	var t_level = cap.calc_jump_landing_time(0.0)
	assert(absf(t_level - flight_t) < 0.01, "水平平飞着陆时间与飞行时间一致")
	var t_above = cap.calc_jump_landing_time(-50.0) # 目标高于起跳点 50px
	assert(t_above > cap.get_time_to_apex(), "着陆解必须在顶点之后的下落阶段")
	var t_too_high = cap.calc_jump_landing_time(-120.0) # 超出 90px 最大跳高
	assert(t_too_high < 0.0, "超出最大跳高应当无有效解")
	print("[PASS] 测试 36: 动力学方程 Landing Solution 与 One-Way 语义验证成功")

	# 测试 37: NavigationNode 构建与安全落地区间 (扣除 Cat 半宽与裕量)
	var surf_wide = SurfaceClass.new("surf_w", "w1", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 200.0, 300.0, 200.0, true, true)
	var node_wide = NavigationNodeClass.new(surf_wide, cap.landing_margin)
	assert(node_wide.navigable == true, "宽平台应可导航")
	assert(absf(node_wide.safe_x1 - (100.0 + cap.landing_margin)) < 0.1, "安全左边界正确扣除 margin")
	assert(absf(node_wide.safe_x2 - (300.0 - cap.landing_margin)) < 0.1, "安全右边界正确扣除 margin")
	var surf_narrow = SurfaceClass.new("surf_n", "w1", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 200.0, 110.0, 200.0, true, true)
	var node_narrow = NavigationNodeClass.new(surf_narrow, cap.landing_margin)
	assert(node_narrow.navigable == false, "窄平台安全落地区间不足应标记为不可导航")
	print("[PASS] 测试 37: NavigationNode 构建与安全落地区间验证成功")

	# 测试 38: Walk Jump 与 Run Jump 区分识别
	var nav_graph = PlatformNavigationGraphClass.new(cat)
	nav_graph.surface_world_model = surf_model


	# 构造 A 平台 (x: 100~300, y: 300)
	var s_a = SurfaceClass.new("A", "wA", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 300.0, 300.0, 300.0, true, true)
	var n_a = NavigationNodeClass.new(s_a, cap.landing_margin)
	# 构造 B 平台 (x: 350~500, y: 300)，间隙 50px (Walk 范围内)
	var s_b = SurfaceClass.new("B", "wB", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 350.0, 300.0, 500.0, 300.0, true, true)
	var n_b = NavigationNodeClass.new(s_b, cap.landing_margin)
	var edge_ab = nav_graph._check_jump_edge(n_a, n_b, [s_a, s_b])
	assert(edge_ab != null and edge_ab.action_type == NavigationEdgeClass.ActionType.JUMP_WALK, "间隙 50px 应识别为 JUMP_WALK")

	# 构造 C 平台 (x: 430~600, y: 300)，间隙 130px (超出 Walk，在 Run 范围内)
	var s_c = SurfaceClass.new("C", "wC", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 430.0, 300.0, 600.0, 300.0, true, true)
	var n_c = NavigationNodeClass.new(s_c, cap.landing_margin)
	var edge_ac = nav_graph._check_jump_edge(n_a, n_c, [s_a, s_c])
	assert(edge_ac != null and edge_ac.action_type == NavigationEdgeClass.ActionType.JUMP_RUN, "间隙 130px 应识别为 JUMP_RUN")
	print("[PASS] 测试 38: Walk Jump 与 Run Jump 区分识别验证成功")

	# 测试 39: 不可达平台有效过滤 (超高、超远)
	var s_too_high = SurfaceClass.new("H", "wH", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 350.0, 180.0, 500.0, 180.0, true, true)
	var n_too_high = NavigationNodeClass.new(s_too_high, cap.landing_margin)
	assert(nav_graph._check_jump_edge(n_a, n_too_high, [s_a, s_too_high]) == null, "超高目标(120px)应无法建立跳跃边")
	var s_too_far = SurfaceClass.new("F", "wF", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 600.0, 300.0, 800.0, 300.0, true, true)
	var n_too_far = NavigationNodeClass.new(s_too_far, cap.landing_margin)
	assert(nav_graph._check_jump_edge(n_a, n_too_far, [s_a, s_too_far]) == null, "超远目标(300px)应无法建立跳跃边")
	print("[PASS] 测试 39: 不可达平台有效过滤验证成功")

	# 测试 40: 弹道轨迹中间平台拦截阻挡检测
	var s_blocker = SurfaceClass.new("Blocker", "wB", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 300.0, 260.0, 460.0, 260.0, true, true)
	var edge_blocked = nav_graph._check_jump_edge(n_a, n_c, [s_a, s_c, s_blocker])
	assert(edge_blocked == null, "被中间平台拦截的弹道不应生成直接跳跃边")

	print("[PASS] 测试 40: 弹道轨迹中间平台拦截阻挡检测验证成功")

	# 测试 41: Drop 边判定与中间截断检测
	var s_top = SurfaceClass.new("Top", "wT", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 200.0, 300.0, 200.0, true, true)
	var n_top = NavigationNodeClass.new(s_top, cap.landing_margin)
	var s_bottom = SurfaceClass.new("Bottom", "wB", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 250.0, 500.0, 500.0, 500.0, true, true)
	var n_bottom = NavigationNodeClass.new(s_bottom, cap.landing_margin)
	var edge_drop = nav_graph._check_drop_edge(n_top, n_bottom, [s_top, s_bottom])
	assert(edge_drop != null and edge_drop.action_type == NavigationEdgeClass.ActionType.DROP, "正下方无遮挡平台应生成 DROP 边")
	var s_mid = SurfaceClass.new("Mid", "wM", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 280.0, 350.0, 400.0, 350.0, true, true)
	var edge_drop_cut = nav_graph._check_drop_edge(n_top, n_bottom, [s_top, s_bottom, s_mid])
	assert(edge_drop_cut == null, "中间存在更高承接表面时不应越级生成至底层平台的直接 DROP 边")
	print("[PASS] 测试 41: Drop 边判定与中间截断检测验证成功")

	# 测试 42: 全图原子重建与图查询 API
	var s_ground = SurfaceClass.new("screen:ground", "screen", "SCREEN", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 0.0, 800.0, 1920.0, 800.0, true, false)
	surf_model.surfaces_by_id = {

		"Top": s_top, "Mid": s_mid, "Bottom": s_bottom, "screen:ground": s_ground
	}
	assert(nav_graph.rebuild_graph() == true, "全图重建应成功")
	assert(nav_graph.nodes.size() == 4, "应注册 4 个导航节点")
	assert(nav_graph.get_node("Top") != null, "get_node 返回正确")
	var top_edges = nav_graph.get_edges_from("Top")
	assert(top_edges.size() >= 1, "Top 应存在出度边")
	var reachables = nav_graph.get_reachable_surfaces("Top")
	assert(reachables.has("Mid"), "Top 应能到达 Mid")
	assert(nav_graph.find_nearest_node(Vector2(110.0, 210.0)).surface_id == "Top", "最近节点查询正确")
	print("[PASS] 测试 42: 全图原子重建与图查询 API 验证成功")

	# 测试 43: TraversalPlan 数据结构与超时计算
	var plan = TraversalPlanClass.new("A", "B", 0, 1, "WALK", 150.0, 320.0, 120.0, 180.0, 300.0, 350.0, 0.85, 250.0, 1)
	assert(plan.source_surface_id == "A" and plan.target_surface_id == "B", "基础字段赋值正确")
	assert(plan.timeout >= 2.5, "超时时间计算符合公式")
	var p_dict = plan.to_dict()
	assert(p_dict.action == "JUMP_WALK" and p_dict.direction == "RIGHT", "to_dict 序列化正确")
	print("[PASS] 测试 43: TraversalPlan 数据结构与超时计算验证成功")

	# 测试 44: AutonomousJumpPlanner 初始化与状态机前置条件检测
	var planner = AutonomousJumpPlannerClass.new(cat, cmd_mgr, nav_graph, surf_model)
	root.add_child(planner)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.IDLE, "初始相位应为 IDLE")
	cat.current_surface_id = "Top"
	cat.is_grounded = true
	cat.current_mode = Cat.ControlMode.AUTO
	cat.change_state(Cat.CatState.WALK)
	planner.cooldown_timer = 0.0
	assert(planner.can_plan_traversal() == true, "具备地面有效边时应当可以规划")
	cat.change_state(Cat.CatState.SLEEP)
	assert(planner.can_plan_traversal() == false, "睡眠状态下不可规划")
	cat.change_state(Cat.CatState.WALK)
	print("[PASS] 测试 44: AutonomousJumpPlanner 初始化与前置条件验证成功")

	# 测试 45: try_plan_traversal 目标边选择与起落点区间内随机选择
	var plan_ok: bool = planner.try_plan_traversal()
	assert(plan_ok == true, "try_plan_traversal 应当成功选择出度边")
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.APPROACH_TAKEOFF, "进入 APPROACH_TAKEOFF 相位")
	assert(planner.current_plan != null, "当前计划非空")
	assert(planner.current_plan.takeoff_x >= planner.current_plan.takeoff_x_min and planner.current_plan.takeoff_x <= planner.current_plan.takeoff_x_max, "起跳点处于安全区间内")
	assert(planner.current_plan.landing_target_x >= planner.current_plan.landing_x_min and planner.current_plan.landing_target_x <= planner.current_plan.landing_x_max, "落地点处于安全区间内")
	print("[PASS] 测试 45: 目标边加权选择与起落点区间约束验证成功")

	# 测试 46: 助跑空间不足时安全拒绝该边
	var s_short = SurfaceClass.new("Short", "wS", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 300.0, 115.0, 300.0, true, true)
	var edge_fake_run = NavigationEdgeClass.new("Short", "Far", NavigationEdgeClass.ActionType.JUMP_RUN, 1, "RUN", 110.0, 110.0, 200.0, 200.0, 0.8, 90.0, 0.0, 2.0, 0.5)
	surf_model.surfaces_by_id["Short"] = s_short
	cat.current_surface_id = "Short"
	nav_graph.outgoing_edges["Short"] = [edge_fake_run]
	planner.current_phase = AutonomousJumpPlannerClass.TraversalPhase.IDLE
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == false, "跑道长度(15px)小于35px助跑需求时应当拒绝执行")
	print("[PASS] 测试 46: 跑道助跑空间不足安全拒绝验证成功")

	# 测试 47: 走位靠近起跳点与起跳触发
	cat.current_surface_id = "Top"
	cat.position = Vector2(120.0, 200.0)
	cat.is_grounded = true
	cat.current_mode = Cat.ControlMode.AUTO
	planner.current_phase = AutonomousJumpPlannerClass.TraversalPhase.IDLE
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == true, "Top 表面规划应当成功")
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.APPROACH_TAKEOFF, "进入走位阶段")
	cat.position.x = planner.current_plan.takeoff_x - 40.0
	planner.update(0.016)
	assert(cat.direction == 1.0, "小猫应被调度向右移动靠近起跳点")
	cat.position.x = planner.current_plan.takeoff_x
	planner.update(0.016)
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE, "应进入 AIRBORNE 相位")
	assert(cat.current_state == Cat.CatState.JUMP, "小猫状态应进入 JUMP")
	assert(cat.horizontal_throw_speed != 0.0, "起跳时应成功继承水平移动速度")
	print("[PASS] 测试 47: 走位接近与到位起跳触发验证成功")

	# 测试 48: 滞空着陆成功结算与历史表面记录
	var tgt_id_test = planner.current_plan.target_surface_id
	cat.is_grounded = true
	cat.current_surface_id = tgt_id_test
	planner.update(0.016)
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.IDLE, "成功后归位 IDLE")
	assert(planner.stats["success"] >= 1, "成功计数应增加")
	assert(planner.recent_surface_history.has(tgt_id_test), "目标表面应记录至近期历史")
	print("[PASS] 测试 48: 滞空着陆成功结算与历史记录验证成功")

	# 测试 49: 失败偏离目标与短期黑名单隔离
	cat.current_surface_id = "Top"
	cat.current_mode = Cat.ControlMode.AUTO
	cat.change_state(Cat.CatState.WALK)
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == true, "再次规划应当成功")
	var tgt_to_fail = planner.current_plan.target_surface_id
	planner.current_phase = AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE
	cat.is_grounded = true
	cat.current_surface_id = "different_missed_platform"
	planner.update(0.016)
	planner.update(0.016)
	assert(planner.stats["failed"] >= 1, "失败计数应增加")
	assert(planner.failed_edges_blacklist.has(tgt_to_fail), "失败目标应被纳入短期黑名单")
	print("[PASS] 测试 49: 失败偏离目标与黑名单隔离验证成功")

	# 测试 50: 用户显式命令与 DRAG 中断取消
	cat.current_surface_id = "Top"
	cat.current_mode = Cat.ControlMode.AUTO
	cat.change_state(Cat.CatState.WALK)
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == true, "中断测试规划应成功")
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.APPROACH_TAKEOFF, "进入靠近阶段")
	cat.change_state(Cat.CatState.DRAG)
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.IDLE, "用户拖拽应立即取消自主规划")
	assert(planner.current_plan == null, "计划应被清空")
	assert(planner.stats["cancelled"] >= 1, "取消计数应增加")
	print("[PASS] 测试 50: 用户显式命令与 DRAG 中断取消验证成功")

	# ========== T19 Edge Grab 单元测试 ==========
	var GrabbedEdgeClass = load("res://scripts/world/grabbed_edge.gd")

	# 测试 51: GrabbedEdge 数据结构与属性
	var ge = GrabbedEdgeClass.new("surf_test", GrabbedEdgeClass.Side.LEFT, 150.0, 300.0)
	assert(ge.surface_id == "surf_test" and ge.edge_side == -1, "字段赋值正确")
	assert(ge.get_edge_position() == Vector2(150.0, 300.0), "位置向量正确")
	assert(ge.get_side_name() == "LEFT", "侧别名称正确")
	var ge_dict = ge.to_dict()
	assert(ge_dict.edge_side == "LEFT" and ge_dict.edge_x == 150.0, "to_dict 序列化正确")
	print("[PASS] 测试 51: GrabbedEdge 数据结构与属性验证成功")

	# 测试 52: SurfaceWorldModel 平台左右端点提取与屏幕边界过滤
	var s_test_plat = SurfaceClass.new("plat_normal", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 200.0, 400.0, 350.0, 400.0, true, true)
	var s_test_short = SurfaceClass.new("plat_short", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 400.0, 120.0, 400.0, true, true)
	surf_model.surfaces_by_id = {
		"plat_normal": s_test_plat,
		"plat_short": s_test_short,
		"screen:ground": s_ground
	}
	var q_all = Rect2(50.0, 350.0, 400.0, 100.0)
	var edges_found = surf_model.get_grabbable_edges_in_rect(q_all)
	assert(edges_found.size() == 2, "应仅提取正常平台的左右两个端点(排除短平台和屏幕地面)")
	var sides_found: Array = [edges_found[0].side, edges_found[1].side]
	assert(sides_found.has(-1) and sides_found.has(1), "应包含 LEFT(-1) 与 RIGHT(1) 端点")
	print("[PASS] 测试 52: 平台端点提取与屏幕/过短平台过滤验证成功")

	# 测试 53: 正常 Swept Platform Landing 优先于 Edge Grab
	cat.current_mode = Cat.ControlMode.COMMAND
	cat.current_surface_id = ""
	cat.is_grounded = false
	cat.position = Vector2(275.0, 380.0) # 位于平台正中间上方
	cat.vertical_velocity = 200.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.15) # 下落穿过 y=400 平台
	assert(cat.is_grounded == true, "平台正中间下落应优先 Landing 着陆")
	assert(cat.current_state != Cat.CatState.EDGE_HANG, "正常落地绝不应被误判为抓边")
	assert(cat.current_surface_id == "plat_normal", "成功着陆在目标平台上")
	print("[PASS] 测试 53: 正常 Swept Landing 优先于 Edge Grab 验证成功")

	# 测试 54: 左端点抓取 (LEFT Edge Grab)
	cat.current_mode = Cat.ControlMode.COMMAND
	cat.is_grounded = false
	cat.current_surface_id = ""
	cat.ground_y = 800.0
	cat.position = Vector2(190.0, 412.0) # 位于左端点(200, 400)左外侧，前爪在(202, 392)
	cat.direction = 1.0
	cat.vertical_velocity = 150.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08) # 前爪扫掠穿过 (200, 400)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "下落扫掠经过左端点应成功进入 EDGE_HANG")
	assert(cat.grabbed_surface_id == "plat_normal", "抓住对应平台ID")
	assert(cat.grabbed_edge != null and cat.grabbed_edge.edge_side == -1, "抓取的侧别应为 LEFT(-1)")
	assert(cat.direction == 1.0, "抓左端点时小猫朝向应面向平台(朝右)")
	assert(cat.is_grounded == false, "悬挂时 is_grounded 必须为 false")
	assert(cat.vertical_velocity == 0.0, "悬挂时垂直速度必须清零")
	print("[PASS] 测试 54: 左端点抓边与悬挂姿态验证成功")

	# 测试 55: 右端点抓取 (RIGHT Edge Grab)
	cat.release_edge()
	cat.is_grounded = false
	cat.current_surface_id = ""
	cat.ground_y = 800.0
	cat.position = Vector2(360.0, 412.0) # 位于右端点(350, 400)右外侧，左前爪在(348, 392)
	cat.direction = -1.0
	cat.vertical_velocity = 150.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08) # 前爪扫掠穿过 (350, 400)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "下落扫掠经过右端点应成功进入 EDGE_HANG")
	assert(cat.grabbed_edge != null and cat.grabbed_edge.edge_side == 1, "抓取的侧别应为 RIGHT(1)")
	assert(cat.direction == -1.0, "抓右端点时小猫朝向应面向平台(朝左)")
	print("[PASS] 测试 55: 右端点抓边与朝向自适应验证成功")

	# 测试 56: 速度超限与距离过远拒绝抓边 (零磁吸)
	cat.release_edge()
	cat.is_grounded = false
	cat.ground_y = 800.0
	cat.position = Vector2(190.0, 412.0)
	cat.vertical_velocity = 800.0 # 超过 MAX_EDGE_GRAB_VERTICAL_SPEED(600)
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.05)
	assert(cat.current_state == Cat.CatState.FALL, "高速坠落或超速抛掷时应当拒绝抓边")
	cat.position = Vector2(120.0, 412.0) # 距离端点 80px，差太远
	cat.vertical_velocity = 150.0
	cat.update_state(0.05)
	assert(cat.current_state == Cat.CatState.FALL, "超出容差范围绝不发生磁吸")
	print("[PASS] 测试 56: 速度超限与过远拒绝抓边验证成功")

	# 测试 57: RELEASE_EDGE 指令执行与脱手下落
	cat.position = Vector2(190.0, 412.0)
	cat.vertical_velocity = 150.0
	cat.direction = 1.0
	cat.ground_y = 800.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "应重新进入 EDGE_HANG")
	cmd_mgr.send_command(CommandManager.CatCommand.RELEASE_EDGE)
	assert(cat.current_state == Cat.CatState.FALL, "RELEASE_EDGE 指令应使小猫脱离悬挂进入 FALL")
	assert(cat.grabbed_edge == null, "释放后 grabbed_edge 应清空")
	print("[PASS] 测试 57: RELEASE_EDGE 指令执行与脱手下落验证成功")

	# 测试 58: 悬挂状态下 DRAG 最高优先级脱扣
	cat.position = Vector2(190.0, 412.0)
	cat.vertical_velocity = 150.0
	cat.direction = 1.0
	cat.ground_y = 800.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "应进入悬挂状态")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, { "mouse_pos": cat.position })
	assert(cat.current_state == Cat.CatState.DRAG, "DRAG 拥有最高优先级，应瞬间脱扣悬挂")
	assert(cat.grabbed_edge == null, "拖拽时抓边数据必须已清除")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, { "throw_velocity": Vector2.ZERO })
	print("[PASS] 测试 58: 悬挂状态下 DRAG 瞬间脱扣验证成功")

	# 测试 59: 动态表面位移跟随、超限脱落与 Rebind
	cat.position = Vector2(190.0, 412.0)
	cat.vertical_velocity = 150.0
	cat.direction = 1.0
	cat.ground_y = 800.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "进入悬挂状态")
	var prev_cat_pos = cat.position
	# 模拟平台向右平移 10px
	s_test_plat.x1 += 10.0; s_test_plat.x2 += 10.0
	cat.update_state(0.016)
	assert(absf(cat.position.x - (prev_cat_pos.x + 10.0)) < 0.1, "悬挂时应跟随平台端点位移")
	# 模拟平台端点大幅跳变 200px (超限)
	s_test_plat.x1 += 200.0; s_test_plat.x2 += 200.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "端点大幅位移超过 150px 时应安全脱落")
	# 测试 Rebind: 抓新平台后删除原表面，替换为同位置新ID表面
	s_test_plat.x1 = 200.0; s_test_plat.x2 = 350.0
	cat.position = Vector2(190.0, 412.0)
	cat.vertical_velocity = 150.0
	cat.direction = 1.0
	cat.ground_y = 800.0
	cat.change_state(Cat.CatState.FALL)
	cat.update_state(0.08)
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "进入悬挂状态")
	surf_model.surfaces_by_id.erase("plat_normal")
	var s_test_rebind = SurfaceClass.new("plat_rebound", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 202.0, 400.0, 350.0, 400.0, true, true)
	surf_model.surfaces_by_id["plat_rebound"] = s_test_rebind
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.EDGE_HANG and cat.grabbed_surface_id == "plat_rebound", "几何相近时应成功重绑新边缘")
	surf_model.surfaces_by_id.erase("plat_rebound")
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "无等价边缘时应安全脱手下落")
	print("[PASS] 测试 59: 动态位移跟随、超限脱落与 Rebind 验证成功")

	# 测试 60: T18 自主规划器与 EDGE_HANG 协同
	surf_model.surfaces_by_id["Top"] = s_top
	surf_model.surfaces_by_id["Mid"] = s_mid
	cat.current_surface_id = "Top"
	cat.is_grounded = true
	cat.current_mode = Cat.ControlMode.AUTO
	cat.change_state(Cat.CatState.WALK)
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == true, "自主规划应当成功")
	planner.current_phase = AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE
	cat.is_grounded = false
	cat.grabbed_surface_id = planner.current_plan.target_surface_id
	cat.change_state(Cat.CatState.EDGE_HANG)
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE, "抓住目标边缘时规划器应挂起等待攀爬")
	# 模拟抓到非目标表面
	cat.grabbed_surface_id = "other_plat"
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.IDLE, "抓住非目标表面时规划器应平稳退出原计划")
	assert(planner.stats["partial_edge_grab"] >= 1, "partial_edge_grab 统计计数增加")
	print("[PASS] 测试 60: T18 自主规划器与 EDGE_HANG 协同验证成功")

	# ========== T20 Edge Climb-Up 单元测试 ==========
	var ClimbTargetClass = load("res://scripts/world/climb_target.gd")

	# 测试 61: ClimbTarget 数据结构与序列化
	var ct = ClimbTargetClass.new("plat_test", -1, Vector2(200.0, 400.0), 220.0, 400.0, Vector2(194.0, 418.0), Vector2(194.0, 400.0), Vector2(220.0, 400.0), 1)
	assert(ct.surface_id == "plat_test" and ct.edge_side == -1, "字段赋值正确")
	assert(ct.get_landing_foot_position() == Vector2(220.0, 400.0), "落脚目标计算正确")
	var ct_dict = ct.to_dict()
	assert(ct_dict.edge_side == "LEFT" and ct_dict.target_foot_x == 220.0, "序列化正确")
	print("[PASS] 测试 61: ClimbTarget 数据结构与序列化验证成功")

	# 测试 62: Climb 可行性检查 (空间不足与遮挡拒绝)
	surf_model.surfaces_by_id["plat_normal"] = s_test_plat
	s_test_plat.x1 = 200.0; s_test_plat.x2 = 350.0; s_test_plat.y1 = 400.0; s_test_plat.y2 = 400.0
	var s_narrow = SurfaceClass.new("plat_narrow", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 100.0, 400.0, 130.0, 400.0, true, true)
	surf_model.surfaces_by_id["plat_narrow"] = s_narrow
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_narrow", -1, 100.0, 400.0)
	cat.grabbed_surface_id = "plat_narrow"
	cat.change_state(Cat.CatState.EDGE_HANG)
	var feas_narrow = cat.check_climb_feasibility()
	assert(feas_narrow.feasible == false and feas_narrow.reason == "NO_LANDING_SPACE", "平台过窄应拒绝攀爬")
	# 增加上方低矮遮挡平台
	var s_ceil = SurfaceClass.new("plat_ceil", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 180.0, 380.0, 250.0, 380.0, true, true)
	surf_model.surfaces_by_id["plat_ceil"] = s_ceil
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	var feas_blocked = cat.check_climb_feasibility()
	assert(feas_blocked.feasible == false and feas_blocked.reason == "CLEARANCE_BLOCKED", "落脚点上方受阻应拒绝攀爬")
	surf_model.surfaces_by_id.erase("plat_ceil")
	surf_model.surfaces_by_id.erase("plat_narrow")
	print("[PASS] 测试 62: Climb 可行性检查 (空间与遮挡阻挡) 验证成功")

	# 测试 63: 左端点攀爬 (LEFT Edge Climb-Up) 两段式运动与登顶完成
	cat.current_mode = Cat.ControlMode.COMMAND
	cat.position = Vector2(194.0, 418.0)
	cat.direction = 1.0
	cat.vertical_velocity = 0.0
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cmd_mgr.send_command(CommandManager.CatCommand.CLIMB_UP)
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "接收指令后应进入 CLIMB_UP 状态")
	assert(cat.is_grounded == false, "攀爬期间 is_grounded 必须为 false")
	assert(cat.current_climb_phase == Cat.ClimbPhase.PULL_UP, "起始阶段应为 PULL_UP")
	cat.update_state(cat.climb_pull_up_duration + 0.01) # 推进过 PULL_UP
	assert(cat.current_climb_phase == Cat.ClimbPhase.SHIFT_IN, "应平滑过渡至 SHIFT_IN 阶段")
	cat.update_state(cat.climb_shift_in_duration + 0.01) # 推进过 SHIFT_IN
	assert(cat.current_state == Cat.CatState.IDLE, "登顶后应平稳进入 IDLE")
	assert(cat.is_grounded == true, "登顶后 is_grounded 必须为 true")
	assert(cat.current_surface_id == "plat_normal", "成功站在目标平台上")
	assert(absf(cat.position.y - (400.0 - cat.foot_offset.y)) < 0.1, "垂直落脚高度精确对齐")
	print("[PASS] 测试 63: 左端点攀爬两段式运动与登顶完成验证成功")

	# 测试 64: 右端点攀爬 (RIGHT Edge Climb-Up) 对称登顶验证
	cat.current_mode = Cat.ControlMode.COMMAND
	cat.position = Vector2(356.0, 418.0)
	cat.direction = -1.0
	cat.is_grounded = false
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", 1, 350.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cmd_mgr.send_command(CommandManager.CatCommand.CLIMB_UP)
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "应进入 CLIMB_UP")
	assert(cat.direction == -1.0, "右侧攀爬应面向左")
	cat.update_state(cat.climb_pull_up_duration + 0.02)
	cat.update_state(cat.climb_shift_in_duration + 0.02)
	assert(cat.current_state == Cat.CatState.IDLE, "右端点攀爬成功登顶")
	assert(cat.current_surface_id == "plat_normal", "正确站立在目标平台")
	assert(absf(cat.position.x - (350.0 - cat.climb_inward_margin - cat.foot_offset.x)) < 0.1, "右端点落脚 X 坐标对称对齐")
	print("[PASS] 测试 64: 右端点攀爬对称登顶验证成功")

	# 测试 65: 攀爬中表面消失与等价 Rebind 验证
	cat.position = Vector2(194.0, 418.0)
	cat.direction = 1.0
	cat.is_grounded = false
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cat.start_climb()
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "成功进入攀爬")
	# 模拟表面被替换为几何等价新表面
	surf_model.surfaces_by_id.erase("plat_normal")
	var s_re = SurfaceClass.new("plat_rebound2", "wP", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 201.0, 400.0, 350.0, 400.0, true, true)
	surf_model.surfaces_by_id["plat_rebound2"] = s_re
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.CLIMB_UP and cat.grabbed_surface_id == "plat_rebound2", "攀爬中表面更新应成功 Rebind")
	# 模拟新表面彻底消失
	surf_model.surfaces_by_id.erase("plat_rebound2")
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "无可用表面时应安全取消攀爬进入 FALL")
	print("[PASS] 测试 65: 攀爬中表面消失与等价 Rebind 验证成功")

	# 测试 66: 攀爬中平台位移跟随与超限脱落
	surf_model.surfaces_by_id["plat_normal"] = s_test_plat
	s_test_plat.x1 = 200.0; s_test_plat.x2 = 350.0; s_test_plat.y1 = 400.0; s_test_plat.y2 = 400.0
	cat.position = Vector2(194.0, 418.0)
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cat.start_climb()
	var pre_p := cat.position
	# 模拟平台小幅平移 10px
	s_test_plat.x1 += 10.0; s_test_plat.x2 += 10.0
	cat.update_state(0.016)
	assert(absf(cat.position.x - (pre_p.x + 10.0)) < 1.0, "攀爬中应动态跟随平台平移")
	# 模拟平台大幅跳变 200px
	s_test_plat.x1 += 200.0; s_test_plat.x2 += 200.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "平台突变超限时应安全脱落")
	# 还原测试平台坐标
	s_test_plat.x1 = 200.0; s_test_plat.x2 = 350.0
	print("[PASS] 测试 66: 攀爬中平台位移跟随与超限脱落验证成功")

	# 测试 67: 用户 DRAG 拖拽瞬间中断攀爬
	cat.position = Vector2(194.0, 418.0)
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cat.start_climb()
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "进入攀爬状态")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, { "mouse_pos": cat.position })
	assert(cat.current_state == Cat.CatState.DRAG, "DRAG 拥有最高优先级，应瞬间中断攀爬")
	assert(cat.current_climb_target == null and cat.grabbed_edge == null, "攀爬与抓边数据均已清除")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, { "throw_velocity": Vector2.ZERO })
	print("[PASS] 测试 67: 用户 DRAG 拖拽瞬间中断攀爬验证成功")

	# 测试 68: RELEASE_EDGE 指令 (按键 G) 在攀爬中立即脱手下落
	cat.position = Vector2(194.0, 418.0)
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cat.start_climb()
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "进入攀爬状态")
	cmd_mgr.send_command(CommandManager.CatCommand.RELEASE_EDGE)
	assert(cat.current_state == Cat.CatState.FALL, "RELEASE_EDGE 应立即取消攀爬进入 FALL")
	assert(cat.current_climb_target == null, "攀爬数据已清空")
	print("[PASS] 测试 68: RELEASE_EDGE 指令在攀爬中立即脱手下落验证成功")

	# 测试 69: AUTO 模式反应延迟与自动翻越闭环
	cat.current_mode = Cat.ControlMode.AUTO
	cat.position = Vector2(194.0, 418.0)
	cat.direction = 1.0
	cat.grabbed_edge = GrabbedEdgeClass.new("plat_normal", -1, 200.0, 400.0)
	cat.grabbed_surface_id = "plat_normal"
	cat.change_state(Cat.CatState.EDGE_HANG)
	cat.auto_climb_pause_timer = 0.0
	cat.update_state(0.1) # 停顿阶段
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "反应停顿期间保持 EDGE_HANG")
	cat.update_state(cat.auto_climb_reaction_delay + 0.05) # 超过停顿时间
	assert(cat.current_state == Cat.CatState.CLIMB_UP, "反应延迟到达后应自动进入 CLIMB_UP")
	cat.update_state(cat.climb_pull_up_duration + 0.02)
	cat.update_state(cat.climb_shift_in_duration + 0.02)
	assert(cat.current_state == Cat.CatState.IDLE, "自动攀爬完成登顶进入 IDLE")
	assert(cat.is_grounded == true and cat.current_surface_id == "plat_normal", "成功站在平台上")
	print("[PASS] 测试 69: AUTO 模式反应延迟与自动翻越闭环验证成功")

	# 测试 70: T18 自主规划器与 Edge Climb 成功闭环 (Recovery Success)
	surf_model.surfaces_by_id["Top"] = s_top
	surf_model.surfaces_by_id["Mid"] = s_mid
	cat.current_surface_id = "Top"
	cat.is_grounded = true
	cat.current_mode = Cat.ControlMode.AUTO
	cat.change_state(Cat.CatState.WALK)
	planner.cooldown_timer = 0.0
	assert(planner.try_plan_traversal() == true, "自主规划成功")
	planner.current_phase = AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE
	cat.is_grounded = false
	cat.grabbed_surface_id = planner.current_plan.target_surface_id
	cat.change_state(Cat.CatState.EDGE_HANG)
	planner.update(0.016)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.AIRBORNE, "抓住目标边缘时规划器应挂起等待")
	# 模拟小猫翻越成功
	cat.climb_completed.emit(planner.current_plan.target_surface_id)
	assert(planner.current_phase == AutonomousJumpPlannerClass.TraversalPhase.IDLE, "小猫登顶后规划器完成结算")
	assert(planner.stats["edge_grab_recovery_success"] >= 1, "edge_grab_recovery_success 计数增加")
	print("[PASS] 测试 70: T18 自主规划器与 Edge Climb 闭环验证成功")

	# ========== T21 Vertical Wall Attachment & Climbing 单元测试 ==========
	var WallAttachmentClass = load("res://scripts/world/wall_attachment.gd")

	# 测试 71: climbable 属性标记与屏幕假墙过滤
	var w_long = SurfaceClass.new("win_wall_l", "w1", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 150.0, 200.0, 150.0, 300.0, false, true, true)
	var w_short = SurfaceClass.new("win_wall_s", "w1", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 150.0, 200.0, 150.0, 220.0, false, true, false)
	var w_scr = SurfaceClass.new("screen:left", "screen", "SCREEN", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 0.0, 0.0, 0.0, 1080.0, false, true, false)
	surf_model.surfaces_by_id["win_wall_l"] = w_long
	surf_model.surfaces_by_id["win_wall_s"] = w_short
	surf_model.surfaces_by_id["screen:left"] = w_scr
	var q_walls = surf_model.get_climbable_walls_in_rect(Rect2(100.0, 150.0, 100.0, 200.0))
	assert(q_walls.has(w_long) and not q_walls.has(w_short) and not q_walls.has(w_scr), "正确筛选长墙并过滤短墙与屏幕墙")
	surf_model.surfaces_by_id.erase("win_wall_s")
	surf_model.surfaces_by_id.erase("screen:left")
	print("[PASS] 测试 71: climbable 属性标记与屏幕假墙过滤验证成功")

	# 测试 72: WallAttachment 数据结构与属性序列化
	var wa = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 240.0, 1)
	assert(wa.wall_surface_id == "win_wall_l" and wa.attach_side == -1 and wa.wall_x == 150.0, "字段赋值正确")
	var wa_dict = wa.to_dict()
	assert(wa_dict.attach_side == "LEFT" and wa_dict.anchor_y == 240.0, "序列化正确")
	print("[PASS] 测试 72: WallAttachment 数据结构与属性序列化验证成功")

	# 测试 73: 下落 Swept 抓墙 (左侧外侧接近、朝向向右、附着坐标计算正确)
	cat.current_mode = Cat.ControlMode.COMMAND
	cat.position = Vector2(138.0, 230.0)
	cat.direction = 1.0
	cat.vertical_velocity = 200.0
	cat.horizontal_throw_speed = 0.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.wall_cooldown = 0.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.WALL_CLING, "下落接近左墙外侧应进入 WALL_CLING")
	assert(cat.direction == 1.0, "挂在左侧时小猫应面向右(面向墙面)")
	assert(absf(cat.position.x - (150.0 - cat.wall_cling_offset_x)) < 0.1, "小猫 X 坐标精确贴靠左墙外侧")
	assert(cat.is_grounded == false and cat.vertical_velocity == 0.0, "挂墙期间暂停重力与下落速度")
	print("[PASS] 测试 73: 下落 Swept 抓墙 (左侧外侧接近与附着坐标) 验证成功")

	# 测试 74: 右侧外侧抓墙与朝向对称自适应
	var w_right = SurfaceClass.new("win_wall_r", "w1", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, 250.0, 200.0, 250.0, 300.0, false, true, true)
	surf_model.surfaces_by_id["win_wall_r"] = w_right
	cat.position = Vector2(262.0, 230.0)
	cat.direction = -1.0
	cat.vertical_velocity = 200.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.wall_cooldown = 0.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.WALL_CLING, "下落接近右墙外侧应进入 WALL_CLING")
	assert(cat.direction == -1.0, "挂在右侧时小猫应面向左(面向墙面)")
	assert(absf(cat.position.x - (250.0 + cat.wall_cling_offset_x)) < 0.1, "小猫 X 坐标对称贴靠右墙外侧")
	print("[PASS] 测试 74: 右侧外侧抓墙与朝向对称自适应验证成功")

	# 测试 75: 超速下落与过远拒绝抓墙 (零磁吸)
	surf_model.surfaces_by_id.erase("Top")
	surf_model.surfaces_by_id.erase("Mid")
	surf_model.surfaces_by_id.erase("plat_normal")
	cat.position = Vector2(138.0, 230.0)
	cat.vertical_velocity = 800.0 # 超出 max_wall_attach_vertical_speed(500.0)
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	cat.wall_cooldown = 0.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "超速下落不应抓墙")
	cat.vertical_velocity = 200.0
	cat.position = Vector2(90.0, 230.0) # 距离墙面 60px，超出 14px 容差
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "距离过远绝不磁吸抓墙")
	print("[PASS] 测试 75: 超速下落与过远拒绝抓墙 (零磁吸) 验证成功")

	# 测试 76: WALL_CLIMB 连续向上/向下爬行、STOP 转 Cling 与中途反向
	cat.position = Vector2(136.0, 260.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 242.0, 1)
	cat.direction = 1.0
	cat.change_state(Cat.CatState.WALL_CLING)
	cmd_mgr.send_command(CommandManager.CatCommand.WALL_CLIMB_UP)
	assert(cat.current_state == Cat.CatState.WALL_CLIMB and cat.current_wall_climb_dir == Cat.WallClimbDirection.UP, "接收 WALL_CLIMB_UP 指令进入爬行")
	var pre_y := cat.position.y
	cat.update_state(0.2) # 爬行 0.2s: -60.0 * 0.2 = -12.0
	assert(cat.position.y < pre_y - 10.0, "向上爬行 Y 坐标平滑上升")
	# 中途无缝反向向下
	cmd_mgr.send_command(CommandManager.CatCommand.WALL_CLIMB_DOWN)
	assert(cat.current_wall_climb_dir == Cat.WallClimbDirection.DOWN, "中途换向向下")
	pre_y = cat.position.y
	cat.update_state(0.1)
	assert(cat.position.y > pre_y + 4.0, "向下爬行 Y 坐标下降")
	# 停止爬行停留在当前位置
	cmd_mgr.send_command(CommandManager.CatCommand.STOP)
	assert(cat.current_state == Cat.CatState.WALL_CLING and cat.current_wall_climb_dir == Cat.WallClimbDirection.NONE, "STOP 后转为 WALL_CLING")
	print("[PASS] 测试 76: WALL_CLIMB 连续向上/向下爬行、STOP 转 Cling 与中途反向验证成功")

	# 测试 77: 爬到 Wall Top 自动过渡为 EDGE_HANG 并触发 T20 CLIMB_UP 登顶
	var plat_top = SurfaceClass.new("win_top", "w1", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, 150.0, 200.0, 250.0, 200.0, true, true)
	surf_model.surfaces_by_id["win_top"] = plat_top
	cat.position = Vector2(136.0, 212.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 204.0, 1)
	cat.direction = 1.0
	cat.change_state(Cat.CatState.WALL_CLING)
	cmd_mgr.send_command(CommandManager.CatCommand.WALL_CLIMB_UP)
	cat.update_state(0.1) # 向上到达顶端 200.0 + tolerance
	assert(cat.current_state == Cat.CatState.EDGE_HANG, "爬到墙顶自动平滑过渡为 EDGE_HANG")
	assert(cat.grabbed_surface_id == "win_top" and cat.grabbed_edge.edge_side == -1, "抓取对应 Platform 左端点")
	cmd_mgr.send_command(CommandManager.CatCommand.CLIMB_UP)
	cat.update_state(cat.climb_pull_up_duration + 0.02)
	cat.update_state(cat.climb_shift_in_duration + 0.02)
	assert(cat.current_state == Cat.CatState.IDLE and cat.is_grounded == true, "从墙顶翻越并登顶站立在平台上")
	assert(cat.current_surface_id == "win_top", "站在目标平台上")
	print("[PASS] 测试 77: 爬到 Wall Top 自动过渡为 EDGE_HANG 并登顶验证成功")

	# 测试 78: 爬墙中表面平移跟随、超大位移 (>150px) 脱落与等价 Rebind
	cat.position = Vector2(150.0 - cat.wall_cling_offset_x, 250.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 232.0, 1)
	cat.direction = 1.0
	cat.change_state(Cat.CatState.WALL_CLING)
	var prev_cx := cat.position.x
	# 模拟窗口平移 10px
	w_long.x1 += 10.0; w_long.x2 += 10.0
	cat.update_state(0.016)
	assert(absf(cat.position.x - (prev_cx + 10.0)) < 1.0, "爬墙时坐标应跟随墙面平移")
	# 模拟表面被替换为几何相近新表面 (Rebind)
	surf_model.surfaces_by_id.erase("win_wall_l")
	var w_re = SurfaceClass.new("win_wall_re", "w1", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 161.0, 200.0, 161.0, 300.0, false, true, true)
	surf_model.surfaces_by_id["win_wall_re"] = w_re
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.WALL_CLING and cat.current_wall_attachment.wall_surface_id == "win_wall_re", "等价新表面应自动 Rebind")
	# 模拟突变 200px 超过容差脱落
	w_re.x1 += 200.0; w_re.x2 += 200.0
	cat.update_state(0.016)
	assert(cat.current_state == Cat.CatState.FALL, "墙面大幅瞬移超限时应安全脱落")
	print("[PASS] 测试 78: 爬墙中表面平移跟随、超大位移脱落与等价 Rebind 验证成功")

	# 测试 79: 用户 DRAG 拖拽与 G (WALL_RELEASE) 瞬间脱落进入 FALL
	surf_model.surfaces_by_id["win_wall_l"] = w_long
	w_long.x1 = 150.0; w_long.x2 = 150.0
	cat.position = Vector2(136.0, 250.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 232.0, 1)
	cat.direction = 1.0
	cat.change_state(Cat.CatState.WALL_CLING)
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_START, { "mouse_pos": cat.position })
	assert(cat.current_state == Cat.CatState.DRAG, "DRAG 拖拽应瞬间中断附着转入 DRAG")
	assert(cat.current_wall_attachment == null, "附着数据已清空")
	cmd_mgr.send_command(CommandManager.CatCommand.DRAG_END, { "throw_velocity": Vector2.ZERO })

	cat.position = Vector2(136.0, 250.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 200.0, 300.0, SurfaceClass.Orientation.LEFT, -1, 232.0, 1)
	cat.change_state(Cat.CatState.WALL_CLING)
	cmd_mgr.send_command(CommandManager.CatCommand.WALL_RELEASE)
	assert(cat.current_state == Cat.CatState.FALL, "WALL_RELEASE 指令应立即脱手进入 FALL")
	assert(cat.current_wall_attachment == null, "附着数据已清空")
	print("[PASS] 测试 79: 用户 DRAG 拖拽与 G 释放指令瞬间脱落验证成功")

	# 测试 80: AUTO 模式停顿 0.5s 自动往上爬与长墙超时脱落
	cat.current_mode = Cat.ControlMode.AUTO
	cat.position = Vector2(136.0, 250.0)
	cat.current_wall_attachment = WallAttachmentClass.new("win_wall_l", 150.0, 100.0, 800.0, SurfaceClass.Orientation.LEFT, -1, 232.0, 1)
	cat.direction = 1.0
	cat.auto_wall_pause_timer = 0.5
	cat.auto_wall_climb_timer = 0.0
	cat.change_state(Cat.CatState.WALL_CLING)
	cat.update_state(0.2)
	assert(cat.current_state == Cat.CatState.WALL_CLING, "停顿时间内保持附着静止")
	cat.update_state(0.4) # 累计超过 0.5s
	assert(cat.current_state == Cat.CatState.WALL_CLIMB and cat.current_wall_climb_dir == Cat.WallClimbDirection.UP, "停顿结束后自动向上爬")
	cat.update_state(cat.auto_max_wall_climb_duration + 0.1)
	assert(cat.current_state == Cat.CatState.FALL, "长墙爬行超时后安全自动脱落")
	print("[PASS] 测试 80: AUTO 模式停顿自动爬行与长墙超时脱落验证成功")

	# ========== T20A Adaptive Cat Scale & CatMetrics 单元测试 ==========
	var CatMetricsClass = load("res://scripts/cat/cat_metrics.gd")
	var CatBodyProfileClass = load("res://scripts/cat/cat_body_profile.gd")

	# 测试 81: CatBodyProfile 与 CatMetrics 数据结构与归一化计算
	var c_profile = CatBodyProfileClass.new()
	assert(c_profile.raw_width == 64.0 and c_profile.raw_height == 64.0, "原始贴图规格为 64x64")
	assert(c_profile.normalized_body_width > 0.5 and c_profile.normalized_body_height > 0.5, "归一化身体尺寸合理")
	var c_metrics = CatMetricsClass.new(c_profile)
	assert(c_metrics.visual_width == 64.0 and c_metrics.visual_height == 64.0, "默认 scale 1.0 时可视宽高等于原始尺寸")
	assert(c_metrics.to_dict().has("metrics_revision"), "to_dict 序列化包含 revision")
	print("[PASS] 测试 81: CatBodyProfile 与 CatMetrics 数据结构与归一化计算验证成功")

	# 测试 82: 自适应 Base Scale 计算与多显示器高度 Clamp
	var bs_1080 = CatMetricsClass.calc_base_scale_from_screen_height(1080.0)
	assert(absf(bs_1080 - (108.0 / 64.0)) < 0.001, "1080p 下目标高度 108px，base_scale = 1.6875")
	var bs_1440 = CatMetricsClass.calc_base_scale_from_screen_height(1440.0)
	assert(absf(bs_1440 - (144.0 / 64.0)) < 0.001, "1440p 下目标高度 144px，base_scale = 2.25")
	var bs_4k = CatMetricsClass.calc_base_scale_from_screen_height(2160.0)
	assert(absf(bs_4k - (180.0 / 64.0)) < 0.001, "4K 屏幕目标高度 Clamp 至 MAX_CAT_VISUAL_HEIGHT 180px")
	var bs_small = CatMetricsClass.calc_base_scale_from_screen_height(600.0)
	assert(absf(bs_small - (85.0 / 64.0)) < 0.001, "极小屏幕目标高度 Clamp 至 MIN_CAT_VISUAL_HEIGHT 85px")
	print("[PASS] 测试 82: 自适应 Base Scale 计算与多显示器高度 Clamp 验证成功")

	# 测试 83: User Scale 调节、安全 Clamp (0.70 ~ 1.60) 与异常值回退
	c_metrics.update_scales(1.0, 0.4) # 低于 MIN_USER_SCALE (0.70)
	assert(c_metrics.user_scale == 0.70, "低于下限时 Clamp 至 0.70")
	c_metrics.update_scales(1.0, 2.5) # 高于 MAX_USER_SCALE (1.60)
	assert(c_metrics.user_scale == 1.60, "高于上限时 Clamp 至 1.60")
	c_metrics.update_scales(1.0, NAN)
	assert(c_metrics.user_scale == CatMetricsClass.DEFAULT_USER_SCALE, "NaN 输入安全回退默认值")
	print("[PASS] 测试 83: User Scale 调节、安全 Clamp 与异常值回退验证成功")

	# 测试 84: Scale 0.8 下物理与着陆几何变化
	c_metrics.update_scales(1.0, 0.8)
	var m_prev_rev: int = int(c_metrics.metrics_revision)
	assert(absf(c_metrics.final_scale - 0.8) < 0.001, "final_scale 精确为 0.8")
	assert(absf(c_metrics.visual_height - 64.0 * 0.8) < 0.01, "visual_height 随 scale 缩放")
	assert(c_metrics.body_width < 52.0 and absf(c_metrics.grab_point_offset_y) < 20.0, "物理几何尺寸等比缩小")
	print("[PASS] 测试 84: Scale 0.8 下物理与着陆几何变化验证成功")

	# 测试 85: Scale 1.0 下完整几何与锚点对称性
	c_metrics.update_scales(1.0, 1.0)
	assert(c_metrics.grab_point_offset_x > 0.0, "抓取偏移为正数")
	var l_pt = c_metrics.get_mouse_passthrough_polygon(Vector2(100.0, 100.0))
	assert(l_pt.size() == 4, "鼠标穿透多边形为4个顶点")
	assert(absf((l_pt[1].x - 100.0) - (100.0 - l_pt[0].x)) < 0.001, "左右点击区域严格对称")
	print("[PASS] 测试 85: Scale 1.0 下完整几何与锚点对称性验证成功")

	# 测试 86: Scale 1.2 下 Edge Grab 与 Climb-Up 几何适配
	cat.set_user_scale(1.2)
	var cat_m: RefCounted = cat.get("metrics")
	assert(absf(float(cat_m.user_scale) - 1.2) < 0.001, "小猫成功应用 user_scale 1.2")
	assert(cat.edge_hang_offset_y > 18.0 and cat.grab_point_offset_x > 12.0, "抓取与悬挂偏移自动放大")
	var gp_l := cat.get_left_grab_point()
	var gp_r := cat.get_right_grab_point()
	assert(gp_l.x < cat.position.x and gp_r.x > cat.position.x, "左右抓点对称分布在小猫两侧")
	print("[PASS] 测试 86: Scale 1.2 下 Edge Grab 与 Climb-Up 几何适配验证成功")

	# 测试 87: Scale 1.5 下平台与墙面门槛自动提升
	cat.set_user_scale(1.5)
	var min_plat_15: float = float(cat.get("metrics").min_platform_length)
	cat.set_user_scale(1.0)
	var min_plat_10: float = float(cat.get("metrics").min_platform_length)
	assert(min_plat_15 > min_plat_10 * 1.35, "Scale 1.5 下最小平台长度门槛自动提升")
	print("[PASS] 测试 87: Scale 1.5 下平台与墙面门槛自动提升验证成功")

	# 测试 88: Metrics 变更触发 metrics_changed 与 NavigationGraph 重建
	var nav_graph_rebuilt := false
	var graph_test = PlatformNavigationGraphClass.new(cat)
	graph_test.surface_world_model = surf_model
	assert(graph_test.pending_build == false, "初始状态无待构建")
	cat.adjust_user_scale(0.1)
	assert(graph_test.pending_build == true, "Metrics 变更自动触发 NavigationGraph 重建请求")
	print("[PASS] 测试 88: Metrics 变更触发 metrics_changed 与 NavigationGraph 重建验证成功")

	# 测试 89: 运行时缩放突变安全策略 (挂墙/翻越脱落与地面贴合)
	cat.change_state(Cat.CatState.WALL_CLING)
	cat.set_user_scale(1.1)
	assert(cat.current_state == Cat.CatState.FALL, "挂墙时 Scale 改变触发安全脱落进入 FALL")
	# 落地贴合测试
	cat.is_grounded = true
	cat.current_surface = plat_top
	cat.current_surface_id = "win_top"
	cat.position = Vector2(200.0, plat_top.y1)
	var prev_foot_y: float = float(cat.get_foot_position().y)
	cat.set_user_scale(1.3)
	assert(absf(float(cat.get_foot_position().y) - prev_foot_y) < 0.1, "Scale 调整后脚底无缝贴合平台表面")
	print("[PASS] 测试 89: 运行时缩放突变安全策略与地面贴合验证成功")

	# 测试 90: Mouse Passthrough 多边形与 Area2D Hitbox 动态跟随
	var col_shape: CollisionShape2D = cat.get_node_or_null("Area2D/CollisionShape2D")
	assert(col_shape and col_shape.shape is RectangleShape2D, "Hitbox 节点存在")
	var cur_m: RefCounted = cat.get("metrics")
	assert(absf(float(col_shape.shape.size.x) - float(cur_m.hitbox_size.x)) < 0.01, "碰撞区大小跟随 CatMetrics")
	var poly = cur_m.get_mouse_passthrough_polygon(cat.position)
	assert(poly.size() == 4, "鼠标穿透多边形顶点正确")
	print("[PASS] 测试 90: Mouse Passthrough 多边形与 Area2D Hitbox 动态跟随验证成功")

	fusion_builder.queue_free()
	vis_model.queue_free()
	ui_model.queue_free()
	surf_model.queue_free()
	bridge.stop_server(); bridge.queue_free()
	world_model.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	planner.queue_free()
	print("========== T20A Adaptive Cat Scale & CatMetrics 单元测试全部通过 (共90项测试) ==========")
	quit(0)









