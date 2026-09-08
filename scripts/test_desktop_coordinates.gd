extends SceneTree

class CoordinateMain:
	extends "res://scripts/main.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = CoordinateMain.new()
	var cat := Node2D.new()
	cat.name = "Cat"
	main.add_child(cat)
	root.add_child(main)
	var failures := 0
	root.borderless = true
	for screen in DisplayServer.get_screen_count():
		main.current_target_screen = screen
		var rect := DisplayServer.screen_get_usable_rect(screen)
		root.position = rect.position
		root.size = rect.size
		await create_timer(0.2).timeout
		var info: Dictionary = main.get_overlay_info()
		var expected := root.position - DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
		var ok: bool = info.screen_pos == expected
		print("PASS " if ok else "FAIL ", "desktop origin screen ", screen)
		if not ok: failures += 1
		print(JSON.stringify({"screen": screen, "hwnd": info.window_handle,
			"x": info.screen_pos.x, "y": info.screen_pos.y,
			"width": info.width, "height": info.height}))
		await create_timer(3).timeout
		# Simulate the native window's transient two-pixel resize during runtime.
		root.size = rect.size - Vector2i(0, 2)
		root.position = rect.position + Vector2i(0, 2)
		await create_timer(0.2).timeout
		var transient: Dictionary = main.get_overlay_info()
		var stable: bool = transient.screen_pos == expected and transient.width == rect.size.x and transient.height == rect.size.y
		print("PASS " if stable else "FAIL ", "work area ignores transient window geometry on screen ", screen)
		if not stable: failures += 1
	quit(1 if failures else 0)
