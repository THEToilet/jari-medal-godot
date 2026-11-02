extends SceneTree
var t := 0.0
var k := 0
func _initialize(): change_scene_to_file("res://scenes/main.tscn")
func _process(d):
	t += d
	var m = current_scene
	if m == null: return false
	if t > 0.5 and t < 0.6:
		var e := InputEventAction.new(); e.action = "coin"; e.pressed = true; Input.parse_input_event(e)
		var e2 := InputEventAction.new(); e2.action = "coin"; e2.pressed = false; Input.parse_input_event(e2)
	if t > 2.0 and k < 16 and fmod(t, 0.1) < d:
		root.get_texture().get_image().save_png("/tmp/seq/%02d.png" % k); k += 1
	return t > 4.0
