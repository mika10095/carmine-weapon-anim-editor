class_name AnimationKey
#1 = 1 tile
#0.03125 = 1 world pixel
var index: int
var offsetX: float
var offsetY: float
var angle: float
var delta: float
var color: Color = Color.WHITE
var scaleX: float = 1
var scaleY: float = 1

func _to_string():
	return(str(index)+" "+str(offsetX)+" "+str(offsetY)+" "+str(angle)+" "+str(delta)+" "+color.to_html()+" "+str(scaleX)+" "+str(scaleY))
