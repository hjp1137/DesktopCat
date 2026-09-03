extends Node2D

const MouseControllerClass = preload("res://scripts/mouse_controller.gd")
const MousePerceptionControllerClass = preload("res://scripts/mouse_perception_controller.gd")
const ExternalBridgeClass = preload("res://scripts/external_bridge.gd")
const WindowWorldModelClass = preload("res://scripts/world/window_world_model.gd")
const SurfaceWorldModelClass = preload("res://scripts/world/surface_world_model.gd")
const UIElementWorldModelClass = preload("res://scripts/world/ui_element_world_model.gd")
const VisualWorldModelClass = preload("res://scripts/world/visual_world_model.gd")
const SurfaceFusionBuilderClass = preload("res://scripts/world/surface_fusion_builder.gd")
const PlatformNavigationGraphClass = preload("res://scripts/navigation/platform_navigation_graph.gd")
const AutonomousJumpPlannerClass = preload("res://scripts/navigation/autonomous_jump_planner.gd")
const ScreenExplorationControllerClass = preload("res://scripts/exploration/screen_exploration_controller.gd")
const SurfaceClass = preload("res://scripts/world/surface.gd")

@onready var cat: Node2D = $Cat
var command_manager: CommandManager = null
var mouse_controller: Node = null
var mouse_perception_controller: Node = null
var external_bridge: Node = null
var window_world_model: Node2D = null
var surface_world_model: Node2D = null
var ui_element_world_model: Node2D = null
var visual_world_model: Node2D = null
var surface_fusion_builder: Node2D = null
var platform_navigation_graph: RefCounted = null
var autonomous_jump_planner: Node2D = null
var screen_exploration_controller: Node2D = null
var current_target_screen: int = 0
var perception_service_pid: int = -1
var fallback_timer: float = 0.0
var fallback_demo_spawned: bool = false

func _ready() -> void:




	print("[Main] DesktopCat 启动中...")
	command_manager = CommandManager.new()
	add_child(command_manager)
	if is_instance_valid(cat):
		command_manager.register_cat(cat)
	
	mouse_controller = MouseControllerClass.new()
	mouse_controller.set("command_manager", command_manager)
	mouse_controller.set("cat", cat)
	mouse_controller.set("main_node", self)
	add_child(mouse_controller)
	
	mouse_perception_controller = MousePerceptionControllerClass.new()
	mouse_perception_controller.set("command_manager", command_manager)
	mouse_perception_controller.set("cat", cat)
	mouse_perception_controller.set("main_node", self)
	add_child(mouse_perception_controller)
	
	window_world_model = WindowWorldModelClass.new()
	add_child(window_world_model)
	
	surface_world_model = SurfaceWorldModelClass.new()
	add_child(surface_world_model)
	if is_instance_valid(cat):
		cat.set("surface_world_model", surface_world_model)
		if cat.has_method("on_surface_world_updated"):
			surface_world_model.surface_world_updated.connect(cat.on_surface_world_updated)
	
	ui_element_world_model = UIElementWorldModelClass.new()
	add_child(ui_element_world_model)
	
	visual_world_model = VisualWorldModelClass.new()
	add_child(visual_world_model)

	surface_fusion_builder = SurfaceFusionBuilderClass.new()
	surface_fusion_builder.window_world_model = window_world_model
	surface_fusion_builder.ui_element_world_model = ui_element_world_model
	surface_fusion_builder.visual_world_model = visual_world_model
	surface_fusion_builder.surface_world_model = surface_world_model
	surface_fusion_builder.cat = cat
	add_child(surface_fusion_builder)

	platform_navigation_graph = PlatformNavigationGraphClass.new(cat)
	platform_navigation_graph.surface_world_model = surface_world_model
	add_child(platform_navigation_graph.create_drawer())

	autonomous_jump_planner = AutonomousJumpPlannerClass.new(cat, command_manager, platform_navigation_graph, surface_world_model)
	add_child(autonomous_jump_planner)

	screen_exploration_controller = ScreenExplorationControllerClass.new(cat, command_manager, platform_navigation_graph, surface_world_model, autonomous_jump_planner)
	add_child(screen_exploration_controller)
	autonomous_jump_planner.exploration_controller = screen_exploration_controller

	window_world_model.window_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
	ui_element_world_model.ui_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
	visual_world_model.visual_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
	surface_world_model.surface_world_updated.connect(func(_r): platform_navigation_graph.request_rebuild())
	_on_window_world_updated(0)
	
	external_bridge = ExternalBridgeClass.new()
	external_bridge.set("command_manager", command_manager)
	external_bridge.set("cat", cat)
	external_bridge.set("main_node", self)
	external_bridge.set("window_world_model", window_world_model)
	external_bridge.set("surface_world_model", surface_world_model)
	external_bridge.set("ui_element_world_model", ui_element_world_model)
	external_bridge.set("visual_world_model", visual_world_model)
	external_bridge.set("surface_fusion_builder", surface_fusion_builder)
	external_bridge.set("platform_navigation_graph", platform_navigation_graph)
	external_bridge.set("autonomous_jump_planner", autonomous_jump_planner)
	external_bridge.set("screen_exploration_controller", screen_exploration_controller)

	add_child(external_bridge)





	
	if DisplayServer.get_name() != "headless":
		current_target_screen = get_window().current_screen
		if current_target_screen < 0: current_target_screen = DisplayServer.window_get_current_screen()
	_setup_transparent_overlay()
	_try_start_perception_service()


