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
func _to_yaml():
	var string = ""
	#      - offsetX: -1
    #        offsetY: -0.3
    #        angle: -220
    #        time: 0.1
    #        color: "#ffffff2f"
	#        scale: "1.0, 1.0"
	string += "      - offsetX: " + str(offsetX).left(4)+"\n"
	string += "        offsetY: " + str(offsetY).left(4)+"\n"
	string += "        angle: " + str(int(angle))+"\n"
	string += "        time: " + str(delta).left(4)+"\n"
	if(color != Color.WHITE):
		string += '        color: "#' + color.to_html()+'"\n'
	if(scaleX != 1 || scaleY != 1):
		string += "        scale: "+str(scaleX).left(3)+", "+str(scaleY).left(3)+"\n"
	return string
	
