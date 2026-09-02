extends Node2D

@onready var cat: Node2D = $Cat
var current_target_screen: int = 0

func _ready() -> void:
	print("[Main] DesktopCat 启动中...")
	if DisplayServer.get_name() != "headless":
		current_target_screen = get_window().current_screen
		if current_target_screen < 0:
			current_target_screen = DisplayServer.window_get_current_screen()
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
	var window := get_window()
	var total_screens := DisplayServer.get_screen_count()
	screen_idx = clampi(screen_idx, 0, total_screens - 1)
	current_target_screen = screen_idx
	
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_idx)
	var screen_pos: Vector2i = usable_rect.position
	var screen_size: Vector2i = usable_rect.size
	
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_pos = DisplayServer.screen_get_position(screen_idx)
		screen_size = DisplayServer.screen_get_size(screen_idx) - Vector2i(0, 1)
	
	print("[Main] 切换/应用屏幕 ID: %d, 位置=%s, 尺寸=%s" % [screen_idx, screen_pos, screen_size])
	
	window.position = screen_pos
	window.size = screen_size
	
	if is_instance_valid(cat):
		cat.position = Vector2(screen_size.x / 2.0, screen_size.y / 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			print("[Main] 接收到 ESC 键，触发安全退出。")
			get_tree().quit()
		elif event.keycode == KEY_TAB:
			# 按 TAB 在多显示器之间循环切换
			var next_screen = (current_target_screen + 1) % DisplayServer.get_screen_count()
			_apply_screen_layout(next_screen)
