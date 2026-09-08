class_name CatPhysicsWorldModel
extends Node2D

signal t25_world_updated(revision: int)

var is_enabled: bool = false
var debug_layer_mode: int = 6 # 1~7: 1=Raw, 2=Evidence, 3=Candidates, 4=Merged, 5=Stable, 6=Final, 7=Comparison
var perception_mode: String = "hybrid" # "legacy" | "opencv" | "hybrid"
var latest_revision: int = 0
var last_received_msec: int = 0
var session_id: String = ""
var debug_preview: Dictionary = {}

func reset_snapshot() -> void:
	latest_revision = 0
	last_received_msec = 0
	legacy_surfaces.clear()
	opencv_surfaces.clear()
	hybrid_surfaces.clear()
	debug_preview.clear()
	debug_layers.clear()
	t25_world_updated.emit(0)

# 三路表面数据
var legacy_surfaces: Array = []
var opencv_surfaces: Array = []
var hybrid_surfaces: Array = []

# 调试阶段图层数据
var debug_layers: Dictionary = {
	"raw_evidence": [],
	"candidates": [],
	"merged_regions": [],
	"stable_regions": [],
	"final_surfaces": []
}

# 综合量化指标
var metrics: Dictionary = {
	"frame": 0,
	"timing": {"cv_ms": 0.0, "hybrid_ms": 0.0, "legacy_ms": 0.0, "total_ms": 0.0},
	"legacy": {"final_surface_count": 0, "fragmentation_count": 0, "average_surface_length": 0.0},
	"opencv": {"candidate_region_count": 0, "final_surface_count": 0, "stable_surface_count": 0, "fragmentation_count": 0, "temporal_jitter": 0, "average_surface_length": 0.0},
	"hybrid": {"candidate_region_count": 0, "final_surface_count": 0, "stable_surface_count": 0, "fragmentation_count": 0, "temporal_jitter": 0, "reduction_ratio": 1.0, "average_surface_length": 0.0},
	"cat_scale": {}
}

# 调色板
const COLOR_LEGACY_PLATFORM: Color = Color(1.0, 0.4, 0.3, 0.9)  # 红色系 (Legacy碎片)
const COLOR_OPENCV_PLATFORM: Color = Color(0.2, 0.7, 1.0, 0.9)  # 蓝色系 (OpenCV纯视觉)
const COLOR_HYBRID_PLATFORM: Color = Color(0.2, 1.0, 0.5, 0.95) # 青绿色 (Hybrid核心高可信)
const COLOR_WALL: Color = Color(1.0, 0.85, 0.2, 0.9)            # 亮黄色
const COLOR_LEDGE: Color = Color(1.0, 0.3, 0.9, 0.95)           # 紫粉色
const COLOR_CANDIDATE: Color = Color(0.8, 0.8, 0.8, 0.3)        # 半透明白
const COLOR_MERGED: Color = Color(0.3, 0.8, 0.9, 0.45)          # 半透明青蓝
const COLOR_STABLE: Color = Color(0.2, 0.9, 0.4, 0.5)           # 半透明绿

func toggle_enabled() -> bool:
	is_enabled = not is_enabled
	print("[CatPhysicsWorld] T25 猫眼物理世界 Debug Overlay: %s" % ("ON" if is_enabled else "OFF"))
	queue_redraw()
	return is_enabled

func set_debug_layer_mode(mode: int) -> void:
	debug_layer_mode = clampi(mode, 1, 7)
	print("[CatPhysicsWorld] 切换调试图层模式 -> Mode %d" % debug_layer_mode)
	queue_redraw()

func cycle_perception_mode() -> String:
	match perception_mode:
		"legacy": perception_mode = "opencv"
		"opencv": perception_mode = "hybrid"
		"hybrid": perception_mode = "legacy"
		_: perception_mode = "hybrid"
	print("[CatPhysicsWorld] 切换感知模式 -> %s" % perception_mode.to_upper())
	queue_redraw()
	return perception_mode

func set_perception_mode_explicit(mode: String) -> void:
	if mode in ["legacy", "opencv", "hybrid"]:
		perception_mode = mode
		queue_redraw()

func apply_snapshot(data: Dictionary) -> bool:
	if int(data.get("v", 0)) != 1 or str(data.get("type", "")) != "t25_perception_snapshot":
		return false

	var rev: int = int(data.get("revision", 0))
	var incoming_session := str(data.get("session_id", ""))
	if incoming_session != session_id:
		reset_snapshot()
		session_id = incoming_session
	if rev <= latest_revision and latest_revision > 0:
		return false
	latest_revision = rev
	last_received_msec = Time.get_ticks_msec()

	var surfs = data.get("surfaces", {})
	legacy_surfaces = surfs.get("legacy", [])
	opencv_surfaces = surfs.get("opencv", [])
	hybrid_surfaces = surfs.get("hybrid", [])

	debug_layers = data.get("debug_layers", {})
	metrics = data.get("metrics", {})
	if data.has("debug_preview"):
		debug_preview = data.debug_preview

	queue_redraw()
	emit_signal("t25_world_updated", latest_revision)
	return true

