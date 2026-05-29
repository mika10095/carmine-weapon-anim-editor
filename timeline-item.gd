extends ColorRect
@onready var index_label = $IndexLabel
@onready var editor = $"../../../.."
@onready var anim_key_holder = $".."
var length
# Called when the node enters the scene tree for the first time.
func _ready():
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func initialise(key:AnimationKey):
	index_label.text = str(key.index)
	length = key.delta
	editor.total_length_changed.connect(_on_total_length_changed)
	editor.current_key_changed.connect(_on_key_changed)

func _on_total_length_changed(item_count):
	await get_tree().process_frame
	var total_width = anim_key_holder.size.x-200
	custom_minimum_size.x = total_width*(length/item_count)
	print("new length for "+ index_label.text+" "+ str(size.x))

func _on_key_changed(key):
	if index_label.text == str(key):
		color = Color.DARK_GREEN
	else:
		color = Color.REBECCA_PURPLE
