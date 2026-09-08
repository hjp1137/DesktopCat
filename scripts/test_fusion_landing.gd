extends SceneTree

func _init():
	var MainScene = load("res://scenes/main.tscn")
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	# 模拟接收 UIA Button、Text 与 Visual Line
	var ui_snap = {
		"v": 1, "type": "ui_snapshot", "revision": 1,
		"elements": [
			{"id": "btn_chat", "window_id": "win_chat", "control_type": "Button", "x": 300.0, "y": 400.0, "width": 120.0, "height": 40.0},
			{"id": "txt_title", "window_id": "win_chat", "control_type": "Text", "x": 300.0, "y": 250.0, "width": 200.0, "height": 24.0}
		]
	}
	var vis_snap = {
		"v": 1, "type": "visual_snapshot", "revision": 1,
		"geometries": [
			{"id": "line_div", "type": "LINE", "orientation": "HORIZONTAL", "x1": 500.0, "y1": 600.0, "x2": 800.0, "y2": 600.0}
		]
	}
	main.ui_element_world_model.update_from_snapshot(ui_snap)
	main.visual_world_model.update_from_snapshot(vis_snap)
	main.surface_fusion_builder.execute_fusion()

	var surf_model = main.surface_world_model
	main.cat.ground_y = 1000.0
	main.surface_fusion_builder.execute_fusion()
	print("Surfaces in model:", surf_model.surfaces_by_id.keys())
	assert(surf_model.surfaces_by_id.has("uia:btn_chat:top"), "UI Button Surface exists")
	assert(surf_model.surfaces_by_id.has("uia:txt_title:top"), "UI Text Surface exists")
	assert(surf_model.surfaces_by_id.has("vg:line_div"), "Visual Line Surface exists")

	# 测试 1: 小猫从上方下落着陆到 Button
	var cat = main.cat
	cat.ground_y = 1000.0
	cat.position = Vector2(350.0, 320.0) # 在按钮上方
	cat.vertical_velocity = 400.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)

	for i in range(15):
		cat.update_state(0.016)
		if cat.is_grounded: break

	print("Cat landing on Button: is_grounded =", cat.is_grounded, ", current_surface =", cat.current_surface_id, ", Y =", cat.position.y)
	assert(cat.is_grounded == true, "Cat should be grounded on Button")
	assert(cat.current_surface_id == "uia:btn_chat:top", "Cat landed on Button top")

	# 测试 2: 小猫从上方下落着陆到 Text
	cat.ground_y = 1000.0
	cat.position = Vector2(350.0, 180.0) # 在文字上方
	cat.vertical_velocity = 400.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)

	for i in range(15):
		cat.update_state(0.016)
		if cat.is_grounded: break

	print("Cat landing on Text: is_grounded =", cat.is_grounded, ", current_surface =", cat.current_surface_id, ", Y =", cat.position.y)
	assert(cat.is_grounded == true, "Cat should be grounded on Text")
	assert(cat.current_surface_id == "uia:txt_title:top", "Cat landed on Text top")

	# 测试 3: 小猫从上方下落着陆到 Visual Line
	cat.ground_y = 1000.0
	cat.position = Vector2(600.0, 520.0) # 在视觉线上方
	cat.vertical_velocity = 400.0
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)

	for i in range(15):
		cat.update_state(0.016)
		if cat.is_grounded: break



	print("Cat landing on Visual Line: is_grounded =", cat.is_grounded, ", current_surface =", cat.current_surface_id, ", Y =", cat.position.y)
	assert(cat.is_grounded == true, "Cat should be grounded on Visual Line")
	assert(cat.current_surface_id == "vg:line_div", "Cat landed on Visual Line")

	# T25 必须经过真实融合器和 Cat 下落处理，不能手动摆放脚底代替验收。
	var t25 := {"v": 1, "type": "t25_perception_snapshot", "session_id": "landing", "revision": 1,
		"surfaces": {"hybrid": [{"id": "text", "type": "PLATFORM", "x1": 100, "x2": 400, "y1": 320, "y2": 320},
		{"id": "image_right", "type": "WALL", "orientation": "RIGHT", "x1": 500, "x2": 500, "y1": 100, "y2": 700}]}}
	main.external_bridge._handle_t25_perception_snapshot(t25)
	main.surface_fusion_builder.execute_fusion()
	cat.position = Vector2(250, 220)
	cat.vertical_velocity = 200
	cat.is_grounded = false
	cat.change_state(Cat.CatState.FALL)
	for i in range(45):
		cat.update_state(0.016)
		if cat.is_grounded: break
	assert(cat.is_grounded and cat.current_surface_id == "t25:text", "T25 text supports real Cat falling")
	assert(absf(cat.get_foot_position().y - 320.0) < 0.01, "T25 foot contact error below 0.01 px")
	print("PASS T25 real fall contact error=", absf(cat.get_foot_position().y - 320.0))
	cat.position = Vector2(500 + cat.metrics.wall_cling_offset_x, 300)
	cat.is_grounded = false
	cat.wall_cooldown = 0
	cat.vertical_velocity = 100
	cat.change_state(Cat.CatState.FALL)
	cat._check_wall_attach(cat.position, cat.position)
	assert(cat.current_state == Cat.CatState.WALL_CLING, "T25 RIGHT image wall attaches from outside")
	assert(cat.current_wall_attachment.attach_side == 1, "T25 RIGHT wall preserves positive attach side")
	print("PASS T25 RIGHT wall attached outside with side=1")
	print("========== T16/T25 多感知实体着陆物理验证全部成功！ ==========")
	quit(0)
