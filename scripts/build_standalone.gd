extends SceneTree

func _init() -> void:
	print("[Build] 开始打包 DesktopCat.pck...")
	DirAccess.make_dir_recursive_absolute("res://build")
	
	var packer := PCKPacker.new()
	var err := packer.pck_start("build/DesktopCat.pck")
	if err != OK:
		printerr("创建 PCK 失败: ", err)
		quit(1)
		return
	
	_pack_file(packer, "res://project.godot")
	_pack_dir(packer, "res://scenes")
	_pack_dir(packer, "res://scripts")
	_pack_dir(packer, "res://assets")
	if DirAccess.dir_exists_absolute("res://.godot/imported"):
		_pack_dir(packer, "res://.godot/imported")
	
	packer.flush()
	print("[Build] 打包完成: build/DesktopCat.pck")
	DirAccess.copy_absolute("build/DesktopCat.pck", "build/DesktopCat_Standalone.pck")
	print("[Build] 已同步至: build/DesktopCat_Standalone.pck")
	quit(0)

func _pack_file(packer: PCKPacker, path: String) -> void:
	if FileAccess.file_exists(path):
		packer.add_file(path, path)
		print("[Build] 已添加: ", path)

func _pack_dir(packer: PCKPacker, dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := dir_path.path_join(file_name)
			if dir.current_is_dir():
				_pack_dir(packer, full_path)
			else:
				_pack_file(packer, full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
