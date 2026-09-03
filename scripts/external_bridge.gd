class_name ExternalBridge
extends Node

const DEFAULT_PORT: int = 47831
const BIND_ADDRESS: String = "127.0.0.1"
const PROTOCOL_VERSION: int = 1
const MAX_MESSAGE_SIZE: int = 262144
const MAX_BUFFER_SIZE: int = 524288
const MAX_WINDOWS: int = 256

const ALLOWED_COMMANDS: Dictionary = {
	"STOP": CommandManager.CatCommand.STOP,
	"WALK_LEFT": CommandManager.CatCommand.WALK_LEFT,
	"WALK_RIGHT": CommandManager.CatCommand.WALK_RIGHT,
	"RESUME_AUTO": CommandManager.CatCommand.RESUME_AUTO,
	"JUMP": CommandManager.CatCommand.JUMP,
	"RUN_LEFT": CommandManager.CatCommand.RUN_LEFT,
	"RUN_RIGHT": CommandManager.CatCommand.RUN_RIGHT,
	"SIT": CommandManager.CatCommand.SIT,
	"SLEEP": CommandManager.CatCommand.SLEEP,
	"WAKE": CommandManager.CatCommand.WAKE,
	"LOOK_AT_POSITION": CommandManager.CatCommand.LOOK_AT_POSITION,
	"MOVE_TO_POSITION": CommandManager.CatCommand.MOVE_TO_POSITION,
	"CLEAR_TARGET": CommandManager.CatCommand.CLEAR_TARGET
}

var port: int = DEFAULT_PORT
var server: TCPServer = null
var client: StreamPeerTCP = null
var input_buffer: PackedByteArray = PackedByteArray()
var command_manager: CommandManager = null
var cat: Node2D = null
var main_node: Node2D = null
var window_world_model: Node = null


func _ready() -> void:
	start_server(port)

func start_server(bind_port: int = DEFAULT_PORT) -> bool:
	port = bind_port
	server = TCPServer.new()
	var err := server.listen(port, BIND_ADDRESS)
	if err == OK:
		print("[Bridge] Listening on %s:%d" % [BIND_ADDRESS, port])
		return true
	printerr("[Bridge] Failed to listen on %s:%d (error=%d)" % [BIND_ADDRESS, port, err])
	return false

func stop_server() -> void:
	if client:
		_cleanup_client("Server stopping")
	if server:
		server.stop()
		print("[Bridge] Server stopped")

func _process(_delta: float) -> void:
	if not server or not server.is_listening():
		return
	if client == null:
		if server.is_connection_available():
			client = server.take_connection()
			input_buffer.clear()
			print("[Bridge] Client connected")
			_send_hello()
	else:
		if server.is_connection_available():
			var extra := server.take_connection()
			if extra: extra.disconnect_from_host()
		client.poll()
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_cleanup_client("Client disconnected")
			return
		var avail := client.get_available_bytes()
		if avail > 0:
			if input_buffer.size() + avail > MAX_BUFFER_SIZE:
				_send_error("BUFFER_OVERFLOW", "Input buffer limit exceeded")
				_cleanup_client("Buffer overflow")
				return
			var res := client.get_data(avail)
			if res[0] == OK:
				input_buffer.append_array(res[1])
				_process_input_buffer()

func _cleanup_client(reason: String = "") -> void:
	if client:
		client.disconnect_from_host()
		client = null
	input_buffer.clear()
	if is_instance_valid(window_world_model) and window_world_model.has_method("clear_windows"):
		window_world_model.clear_windows()
	if reason != "":
		print("[Bridge] %s" % reason)


func _process_input_buffer() -> void:
	while true:
		var newline_idx := input_buffer.find(10)
		if newline_idx == -1:
			break
		var line_bytes := input_buffer.slice(0, newline_idx)
		input_buffer = input_buffer.slice(newline_idx + 1)
		if line_bytes.size() > MAX_MESSAGE_SIZE:
			_send_error("MESSAGE_TOO_LARGE", "Message exceeded 256KB")
			continue
		var line_str := line_bytes.get_string_from_utf8().strip_edges()
		if line_str == "":
			continue
		_handle_raw_message(line_str)

func _handle_raw_message(msg_str: String) -> void:
	var json := JSON.new()
	var err := json.parse(msg_str)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		_send_error("INVALID_JSON", "Message must be valid JSON object")
		return
	var data: Dictionary = json.data
	if int(data.get("v", 0)) != PROTOCOL_VERSION:
		_send_error("UNSUPPORTED_VERSION", "Expected protocol version 1")
		return
	var mtype := str(data.get("type", ""))
	match mtype:
		"ping": _send_pong()
		"get_status": _send_status()
		"command": _handle_command_message(data)
		"window_snapshot": _handle_window_snapshot(data)
		"surface_snapshot": _send_error("NOT_IMPLEMENTED", "Surface snapshots are reserved for future versions")
		_: _send_error("UNKNOWN_TYPE", "Unknown message type: " + mtype)