func _setup_transparent_overlay() -> void:
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	get_viewport().transparent_bg = true
	get_tree().root.transparent_bg = true
	get_tree().root.transparent = true
	var window := get_window()
	window.transparent = true
	window.borderless = true
	window.always_on_top = true
	if DisplayServer.get_name() != "headless":
		var window_id := window.get_window_id()
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, window_id)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, window_id)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, window_id)
		_apply_screen_layout(current_target_screen)
	print("[Main] 透明桌面 Overlay 初始化完成。")

func _apply_screen_layout(screen_idx: int) -> void:
	if mouse_controller and mouse_controller.has_method("cancel_drag"): mouse_controller.cancel_drag()
	var window := get_window()
	screen_idx = clampi(screen_idx, 0, DisplayServer.get_screen_count() - 1)
	current_target_screen = screen_idx
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_idx)
	var screen_pos: Vector2i = usable_rect.position; var screen_size: Vector2i = usable_rect.size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_pos = DisplayServer.screen_get_position(screen_idx); screen_size = DisplayServer.screen_get_size(screen_idx) - Vector2i(0, 1)
	print("[Main] 切换/应用屏幕 ID: %d, 位置=%s, 尺寸=%s" % [screen_idx, screen_pos, screen_size])
	window.position = screen_pos; window.size = screen_size
	if window_world_model and window_world_model.has_method("clear_windows"):
		window_world_model.clear_windows()
	if surface_world_model and surface_world_model.has_method("clear_surfaces"):
		surface_world_model.clear_surfaces()
	if ui_element_world_model and ui_element_world_model.has_method("clear_elements"):
		ui_element_world_model.clear_elements()
	if visual_world_model and visual_world_model.has_method("clear_geometries"):
		visual_world_model.clear_geometries()
	_on_window_world_updated(0)


	if is_instance_valid(cat) and cat.has_method("recalculate_for_display"):
		cat.recalculate_for_display(screen_size.y)
	if is_instance_valid(cat) and cat.has_method("reset_to_ground"):
		var foot_y_off: float = cat.foot_offset.y if "foot_offset" in cat else 26.0
		cat.reset_to_ground(Vector2(screen_size.x / 2.0, screen_size.y - foot_y_off)); update_mouse_passthrough(cat.position)
	if is_instance_valid(screen_exploration_controller):
		screen_exploration_controller.notify_route_cancelled("DISPLAY_SWITCHED")
		screen_exploration_controller.memory.recent_surfaces.clear()
		screen_exploration_controller.last_candidates.clear()


