extends Control
@onready var yaml_text := %YAMLText
const TIMELINE_ITEM := preload("uid://cd5nssgom0amw")
@onready var anim_button := $VBoxContainer/HBoxContainer/Tree/AnimButton
@onready var total_length_label := %TotalLengthLabel
@onready var weapon_sprite := %WeaponSprite
@onready var weapon_sprite_ghost := %WeaponSpriteGhost
@onready var weapon_sprite_ghost_previous := %WeaponSpriteGhostPrevious
@onready var weapon_sprite_ghost_next := %WeaponSpriteGhostNext
@onready var rotation_anchor := %RotationAnchor
@onready var progress_marker := %ProgressMarker
@onready var anim_key_holder := %AnimKeyHolder
@onready var urist := %Urist
@onready var undo_redo_label := %UndoRedoLabel

@onready var timer_text := %TimerText
@onready var key_text := %KeyText
@onready var color_picker_button := %ColorPickerButton

@onready var key_pos_x_text := %KeyPosX
@onready var key_pos_y_text := %KeyPosY
@onready var key_scale_x_text := %KeyScaleX
@onready var key_scale_y_text := %KeyScaleY
@onready var key_rot_text := %KeyRot
@onready var key_length_text := %KeyLength

var key_color := Color.WHITE
var key_pos_x := 0.0
var key_pos_y := 0.0
var key_scale_x := 1.0
var key_scale_y := 1.0
var key_rot := 0.0
var key_length := 0.1

var selected_key := 0

var keyframes = []

var undo_states = []
var redo_states = []
var is_restoring_state := false

signal total_length_changed(item_count)
signal current_key_changed(key)
var index := 0
var time := 0.0
var playing := false
var time_scale := 1.0
var interpolated := false
var mirrored := false
var gunmode := false
var copy_key := false
var key_visuals := true
var start_time := 0.0
var end_time := 0.0
var move_speed := 50
# Called when the node enters the scene tree for the first time.
func _ready():
	var new_key = AnimationKey.new()
	new_key.index = index
	new_key.offsetX = float(key_pos_x_text.text)
	new_key.offsetY = float(key_pos_y_text.text)
	new_key.angle = float(key_rot_text.text)
	new_key.scaleX = float(key_scale_x_text.text)
	new_key.scaleY = float(key_scale_y_text.text)
	new_key.color = key_color
	new_key.delta = float(key_length_text.text)
	keyframes.append(new_key)
	_write_back_keys()
	_on_parse_pressed()
	_on_anim_button_pressed()
	await get_tree().create_timer(0.25).timeout
	_write_back_keys()
	_on_parse_pressed()
	_on_anim_button_pressed()
	set_total_length()
	await get_tree().process_frame
	undo_states.clear()
	redo_states.clear()
	save_undo_state()
	selected_key = 0
	current_key_changed.emit(selected_key)

	
func _input(_event):
	pass

