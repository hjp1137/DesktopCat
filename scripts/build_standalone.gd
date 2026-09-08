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
	_pack_file(packer, "res://.godot/global_script_class_cache.cfg")
	_pack_file(packer, "res://.godot/uid_cache.bin")
	
	err = packer.flush()
	if err != OK:
		printerr("写入 PCK 失败: ", err)
		quit(1)
		return
	print("[Build] 打包完成: build/DesktopCat.pck")
	err = DirAccess.copy_absolute("build/DesktopCat.pck", "build/DesktopCat_Standalone.pck")
	if err != OK:
		printerr("复制 Standalone PCK 失败: ", err)
		quit(1)
		return
	print("[Build] 已同步至: build/DesktopCat_Standalone.pck")
	var perception_dir := "res://build/tools/perception"
	DirAccess.make_dir_recursive_absolute(perception_dir)
	for file_name in DirAccess.get_files_at("res://tools/perception"):
		if not file_name.ends_with(".py") or file_name.begins_with("test_") or file_name == "desktop_fixture.py":
			continue
		err = DirAccess.copy_absolute("res://tools/perception/" + file_name, perception_dir.path_join(file_name))
		if err != OK:
			printerr("复制感知脚本失败: ", file_name, " error=", err)
			quit(1)
			return
	quit(0)

func _pack_file(packer: PCKPacker, path: String) -> void:
	if FileAccess.file_exists(path):
		var err := packer.add_file(path, path)
		assert(err == OK, "打包文件失败: %s (%s)" % [path, err])
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