func update_mouse_passthrough(cat_pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless" or (mouse_controller and mouse_controller.get("is_dragging")): return
	if is_instance_valid(cat) and cat.get("metrics") != null:
		DisplayServer.window_set_mouse_passthrough(cat.metrics.get_mouse_passthrough_polygon(cat_pos))
	else:
		var half_w := 32.0; var top_h := 36.0; var bottom_h := 28.0
		var p1 := cat_pos + Vector2(-half_w, -top_h); var p2 := cat_pos + Vector2(half_w, -top_h)
		var p3 := cat_pos + Vector2(half_w, bottom_h); var p4 := cat_pos + Vector2(-half_w, bottom_h)
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array([p1, p2, p3, p4]))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key_event(event):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key_event(event)

func _handle_key_event(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_ESCAPE: print("[Main] 接收到 ESC 键，安全退出。"); get_tree().quit(); return true
		KEY_TAB:
			if is_instance_valid(cat):
				if cat.current_state in [Cat.CatState.WALL_CLING, Cat.CatState.WALL_CLIMB]:
					cat.release_wall("TAB_SWITCH")
				elif cat.current_state == Cat.CatState.CLIMB_UP:
					cat.cancel_climb("TAB_SWITCH")
				elif cat.current_state == Cat.CatState.EDGE_HANG:
					cat.release_edge()
			_apply_screen_layout((current_target_screen + 1) % DisplayServer.get_screen_count())
			return true
		KEY_F8, KEY_MINUS, KEY_EQUAL, KEY_QUOTELEFT, KEY_V, KEY_W:
			if window_world_model and window_world_model.has_method("toggle_debug_draw"):
				window_world_model.toggle_debug_draw()
			return true
		KEY_F9, KEY_B:
			if surface_world_model and surface_world_model.has_method("toggle_debug_draw"):
				surface_world_model.toggle_debug_draw()
			return true
		KEY_F10, KEY_N, KEY_M:
			if is_instance_valid(cat) and cat.has_method("toggle_physics_debug"):
				cat.toggle_physics_debug()
			return true
		KEY_U:
			if is_instance_valid(cat) and cat.current_state in [Cat.CatState.WALL_CLING, Cat.CatState.WALL_CLIMB]:
				command_manager.send_command(CommandManager.CatCommand.WALL_CLIMB_UP)
				return true
			if ui_element_world_model and ui_element_world_model.has_method("toggle_debug_draw"):
				ui_element_world_model.toggle_debug_draw()
			return true
		KEY_F11, KEY_K, KEY_O:
			if ui_element_world_model and ui_element_world_model.has_method("toggle_debug_draw"):
				ui_element_world_model.toggle_debug_draw()
			return true
		KEY_J:
			if is_instance_valid(cat) and cat.current_state in [Cat.CatState.WALL_CLING, Cat.CatState.WALL_CLIMB]:
				command_manager.send_command(CommandManager.CatCommand.WALL_CLIMB_DOWN)
				return true
			if visual_world_model and visual_world_model.has_method("toggle_debug_draw"):
				visual_world_model.toggle_debug_draw()
			return true
		KEY_F12:
			if visual_world_model and visual_world_model.has_method("toggle_debug_draw"):
				visual_world_model.toggle_debug_draw()
			return true
		KEY_H:
			if is_instance_valid(cat) and cat.current_state == Cat.CatState.EDGE_HANG:
				command_manager.send_command(CommandManager.CatCommand.CLIMB_UP)
				return true
			if surface_fusion_builder and surface_fusion_builder.has_method("toggle_debug_diagnostics"):
				surface_fusion_builder.toggle_debug_diagnostics()
			return true
		KEY_F13, KEY_Y:
			if surface_fusion_builder and surface_fusion_builder.has_method("toggle_debug_diagnostics"):
				surface_fusion_builder.toggle_debug_diagnostics()
			return true
		KEY_G:
			if is_instance_valid(cat):
				if cat.current_state in [Cat.CatState.WALL_CLING, Cat.CatState.WALL_CLIMB]:
					command_manager.send_command(CommandManager.CatCommand.WALL_RELEASE)
					return true
				elif cat.current_state in [Cat.CatState.EDGE_HANG, Cat.CatState.CLIMB_UP]:
					command_manager.send_command(CommandManager.CatCommand.RELEASE_EDGE)
					return true
			if platform_navigation_graph and platform_navigation_graph.has_method("toggle_debug_draw"):
				platform_navigation_graph.toggle_debug_draw()
			return true
		KEY_F14:
			if platform_navigation_graph and platform_navigation_graph.has_method("toggle_debug_draw"):
				platform_navigation_graph.toggle_debug_draw()
			return true
		KEY_F15, KEY_X:
			if autonomous_jump_planner and autonomous_jump_planner.has_method("toggle_debug_draw"):
				autonomous_jump_planner.toggle_debug_draw()
			return true
		KEY_F16, KEY_Z:
			if is_instance_valid(cat) and cat.has_method("toggle_edge_grab_debug"):
				cat.toggle_edge_grab_debug()
			return true
		KEY_F17:
			if is_instance_valid(cat) and cat.has_method("toggle_climb_debug"):
				cat.toggle_climb_debug()
			return true
		KEY_F18:
			if is_instance_valid(cat) and cat.has_method("toggle_wall_debug"):
				cat.toggle_wall_debug()
			return true
		KEY_F19:
			if is_instance_valid(cat) and cat.has_method("toggle_metrics_debug"):
				cat.toggle_metrics_debug()
			return true
		KEY_F20:
			if autonomous_jump_planner and autonomous_jump_planner.has_method("toggle_route_debug"):
				autonomous_jump_planner.toggle_route_debug()
			return true
		KEY_F21:
			if screen_exploration_controller and screen_exploration_controller.has_method("toggle_debug_draw"):
				screen_exploration_controller.toggle_debug_draw()
			return true
		KEY_E:
			if screen_exploration_controller and screen_exploration_controller.has_method("trigger_exploration_decision"):
				var ok: bool = screen_exploration_controller.trigger_exploration_decision(true)
				print("[Main] E 键触发自主屏幕探索决策: %s" % ("成功启动" if ok else "未触发(无候选/正在执行)"))
			return true
		KEY_F22:
			if is_instance_valid(cat) and cat.anim_controller and cat.anim_controller.has_method("toggle_debug"):
				cat.anim_controller.toggle_debug()
			return true
		KEY_7:
			if is_instance_valid(cat) and cat.anim_controller and cat.anim_controller.has_method("toggle_showcase"):
				cat.anim_controller.toggle_showcase()
			return true
		KEY_BRACKETLEFT:
			if is_instance_valid(cat) and cat.has_method("adjust_user_scale"):
				cat.adjust_user_scale(-0.1)
			return true
		KEY_BRACKETRIGHT:
			if is_instance_valid(cat) and cat.has_method("adjust_user_scale"):
				cat.adjust_user_scale(0.1)
			return true
		KEY_BACKSLASH:
			if is_instance_valid(cat) and cat.has_method("reset_user_scale"):
				cat.reset_user_scale()
			return true
		KEY_P, KEY_R:
			if autonomous_jump_planner and autonomous_jump_planner.has_method("try_plan_traversal"):
				var ok: bool = autonomous_jump_planner.try_plan_traversal()
				print("[Main] P/R 键触发自主路线规划: %s" % ("成功启动" if ok else "未触发(条件未满足/无有效边/冷却中)"))
			return true
		KEY_T:
			if platform_navigation_graph and platform_navigation_graph.has_method("print_current_nav_summary"):
				platform_navigation_graph.print_current_nav_summary()
			return true



		KEY_C: if mouse_perception_controller and mouse_perception_controller.has_method("toggle_debug_follow"): mouse_perception_controller.toggle_debug_follow(); return true
		KEY_1: command_manager.send_command(CommandManager.CatCommand.STOP); return true
		KEY_2: command_manager.send_command(CommandManager.CatCommand.WALK_LEFT); return true
		KEY_3: command_manager.send_command(CommandManager.CatCommand.WALK_RIGHT); return true
		KEY_4: command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO); return true
		KEY_5: command_manager.send_command(CommandManager.CatCommand.JUMP); return true
		KEY_6: command_manager.send_command(CommandManager.CatCommand.RUN_LEFT); return true
		KEY_7: command_manager.send_command(CommandManager.CatCommand.RUN_RIGHT); return true
		KEY_8: command_manager.send_command(CommandManager.CatCommand.SIT); return true
		KEY_9: command_manager.send_command(CommandManager.CatCommand.SLEEP); return true
		KEY_0: command_manager.send_command(CommandManager.CatCommand.WAKE); return true
	return false

