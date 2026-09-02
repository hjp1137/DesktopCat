class_name CommandManager
extends Node

enum CatCommand {
	STOP,
	WALK_LEFT,
	WALK_RIGHT,
	RESUME_AUTO
}

signal command_dispatched(cmd: CatCommand, payload: Dictionary)

var _cat: Node = null

func register_cat(cat: Node) -> void:
	_cat = cat
	print("[CommandManager] 已注册小猫实例: ", cat.name)

func send_command(cmd: CatCommand, payload: Dictionary = {}) -> void:
	var keys := CatCommand.keys()
	var cmd_name: String = keys[cmd] if cmd >= 0 and cmd < keys.size() else "UNKNOWN"
	print("[CommandManager] 接收并分发指令: ", cmd_name)
	command_dispatched.emit(cmd, payload)
	if is_instance_valid(_cat) and _cat.has_method("handle_command"):
		_cat.handle_command(cmd, payload)
