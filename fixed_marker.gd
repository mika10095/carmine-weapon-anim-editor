extends ColorRect
@onready var anim_key_holder = %AnimKeyHolder
@onready var editor = $"../../.."
@export var mark_time = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	editor.total_length_changed.connect(_on_total_length_changed)

func _on_total_length_changed(length):
	await get_tree().process_frame
	var total_width = anim_key_holder.size.x
	position.x = total_width*(mark_time/length)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