func _process(delta):
	var movement_vec = Input.get_vector("move_left","move_right","move_up","move_down")
	var rotation_vec = Input.get_vector("rotate_right", "rotate_left","length_down","length_up")
	if(movement_vec):
		var corrected_movement = movement_vec.rotated(rotation_anchor.global_rotation)
		corrected_movement.y *= -1
		if(rotation_anchor.rotation_degrees > 45 && rotation_anchor.rotation_degrees < 135 || rotation_anchor.rotation_degrees < -45 && rotation_anchor.rotation_degrees > -135):
			corrected_movement.y *= -1
			corrected_movement.x *= -1
		weapon_sprite_ghost.position += corrected_movement*delta*move_speed
		key_pos_x_text.text = str(snapped(-weapon_sprite_ghost.position.x * 0.03125,0.01))
		key_pos_y_text.text = str(snapped(-weapon_sprite_ghost.position.y * 0.03125,0.01))
	if(rotation_vec):
		weapon_sprite_ghost.rotation_degrees += rotation_vec.x*delta*move_speed
		key_length_text.text = str(max(float(key_length_text.text)+snapped(rotation_vec.y*0.01,0.01),0.0))
	key_rot_text.text = str(snapped(
	wrapf(weapon_sprite_ghost.rotation_degrees, 0.0, 360.0),
	0.01
	))
		
	var new_key = AnimationKey.new()
	new_key.index = index
	new_key.offsetX = float(key_pos_x_text.text)
	new_key.offsetY = float(key_pos_y_text.text)
	new_key.angle = float(key_rot_text.text)
	new_key.scaleX = float(key_scale_x_text.text)
	new_key.scaleY = float(key_scale_y_text.text)
	new_key.color = key_color
	new_key.delta = float(key_length_text.text)
	if(Input.is_action_just_pressed("quick_key_place")):
		new_key.index = selected_key+1
		keyframes.insert(selected_key+1, new_key)
		_write_back_keys()
		_on_parse_pressed()
		current_key_changed.emit(selected_key+1)
		update_animation()
		set_total_length()
		_on_key_text_text_changed(str(selected_key+1))
		update_animation()
		copy_key_to_ghost(selected_key)
		save_undo_state()
	elif(Input.is_action_just_pressed("key_modify")):
		new_key.index = selected_key
		keyframes.set(selected_key, new_key)
		_write_back_keys()
		_on_parse_pressed()
		current_key_changed.emit(selected_key)
		update_animation()
		set_total_length()
		#copy_key_to_ghost(selected_key)
		save_undo_state()
	elif(Input.is_action_just_pressed("next_key")):
		selected_key=min(selected_key+1,keyframes.size()-1)
		current_key_changed.emit(selected_key)
		_on_key_text_text_changed(str(selected_key))
		update_animation()
		set_total_length()
		copy_key_to_ghost(selected_key)
		save_undo_state()
	elif(Input.is_action_just_pressed("previous_key")):
		selected_key=max(selected_key-1,0)
		current_key_changed.emit(selected_key)
		_on_key_text_text_changed(str(selected_key))
		update_animation()
		set_total_length()
		copy_key_to_ghost(selected_key)
		save_undo_state()
	elif(Input.is_action_just_pressed("delete_key")):
		if(keyframes.size()>1):
			keyframes.remove_at(selected_key)
			selected_key = max(selected_key-1,0)
		_write_back_keys()
		_on_parse_pressed()
		current_key_changed.emit(selected_key)
		update_animation()
		set_total_length()
		_on_key_text_text_changed(selected_key)
		update_animation()
		copy_key_to_ghost(selected_key)
		save_undo_state()
	if(!playing):
		return
	
	if keyframes.size() < 1:
		return

	time += delta * time_scale
	
	var total_length = 0.0
	for key in keyframes:
		total_length+=key.delta
	total_length_label.text = "total length: " + str(total_length)
	
	var progress_max = anim_key_holder.size.x 
	progress_marker.position.x = progress_max*(time/total_length)-8
	
	if time < start_time:
		time = start_time
	
	if time >= total_length:
		time = start_time
	
	if time >= end_time && end_time > 0:
		time = start_time

	update_animation()


func _write_back_keys():
	yaml_text.clear()
	yaml_text.text += "animationKeyframes:\n"

	for key in keyframes:
		yaml_text.text += key._to_yaml()

func create_state():
	return {
		"yaml": yaml_text.text,
		"selected_key": selected_key,
		"time": time
	}

func save_undo_state():
	redo_states.clear()
	undo_states.append(create_state())

	if undo_states.size() > 200:
		undo_states.pop_front()
	undo_redo_label.text = "Undo: "+str(undo_states.size())+" Redo: "+str(redo_states.size())

func restore_state(state):
	is_restoring_state = true

	yaml_text.text = state.yaml

	_on_parse_pressed()

	selected_key = clamp(state.selected_key, 0, keyframes.size() - 1)
	time = state.time

	key_text.text = str(selected_key)
	timer_text.text = str(snapped(time, 0.01))

	current_key_changed.emit(selected_key)

	copy_key_to_ghost(selected_key)

	update_animation()
	set_total_length()

	is_restoring_state = false
	undo_redo_label.text = "Undo states: "+str(undo_states.size())+" Redo states "+str(redo_states.size())

