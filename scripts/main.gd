extends Node2D

@onready var cat: Cat = $Cat

func _ready() -> void:
	print("[Main] DesktopCat 启动中...")
	_setup_transparent_overlay()

func _setup_transparent_overlay() -> void:
	get_tree().root.transparent_bg = true
	var window := get_window()
	
	if DisplayServer.get_name() != "headless":
		var screen := window.current_screen
		if screen < 0:
			screen = DisplayServer.window_get_current_screen()
		var screen_pos := DisplayServer.screen_get_position(screen)
		var screen_size := DisplayServer.screen_get_size(screen)
		
		print("[Main] 识别到屏幕 ID: %d, 位置: %s, 尺寸: %s" % [screen, screen_pos, screen_size])
		
		window.borderless = true
		window.transparent = true
		window.always_on_top = true
		window.position = screen_pos
		window.size = screen_size
		
		if is_instance_valid(cat):
			cat.position = Vector2(screen_size.x / 2.0, screen_size.y / 2.0)
	
	print("[Main] 透明桌面 Overlay 初始化完成。")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			print("[Main] 接收到 ESC 键，触发安全退出。")
			get_tree().quit()
