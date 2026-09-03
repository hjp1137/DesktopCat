class_name ExplorationMemory
extends RefCounted

const RECENT_SURFACE_HISTORY_MAX: int = 16
const VISIT_DECAY_SECONDS: float = 60.0 # 60秒半衰期衰减
const MAX_MEMORY_ENTRIES: int = 300

var recent_surfaces: Array = [] # Array of String (surface_id)
var surface_visit_count: Dictionary = {} # surface_id -> int
var surface_last_visit_time: Dictionary = {} # surface_id -> float (seconds)
var recent_routes: Array = [] # Array of String ("src->tgt")
var failed_goals: Dictionary = {} # surface_id -> float (expire timestamp sec)
var region_visit_history: Array = [] # Array of String ("TOP", "MID", "BOTTOM")
var consecutive_failures: int = 0
var last_stuck_check_time: float = 0.0

func record_visit(surface_id: String, region: String = "", route_str: String = "") -> void:
	if surface_id.is_empty(): return
	var now := float(Time.get_ticks_msec()) / 1000.0
	surface_visit_count[surface_id] = int(surface_visit_count.get(surface_id, 0)) + 1
	surface_last_visit_time[surface_id] = now
	recent_surfaces.append(surface_id)
	while recent_surfaces.size() > RECENT_SURFACE_HISTORY_MAX:
		recent_surfaces.pop_front()
	if not region.is_empty():
		region_visit_history.append(region)
		while region_visit_history.size() > RECENT_SURFACE_HISTORY_MAX:
			region_visit_history.pop_front()
	if not route_str.is_empty():
		recent_routes.append(route_str)
		while recent_routes.size() > RECENT_SURFACE_HISTORY_MAX:
			recent_routes.pop_front()
	failed_goals.erase(surface_id)
	consecutive_failures = 0
	enforce_memory_cap()

func record_failure(surface_id: String, cooldown_sec: float = 16.0) -> void:
	if surface_id.is_empty(): return
	var now := float(Time.get_ticks_msec()) / 1000.0
	failed_goals[surface_id] = now + cooldown_sec
	consecutive_failures += 1
	enforce_memory_cap()

func is_goal_failed_recently(surface_id: String) -> bool:
	if not failed_goals.has(surface_id): return false
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < float(failed_goals[surface_id]): return true
	failed_goals.erase(surface_id)
	return false

func get_decayed_visit_count(surface_id: String) -> float:
	var raw_count: float = float(surface_visit_count.get(surface_id, 0))
	if raw_count <= 0.0: return 0.0
	var last_t: float = float(surface_last_visit_time.get(surface_id, 0.0))
	var now := float(Time.get_ticks_msec()) / 1000.0
	var dt := maxf(0.0, now - last_t)
	var decay: float = exp(-dt / VISIT_DECAY_SECONDS)
	return raw_count * decay

func enforce_memory_cap() -> void:
	if surface_visit_count.size() > MAX_MEMORY_ENTRIES:
		var keys := surface_visit_count.keys()
		for i in range(keys.size() - MAX_MEMORY_ENTRIES):
			surface_visit_count.erase(keys[i])
			surface_last_visit_time.erase(keys[i])

func detect_loop() -> Dictionary:
	var n: int = recent_surfaces.size()
	if n < 4: return { "is_loop": false, "period": 0, "surfaces": [] }
	# 检查周期 2: A-B-A-B
	if n >= 4 and recent_surfaces[n - 1] == recent_surfaces[n - 3] and recent_surfaces[n - 2] == recent_surfaces[n - 4] and recent_surfaces[n - 1] != recent_surfaces[n - 2]:
		return { "is_loop": true, "period": 2, "surfaces": [recent_surfaces[n - 1], recent_surfaces[n - 2]] }
	# 检查周期 3: A-B-C-A-B-C
	if n >= 6 and recent_surfaces[n - 1] == recent_surfaces[n - 4] and recent_surfaces[n - 2] == recent_surfaces[n - 5] and recent_surfaces[n - 3] == recent_surfaces[n - 6]:
		return { "is_loop": true, "period": 3, "surfaces": [recent_surfaces[n - 1], recent_surfaces[n - 2], recent_surfaces[n - 3]] }
	# 检查周期 4: A-B-C-D-A-B-C-D
	if n >= 8:
		var is_p4: bool = true
		for i in range(4):
			if recent_surfaces[n - 1 - i] != recent_surfaces[n - 5 - i]:
				is_p4 = false
				break
		if is_p4:
			return { "is_loop": true, "period": 4, "surfaces": [recent_surfaces[n - 1], recent_surfaces[n - 2], recent_surfaces[n - 3], recent_surfaces[n - 4]] }
	return { "is_loop": false, "period": 0, "surfaces": [] }

func detect_stuck(available_candidates_count: int, duration_sec: float = 40.0) -> bool:
	if available_candidates_count <= 2: return false
	if recent_surfaces.size() < 6: return false
	var unique_recent: Dictionary = {}
	for s_id in recent_surfaces: unique_recent[s_id] = true
	return unique_recent.size() <= 2

func cleanup_vanished_surfaces(valid_surface_ids: Dictionary) -> void:
	var keys := surface_visit_count.keys()
	for s_id in keys:
		if not valid_surface_ids.has(s_id):
			surface_visit_count.erase(s_id)
			surface_last_visit_time.erase(s_id)
			failed_goals.erase(s_id)
