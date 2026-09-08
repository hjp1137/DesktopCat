extends SceneTree

var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func drain(peer: StreamPeerTCP) -> String:
	peer.poll()
	var count := peer.get_available_bytes()
	return peer.get_utf8_string(count) if count else ""

func run() -> void:
	var bridge = load("res://scripts/external_bridge.gd").new()
	bridge.port = 47839
	root.add_child(bridge)
	var first := StreamPeerTCP.new()
	var second := StreamPeerTCP.new()
	first.connect_to_host("127.0.0.1", bridge.port)
	second.connect_to_host("127.0.0.1", bridge.port)
	await create_timer(0.15).timeout
	drain(first)
	drain(second)
	first.put_data('{"v":1,"type":"ping"}\n'.to_utf8_buffer())
	await create_timer(0.15).timeout
	check(drain(first).contains('"pong"'), "requesting socket receives pong")
	check(drain(second).is_empty(), "other socket receives no broadcast pong")
	# Switch the active peer, then verify the oversized error also routes back.
	second.put_data('{"v":1,"type":"ping"}\n'.to_utf8_buffer())
	await create_timer(0.15).timeout
	drain(second)
	drain(first)
	first.put_data(("x".repeat(262145) + "\n").to_utf8_buffer())
	await create_timer(0.2).timeout
	check(drain(first).contains("MESSAGE_TOO_LARGE"), "oversized response returns to sending socket")
	check(drain(second).is_empty(), "oversized error is not sent to another socket")
	first.disconnect_from_host()
	second.disconnect_from_host()
	bridge.stop_server()
	quit(1 if failures else 0)
