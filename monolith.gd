extends Control
@onready var yaml_text = %YAMLText
const TIMELINE_ITEM = preload("uid://cd5nssgom0amw")
@onready var anim_button = $VBoxContainer/HBoxContainer/Tree/AnimButton
@onready var total_length_label = $VBoxContainer/HBoxContainer/Tree/TotalLengthLabel
@onready var current_time_label = $VBoxContainer/HBoxContainer/Tree/CurrentTimeLabel
@onready var weapon_sprite = %WeaponSprite
@onready var rotation_anchor = %RotationAnchor
@onready var progress_marker = %ProgressMarker
@onready var anim_key_holder = %AnimKeyHolder
@onready var urist = %Urist

var keyframes = []
signal total_length_changed(item_count)
signal current_key_changed(key)
var index = 0
var time = 0.0
var playing = false
var time_scale = 1.0
var interpolated = false
var mirrored = false
var gunmode = false
var start_time = 0.0
var end_time = 0.0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(!playing):
		return
	
	if keyframes.size() < 2:
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

func update_animation():
	var current_time = time
	var time_accumulator = 0.0
	var i = 0

	if keyframes.size() < 2:
		return

	if(mirrored):
		rotation_anchor.scale = Vector2.ONE
	else:
		rotation_anchor.scale = Vector2(-1.0, 1.0)

	var current = keyframes[0]
	var next = keyframes[1]

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

	current_time_label.text = "time " + str(time).substr(0, 4) + " key " + str(i)
	current_key_changed.emit(i)
	apply_interpolated_frame(current, next, t, i)

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

	weapon_sprite.rotation_degrees = cubic_interp(
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
		key.angle = keyframe.get("angle", 0.0)
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
		await item.is_node_ready()
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

func _on_anim_button_pressed():
	if(!playing):
		playing = true
		time = 0.0
		anim_button.text = "Stop"
	else:
		playing = false
		time = 0.0
		anim_button.text = "Play"


func _on_global_rotation_text_changed(new_text):
	var rotation:float = float(new_text)
	rotation_anchor.global_rotation_degrees = rotation
	if rotation >= -45 and rotation < 45:
		urist.frame = 4
	elif rotation >= 45 and rotation < 135:
		urist.frame = 7
	elif rotation >= -135 and rotation < -45:
		urist.frame = 6
	else:
		urist.frame = 5


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


func _on_time_scale_text_changed(new_text):
	var scale = float(new_text)
	if(scale):
		time_scale = scale

func _on_interpolation_pressed():
	interpolated = not interpolated
	


func _on_mirrored_anim_pressed():
	mirrored = not mirrored


func _on_gun_mode_pressed():
	gunmode = not gunmode
	rotation_anchor.global_rotation_degrees = 180


func _on_clipboard_button_pressed():
	DisplayServer.clipboard_set(yaml_text.text)


func _on_start_time_text_changed(new_text):
	var start = float(new_text)
	if(start):
		start_time = start


func _on_end_time_text_changed(new_text):
	var end = float(new_text)
	if(end):
		end_time = end
