@tool
extends Control

# Custom dock for physics import functionality

const PhysicsBase = preload("res://addons/physics_collision_import_generator/import_scripts/import_physics_base.gd")

var plugin_reference
var file_list: ItemList
var refresh_button: Button
var apply_button: Button
var apply_all_button: Button # Added
var remove_button: Button
var shape_type_option: OptionButton
var shape_type_label: Label
var search_filter: LineEdit
var all_files: Array = []  # Store all found files for filtering
var _shape_icons: Dictionary = {}  # ShapeType -> ImageTexture
var _icon_none: ImageTexture

func _init():
	name = "Collision Import Generator"
	custom_minimum_size = Vector2(200, 500)  # Increased height only
	_create_status_icons()
	_setup_ui()

func _create_status_icons():
	var s := 12  # shape draw size
	var h := 16  # icon height
	var pad := 8  # left padding to indent file entries under folder headers
	var w := pad + s # total icon width

	# No physics — fully transparent (invisible but reserves space for alignment)
	_icon_none = _make_icon(w, h, func(_img: Image): pass)

	# Trimesh — red triangle
	var c_trimesh := Color(0.9, 0.3, 0.3)
	_shape_icons[PhysicsBase.ShapeType.TRIMESH] = _make_icon(w, h, func(img: Image):
		for y in range(2, 14):
			var half_w := int((y - 2) * 5.0 / 11.0)
			var cx := pad + 6
			for x in range(cx - half_w, cx + half_w + 1):
				img.set_pixel(x, y, c_trimesh)
	)

	# Convex — orange diamond
	var c_convex := Color(0.9, 0.6, 0.2)
	_shape_icons[PhysicsBase.ShapeType.CONVEX] = _make_icon(w, h, func(img: Image):
		var cx := pad + 6
		var cy := 8
		var r := 5
		for y in range(cy - r, cy + r + 1):
			var half_w := r - absi(y - cy)
			for x in range(cx - half_w, cx + half_w + 1):
				img.set_pixel(x, y, c_convex)
	)

	# Box — green square
	var c_box := Color(0.3, 0.85, 0.4)
	_shape_icons[PhysicsBase.ShapeType.BOX] = _make_icon(w, h, func(img: Image):
		for x in range(pad + 1, pad + 11):
			for y in range(3, 13):
				img.set_pixel(x, y, c_box)
	)

	# Sphere — blue circle
	var c_sphere := Color(0.3, 0.55, 0.95)
	_shape_icons[PhysicsBase.ShapeType.SPHERE] = _make_icon(w, h, func(img: Image):
		var cx := pad + 6.0
		var cy := 8.0
		var r := 5.0
		for x in range(pad, w):
			for y in range(h):
				if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
					img.set_pixel(x, y, c_sphere)
	)

	# Capsule — purple pill
	var c_capsule := Color(0.7, 0.4, 0.9)
	_shape_icons[PhysicsBase.ShapeType.CAPSULE] = _make_icon(w, h, func(img: Image):
		var cx := pad + 6.0
		var r := 3.5
		for x in range(pad, w):
			for y in range(0, 6):
				if (x - cx) * (x - cx) + (y - 5.0) * (y - 5.0) <= r * r:
					img.set_pixel(x, y, c_capsule)
		for x in range(int(cx - r), int(cx + r) + 1):
			for y in range(5, 11):
				img.set_pixel(x, y, c_capsule)
		for x in range(pad, w):
			for y in range(10, 16):
				if (x - cx) * (x - cx) + (y - 10.0) * (y - 10.0) <= r * r:
					img.set_pixel(x, y, c_capsule)
	)

func _make_icon(w: int, h: int, draw_fn: Callable) -> ImageTexture:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	draw_fn.call(img)
	return ImageTexture.create_from_image(img)