func undo():
	if undo_states.size() <= 1:
		return

	var current = create_state()
	redo_states.append(current)

	undo_states.pop_back()
	undo_redo_label.text = "Undo states: "+str(undo_states.size())+" Redo states "+str(redo_states.size())
	var previous = undo_states.back()

	restore_state(previous)

func redo():
	if redo_states.is_empty():
		return

	var current = create_state()
	undo_states.append(current)

	var next = redo_states.pop_back()
	undo_redo_label.text = "Undo states: "+str(undo_states.size())+" Redo states "+str(redo_states.size())
	restore_state(next)

func copy_key_to_ghost(index):
	var key :AnimationKey = keyframes[index]
	var next :AnimationKey = keyframes[min(index+1,keyframes.size()-1)]
	var previous :AnimationKey = keyframes[max(index-1,0)]
	if(key.index != next.index):
		weapon_sprite_ghost_next.visible = true
		update_ghost_pos(weapon_sprite_ghost_next,next)
	else:
		weapon_sprite_ghost_next.visible = false
	if(key.index != previous.index):
		weapon_sprite_ghost_previous.visible = true
		update_ghost_pos(weapon_sprite_ghost_previous,previous)
	else:
		weapon_sprite_ghost_previous.visible = false
	if(!key_visuals):
		weapon_sprite_ghost_previous.visible = false
		weapon_sprite_ghost_next.visible = false
	if(!copy_key):
		return
	update_ghost_pos(weapon_sprite_ghost,key)
	key_pos_x_text.text = str(key.offsetX)
	key_pos_y_text.text = str(key.offsetY)
	key_rot_text.text = str(int(key.angle))
	key_length_text.text = str(key.delta)
	key_color = key.color
	key_scale_x_text.text = str(key.scaleX)
	key_scale_y_text.text = str(key.scaleY)
	color_picker_button.color = key.color

func update_ghost_pos(ghost, animationkey):
	ghost.position.x = -animationkey.offsetX * 32
	ghost.position.y = -animationkey.offsetY * 32
	ghost.rotation_degrees = int(animationkey.angle)
	ghost.scale.x = -animationkey.scaleX
	ghost.scale.y = animationkey.scaleY

func update_animation():
	var current_time = time
	var time_accumulator = 0.0
	var i = 0

	if keyframes.size() < 1:
		return

	if(mirrored):
		rotation_anchor.scale = Vector2.ONE
	else:
		rotation_anchor.scale = Vector2(-1.0, 1.0)

	var current = keyframes[0]
	var next = keyframes[0]
	if(keyframes.size() != 1):
		next = keyframes[1]

	

	while i < keyframes.size() - 1 and current_time > time_accumulator + current.delta:
		time_accumulator += current.delta
		i += 1
		current = keyframes[i]
		next = keyframes[min(i + 1, keyframes.size() - 1)]

	var segment_start = time_accumulator
	var segment_end = time_accumulator + current.delta

	var t = inverse_lerp(segment_start, segment_end, current_time)
	t = clamp(t, 0.0, 1.0)

	t = t * t * (3.0 - 2.0 * t)

	timer_text.text =  str(snapped(time,0.01))
	key_text.text = str(i)
	
	current_key_changed.emit(i)
	copy_key_to_ghost(i)
	selected_key = i
	apply_interpolated_frame(current, next, t, i)

func shortest_angle_delta(from: float, to: float) -> float:
	return wrapf(to - from, -180.0, 180.0)

func unwrap_angle(reference: float, angle: float) -> float:
	return reference + shortest_angle_delta(reference, angle)

func cubic_angle_interp(a0, a1, a2, a3, t):
	# unwrap everything relative to previous point
	a1 = wrapf(a1, 0.0, 360.0)
	a0 = unwrap_angle(a1, a0)
	a2 = unwrap_angle(a1, a2)
	a3 = unwrap_angle(a2, a3)

	var result = cubic_interp(a0, a1, a2, a3, t)

	return wrapf(result, 0.0, 360.0)

