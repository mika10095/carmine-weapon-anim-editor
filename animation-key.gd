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
	string += "      - offsetX: " + str(snapped(offsetX,0.01))+"\n"
	string += "        offsetY: " + str(snapped(offsetY,0.01))+"\n"
	string += "        angle: " + str(int(angle))+"\n"
	string += "        time: " + str(snapped(delta,0.01))+"\n"
	if(color != Color.WHITE):
		string += '        color: "#' + color.to_html()+'"\n'
	if(scaleX != 1 || scaleY != 1):
		string += "        scale: "+str(snapped(scaleX,0.01))+", "+str(snapped(scaleY,0.01))+"\n"
	return string
	
