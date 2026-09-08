extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = preload("res://scripts/world/surface_world_model.gd").new()
	var t25 = preload("res://scripts/world/cat_physics_world_model.gd").new()
	var windows = preload("res://scripts/world/window_world_model.gd").new()
	var fusion = preload("res://scripts/world/surface_fusion_builder.gd").new()
	for node in [world, t25, windows, fusion]: root.add_child(node)
	fusion.surface_world_model = world
	fusion.cat_physics_world_model = t25
	fusion.window_world_model = windows
	windows.apply_snapshot({"v": 1, "type": "window_snapshot", "revision": 1,
		"windows": [{"id": "fallback", "x": 400, "y": 300, "width": 300,
			"height": 200, "z_order": 0}]})
	var snapshot := {"v": 1, "type": "t25_perception_snapshot", "revision": 1,
		"surfaces": {"hybrid": [{"id": "text", "type": "PLATFORM",
			"x1": 100, "y1": 200, "x2": 300, "y2": 200}]}}
	t25.apply_snapshot(snapshot)
	fusion.execute_fusion()
	if not world.surfaces_by_id.has("t25:text"):
		printerr("[FAIL] Fresh T25 must own physics")
		quit(1); return
	# 服务停止发送后没有任何新的快照/融合事件，真实等待既有超时。
	await create_timer(4.15).timeout
	if world.surfaces_by_id.has("t25:text") or not world.surfaces_by_id.has("fallback:top"):
		printerr("[FAIL] Expired T25 must disappear and window fallback must resume without new input")
		quit(1); return
	snapshot.revision = 2
	t25.apply_snapshot(snapshot)
	fusion.request_fusion()
	await create_timer(.1).timeout
	if not world.surfaces_by_id.has("t25:text"):
		printerr("[FAIL] Reconnected T25 must resume physics")
		quit(1); return
	print("[PASS] T25 timeout removes frozen surfaces, resumes windows, and reconnects")
	quit(0)
