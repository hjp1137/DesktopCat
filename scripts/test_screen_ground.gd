extends SceneTree

class SupportedCat:
	extends Node2D
	var ground_y: float = 312.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(2880, 1812)
	var world = load("res://scripts/world/surface_world_model.gd").new()
	var fusion = load("res://scripts/world/surface_fusion_builder.gd").new()
	var cat := SupportedCat.new()
	root.add_child(world)
	root.add_child(fusion)
	root.add_child(cat)
	fusion.surface_world_model = world
	fusion.cat = cat
	var failures := 0
	for support_y in [312.0, 320.0, 980.0]:
		cat.ground_y = support_y
		fusion.execute_fusion()
		var ground = world.get_surface_by_id("screen:ground")
		var ok: bool = is_equal_approx(ground.y1, 1812.0)
		print("PASS " if ok else "FAIL ", "screen floor stays at 1812 while cat support is ", support_y, " actual=", ground.y1)
		if not ok: failures += 1
	root.size = Vector2i(1920, 1080)
	fusion.execute_fusion()
	var resized: bool = is_equal_approx(world.get_surface_by_id("screen:ground").y1, 1080.0)
	print("PASS " if resized else "FAIL ", "display resize updates screen floor")
	if not resized: failures += 1
	quit(1 if failures else 0)
