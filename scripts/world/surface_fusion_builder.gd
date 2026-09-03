class_name SurfaceFusionBuilder
extends Node2D

const SurfaceClass = preload("res://scripts/world/surface.gd")
const SurfaceCandidateClass = preload("res://scripts/world/surface_candidate.gd")

const PRIORITY_SCREEN: int = 100
const PRIORITY_WINDOW: int = 90
const PRIORITY_UIA: int = 80
const PRIORITY_VISUAL: int = 60

const MIN_PLATFORM_LENGTH: float = 48.0
const MIN_TEXT_PLATFORM_LENGTH: float = 48.0
const MIN_WALL_LENGTH: float = 48.0

const MERGE_Y_TOLERANCE: float = 4.0
const MERGE_GAP: float = 16.0
const OVERLAP_DEDUP_THRESHOLD: float = 0.80
const FUSION_QUANTIZATION: float = 4.0

const FINAL_SURFACE_MISSING_GRACE_MS: int = 600
const WINDOW_MISSING_GRACE_MS: int = 100
const STALE_PROVIDER_TIMEOUT_MS: int = 4000
const FUSION_DEBOUNCE_SEC: float = 0.05
const MAX_SURFACES: int = 1024

const CONTAINER_TYPES: Array[String] = ["Pane", "Group", "Document", "List", "Tree", "Toolbar", "Menu"]
const ALLOWED_UIA_TYPES: Array[String] = ["Text", "Hyperlink", "Button", "Edit", "Image", "ListItem", "TreeItem", "TabItem", "MenuItem", "Custom"]

var window_world_model: Node2D = null
var ui_element_world_model: Node2D = null
var visual_world_model: Node2D = null
var surface_world_model: Node2D = null
var cat: Node2D = null

var pending_fusion: bool = false
var debounce_timer: float = 0.0
var debug_diagnostics_enabled: bool = false

var surface_grace_map: Dictionary = {}
var previous_window_positions: Dictionary = {}
var window_deltas: Dictionary = {}

var stats: Dictionary = {
	"screen": 0, "window": 0, "uia": 0, "visual": 0,
	"filtered_small": 0, "filtered_nested": 0, "deduplicated": 0,
	"merged": 0, "occluded": 0, "final_platforms": 0, "final_walls": 0,
	"fusion_ms": 0.0
}

func _ready() -> void:
	pass

func request_fusion() -> void:
	pending_fusion = true
	debounce_timer = FUSION_DEBOUNCE_SEC

func _process(delta: float) -> void:
	if pending_fusion:
		debounce_timer -= delta
		if debounce_timer <= 0.0:
			pending_fusion = false
			execute_fusion()

func toggle_debug_diagnostics() -> bool:
	debug_diagnostics_enabled = not debug_diagnostics_enabled
	print("[FusionBuilder] Debug Diagnostics (F13): %s" % ("ON" if debug_diagnostics_enabled else "OFF"))
	queue_redraw()
	return debug_diagnostics_enabled

func _extract_screen_candidates(overlay_sz: Vector2, ground_y: float) -> Array:
	var list: Array = []
	var sx: float = maxf(overlay_sz.x, 1920.0)
	var sy: float = maxf(overlay_sz.y, 1080.0)
	list.append(SurfaceCandidateClass.new("screen:ground", "SCREEN", "screen", "Screen", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, -5000.0, ground_y, sx + 5000.0, ground_y, true, false, PRIORITY_SCREEN))
	list.append(SurfaceCandidateClass.new("screen:left", "SCREEN", "screen", "Screen", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, 0.0, 0.0, 0.0, sy, false, false, PRIORITY_SCREEN))
	list.append(SurfaceCandidateClass.new("screen:right", "SCREEN", "screen", "Screen", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, sx, 0.0, sx, sy, false, false, PRIORITY_SCREEN))
	list.append(SurfaceCandidateClass.new("screen:top", "SCREEN", "screen", "Screen", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.BOTTOM, 0.0, 0.0, sx, 0.0, false, false, PRIORITY_SCREEN))
	return list

