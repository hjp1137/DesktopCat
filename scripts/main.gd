extends Node2D

const MouseControllerClass = preload("res://scripts/mouse_controller.gd")
const MousePerceptionControllerClass = preload("res://scripts/mouse_perception_controller.gd")
const ExternalBridgeClass = preload("res://scripts/external_bridge.gd")

@onready var cat: Node2D = $Cat
var command_manager: CommandManager = null
var mouse_controller: Node = null
var mouse_perception_controller: Node = null
var external_bridge: Node = null
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
	
	external_bridge = ExternalBridgeClass.new()
	external_bridge.set("command_manager", command_manager)
	external_bridge.set("cat", cat)
	external_bridge.set("main_node", self)
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
	if is_instance_valid(cat) and cat.has_method("reset_to_ground"):
		cat.reset_to_ground(Vector2(screen_size.x / 2.0, screen_size.y - 48.0)); update_mouse_passthrough(cat.position)

func update_mouse_passthrough(cat_pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless" or (mouse_controller and mouse_controller.get("is_dragging")): return
	var half_w := 32.0; var top_h := 36.0; var bottom_h := 28.0
	var p1 := cat_pos + Vector2(-half_w, -top_h); var p2 := cat_pos + Vector2(half_w, -top_h)
	var p3 := cat_pos + Vector2(half_w, bottom_h); var p4 := cat_pos + Vector2(-half_w, bottom_h)
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array([p1, p2, p3, p4]))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: print("[Main] 接收到 ESC 键，安全退出。"); get_tree().quit()
			KEY_TAB: _apply_screen_layout((current_target_screen + 1) % DisplayServer.get_screen_count())
			KEY_C: if mouse_perception_controller and mouse_perception_controller.has_method("toggle_debug_follow"): mouse_perception_controller.toggle_debug_follow()
			KEY_1: command_manager.send_command(CommandManager.CatCommand.STOP)
			KEY_2: command_manager.send_command(CommandManager.CatCommand.WALK_LEFT)
			KEY_3: command_manager.send_command(CommandManager.CatCommand.WALK_RIGHT)
			KEY_4: command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)
			KEY_5: command_manager.send_command(CommandManager.CatCommand.JUMP)
			KEY_6: command_manager.send_command(CommandManager.CatCommand.RUN_LEFT)
			KEY_7: command_manager.send_command(CommandManager.CatCommand.RUN_RIGHT)
			KEY_8: command_manager.send_command(CommandManager.CatCommand.SIT)
			KEY_9: command_manager.send_command(CommandManager.CatCommand.SLEEP)
			KEY_0: command_manager.send_command(CommandManager.CatCommand.WAKE)

func get_overlay_info() -> Dictionary:
	var window := get_window()
	var sz: Vector2i = window.size if window else Vector2i(1920, 1080)
	return {
		"screen_index": current_target_screen,
		"width": sz.x,
		"height": sz.y
	}

