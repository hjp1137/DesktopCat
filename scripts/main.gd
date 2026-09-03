extends Node2D

const MouseControllerClass = preload("res://scripts/mouse_controller.gd")
const MousePerceptionControllerClass = preload("res://scripts/mouse_perception_controller.gd")
const ExternalBridgeClass = preload("res://scripts/external_bridge.gd")
const WindowWorldModelClass = preload("res://scripts/world/window_world_model.gd")
const SurfaceWorldModelClass = preload("res://scripts/world/surface_world_model.gd")
const UIElementWorldModelClass = preload("res://scripts/world/ui_element_world_model.gd")
const VisualWorldModelClass = preload("res://scripts/world/visual_world_model.gd")
const SurfaceFusionBuilderClass = preload("res://scripts/world/surface_fusion_builder.gd")

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
var current_target_screen: int = 0

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

	window_world_model.window_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
	ui_element_world_model.ui_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
	visual_world_model.visual_world_updated.connect(func(_r): surface_fusion_builder.request_fusion())
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

	add_child(external_bridge)



	
	if DisplayServer.get_name() != "headless":
		current_target_screen = get_window().current_screen
		if current_target_screen < 0: current_target_screen = DisplayServer.window_get_current_screen()
	_setup_transparent_overlay()


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


	if is_instance_valid(cat) and cat.has_method("reset_to_ground"):
		cat.reset_to_ground(Vector2(screen_size.x / 2.0, screen_size.y - 48.0)); update_mouse_passthrough(cat.position)


func update_mouse_passthrough(cat_pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless" or (mouse_controller and mouse_controller.get("is_dragging")): return
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
		KEY_TAB: _apply_screen_layout((current_target_screen + 1) % DisplayServer.get_screen_count()); return true
		KEY_F8, KEY_MINUS, KEY_EQUAL, KEY_QUOTELEFT, KEY_V, KEY_W:
			if window_world_model and window_world_model.has_method("toggle_debug_draw"):
				window_world_model.toggle_debug_draw()
			return true
		KEY_F9, KEY_B, KEY_P:
			if surface_world_model and surface_world_model.has_method("toggle_debug_draw"):
				surface_world_model.toggle_debug_draw()
			return true
		KEY_F10, KEY_N, KEY_M:
			if is_instance_valid(cat) and cat.has_method("toggle_physics_debug"):
				cat.toggle_physics_debug()
			return true
		KEY_F11, KEY_K, KEY_O, KEY_U:
			if ui_element_world_model and ui_element_world_model.has_method("toggle_debug_draw"):
				ui_element_world_model.toggle_debug_draw()
			return true
		KEY_F12, KEY_J:
			if visual_world_model and visual_world_model.has_method("toggle_debug_draw"):
				visual_world_model.toggle_debug_draw()
			return true
		KEY_F13, KEY_H, KEY_Y:
			if surface_fusion_builder and surface_fusion_builder.has_method("toggle_debug_diagnostics"):
				surface_fusion_builder.toggle_debug_diagnostics()
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


