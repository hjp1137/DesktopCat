class_name SurfaceCandidate
extends RefCounted

const SurfaceClass = preload("res://scripts/world/surface.gd")

var candidate_id: String = ""
var source_type: String = "SCREEN" # "SCREEN", "WINDOW", "UIA", "VISUAL"
var source_id: String = ""
var source_window_id: String = ""
var element_type: String = ""
var surface_type: int = SurfaceClass.SurfaceType.PLATFORM
var orientation: int = SurfaceClass.Orientation.TOP
var x1: float = 0.0
var y1: float = 0.0
var x2: float = 0.0
var y2: float = 0.0
var walkable: bool = false
var dynamic: bool = true
var priority: int = 100
var confidence: float = 1.0
var source_aliases: Array[String] = []

func _init(p_id: String = "", p_src_type: String = "SCREEN", p_src_id: String = "",
		p_elem_type: String = "", p_surf_type: int = SurfaceClass.SurfaceType.PLATFORM,
		p_orient: int = SurfaceClass.Orientation.TOP, p_x1: float = 0.0, p_y1: float = 0.0,
		p_x2: float = 0.0, p_y2: float = 0.0, p_walkable: bool = false,
		p_dynamic: bool = true, p_priority: int = 100) -> void:
	candidate_id = p_id
	source_type = p_src_type
	source_id = p_src_id
	element_type = p_elem_type
	surface_type = p_surf_type
	orientation = p_orient
	x1 = minf(p_x1, p_x2) if p_surf_type == SurfaceClass.SurfaceType.PLATFORM else p_x1
	x2 = maxf(p_x1, p_x2) if p_surf_type == SurfaceClass.SurfaceType.PLATFORM else p_x2
	y1 = minf(p_y1, p_y2) if p_surf_type == SurfaceClass.SurfaceType.WALL else p_y1
	y2 = maxf(p_y1, p_y2) if p_surf_type == SurfaceClass.SurfaceType.WALL else p_y2
	walkable = p_walkable
	dynamic = p_dynamic
	priority = p_priority

func get_length() -> float:
	return Vector2(x2 - x1, y2 - y1).length()

func is_horizontal() -> bool:
	return absf(y2 - y1) < 0.1

func to_surface() -> RefCounted:
	var s = SurfaceClass.new(candidate_id, source_id, source_type, surface_type, orientation, x1, y1, x2, y2, walkable, dynamic)
	s.set("source_aliases", source_aliases)
	s.set("element_type", element_type)
	s.set("priority", priority)
	return s
