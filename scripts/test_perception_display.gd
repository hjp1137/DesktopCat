extends SceneTree

const Model = preload("res://scripts/world/cat_physics_world_model.gd")
const Fusion = preload("res://scripts/world/surface_fusion_builder.gd")
const World = preload("res://scripts/world/surface_world_model.gd")
const Main = preload("res://scripts/main.gd")
class BridgeProbe:
	extends "res://scripts/external_bridge.gd"
	var recipients: Array = []
	func _send_json(_data: Dictionary) -> void:
		recipients.append(client)
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _initialize() -> void:
	var model = Model.new()
	var fusion = Fusion.new()
	var world = World.new()
	root.add_child(world)
	root.add_child(fusion)
	fusion.surface_world_model = world
	fusion.cat_physics_world_model = model
	var wall := {"id": "right", "type": "WALL", "orientation": "RIGHT", "x1": 200, "x2": 200, "y1": 100, "y2": 400}
	check(fusion._extract_t25_candidates([wall])[0].orientation == Surface.Orientation.RIGHT, "right wall retains side")
	var data := {"v": 1, "type": "t25_perception_snapshot", "session_id": "first", "revision": 100, "surfaces": {"hybrid": [wall]}}
	model.apply_snapshot(data)
	fusion.execute_fusion()
	data.revision = 101
	data.surfaces.hybrid = []
	model.apply_snapshot(data)
	fusion.execute_fusion()
	check(world.surfaces_by_id.values().filter(func(s): return s.source_type == "HYBRID").is_empty(), "empty confirmed snapshot clears without second grace")
	data.session_id = "restarted"
	data.revision = 1
	check(model.apply_snapshot(data), "service restart accepts revision one")
	var left := Surface.new("edge", "image", "HYBRID", Surface.SurfaceType.WALL, Surface.Orientation.LEFT, 200, 100, 200, 400)
	var right := Surface.new("edge", "image", "HYBRID", Surface.SurfaceType.WALL, Surface.Orientation.RIGHT, 200, 100, 200, 400)
	world.commit_surfaces({"edge": left})
	check(world.commit_surfaces({"edge": right}), "wall direction changes invalidate physics world")
	var bridge = BridgeProbe.new()
	var peer_one = StreamPeerTCP.new()
	var peer_two = StreamPeerTCP.new()
	bridge.client = peer_two
	bridge._process_client_buffer({"peer": peer_one, "buffer": '{"v":1,"type":"ping"}\n'.to_utf8_buffer()})
	check(bridge.recipients == [peer_one], "reply is routed to requesting peer")
	bridge._process_client_buffer({"peer": peer_two, "buffer": '{"v":1,"type":"ping"}\n'.to_utf8_buffer()})
	check(bridge.recipients == [peer_one, peer_two], "interleaved clients retain their own replies")
	bridge.free()
	var main = Main.new()
	check(main.has_method("toggle_debug_window"), "main exposes independent debug window")
	main.free()
	model.free()
	fusion.free()
	world.free()
	quit(1 if failures else 0)
