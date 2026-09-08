extends SceneTree

const BridgeClass = preload("res://scripts/external_bridge.gd")
const T25ModelClass = preload("res://scripts/world/cat_physics_world_model.gd")
const SurfaceWorldClass = preload("res://scripts/world/surface_world_model.gd")
const FusionClass = preload("res://scripts/world/surface_fusion_builder.gd")
const NavGraphClass = preload("res://scripts/navigation/platform_navigation_graph.gd")

var failures: int = 0

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		printerr("[RED] ", message)

func _has_property(object: Object, property_name: String) -> bool:
	for item in object.get_property_list():
		if str(item.get("name", "")) == property_name:
			return true
	return false

func _contains_hybrid_geometry(world: Node) -> bool:
	for surface in world.surfaces_by_id.values():
		if absf(surface.x1 - 100.0) < 0.1 and absf(surface.y1 - 220.0) < 0.1 \
			and absf(surface.x2 - 260.0) < 0.1:
			return true
	return false

func _initialize() -> void:
	var world = SurfaceWorldClass.new()
	var t25 = T25ModelClass.new()
	var fusion = FusionClass.new()
	var bridge = BridgeClass.new()
	var nav = NavGraphClass.new()
	root.add_child(world)
	root.add_child(t25)
	root.add_child(fusion)

	fusion.surface_world_model = world
	bridge.surface_world_model = world
	bridge.surface_fusion_builder = fusion
	bridge.cat_physics_world_model = t25
	bridge.platform_navigation_graph = nav
	var supports_t25_source := _has_property(fusion, "cat_physics_world_model")
	_expect(supports_t25_source, "SurfaceFusionBuilder 应声明 T25 物理来源")
	if supports_t25_source:
		fusion.set("cat_physics_world_model", t25)
	world.surface_world_updated.connect(func(_revision): nav.request_rebuild())

	var snapshot := {
		"v": 1, "type": "t25_perception_snapshot", "revision": 1,
		"mode": "hybrid",
		"surfaces": {
			"legacy": [], "opencv": [],
			"hybrid": [{"id": "hy_platform", "type": "PLATFORM",
				"x1": 100.0, "y1": 220.0, "x2": 260.0, "y2": 220.0,
				"confidence": 0.95, "source": "hybrid"}]
		},
		"debug_layers": {}, "metrics": {}
	}
	bridge._handle_t25_perception_snapshot(snapshot)
	fusion._process(1.0)

	_expect(_contains_hybrid_geometry(world),
		"Hybrid 快照表面应进入实际 SurfaceWorldModel")
	_expect(nav.pending_build,
		"Hybrid 几何变更应沿 SurfaceWorldModel 信号触发导航重建")
	print("T25 physical source RED failures: %d" % failures)
	bridge.free()
	fusion.free()
	t25.free()
	world.free()
	quit(1 if failures > 0 else 0)
