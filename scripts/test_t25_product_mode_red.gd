extends SceneTree

const MainClass = preload("res://scripts/main.gd")
const T25ModelClass = preload("res://scripts/world/cat_physics_world_model.gd")
const SurfaceWorldClass = preload("res://scripts/world/surface_world_model.gd")
const SurfaceClass = preload("res://scripts/world/surface.gd")
const CommandManagerClass = preload("res://scripts/command_manager.gd")

class FakeCat:
	extends Node2D
	var metrics = null

var failures: int = 0

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[RED] ", message)

func _key(keycode: Key, ctrl := false, alt := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt
	return event

func _initialize() -> void:
	var main = MainClass.new()
	var cat = FakeCat.new()
	var world = SurfaceWorldClass.new()
	var t25 = T25ModelClass.new()
	var commands = CommandManagerClass.new()
	main.cat = cat
	main.surface_world_model = world
	main.cat_physics_world_model = t25
	main.command_manager = commands
	world.surfaces_by_id["content"] = SurfaceClass.new(
		"content", "hybrid", "HYBRID", SurfaceClass.SurfaceType.PLATFORM,
		SurfaceClass.Orientation.TOP, 20.0, 120.0, 220.0, 120.0, true, true)

	_expect(main.show_debug_lines == false,
		"产品模式默认不显示 Surface 调试线")
	_expect(world.debug_draw_enabled == false,
		"SurfaceWorldModel 默认关闭调试绘制")
	var polygon := main._build_stitched_passthrough_polygon(Vector2(300, 300))
	_expect(polygon.size() == 4,
		"鼠标穿透区域应始终只有小猫自身简单四边形")

	var dispatched: Array = []
	commands.command_dispatched.connect(func(cmd, _payload): dispatched.append(cmd))
	t25.debug_layer_mode = 6
	main._handle_key_event(_key(KEY_1))
	_expect(dispatched == [CommandManager.CatCommand.STOP],
		"普通数字键 1 应继续执行既有 STOP 控制")
	_expect(t25.debug_layer_mode == 6,
		"普通数字键不应切换 T25 调试图层")

	dispatched.clear()
	main._handle_key_event(_key(KEY_1, true, true))
	_expect(t25.debug_layer_mode == 1,
		"Ctrl+Alt+数字键应切换 T25 调试图层")
	_expect(dispatched.is_empty(),
		"T25 组合快捷键不应同时派发小猫控制命令")
	print("T25 product mode RED failures: %d" % failures)
	main.free()
	cat.free()
	world.free()
	t25.free()
	commands.free()
	quit(1 if failures > 0 else 0)