func cubic_interp(p0, p1, p2, p3, t):
	var t2 = t * t
	var t3 = t2 * t

	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func apply_interpolated_frame(a, b, t, i):
	if !interpolated:
		weapon_sprite.position = Vector2(-a.offsetX, -a.offsetY) / 0.03125
		weapon_sprite.rotation_degrees = a.angle
		weapon_sprite.scale = Vector2(-a.scaleX, a.scaleY)
		weapon_sprite.modulate = a.color
		return

	var p0 = keyframes[max(i - 1, 0)]
	var p1 = a
	var p2 = b
	var p3 = keyframes[min(i + 2, keyframes.size() - 1)]

	var pos_x
	var pos_y

	if gunmode:
		pos_x = cubic_interp(
			p0.offsetX,
			p1.offsetX,
			p2.offsetX,
			p3.offsetX,
			t
		)

		pos_y = cubic_interp(
			-p0.offsetY,
			-p1.offsetY,
			-p2.offsetY,
			-p3.offsetY,
			t
		)
	else:
		pos_x = cubic_interp(
			-p0.offsetX,
			-p1.offsetX,
			-p2.offsetX,
			-p3.offsetX,
			t
		)

		pos_y = cubic_interp(
			-p0.offsetY,
			-p1.offsetY,
			-p2.offsetY,
			-p3.offsetY,
			t
		)

	weapon_sprite.position = Vector2(pos_x, pos_y) / 0.03125

	weapon_sprite.rotation_degrees = cubic_angle_interp(
	p0.angle,
	p1.angle,
	p2.angle,
	p3.angle,
	t
	)

	if gunmode:
		weapon_sprite.rotation_degrees += 180

	weapon_sprite.scale = Vector2(
		cubic_interp(-p0.scaleX, -p1.scaleX, -p2.scaleX, -p3.scaleX, t),
		cubic_interp(p0.scaleY, p1.scaleY, p2.scaleY, p3.scaleY, t)
	)

	weapon_sprite.modulate = a.color.lerp(b.color, t)

func _on_parse_pressed():
	keyframes.clear()
	for child in anim_key_holder.get_children():
		child.queue_free()
	index = 0
	parse_data(_yaml_to_data())
	_write_back_keys() 
	set_total_length()

	

func _yaml_to_data():
	var parser = YAMLParser.new()
	return parser.parse(yaml_text.text)

func parse_data(result):
	var parsed = JSON.parse_string(str(result))
	for keyframe in parsed["animationKeyframes"]:
		var key = AnimationKey.new()
		key.index = index
		key.offsetX = keyframe.get("offsetX", 0.0)
		key.offsetY = keyframe.get("offsetY", 0.0)
		key.angle = wrapf(keyframe.get("angle", 0.0),0,360)
		key.delta = keyframe.get("time", 0.1)
		if keyframe.has("scale"):
			var scalexy = keyframe.get("scale").split(",")
			key.scaleX = scalexy[0].strip_edges().to_float()
			key.scaleY = scalexy[1].strip_edges().to_float()
		if keyframe.has("color"):
			var color = keyframe.get("color")
			key.color = Color.from_string(color,Color.WHITE)
		keyframes.append(key)
		var item = TIMELINE_ITEM.instantiate()
		anim_key_holder.add_child(item)
		print(key._to_string())
		item.call("initialise", key)
		index+=1
	await get_tree().process_frame
	set_total_length()

func set_total_length():
	var length = 0.0
	for key in keyframes:
		length+=key.delta
	print("total length of all segments: " +str(length))
	total_length_changed.emit(length)
	total_length_label.text = "total length: " + str(length)
	var progress_max = anim_key_holder.size.x 
	progress_marker.position.x = progress_max*(time/length)-8
	


func _on_anim_button_pressed():
	if(!playing):
		weapon_sprite_ghost.visible = true
		weapon_sprite_ghost.process_mode = Node.PROCESS_MODE_ALWAYS
		playing = true
		time = 0.0
		anim_button.text = "Stop"
	else:
		weapon_sprite_ghost.visible = true
		weapon_sprite_ghost.process_mode = Node.PROCESS_MODE_ALWAYS
		playing = false
		time = 0.0
		anim_button.text = "Play"


