tool
extends EditorPlugin

# todo:
	# 0. use it!
	# 1. fix editor warnings
	# 2. fill (ctrl) and select tools (shift), perhaps with little icon
	# 3. dense sample lines so smooth line drawing, just use basic vector math

var _toolbar = preload("res://addons/painter/painter toolbar.tscn").instance()
var _resize = preload("res://addons/painter/resize popup.tscn").instance()
var _file_load
var _file_save
var _pressed = [false,false,false,false,false,false,false,false,false,false]
var _pixel_pos
var _pixel_list = []
var _pixels = {}
var _brush_size = 1
enum {PALETTE_FROM_IMAGE, PALETTE_INDEXED}
enum {SPRITE_SAVE_AS, SPRITE_LOAD, SPRITE_RESIZE=3}

func _enter_tree():
	set_process_input(true)
	_toolbar.set_hidden(true)
	add_control_to_container( CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	for c in _toolbar.get_node("PaletteContainer").get_children():
		c.connect("color_changed", self, "on_color_picker_changed", [c])
		c.connect("pressed", self, "on_color_picker_pressed", [c])
	var palette = _toolbar.get_node("PaletteMenu").get_popup().connect("item_pressed", self, "on_palette_menu")
	var sprite = _toolbar.get_node("SpriteMenu").get_popup().connect("item_pressed", self, "on_sprite_menu")
	_toolbar.get_node("BrushContainer/HSlider").connect("value_changed", self, "on_brush_size_changed")
	_file_save = EditorFileDialog.new()
	_file_save.set_mode(EditorFileDialog.MODE_SAVE_FILE)
	_file_save.set_name("FileDialogSave")
	_file_save.add_filter("*.png ; PNG Images")
	_file_save.connect("file_selected", self, "on_file_save")
	_file_load = EditorFileDialog.new()
	_file_load.set_mode(EditorFileDialog.MODE_OPEN_FILE)
	_file_load.set_name("FileDialogLoad")
	_file_load.add_filter("*.png ; PNG Images")
	_file_load.connect("file_selected", self, "on_file_load")
	_resize.connect("confirmed", self, "on_resize_confirmed")
	_toolbar.add_child(_file_save)
	_toolbar.add_child(_file_load)
	_toolbar.add_child(_resize)

func _exit_tree():
	# Remove from docks (must be called so layout is updated and saved)
	pass

func _get_selected_color():
	for i in range(_pressed.size()):
		if _pressed[i]:
			return _toolbar.get_node("PaletteContainer").get_node(hotkey_to_colorpicker(i)).get_color()

func _input(event):
	var selection = get_selected_sprite()
	if selection == null or !_toolbar.is_visible() \
		or _resize.is_visible() \
		or _file_load.is_visible() \
		or _file_save.is_visible():
			return false

	# update pixel position if motion changes
	if event.type == InputEvent.MOUSE_MOTION:
		var mouse_pos = get_tree().get_edited_scene_root().get_global_mouse_pos()
		var texture_size = selection.get_texture().get_size()
		var local_pos = selection.make_canvas_pos_local(mouse_pos)
		var offset = selection.get_offset()
		var pixel_posf = (local_pos+Vector2(round(texture_size.x/2), round(texture_size.y/2))-offset)
		_pixel_pos = Vector2(floor(clamp(pixel_posf.x, 0, texture_size.x-1)), floor(clamp(pixel_posf.y, 0, texture_size.y-1)))

	if event.type == InputEvent.KEY:
		if event.scancode >= 48 and event.scancode <= 57:
			var key = event.scancode - 48
			var last = _pressed[key]
			_pressed[key] = event.is_pressed()
			if last and !_pressed[key]:
				var ur = get_undo_redo()
				var nw = str2var(var2str(_pixels))
				var col = str2var(var2str(_toolbar.get_node("PaletteContainer").get_node(hotkey_to_colorpicker(key)).get_color()))
				ur.create_action("Paint Sprite")
				ur.add_undo_method(self, "undo_paint", [nw, selection, col])
				ur.add_do_method(self, "do_paint", [nw, selection, col])
				ur.commit_action()
				_pixels.clear()
		if event.scancode == KEY_P and event.is_pressed():
			palette_from_image()

	if _pressed.has(true):
		var rad = _brush_size-1
		var rad2 = rad*rad
		var txs = selection.get_texture().get_size()
		var img = selection.get_texture().get_data()
		var col = _get_selected_color()
		for y in range(-rad, rad+1):
			for x in range(-rad, rad+1):
				if(rad < 2 or x*x+y*y <= rad2):
					var p = Vector2(floor(clamp(_pixel_pos.x+x, 0, txs.x-1)), floor(clamp(_pixel_pos.y+y, 0, txs.y-1)))
					if !_pixels.has(p):
						_pixels[p] = img.get_pixel(p.x, p.y)
						img.put_pixel(p.x, p.y, col)
		selection.get_texture().set_data(img)

	return true

func undo_paint(arr):
	var nw = arr[0]
	var selection = arr[1]
	var image = selection.get_texture().get_data()
	for k in nw:
		image.put_pixel(k.x, k.y, nw[k])
	selection.get_texture().set_data(image)
	print("undo")

func do_paint(arr):
	var nw = arr[0]
	var selection = arr[1]
	var col = arr[2]
	var image = selection.get_texture().get_data()
	for k in nw:
		image.put_pixel(k.x, k.y, col)
	selection.get_texture().set_data(image)
	print("redo")

func hotkey_to_colorpicker(i):
	if i == 0:
		return str(9)
	return str(i-1)

func palette_sort_colors(c1,c2):
	return c1.v > c2.v

func palette_from_image():
	var sprite = get_selected_sprite()
	if sprite == null:
		return
	var image = sprite.get_texture().get_data()
	var cols = {}

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			cols[image.get_pixel(x,y)] = true

	# erase all alpha colors as we don't want duplicates, e.g. (0,0,0,0) = (1,0,0,0)
	var alpha_colors = []
	for c in cols:
		if c.a == 0:
			alpha_colors.append(c)
	for c in alpha_colors:
		cols.erase(c)

	var cols_arr = cols.keys()
	cols_arr.sort_custom(self, "palette_sort_colors")
	for i in range(1,10):
		if i >= cols.size():
			_toolbar.get_node("PaletteContainer").get_node(str(i)).set_hidden(true)
		elif cols_arr[i] != null:
			_toolbar.get_node("PaletteContainer").get_node(str(i)).set_hidden(false)
			_toolbar.get_node("PaletteContainer").get_node(str(i)).set_color(cols_arr[i-1])
	_toolbar.get_node("PaletteContainer").get_node("0").set_color(Color(0,0,0,0))

func color_picker_do(arr):
	do_paint(arr)
	palette_from_image()

func color_picker_undo(arr):
	undo_paint(arr)
	palette_from_image()

func get_selected_sprite():
	var selected_object = get_selection().get_selected_nodes()
	if selected_object.size() != 1 or !(selected_object[0] extends Sprite):
		_toolbar.set_hidden(true)
		return null
	else:
		_toolbar.set_hidden(false)
		return selected_object[0]

func on_color_picker_changed(color, which):
	var image = get_selected_sprite().get_texture().get_data()
	var nw = {}
	if _pixel_list.size() > 0:
		var last_col = image.get_pixel(_pixel_list[0].x, _pixel_list[0].y)
		for v in _pixel_list:
			nw[v] = last_col
	var ur = get_undo_redo()
	ur.create_action("Palette Changed")
	ur.add_undo_method(self, "color_picker_undo", [nw, get_selected_sprite(), color])
	ur.add_do_method(self, "color_picker_do", [nw, get_selected_sprite(), color])
	ur.commit_action()

func on_color_picker_pressed(which):
	var col = _toolbar.get_node("PaletteContainer").get_node(which.get_name()).get_color()
	_pixel_list.clear()
	var image = get_selected_sprite().get_texture().get_data()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y) == col:
				_pixel_list.append(Vector2(x,y))