func _on_window_world_updated(_rev: int) -> void:
	if is_instance_valid(surface_fusion_builder):
		surface_fusion_builder.execute_fusion()





func get_overlay_info() -> Dictionary:
	var window := get_window()
	var sz: Vector2i = window.size if window else Vector2i(1920, 1080)
	var pos: Vector2i = window.position if window else Vector2i.ZERO
	var wh: String = ""
	if DisplayServer.get_name() != "headless":
		var handle = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
		wh = "0x%X" % handle
	return {
		"screen_index": current_target_screen,
		"screen_pos": pos,
		"width": sz.x,
		"height": sz.y,
		"window_handle": wh
	}

func _process(delta: float) -> void:
	if not fallback_demo_spawned and DisplayServer.get_name() != "headless":
		fallback_timer += delta
		if fallback_timer >= 3.0:
			fallback_demo_spawned = true
			_spawn_fallback_demo_surfaces()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_cleanup_perception_service()

func _try_start_perception_service() -> void:
	if DisplayServer.get_name() == "headless": return
	if OS.get_name() != "Windows": return
	
	var base_dir: String = OS.get_executable_path().get_base_dir()
	var script_candidates = [
		base_dir.path_join("../tools/perception/perception_service.py"),
		base_dir.path_join("tools/perception/perception_service.py"),
		ProjectSettings.globalize_path("res://tools/perception/perception_service.py")
	]
	var target_script: String = ""
	for c in script_candidates:
		if FileAccess.file_exists(c):
			target_script = c
			break
	
	if target_script == "":
		print("[Main] 未检测到本地感知脚本，使用纯单机模式运行")
		return

	# 优先通过 pythonw.exe 静默启动感知服务 (避免弹出黑色控制台黑框)
	var pid: int = OS.create_process("pythonw.exe", [target_script])
	if pid <= 0:
		pid = OS.create_process("python.exe", [target_script])
	
	if pid > 0:
		perception_service_pid = pid
		print("[Main] 已成功拉起后台桌面感知服务 (PID: %d): %s" % [pid, target_script])
	else:
		print("[Main] 尝试拉起感知服务失败，请确保 python 已配置于环境变量")

