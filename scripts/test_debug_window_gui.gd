extends SceneTree

class TestMain:
	extends "res://scripts/main.gd"
	func _try_start_perception_service() -> void: pass

var failures := 0
const OUTPUT := "res://Walkthroughes/screenshots/20260905_屏幕猫爬架感知与渲染修正/"

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = TestMain.new()
	var cat = load("res://scenes/cat.tscn").instantiate()
	cat.name = "Cat"
	main.add_child(cat)
	root.add_child(main)
	await process_frame
	main.external_bridge.stop_server()
	main.set_process(false)
	cat.set_process(false)
	cat.set_physics_process(false)
	main.screen_exploration_controller.set_process(false)
	var before: PackedVector2Array = main._build_stitched_passthrough_polygon(cat.position)
	var model = main.cat_physics_world_model
	var data := {"v": 1, "type": "t25_perception_snapshot", "session_id": "gui-fixture", "revision": 1, "surfaces": {"hybrid": []}}
	model.apply_snapshot(data)
	main.surface_fusion_builder.execute_fusion()
	main.toggle_debug_window()
	await create_timer(0.4).timeout
	check(main.debug_window.visible, "independent window opens")
	check(not main.debug_window.transparent and not main.debug_window.borderless, "debug window uses ordinary opaque frame")
	check(not main.surface_world_model.debug_draw_enabled and not model.is_enabled, "main overlay drawing stays disabled")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	check(main.debug_window.get_texture().get_image().save_png(OUTPUT + "01_独立调试窗口_等待采集.png") == OK, "waiting state screenshot saved")
	var image := Image.create(640, 360, false, Image.FORMAT_RGB8)
	image.fill(Color("eeeeee"))
	image.fill_rect(Rect2i(100, 150, 250, 30), Color("303030"))
	var info: Dictionary = main.get_overlay_info()
	var scale_x: float = info.width / 640.0
	var scale_y: float = info.height / 360.0
	data.revision = 2
	data.debug_preview = {"png_base64": Marshalls.raw_to_base64(image.save_png_to_buffer()), "width": info.width, "height": info.height}
	data.surfaces.hybrid = [{"id": "fixture", "type": "PLATFORM", "x1": 100 * scale_x, "x2": 350 * scale_x, "y1": 150 * scale_y, "y2": 150 * scale_y}]
	model.apply_snapshot(data)
	main.surface_fusion_builder.execute_fusion()
	cat.position = Vector2(220 * scale_x, 150 * scale_y) - cat.foot_offset
	main.debug_window.size = Vector2i(1100, 700)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	check(main.debug_window.canvas.drawn_surface_count == main.surface_world_model.surfaces_by_id.size(), "debug renders actual fused world")
	check(main.debug_window.get_texture().get_image().save_png(OUTPUT + "02_独立调试窗口_合成平台与脚底_缩放.png") == OK, "resized fixture screenshot saved")
	main.toggle_debug_window()
	check(not main.debug_window.visible, "toggle closes debug window")
	check(main.get_debug_window_handle() == "", "hidden debug window has no native handle")
	check(model.latest_revision == 2 and not model.hybrid_surfaces.is_empty(), "closing preserves perception")
	check(main._build_stitched_passthrough_polygon(Vector2.ZERO).size() == before.size(), "debug mode preserves body-only polygon")
	main.toggle_debug_window()
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	main.debug_window._on_window_input(key)
	check(not main.debug_window.visible, "V closes focused debug window")
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