func _handle_window_snapshot(data: Dictionary) -> void:
	var raw_windows = data.get("windows", null)
	if typeof(raw_windows) != TYPE_ARRAY:
		_send_error("INVALID_SNAPSHOT", "windows must be an array")
		return
	if raw_windows.size() > MAX_WINDOWS:
		_send_error("TOO_MANY_WINDOWS", "Exceeded MAX_WINDOWS (%d)" % MAX_WINDOWS)
		return
	for item in raw_windows:
		if typeof(item) != TYPE_DICTIONARY:
			_send_error("INVALID_SNAPSHOT", "Window item must be an object")
			return
		if not item.has("id") or not item.has("x") or not item.has("y") or not item.has("width") or not item.has("height"):
			_send_error("INVALID_SNAPSHOT", "Missing window fields")
			return
		var x = item.get("x"); var y = item.get("y"); var w = item.get("width"); var h = item.get("height")
		if not (x is int or x is float) or not (y is int or y is float) or not (w is int or w is float) or not (h is int or h is float):
			_send_error("INVALID_SNAPSHOT", "Window rect fields must be numbers")
			return
		if is_nan(x) or is_nan(y) or is_nan(w) or is_nan(h) or is_inf(x) or is_inf(y) or is_inf(w) or is_inf(h) or w <= 0.0 or h <= 0.0:
			_send_error("INVALID_SNAPSHOT", "Window rect must be valid positive finite numbers")
			return
	if is_instance_valid(window_world_model) and window_world_model.has_method("apply_snapshot"):
		window_world_model.apply_snapshot(data)
	var rev: int = int(data.get("revision", 0))
	_send_json({"v": PROTOCOL_VERSION, "type": "ok", "action": "window_snapshot", "revision": rev})

func _handle_command_message(data: Dictionary) -> void:
	var cmd_name := str(data.get("name", "")).to_upper()
	if not ALLOWED_COMMANDS.has(cmd_name):
		_send_error("UNKNOWN_COMMAND", "Command not allowed: " + cmd_name)
		return
	var cmd_enum: int = ALLOWED_COMMANDS[cmd_name]
	var raw_payload = data.get("payload", {})
	var payload: Dictionary = raw_payload if typeof(raw_payload) == TYPE_DICTIONARY else {}
	if cmd_name in ["LOOK_AT_POSITION", "MOVE_TO_POSITION"]:
		if not payload.has("x") or not payload.has("y"):
			_send_error("INVALID_PAYLOAD", "Position commands require x and y")
			return
		var px = payload.get("x"); var py = payload.get("y")
		if not (px is int or px is float) or not (py is int or py is float) or is_nan(px) or is_nan(py) or is_inf(px) or is_inf(py):
			_send_error("INVALID_PAYLOAD", "Coordinates must be finite numbers")
			return
		payload["target_pos"] = Vector2(float(px), float(py))
	if cmd_name != "MOVE_TO_POSITION" and cmd_name != "LOOK_AT_POSITION":
		print("[Bridge] Command: %s" % cmd_name)
	if is_instance_valid(command_manager):
		command_manager.send_command(cmd_enum, payload)
	_send_json({"v": PROTOCOL_VERSION, "type": "ok", "command": cmd_name})

func _send_hello() -> void:
	var info := _get_overlay_info()
	var rev: int = window_world_model.latest_revision if is_instance_valid(window_world_model) else 0
	_send_json({"v": PROTOCOL_VERSION, "type": "hello", "app": "DesktopCat", "bridge_version": PROTOCOL_VERSION, "latest_revision": rev, "screen": {"index": info.screen_index, "x": info.screen_pos.x, "y": info.screen_pos.y, "width": info.width, "height": info.height}, "overlay": {"width": info.width, "height": info.height}, "window_handle": info.window_handle})

func _send_pong() -> void:
	_send_json({"v": PROTOCOL_VERSION, "type": "pong"})

func _send_status() -> void:
	var c_state: String = "IDLE"
	var c_mode: String = "AUTO"
	if is_instance_valid(cat):
		var st = cat.get("current_state")
		if st != null and st >= 0 and st < Cat.CatState.size():
			c_state = Cat.CatState.keys()[st]
		var md = cat.get("current_mode")
		if md != null and md >= 0 and md < Cat.ControlMode.size():
			c_mode = Cat.ControlMode.keys()[md]
	var info := _get_overlay_info()
	var rev: int = window_world_model.latest_revision if is_instance_valid(window_world_model) else 0
	_send_json({"v": PROTOCOL_VERSION, "type": "status", "cat_state": c_state, "control_mode": c_mode, "latest_revision": rev, "screen": {"index": info.screen_index, "x": info.screen_pos.x, "y": info.screen_pos.y, "width": info.width, "height": info.height}, "overlay": {"width": info.width, "height": info.height}, "window_handle": info.window_handle, "bridge_connected": true})



func _send_error(code: String, message: String) -> void:
	_send_json({"v": PROTOCOL_VERSION, "type": "error", "code": code, "message": message})

func _send_json(dict: Dictionary) -> void:
	if not client or client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var text := JSON.stringify(dict) + "\n"
	client.put_data(text.to_utf8_buffer())

func _get_overlay_info() -> Dictionary:
	var s_idx: int = 0
	var s_pos := Vector2i.ZERO
	var w: int = 1920
	var h: int = 1080
	var wh: String = ""
	if is_instance_valid(main_node) and main_node.has_method("get_overlay_info"):
		return main_node.get_overlay_info()
	return {"screen_index": s_idx, "screen_pos": s_pos, "width": w, "height": h, "window_handle": wh}


