class_name Surface
extends RefCounted

enum SurfaceType {
	PLATFORM,
	WALL
}

enum Orientation {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT
}

var id: String = ""
var source_id: String = ""
var source_type: String = "WINDOW" # "WINDOW", "SCREEN"
var surface_type: int = SurfaceType.PLATFORM
var orientation: int = Orientation.TOP
var x1: float = 0.0
var y1: float = 0.0
var x2: float = 0.0
var y2: float = 0.0
var walkable: bool = false
var dynamic: bool = true
var length: float = 0.0
var source_aliases: Array[String] = []
var element_type: String = ""
var priority: int = 0

func _init(p_id: String = "", p_src_id: String = "", p_src_type: String = "WINDOW",

		p_type: int = SurfaceType.PLATFORM, p_orient: int = Orientation.TOP,
		p_x1: float = 0.0, p_y1: float = 0.0, p_x2: float = 0.0, p_y2: float = 0.0,
		p_walkable: bool = false, p_dynamic: bool = true) -> void:
	id = p_id
	source_id = p_src_id
	source_type = p_src_type
	surface_type = p_type
	orientation = p_orient
	x1 = min(p_x1, p_x2) if p_type == SurfaceType.PLATFORM else p_x1
	x2 = max(p_x1, p_x2) if p_type == SurfaceType.PLATFORM else p_x2
	y1 = min(p_y1, p_y2) if p_type == SurfaceType.WALL else p_y1
	y2 = max(p_y1, p_y2) if p_type == SurfaceType.WALL else p_y2
	walkable = p_walkable
	dynamic = p_dynamic
	length = Vector2(x2 - x1, y2 - y1).length()


func get_start() -> Vector2:
	return Vector2(x1, y1)

func get_end() -> Vector2:
	return Vector2(x2, y2)

func get_rect() -> Rect2:
	var min_x := minf(x1, x2)
	var min_y := minf(y1, y2)
	var w := absf(x2 - x1)
	var h := absf(y2 - y1)
	return Rect2(min_x, min_y, maxf(w, 1.0), maxf(h, 1.0))

func is_horizontal() -> bool:
	return absf(y2 - y1) < 0.1

func is_vertical() -> bool:
	return absf(x2 - x1) < 0.1

func to_dict() -> Dictionary:
	return {
		"id": id,
		"source_id": source_id,
		"source_type": source_type,
		"type": SurfaceType.keys()[surface_type],
		"orientation": Orientation.keys()[orientation],
		"x1": x1, "y1": y1, "x2": x2, "y2": y2,
		"walkable": walkable,
		"dynamic": dynamic,
		"length": length,
		"source_aliases": source_aliases,
		"element_type": element_type,
		"priority": priority
	}