func on_brush_size_changed(value):
	_brush_size = value
	_toolbar.get_node("BrushContainer/Size").set_text(str(value)+"px")

func on_palette_menu(i):
	if i == PALETTE_FROM_IMAGE:
		palette_from_image()
	elif i == PALETTE_INDEXED:
		print("indexed")

func on_file_load(file):
	get_selected_sprite().set_texture(load(file))
	print("loading: " + str(file))
	
func on_file_save(file):
	var img = get_selected_sprite().get_texture().get_data()
	img.save_png(file)
	get_selected_sprite().set_texture(load(file))
	print("saving: " + str(file))

func on_sprite_menu(i):
	if i == SPRITE_SAVE_AS:
		print("save as..")
		_toolbar.get_node("FileDialogSave").popup_centered_ratio()
	elif i == SPRITE_LOAD:
		print("load")
		_toolbar.get_node("FileDialogLoad").popup_centered_ratio()
	elif i == SPRITE_RESIZE:
		print("resize..")
		_resize.get_node("VBoxContainer/GridContainer/WidthBox").set_value(get_selected_sprite().get_texture().get_width())
		_resize.get_node("VBoxContainer/GridContainer/HeightBox").set_value(get_selected_sprite().get_texture().get_height())
		_resize.popup_centered_minsize(Vector2(196,196))
		
func on_resize_confirmed():
	var os = get_selected_sprite().get_texture().get_size()
	var ns = Vector2(_resize.get_node("VBoxContainer/GridContainer/WidthBox").get_value(),_resize.get_node("VBoxContainer/GridContainer/HeightBox").get_value())
	var selected = _resize.get_node("VBoxContainer/GridContainer/ButtonGroup").get_pressed_button().get_name()

	var img = Image(ns.x, ns.y, false, Image.FORMAT_RGBA)

	var src_rect = Rect2(0,0, os.x, os.y)
	var dest_vec = Vector2(0,0)
	
	if selected.find("R") != -1:
		dest_vec.x = ns.x-os.x
	if selected.find("D") != -1:
		dest_vec.y = ns.y-os.y
	if selected.find("N") != -1:
		dest_vec.x = floor(ns.x/2)-floor(os.x/2)
	if selected.find("M") != -1:
		dest_vec.y = floor(ns.y/2)-floor(os.y/2)

	# guard from copy out-of-bounds, e.g. in case of shrinking canvas
	if dest_vec.x < 0:
		src_rect.pos.x -= dest_vec.x
		dest_vec.x = 0
	if dest_vec.y < 0:
		src_rect.pos.y -= dest_vec.y
		dest_vec.y = 0

	img.blit_rect(get_selected_sprite().get_texture().get_data(), src_rect, dest_vec)

	# set new image
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	get_selected_sprite().set_texture(tex)

	# get_undo_redo().clear_history()
	
	print("resize confirmed: " + selected + " , " + str(os) + ", " + str(ns))
	
