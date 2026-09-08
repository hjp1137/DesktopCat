extends Window

const Canvas = preload("res://scripts/perception_debug_canvas.gd")
var main_node: Node2D
var canvas: Control

func _ready() -> void:
	title = "DesktopCat - 感知调试"
	transparent = false
	borderless = false
	always_on_top = false
	min_size = Vector2i(480, 300)
	size = Vector2i(960, 600)
	canvas = Canvas.new()
	canvas.main_node = main_node
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_requested.connect(hide)
	window_input.connect(_on_window_input)
	main_node.exclude_window_from_capture(self)

func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F7, KEY_F9, KEY_V, KEY_ESCAPE]: hide()