func _cleanup_perception_service() -> void:
	if perception_service_pid > 0:
		print("[Main] 正在终止感知服务进程: %d" % perception_service_pid)
		OS.kill(perception_service_pid)
		perception_service_pid = -1

func _spawn_fallback_demo_surfaces() -> void:
	if surface_world_model == null: return
	# 若已经有外部窗口实体接入 (表面数量 > 4)，则无需注入演示平台
	if surface_world_model.surfaces.size() > 4: return
	
	var vp: Vector2 = Vector2(get_window().size) if get_window() else Vector2(1280, 720)
	if vp.x <= 100 or vp.y <= 100: vp = Vector2(1920, 1080)
	
	var shelf_y: float = vp.y * 0.55
	var shelf_x1: float = vp.x * 0.35
	var shelf_x2: float = vp.x * 0.65
	
	print("[Main] 纯单机环境：自动注入演示桌面平台与垂直攀爬柱以供探索攀爬")
	var surf_top = SurfaceClass.new("demo:shelf:top", "demo", "WINDOW", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, shelf_x1, shelf_y, shelf_x2, shelf_y, true, false, false)
	var surf_left = SurfaceClass.new("demo:shelf:left", "demo", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, shelf_x1, shelf_y, shelf_x1, shelf_y + 180.0, false, false, true)
	var surf_right = SurfaceClass.new("demo:shelf:right", "demo", "WINDOW", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, shelf_x2, shelf_y, shelf_x2, shelf_y + 180.0, false, false, true)
	
	surface_world_model.add_surface(surf_top)
	surface_world_model.add_surface(surf_left)
	surface_world_model.add_surface(surf_right)
	surface_world_model.surface_world_updated.emit(surface_world_model.surface_revision)


