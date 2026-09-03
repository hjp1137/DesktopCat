class_name MousePerceptionController
extends Node

var command_manager: CommandManager = null
var cat: Node2D = null
var main_node: Node2D = null

var attention_radius: float = 400.0
var attention_exit_radius: float = 460.0
var curiosity_radius: float = 350.0
var min_chase_speed: float = 80.0
var chase_duration_min: float = 2.5
var chase_duration_max: float = 4.5
var chase_cooldown_time: float = 15.0

var is_debug_following: bool = false
var is_attention_active: bool = false
var is_curiosity_chasing: bool = false
var chase_timer: float = 0.0
var chase_cooldown: float = 0.0
var click_suppress_timer: float = 0.0
var last_global_mouse_pos: Vector2 = Vector2.ZERO
var pointer_speed: float = 0.0
var sample_timer: float = 0.0

func toggle_debug_follow() -> void:
	is_debug_following = not is_debug_following
	if is_debug_following:
		is_curiosity_chasing = false; is_attention_active = false; print("[Pointer] Debug Follow ON")
	else:
		print("[Pointer] Debug Follow OFF"); if command_manager: command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET); command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)

func suppress_curiosity(duration: float = 0.8) -> void:
	click_suppress_timer = duration; if is_curiosity_chasing: is_curiosity_chasing = false; if command_manager: command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET)

func _process(delta: float) -> void:
	chase_cooldown = maxf(0.0, chase_cooldown - delta); click_suppress_timer = maxf(0.0, click_suppress_timer - delta); sample_timer += delta
	if not is_instance_valid(cat) or not is_instance_valid(command_manager): return
	var global_mouse_pos := DisplayServer.mouse_get_position() if DisplayServer.get_name() != "headless" else Vector2i(get_viewport().get_mouse_position())
	var pointer_active: bool = true; var local_mouse_pos: Vector2 = Vector2(global_mouse_pos)
	if DisplayServer.get_name() != "headless" and is_instance_valid(main_node):
		var screen_idx: int = main_node.current_target_screen; var usable_rect := DisplayServer.screen_get_usable_rect(screen_idx)
		if usable_rect.size.x <= 0: usable_rect.position = DisplayServer.screen_get_position(screen_idx); usable_rect.size = DisplayServer.screen_get_size(screen_idx)
		pointer_active = usable_rect.has_point(global_mouse_pos); local_mouse_pos = Vector2(global_mouse_pos - usable_rect.position)
	if not pointer_active:
		if is_attention_active: is_attention_active = false; print("[Pointer] Attention exited"); command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET)
		if is_curiosity_chasing: is_curiosity_chasing = false; print("[Pointer] Curiosity chase ended"); command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET)
		return
	if sample_timer >= 0.05:
		pointer_speed = (local_mouse_pos - last_global_mouse_pos).length() / sample_timer; last_global_mouse_pos = local_mouse_pos; sample_timer = 0.0
		_update_perception(local_mouse_pos, delta)

func _update_perception(local_pos: Vector2, _delta: float) -> void:
	if is_debug_following:
		command_manager.send_command(CommandManager.CatCommand.MOVE_TO_POSITION, {"target_pos": local_pos, "speed_mode": "RUN"}); return
	var c_state: int = cat.get("current_state"); var c_mode: int = cat.get("current_mode"); var is_grounded: bool = cat.get("is_grounded")
	if c_state in [4, 5, 6, 7] or not is_grounded: # SLEEP(4), JUMP(5), FALL(6), DRAG(7)
		if is_curiosity_chasing: is_curiosity_chasing = false; command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET)
		return
	if is_curiosity_chasing:
		chase_timer -= 0.05
		if chase_timer <= 0.0: is_curiosity_chasing = false; chase_cooldown = chase_cooldown_time; print("[Pointer] Curiosity chase ended"); command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET); command_manager.send_command(CommandManager.CatCommand.RESUME_AUTO)
		else: command_manager.send_command(CommandManager.CatCommand.MOVE_TO_POSITION, {"target_pos": local_pos, "speed_mode": "RUN"})
		return
	var dist: float = cat.position.distance_to(local_pos)
	if c_mode == 0 and click_suppress_timer <= 0.0 and chase_cooldown <= 0.0 and dist <= curiosity_radius and pointer_speed >= min_chase_speed:
		is_curiosity_chasing = true; chase_timer = randf_range(chase_duration_min, chase_duration_max); print("[Pointer] Curiosity chase started"); return
	if not is_attention_active and dist <= attention_radius: is_attention_active = true; print("[Pointer] Attention entered")
	elif is_attention_active and dist >= attention_exit_radius: is_attention_active = false; print("[Pointer] Attention exited"); command_manager.send_command(CommandManager.CatCommand.CLEAR_TARGET)
	if is_attention_active: command_manager.send_command(CommandManager.CatCommand.LOOK_AT_POSITION, {"target_pos": local_pos})