func _setup_ui():
	# UI Spacer/Helper
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)  # Reduced spacing
	# Usage: vbox.add_child(spacer)

	# Create vertical layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	shape_type_option = OptionButton.new()
	shape_type_option.add_item("SELECT a physics shape type to apply:", PhysicsBase.ShapeType.NONE)
	shape_type_option.add_item("Box (Simple, Fastest)", PhysicsBase.ShapeType.BOX)
	shape_type_option.add_item("Capsule (Simple, Fastest)", PhysicsBase.ShapeType.CAPSULE)
	shape_type_option.add_item("Convex (Optimized)", PhysicsBase.ShapeType.CONVEX)
	shape_type_option.add_item("Sphere (Simple, Fastest)", PhysicsBase.ShapeType.SPHERE)
	shape_type_option.add_item("Trimesh (Exact, but Slow)", PhysicsBase.ShapeType.TRIMESH)
	shape_type_option.selected = 0  # Default to None/Unknown
	shape_type_option.item_selected.connect(_on_shape_type_changed)
	vbox.add_child(shape_type_option)
	
	# Info label
	# var info = Label.new()
	# info.text = "GLB/GLTF files in project:"
	# info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# vbox.add_child(info)
	vbox.add_child(spacer)

	# Search filter container
	var search_container = HBoxContainer.new()
	vbox.add_child(search_container)

	# Search filter
	search_filter = LineEdit.new()
	search_filter.placeholder_text = "Filter Files/Folders"
	search_filter.custom_minimum_size = Vector2(0, 24)
	search_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_filter.text_changed.connect(_on_search_text_changed)
	search_container.add_child(search_filter)

	# Clear search button
	var clear_button = Button.new()
	clear_button.text = "×"
	clear_button.custom_minimum_size = Vector2(24, 24)
	clear_button.tooltip_text = "Clear search"
	clear_button.pressed.connect(_on_clear_search_pressed)
	search_container.add_child(clear_button)

	# Refresh button (icon loaded from editor theme)
	refresh_button = Button.new()
	refresh_button.custom_minimum_size = Vector2(24, 24)
	refresh_button.tooltip_text = "Refresh file list"
	refresh_button.pressed.connect(_on_refresh_pressed)
	search_container.add_child(refresh_button)
	# Defer icon load until the button is in the scene tree
	refresh_button.ready.connect(func():
		var icon = refresh_button.get_theme_icon("Reload", "EditorIcons")
		if icon:
			refresh_button.icon = icon
		else:
			refresh_button.text = "↻"
	)

	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(0, 200)
	file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_list.select_mode = ItemList.SELECT_MULTI
	file_list.allow_reselect = true
	file_list.auto_height = false # Set to false to allow scrolling in the dock
	file_list.add_theme_constant_override("icon_margin", 2)
	vbox.add_child(file_list)

	file_list.multi_selected.connect(_on_multi_selected)
	file_list.set_drag_forwarding(_file_list_get_drag_data, Callable(), Callable())

	# Action buttons row (below list, always visible)
	var hbox_buttons = HBoxContainer.new()
	vbox.add_child(hbox_buttons)

	remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_button.pressed.connect(_on_remove_physics_pressed)
	remove_button.disabled = true
	hbox_buttons.add_child(remove_button)

	apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.pressed.connect(_on_apply_physics_pressed)
	apply_button.disabled = true
	hbox_buttons.add_child(apply_button)

	apply_all_button = Button.new()
	apply_all_button.text = "Apply All"
	apply_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_all_button.pressed.connect(_on_apply_to_all_pressed)
	apply_all_button.disabled = true
	hbox_buttons.add_child(apply_all_button)

	call_deferred("_refresh_file_list")

func _refresh_file_list():
	# Get all GLB/GLTF files in the project and store them
	all_files = _find_gltf_files("res://")
	all_files.sort()
	_update_filtered_list()