func has_fresh_snapshot(timeout_ms: int) -> bool:
	return latest_revision > 0 and Time.get_ticks_msec() - last_received_msec < timeout_ms

func get_active_surfaces() -> Array:
	match perception_mode:
		"legacy": return legacy_surfaces
		"opencv": return opencv_surfaces
		"hybrid": return hybrid_surfaces
		_: return hybrid_surfaces

func _draw() -> void:
	if not is_enabled:
		return

	# Mode 7: Side-by-side / 对比模式 (A: Legacy vs B: OpenCV vs C: Hybrid 同屏分色对比)
	if debug_layer_mode == 7:
		_draw_comparison_mode()
		_draw_hud()
		return

	# Mode 1~6: 分层调试
	match debug_layer_mode:
		1: # Mode 1: Raw Screen 边界
			var vp_size = get_viewport_rect().size
			draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.2, 0.4, 0.8, 0.15), false, 3.0)
		2: # Mode 2: Raw Visual Evidence
			var ev_list = debug_layers.get("raw_evidence", [])
			for ev in ev_list:
				if typeof(ev) == TYPE_DICTIONARY and ev.has("x"):
					draw_rect(Rect2(float(ev["x"]), float(ev["y"]), float(ev["w"]), float(ev["h"])), Color(1.0, 1.0, 0.3, 0.35), false, 1.5)
		3: # Mode 3: Occupancy / Candidate Regions
			var cand_list = debug_layers.get("candidates", [])
			for cand in cand_list:
				if typeof(cand) == TYPE_DICTIONARY and cand.has("x"):
					draw_rect(Rect2(float(cand["x"]), float(cand["y"]), float(cand["w"]), float(cand["h"])), COLOR_CANDIDATE, true)
					draw_rect(Rect2(float(cand["x"]), float(cand["y"]), float(cand["w"]), float(cand["h"])), Color(1, 1, 1, 0.6), false, 1.0)
		4: # Mode 4: Merged Regions (Cat-scale)
			var m_list = debug_layers.get("merged_regions", [])
			for m in m_list:
				if typeof(m) == TYPE_DICTIONARY and m.has("x"):
					draw_rect(Rect2(float(m["x"]), float(m["y"]), float(m["w"]), float(m["h"])), COLOR_MERGED, true)
					draw_rect(Rect2(float(m["x"]), float(m["y"]), float(m["w"]), float(m["h"])), Color(0.4, 1.0, 1.0, 0.8), false, 1.5)
		5: # Mode 5: Stable Regions (Temporal Filtered)
			var s_list = debug_layers.get("stable_regions", [])
			for s in s_list:
				if typeof(s) == TYPE_DICTIONARY and s.has("x"):
					draw_rect(Rect2(float(s["x"]), float(s["y"]), float(s["w"]), float(s["h"])), COLOR_STABLE, true)
		6: # Mode 6: Final Surfaces
			_draw_surface_list(get_active_surfaces(), perception_mode)

	_draw_hud()

func _draw_comparison_mode() -> void:
	# 三路分色同屏叠加对比：
	# Legacy: 暖橙红线 (粗 2px) - 呈现细碎笔画与碎片
	for s in legacy_surfaces:
		if s.get("type") == "PLATFORM":
			draw_line(Vector2(float(s["x1"]), float(s["y1"]) - 3.0), Vector2(float(s["x2"]), float(s["y2"]) - 3.0), COLOR_LEGACY_PLATFORM, 2.0)

	# OpenCV: 蓝色线 (粗 3px) - 呈现纯视觉连续结构
	for s in opencv_surfaces:
		if s.get("type") == "PLATFORM":
			draw_line(Vector2(float(s["x1"]), float(s["y1"])), Vector2(float(s["x2"]), float(s["y2"])), COLOR_OPENCV_PLATFORM, 3.0)

	# Hybrid: 亮嫩绿发光线 (粗 4px) + Ledge 紫色标记 - 呈现极简稳定表面
	for s in hybrid_surfaces:
		var stype = str(s.get("type", ""))
		if stype == "PLATFORM":
			draw_line(Vector2(float(s["x1"]), float(s["y1"]) + 3.0), Vector2(float(s["x2"]), float(s["y2"]) + 3.0), COLOR_HYBRID_PLATFORM, 4.0)
		elif stype == "WALL":
			draw_line(Vector2(float(s["x1"]), float(s["y1"])), Vector2(float(s["x2"]), float(s["y2"])), COLOR_WALL, 3.5)
		elif stype == "LEDGE":
			draw_circle(Vector2(float(s["x1"]), float(s["y1"])), 5.0, COLOR_LEDGE)