func _subtract_interval(intervals: Array, ox1: float, ox2: float) -> Array:
	var result: Array = []
	for inv in intervals:
		var ix1: float = inv[0]; var ix2: float = inv[1]
		if ox2 <= ix1 or ox1 >= ix2:
			result.append(inv)
		else:
			if ox1 > ix1: result.append([ix1, ox1])
			if ox2 < ix2: result.append([ox2, ix2])
	return result

func _extract_window_candidates(windows: Dictionary) -> Array:
	var list: Array = []
	var win_list := windows.values()
	var new_positions: Dictionary = {}
	var new_deltas: Dictionary = {}
	for win in win_list:
		var wid: String = str(win.get("id", ""))
		var r: Rect2 = win.get("rect", Rect2())
		new_positions[wid] = r.position
		if previous_window_positions.has(wid):
			new_deltas[wid] = r.position - previous_window_positions[wid]
		else:
			new_deltas[wid] = Vector2.ZERO

		if r.size.x >= MIN_PLATFORM_LENGTH:
			list.append(SurfaceCandidateClass.new(wid + ":bottom", "WINDOW", wid, "Window", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.BOTTOM, r.position.x, r.end.y, r.end.x, r.end.y, false, true, PRIORITY_WINDOW))
			var intervals: Array = [[r.position.x, r.end.x]]
			for other in win_list:
				if other.id == wid: continue
				if other.z_order < win.z_order:
					var or_rect: Rect2 = other.rect
					if or_rect.position.y <= r.position.y and or_rect.end.y >= r.position.y:
						intervals = _subtract_interval(intervals, or_rect.position.x, or_rect.end.x)
			var valid_intervals: Array = []
			for inv in intervals:
				if (inv[1] - inv[0]) >= MIN_PLATFORM_LENGTH: valid_intervals.append(inv)
			if valid_intervals.size() == 1 and absf(valid_intervals[0][0] - r.position.x) < 0.5 and absf(valid_intervals[0][1] - r.end.x) < 0.5:
				list.append(SurfaceCandidateClass.new(wid + ":top", "WINDOW", wid, "Window", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, valid_intervals[0][0], r.position.y, valid_intervals[0][1], r.position.y, true, true, PRIORITY_WINDOW))
			else:
				for i in range(valid_intervals.size()):
					var inv = valid_intervals[i]
					list.append(SurfaceCandidateClass.new("%s:top:%d" % [wid, i], "WINDOW", wid, "Window", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, inv[0], r.position.y, inv[1], r.position.y, true, true, PRIORITY_WINDOW))

		if r.size.y >= MIN_WALL_LENGTH:
			list.append(SurfaceCandidateClass.new(wid + ":left", "WINDOW", wid, "Window", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, r.position.x, r.position.y, r.position.x, r.end.y, false, true, PRIORITY_WINDOW))
			list.append(SurfaceCandidateClass.new(wid + ":right", "WINDOW", wid, "Window", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, r.end.x, r.position.y, r.end.x, r.end.y, false, true, PRIORITY_WINDOW))

	previous_window_positions = new_positions
	window_deltas = new_deltas
	return list