func _update_filtered_list():
	file_list.clear()
	apply_button.disabled = true
	remove_button.disabled = true
	
	# Get the current search filter
	var filter_text = search_filter.text.to_lower() if search_filter else ""
	
	# Group files by parent directory
	var grouped: Dictionary = {}
	for file_path in all_files:
		var file_name = file_path.get_file()
		if filter_text != "" and not file_path.to_lower().contains(filter_text):
			continue
		var dir_path = file_path.get_base_dir()
		if dir_path not in grouped:
			grouped[dir_path] = []
		grouped[dir_path].append(file_path)

	# Display grouped files with folder separators
	for dir_path in grouped:
		# Add folder separator (non-selectable)
		var sep_index = file_list.add_item(dir_path.replace("res://", "").lstrip("/") + "/")
		file_list.set_item_selectable(sep_index, false)
		file_list.set_item_custom_fg_color(sep_index, Color(1, 1, 1, 0.4))

		for file_path in grouped[dir_path]:
			var file_name = file_path.get_file()
			var item_index = file_list.add_item("  " + file_name)
			file_list.set_item_metadata(item_index, file_path)

			# Show shape-specific icon if physics is applied
			var shape_type := _get_file_physics_shape_type(file_path)
			if shape_type != PhysicsBase.ShapeType.NONE and shape_type in _shape_icons:
				file_list.set_item_icon(item_index, _shape_icons[shape_type])
				var shape_name := _get_shape_name(shape_type)
				file_list.set_item_tooltip(item_index, file_path + "\n✓ " + shape_name)
			else:
				file_list.set_item_icon(item_index, _icon_none)
				file_list.set_item_tooltip(item_index, file_path + "\n○ No physics import script")