func _draw_surface_list(surfs: Array, mode: String) -> void:
	var p_col = COLOR_HYBRID_PLATFORM
	if mode == "legacy": p_col = COLOR_LEGACY_PLATFORM
	elif mode == "opencv": p_col = COLOR_OPENCV_PLATFORM

	for s in surfs:
		if typeof(s) != TYPE_DICTIONARY: continue
		var stype = str(s.get("type", "PLATFORM"))
		var p1 = Vector2(float(s.get("x1", 0.0)), float(s.get("y1", 0.0)))
		var p2 = Vector2(float(s.get("x2", 0.0)), float(s.get("y2", 0.0)))

		if stype == "PLATFORM":
			draw_line(p1, p2, p_col, 3.5)
			# 发光顶沿点缀
			draw_line(p1 - Vector2(0, 1), p2 - Vector2(0, 1), Color(1, 1, 1, 0.7), 1.5)
		elif stype == "WALL":
			draw_line(p1, p2, COLOR_WALL, 3.0)
		elif stype == "LEDGE":
			draw_circle(p1, 5.0, COLOR_LEDGE)

func _draw_hud() -> void:
	var hud_x: float = 24.0
	var hud_y: float = 40.0
	var line_h: float = 20.0

	var layer_names = {
		1: "Mode 1: Raw Screen 原始屏幕",
		2: "Mode 2: Raw Visual Evidence 原始视觉特征",
		3: "Mode 3: Occupancy Candidate 视觉占据候选区",
		4: "Mode 4: Merged Regions 猫尺度连通区域",
		5: "Mode 5: Stable Regions 时间滤波稳定区",
		6: "Mode 6: Final Surfaces 最终猫眼物理世界",
		7: "Mode 7: Side-by-side 对比视图 (Legacy/OpenCV/Hybrid)"
	}

	# 背景面板
	var panel_rect = Rect2(hud_x - 12.0, hud_y - 12.0, 520.0, 260.0)
	draw_rect(panel_rect, Color(0.08, 0.10, 0.14, 0.88), true)
	draw_rect(panel_rect, Color(0.25, 0.55, 0.90, 0.95), false, 2.0)

	var font = ThemeDB.fallback_font
	var fsize: int = 13

	# Title
	draw_string(font, Vector2(hud_x, hud_y + 12.0), "🐾 DesktopCat T25 猫眼物理世界感知原型", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.3))
	hud_y += line_h * 1.3

	# Mode & Layer
	var mode_text = "当前感知路线: [%s]" % perception_mode.to_upper()
	if perception_mode == "hybrid": mode_text += " (推荐核心方案)"
	draw_string(font, Vector2(hud_x, hud_y + 12.0), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.3, 1.0, 0.6))
	hud_y += line_h

	var layer_str = layer_names.get(debug_layer_mode, "Mode %d" % debug_layer_mode)
	draw_string(font, Vector2(hud_x, hud_y + 12.0), "当前调试图层: %s" % layer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.4, 0.8, 1.0))
	hud_y += line_h * 1.2

	# 核心量化指标
	var leg_m = metrics.get("legacy", {})
	var cv_m = metrics.get("opencv", {})
	var hy_m = metrics.get("hybrid", {})
	var timing = metrics.get("timing", {})

	var line_surfs = "表面数量: Legacy=%d | OpenCV=%d | Hybrid=%d" % [
		int(leg_m.get("final_surface_count", 0)),
		int(cv_m.get("final_surface_count", 0)),
		int(hy_m.get("final_surface_count", 0))
	]
	draw_string(font, Vector2(hud_x, hud_y + 12.0), line_surfs, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1))
	hud_y += line_h

	var line_frag = "碎片数量 (<48px): Legacy=%d | OpenCV=%d | Hybrid=%d" % [
		int(leg_m.get("fragmentation_count", 0)),
		int(cv_m.get("fragmentation_count", 0)),
		int(hy_m.get("fragmentation_count", 0))
	]
	# 突出碎片率对比
	draw_string(font, Vector2(hud_x, hud_y + 12.0), line_frag, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1.0, 0.5, 0.4) if int(leg_m.get("fragmentation_count", 0)) > int(hy_m.get("fragmentation_count", 0)) else Color(1, 1, 1))
	hud_y += line_h

	var line_jitter = "时间抖动 (Jitter): OpenCV=%d | Hybrid=%d / frame (趋近0)" % [
		int(cv_m.get("temporal_jitter", 0)),
		int(hy_m.get("temporal_jitter", 0))
	]
	draw_string(font, Vector2(hud_x, hud_y + 12.0), line_jitter, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.4, 0.9, 0.9))
	hud_y += line_h

	var line_ratio = "压缩比 (Candidates -> Final): %.2fx (极简世界)" % float(hy_m.get("reduction_ratio", 1.0))
	draw_string(font, Vector2(hud_x, hud_y + 12.0), line_ratio, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1.0, 0.9, 0.4))
	hud_y += line_h

	var line_time = "耗时: CV=%.1fms | Hybrid=%.1fms | Total=%.1fms" % [
		float(timing.get("cv_ms", 0.0)),
		float(timing.get("hybrid_ms", 0.0)),
		float(timing.get("total_ms", 0.0))
	]
	draw_string(font, Vector2(hud_x, hud_y + 12.0), line_time, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.7, 0.8, 0.9))
	hud_y += line_h

	# 快捷键帮助
	draw_string(font, Vector2(hud_x, hud_y + 12.0), "快捷键: [F7] 开关 | [Ctrl+Alt+1~7] 图层 | [F6/Ctrl+Alt+8] 切换模式", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.6))
