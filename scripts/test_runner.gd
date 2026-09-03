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


	fusion_builder.queue_free()

	vis_model.queue_free()
	ui_model.queue_free()
	surf_model.queue_free()
	bridge.stop_server(); bridge.queue_free()
	world_model.queue_free()
	cat.queue_free(); cmd_mgr.queue_free()
	print("========== T17 Platform Navigation Graph 单元测试全部通过 ==========")
	quit(0)