func _on_global_rotation_text_changed(new_text):
	var rot:float = float(new_text)
	rot = wrapf(rot,0,360)
	rotation_anchor.global_rotation_degrees = rot
	if rot >= 315 or rot < 45:
		urist.frame = 4 
	elif rot >= 45 and rot < 135:
		urist.frame = 7
	elif rot >= 135 and rot < 225:
		urist.frame = 5 
	else:
		urist.frame = 6


func _on_set_sprite_button_pressed():
	var file_dialog := FileDialog.new()

	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray([
		"*.png ; PNG Images",
	])

	add_child(file_dialog)

	file_dialog.file_selected.connect(_on_sprite_file_selected)

	file_dialog.popup_centered()


func _on_sprite_file_selected(path: String):
	var image := Image.load_from_file(path)

	if image == null:
		push_error("Failed to load image")
		return

	var texture := ImageTexture.create_from_image(image)

	weapon_sprite.texture = texture
	weapon_sprite_ghost.texture = texture


func _on_time_scale_text_changed(new_text):
	var tscale = float(new_text)
	if(tscale):
		time_scale = tscale

func _on_interpolation_pressed():
	interpolated = not interpolated
	


func _on_mirrored_anim_pressed():
	mirrored = not mirrored


func _on_gun_mode_pressed():
	gunmode = not gunmode
	rotation_anchor.global_rotation_degrees = 180


func _on_clipboard_button_pressed():
	var text = ""
	text += "animationKeyframes:\n"
	var init_key = keyframes[0]
	init_key.delta = 0 
	text += init_key._to_yaml()
	for key in keyframes:
		text += key._to_yaml()
	DisplayServer.clipboard_set(text)


func _on_start_time_text_changed(new_text):
	var start = float(new_text)
	if(start):
		start_time = start


func _on_end_time_text_changed(new_text):
	var end = float(new_text)
	if(end):
		end_time = end


func _on_key_pos_x_text_changed(new_text):
	if !new_text.is_valid_float():
		return
	var posx = float(new_text)
	key_pos_x = posx
	weapon_sprite_ghost.position.x = -posx * 32


func _on_key_pos_y_text_changed(new_text):
	if !new_text.is_valid_float():
		return
	var posy = float(new_text)
	key_pos_y = posy
	weapon_sprite_ghost.position.y = -posy * 32


func _on_key_rot_text_changed(new_text):
	if !new_text.is_valid_float():
		return
	var rot = float(new_text)
	key_rot = rot
	weapon_sprite_ghost.rotation_degrees = rot


func _on_key_scale_x_text_changed(new_text):
	var val = float(new_text)
	if(val):
		key_scale_x = val
		weapon_sprite_ghost.scale.x = -val


func _on_key_scale_y_text_changed(new_text):
	var val = float(new_text)
	if(val):
		key_scale_y = val
		weapon_sprite_ghost.scale.y = val


func _on_key_length_text_changed(new_text):
	var val = float(new_text)
	if(val):
		key_length = val


func _on_color_picker_button_color_changed(color):
	key_color = color


func _on_timer_text_text_changed(new_text):
	var new_time = float(new_text)
	if(new_time):
		time = new_time
		var time_accumulator = 0
		var selected = 0
		for i in range(keyframes.size()):
			time_accumulator += keyframes[i].delta
			if new_time <= time_accumulator:
				selected = i
				break
		selected_key = selected
		current_key_changed.emit(selected)
		copy_key_to_ghost(selected)
		key_text.text = str(selected)


func _on_key_text_text_changed(new_text):
	var key = int(new_text)
	selected_key = key
	var time_accumulator = 0
	for i in range(keyframes.size()):
		if(i<key):
			time_accumulator += keyframes[i].delta
	time_accumulator += keyframes[min(key,keyframes.size()-1)].delta/2
	time = time_accumulator
	timer_text.text = str(time_accumulator)
	_on_timer_text_text_changed(timer_text.text)
	current_key_changed.emit(selected_key)
	copy_key_to_ghost(selected_key)


func _on_copy_key_toggle_pressed():
	copy_key = !copy_key


func _on_undo_button_pressed():
	undo()


func _on_redo_button_pressed():
	redo()


func _on_key_visualiser_toggle_pressed():
	key_visuals = !key_visuals
	update_animation()