func _extract_uia_candidates(elements: Dictionary, windows: Dictionary) -> Array:
	var list: Array = []
	var win_list: Array = windows.values()
	var text_groups: Dictionary = {} # (win_id + ":" + round_y) -> Array[Dictionary]

	for elem in elements.values():
		var ctype: String = str(elem.get("control_type", ""))
		if CONTAINER_TYPES.has(ctype):
			stats["filtered_nested"] += 1
			continue
		if not ALLOWED_UIA_TYPES.has(ctype):
			continue

		var r: Rect2 = elem.get("rect", Rect2())
		var eid: String = str(elem.get("id", ""))
		var wid: String = str(elem.get("window_id", ""))

		# 文本及超链接先按行收集以便同行合并
		if ctype == "Text" or ctype == "Hyperlink":
			var ry: int = int(round(r.position.y / MERGE_Y_TOLERANCE) * MERGE_Y_TOLERANCE)
			var gkey := "%s:%d" % [wid, ry]
			if not text_groups.has(gkey): text_groups[gkey] = []
			text_groups[gkey].append({"elem": elem, "x1": r.position.x, "x2": r.end.x, "y": r.position.y, "id": eid, "wid": wid})
			continue

		# 按钮、输入框、图片等直接提取
		if r.size.x >= MIN_PLATFORM_LENGTH:
			var intervals := _clip_by_windows([[r.position.x, r.end.x]], r.position.y, wid, win_list)
			for inv in intervals:
				if (inv[1] - inv[0]) >= MIN_PLATFORM_LENGTH:
					var cand = SurfaceCandidateClass.new("uia:%s:top" % eid, "UIA", eid, ctype, SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, inv[0], r.position.y, inv[1], r.position.y, true, true, PRIORITY_UIA)
					cand.source_window_id = wid
					list.append(cand)

		if ctype == "Image" and r.size.y >= MIN_WALL_LENGTH:
			var cand_l = SurfaceCandidateClass.new("uia:%s:left" % eid, "UIA", eid, ctype, SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, r.position.x, r.position.y, r.position.x, r.end.y, false, true, PRIORITY_UIA)
			var cand_r = SurfaceCandidateClass.new("uia:%s:right" % eid, "UIA", eid, ctype, SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, r.end.x, r.position.y, r.end.x, r.end.y, false, true, PRIORITY_UIA)
			cand_l.source_window_id = wid; cand_r.source_window_id = wid
			list.append(cand_l); list.append(cand_r)

	# 处理同行 Text Fragment 合并
	for gkey in text_groups.keys():
		var fragments: Array = text_groups[gkey]
		fragments.sort_custom(func(a, b): return a.x1 < b.x1)
		var merged_runs: Array = []
		for frag in fragments:
			if merged_runs.is_empty():
				merged_runs.append([frag.x1, frag.x2, frag.y, frag.id, frag.wid])
			else:
				var last = merged_runs[merged_runs.size() - 1]
				if frag.x1 <= last[1] + MERGE_GAP:
					last[1] = maxf(last[1], frag.x2)
					stats["merged"] += 1
				else:
					merged_runs.append([frag.x1, frag.x2, frag.y, frag.id, frag.wid])

		for run in merged_runs:
			if (run[1] - run[0]) >= MIN_TEXT_PLATFORM_LENGTH:
				var intervals := _clip_by_windows([[run[0], run[1]]], run[2], run[4], win_list)
				for inv in intervals:
					if (inv[1] - inv[0]) >= MIN_TEXT_PLATFORM_LENGTH:
						var cand = SurfaceCandidateClass.new("uia:%s:top" % run[3], "UIA", run[3], "Text", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, inv[0], run[2], inv[1], run[2], true, true, PRIORITY_UIA)
						cand.source_window_id = run[4]
						list.append(cand)
			else:
				stats["filtered_small"] += 1
	return list

func _clip_by_windows(intervals: Array, y: float, wid: String, win_list: Array) -> Array:
	if wid == "" or win_list.is_empty(): return intervals
	var target_win = null
	for w in win_list:
		if w.id == wid: target_win = w; break
	if target_win == null: return intervals
	var cur_intervals = intervals
	for other in win_list:
		if other.id == wid: continue
		if other.z_order < target_win.z_order:
			var or_rect: Rect2 = other.rect
			if or_rect.position.y <= y and or_rect.end.y >= y:
				cur_intervals = _subtract_interval(cur_intervals, or_rect.position.x, or_rect.end.x)
	return cur_intervals