func _find_gltf_files(directory: String) -> Array:
	var files = []
	var dir = DirAccess.open(directory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = directory + "/" + file_name
			if dir.current_is_dir() and not file_name.begins_with("."):
				# Recursively search subdirectories
				files.append_array(_find_gltf_files(full_path))
			elif file_name.get_extension().to_lower() in ["glb", "gltf"]:
				files.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func _has_physics_import_script(file_path: String) -> bool:
	var import_path = file_path + ".import"
	if not FileAccess.file_exists(import_path):
		return false
	
	var config = ConfigFile.new()
	if config.load(import_path) != OK:
		return false
	
	var import_script_path = config.get_value("params", "import_script/path", "")
	return _is_physics_import_script(import_script_path)

# Check if an import script path is one of our physics scripts
func _is_physics_import_script(script_path: String) -> bool:
	if script_path.is_empty():
		return false
	return script_path.matchn("*import_physics_*.gd")

# Get the physics shape type for a specific file by reading its import script
func _get_file_physics_shape_type(file_path: String) -> int:
	var import_path = file_path + ".import"
	if not FileAccess.file_exists(import_path):
		return PhysicsBase.ShapeType.NONE
	
	var config = ConfigFile.new()
	if config.load(import_path) != OK:
		return PhysicsBase.ShapeType.NONE
	var script_path = config.get_value("params", "import_script/path", "")
	
	if script_path.is_empty():
		return PhysicsBase.ShapeType.NONE
	var type_name = script_path.get_file().get_basename().replace("import_physics_", "").to_upper()
	match type_name:
		"TRIMESH": return PhysicsBase.ShapeType.TRIMESH
		"CONVEX": return PhysicsBase.ShapeType.CONVEX
		"BOX": return PhysicsBase.ShapeType.BOX
		"SPHERE": return PhysicsBase.ShapeType.SPHERE
		"CAPSULE": return PhysicsBase.ShapeType.CAPSULE
		_: return PhysicsBase.ShapeType.NONE

func _get_shape_name(shape_type: int) -> String:
	match shape_type:
		PhysicsBase.ShapeType.TRIMESH: return "Trimesh"
		PhysicsBase.ShapeType.CONVEX: return "Convex"
		PhysicsBase.ShapeType.BOX: return "Box"
		PhysicsBase.ShapeType.SPHERE: return "Sphere"
		PhysicsBase.ShapeType.CAPSULE: return "Capsule"
		_: return "None"

func _file_list_get_drag_data(at_position: Vector2):
	var item_index = file_list.get_item_at_position(at_position)
	if item_index < 0:
		return null
	# Use selected items if the dragged item is part of the selection
	var selected = file_list.get_selected_items()
	var files: PackedStringArray = []
	if item_index in selected:
		for idx in selected:
			var meta = file_list.get_item_metadata(idx)
			if meta:
				files.append(meta)
	else:
		var meta = file_list.get_item_metadata(item_index)
		if meta:
			files.append(meta)
	if files.is_empty():
		return null
	# Use the same format as Godot's FileSystem dock
	var preview = Label.new()
	preview.text = files[0].get_file() if files.size() == 1 else "%d files" % files.size()
	file_list.set_drag_preview(preview)
	return {"type": "files", "files": files}

func _restore_selection(file_paths: Array) -> void:
	for i in range(file_list.item_count):
		if file_list.get_item_metadata(i) in file_paths:
			file_list.select(i, false)
	var selected = file_list.get_selected_items()
	if selected.size() > 0:
		_on_multi_selected(selected[0], true)

func _on_refresh_pressed():
	_refresh_file_list()

func _on_search_text_changed(_new_text: String):
	# Update the filtered list whenever search text changes
	_update_filtered_list()

func _on_clear_search_pressed():
	# Clear the search filter
	search_filter.text = ""
	_update_filtered_list()

func _update_button_states() -> void:
	var has_shape := shape_type_option.get_selected_id() != PhysicsBase.ShapeType.NONE
	var selected_items := file_list.get_selected_items()
	var has_selection := not selected_items.is_empty()
	var any_has_physics := false
	for idx in selected_items:
		if _has_physics_import_script(file_list.get_item_metadata(idx)):
			any_has_physics = true
			break
	apply_button.disabled = not (has_shape and has_selection)
	remove_button.disabled = not (has_selection and any_has_physics)
	apply_all_button.disabled = not has_shape

func _on_shape_type_changed(_index: int) -> void:
	_update_button_states()

func _on_multi_selected(_index: int, _selected: bool) -> void:
	if file_list.get_selected_items().size() == 1:
		var shape_type := _get_file_physics_shape_type(file_list.get_item_metadata(file_list.get_selected_items()[0]))
		shape_type_option.selected = shape_type_option.get_item_index(shape_type) if shape_type != PhysicsBase.ShapeType.NONE else 0
	_update_button_states()

func _on_apply_physics_pressed():
	var selected_items = file_list.get_selected_items()
	var paths = []
	for idx in selected_items: paths.append(file_list.get_item_metadata(idx))
	_apply_to_paths(paths)

func _on_apply_to_all_pressed():
	var paths = []
	for i in range(file_list.item_count):
		paths.append(file_list.get_item_metadata(i))
	if paths.is_empty():
		return
	var shape_name = shape_type_option.get_item_text(shape_type_option.selected)
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Are you sure to apply \"%s\" to %d file(s)?\nFiles with an existing physics shape will be overridden!" % [shape_name, paths.size()]
	dialog.confirmed.connect(func(): _apply_to_paths(paths))
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _apply_to_paths(paths: Array):
	if paths.is_empty() or not plugin_reference:
		return

	var shape_type = shape_type_option.get_selected_id()
	
	for path in paths:
		if shape_type != PhysicsBase.ShapeType.NONE:
			plugin_reference.set_physics_import_script(path, shape_type)
		else:
			plugin_reference.remove_physics_import_script(path)
	
	# Wait a bit for import to complete, then refresh
	await get_tree().create_timer(0.5).timeout
	_update_filtered_list()
	# Restore selection by finding the file paths in the refreshed list
	_restore_selection(paths)

func _on_remove_physics_pressed():
	var selected_items = file_list.get_selected_items()
	if selected_items.size() == 0:
		return
	
	var paths = []
	for idx in selected_items: paths.append(file_list.get_item_metadata(idx))
	for path in paths:
		plugin_reference.remove_physics_import_script(path)
		
	await get_tree().create_timer(0.5).timeout
	_update_filtered_list()
	
	# Restore selection by finding the file paths in the refreshed list
	_restore_selection(paths)
