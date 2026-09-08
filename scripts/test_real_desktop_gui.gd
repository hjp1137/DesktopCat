extends SceneTree

# 实机验收入口：普通主场景与真实采集服务；文件仅触发截图，不注入感知结果。
const OUTPUT := "res://Walkthroughes/screenshots/20260905_屏幕猫爬架感知与渲染修正/"
const REQUEST := "user://desktop_acceptance_request.txt"
var main: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if "--isolate-perception" in OS.get_cmdline_user_args():
		main.screen_exploration_controller.set_process(false)
		main.cat.set_process(false)
		main.cat.set_physics_process(false)
	await create_timer(1.0).timeout
	main.toggle_debug_window()
	main.debug_window.position = Vector2i(1000, 120)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	print("ACCEPTANCE_REQUEST=", ProjectSettings.globalize_path(REQUEST))
	while is_instance_valid(main):
		await create_timer(0.2).timeout
		if not FileAccess.file_exists(REQUEST): continue
		var label := FileAccess.get_file_as_string(REQUEST).strip_edges()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REQUEST))
		if label.is_empty(): continue
		if label == "quit":
			main.queue_free()
			await process_frame
			quit(0)
			return
		# 桌宠主体被区域裁剪后系统可能停止自动绘帧；显式渲染再读取视口。
		main.debug_window.canvas.queue_redraw()
		await process_frame
		RenderingServer.force_draw(false)
		var error: int = main.debug_window.get_texture().get_image().save_png(OUTPUT + label + ".png")
		assert(error == OK, "真实感知窗口截图保存成功")
		var model = main.cat_physics_world_model
		if model.debug_preview.has("png_base64"):
			var raw := Image.new()
			assert(raw.load_png_from_buffer(Marshalls.base64_to_raw(model.debug_preview.png_base64)) == OK)
			assert(raw.save_png(OUTPUT + label + "_原始采集.png") == OK)
		var surfaces: Array = []
		for surface in main.surface_world_model.surfaces_by_id.values():
			surfaces.append({"id": surface.id, "start": [surface.get_start().x, surface.get_start().y],
				"end": [surface.get_end().x, surface.get_end().y], "walkable": surface.walkable})
		var result := {"revision": model.latest_revision, "overlay": main.get_overlay_info(),
			"surfaces": surfaces, "debug_visible": main.debug_window.visible,
			"metrics": model.metrics, "isolated": "--isolate-perception" in OS.get_cmdline_user_args()}
		FileAccess.open(OUTPUT + label + ".json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
		print("ACCEPTANCE_CAPTURE=", label, " revision=", model.latest_revision)