func _extract_visual_candidates(geometries: Dictionary) -> Array:
	var list: Array = []
	for g in geometries.values():
		var gid: String = str(g.get("id", ""))
		var gtype: String = str(g.get("type", ""))
		if gtype == "LINE":
			var orient: String = str(g.get("orientation", "HORIZONTAL"))
			var p1: Vector2 = g.get("p1", Vector2.ZERO); var p2: Vector2 = g.get("p2", Vector2.ZERO)
			if orient == "HORIZONTAL":
				if absf(p2.x - p1.x) >= MIN_PLATFORM_LENGTH:
					list.append(SurfaceCandidateClass.new("vg:%s" % gid, "VISUAL", gid, "VisualLine", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, p1.x, p1.y, p2.x, p2.y, true, true, PRIORITY_VISUAL))
				else: stats["filtered_small"] += 1
			else:
				if absf(p2.y - p1.y) >= MIN_WALL_LENGTH:
					list.append(SurfaceCandidateClass.new("vg:%s" % gid, "VISUAL", gid, "VisualLine", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, p1.x, p1.y, p2.x, p2.y, false, true, PRIORITY_VISUAL))
				else: stats["filtered_small"] += 1
		elif gtype == "RECT":
			var r: Rect2 = g.get("rect", Rect2())
			if r.size.x >= MIN_PLATFORM_LENGTH:
				list.append(SurfaceCandidateClass.new("vg:%s:top" % gid, "VISUAL", gid, "VisualRect", SurfaceClass.SurfaceType.PLATFORM, SurfaceClass.Orientation.TOP, r.position.x, r.position.y, r.end.x, r.position.y, true, true, PRIORITY_VISUAL))
			if r.size.y >= MIN_WALL_LENGTH:
				list.append(SurfaceCandidateClass.new("vg:%s:left" % gid, "VISUAL", gid, "VisualRect", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.LEFT, r.position.x, r.position.y, r.position.x, r.end.y, false, true, PRIORITY_VISUAL))
				list.append(SurfaceCandidateClass.new("vg:%s:right" % gid, "VISUAL", gid, "VisualRect", SurfaceClass.SurfaceType.WALL, SurfaceClass.Orientation.RIGHT, r.end.x, r.position.y, r.end.x, r.end.y, false, true, PRIORITY_VISUAL))
	return list

func _deduplicate_platforms(candidates: Array) -> Array:
	candidates.sort_custom(func(a, b):
		if absf(a.y1 - b.y1) > MERGE_Y_TOLERANCE: return a.y1 < b.y1
		if a.priority != b.priority: return a.priority > b.priority
		return a.x1 < b.x1
	)
	var active: Array = []
	for cand in candidates:
		var merged := false
		for ex in active:
			if absf(ex.y1 - cand.y1) <= MERGE_Y_TOLERANCE:
				var overlap: float = maxf(0.0, minf(ex.x2, cand.x2) - maxf(ex.x1, cand.x1))
				var min_len: float = minf(ex.x2 - ex.x1, cand.x2 - cand.x1)
				var ratio: float = (overlap / min_len) if min_len > 0.0 else 0.0
				if ratio >= OVERLAP_DEDUP_THRESHOLD:
					# 重叠去重：扩展范围并记录别名
					ex.x1 = minf(ex.x1, cand.x1)
					ex.x2 = maxf(ex.x2, cand.x2)
					ex.source_aliases.append(cand.candidate_id)
					stats["deduplicated"] += 1
					merged = true
					break
				elif overlap <= 0.0 and (maxf(ex.x1, cand.x1) - minf(ex.x2, cand.x2)) <= MERGE_GAP:
					# 共线合并
					ex.x1 = minf(ex.x1, cand.x1)
					ex.x2 = maxf(ex.x2, cand.x2)
					ex.source_aliases.append(cand.candidate_id)
					stats["merged"] += 1
					merged = true
					break
		if not merged:
			active.append(cand)
	return active

func execute_fusion() -> bool:
	if not is_instance_valid(surface_world_model):
		return false
	var t0 := Time.get_ticks_usec()
	stats["filtered_small"] = 0; stats["filtered_nested"] = 0
	stats["deduplicated"] = 0; stats["merged"] = 0; stats["occluded"] = 0

	var win := get_window()
	var ov_sz: Vector2 = Vector2(win.size) if win and win.size.x > 0 and win.size.y > 0 else Vector2(1920, 1080)
	var gy: float = cat.ground_y if is_instance_valid(cat) and "ground_y" in cat and cat.ground_y > 0.0 else ov_sz.y - 48.0

	var win_map: Dictionary = window_world_model.windows_by_id if is_instance_valid(window_world_model) else {}
	var ui_map: Dictionary = ui_element_world_model.elements_by_id if is_instance_valid(ui_element_world_model) else {}
	var vg_map: Dictionary = visual_world_model.geometries_by_id if is_instance_valid(visual_world_model) else {}

	var screen_cands := _extract_screen_candidates(ov_sz, gy)
	var win_cands := _extract_window_candidates(win_map)
	var uia_cands := _extract_uia_candidates(ui_map, win_map)
	var vis_cands := _extract_visual_candidates(vg_map)

	stats["screen"] = screen_cands.size()
	stats["window"] = win_cands.size()
	stats["uia"] = uia_cands.size()
	stats["visual"] = vis_cands.size()

	var all_raw := []
	all_raw.append_array(screen_cands); all_raw.append_array(win_cands)
	all_raw.append_array(uia_cands); all_raw.append_array(vis_cands)

	var platforms: Array = []
	var others: Array = []
	for c in all_raw:
		if c.surface_type == SurfaceClass.SurfaceType.PLATFORM and c.walkable:
			platforms.append(c)
		else:
			others.append(c)

	var deduped_platforms := _deduplicate_platforms(platforms)
	var final_cands := []
	final_cands.append_array(deduped_platforms)
	final_cands.append_array(others)

	# 坐标 4px 网格量化与最小长度过滤
	var valid_cands: Array = []
	for c in final_cands:
		var q := FUSION_QUANTIZATION
		c.x1 = round(c.x1 / q) * q; c.x2 = round(c.x2 / q) * q
		c.y1 = round(c.y1 / q) * q; c.y2 = round(c.y2 / q) * q
		if c.surface_type == SurfaceClass.SurfaceType.PLATFORM:
			if (c.x2 - c.x1) >= MIN_PLATFORM_LENGTH: valid_cands.append(c)
			else: stats["filtered_small"] += 1
		else:
			if (c.y2 - c.y1) >= MIN_WALL_LENGTH: valid_cands.append(c)
			else: stats["filtered_small"] += 1

	valid_cands.sort_custom(func(a, b):
		if a.priority != b.priority: return a.priority > b.priority
		return a.get_length() > b.get_length()
	)
	if valid_cands.size() > MAX_SURFACES: valid_cands = valid_cands.slice(0, MAX_SURFACES)

	# 时序平滑与丢失 Grace 保护
	var now := Time.get_ticks_msec()
	var new_surfaces: Dictionary = {}
	for c in valid_cands:
		var s = c.to_surface()
		new_surfaces[s.id] = s
		var grace := WINDOW_MISSING_GRACE_MS if s.source_type == "WINDOW" else FINAL_SURFACE_MISSING_GRACE_MS
		surface_grace_map[s.id] = {"surface": s, "expire": now + grace}

	var expired_keys: Array = []
	for gid in surface_grace_map.keys():
		var entry = surface_grace_map[gid]
		if not new_surfaces.has(gid):
			if now < entry["expire"]:
				new_surfaces[gid] = entry["surface"]
			else:
				expired_keys.append(gid)
	for k in expired_keys: surface_grace_map.erase(k)

	var p_count := 0; var w_count := 0
	for s in new_surfaces.values():
		if s.walkable: p_count += 1
		elif s.surface_type == SurfaceClass.SurfaceType.WALL: w_count += 1
	stats["final_platforms"] = p_count; stats["final_walls"] = w_count
	stats["fusion_ms"] = (Time.get_ticks_usec() - t0) / 1000.0

	var changed: bool = surface_world_model.commit_surfaces(new_surfaces, window_deltas)
	if debug_diagnostics_enabled: queue_redraw()
	return changed


func _draw() -> void:
	if not debug_diagnostics_enabled: return
	var font := ThemeDB.fallback_font
	var text1 := "[F13 Fusion Diagnostics] Candidates: Screen=%d, Win=%d, UIA=%d, Visual=%d | Final Surfaces: %d (Walkable: %d, Walls: %d)" % [stats["screen"], stats["window"], stats["uia"], stats["visual"], stats["final_platforms"] + stats["final_walls"], stats["final_platforms"], stats["final_walls"]]
	var text2 := "Simplified: Small=%d, Nested=%d, Dedup=%d, Merged=%d | Fusion Time: %.2f ms" % [stats["filtered_small"], stats["filtered_nested"], stats["deduplicated"], stats["merged"], stats["fusion_ms"]]
	draw_string(font, Vector2(24.0, 85.0), text1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 0.95, 0.4, 0.95))
	draw_string(font, Vector2(24.0, 102.0), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.8, 0.3, 0.95))




