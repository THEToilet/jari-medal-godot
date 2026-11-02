extends SceneTree
var t := 0.0
var done := false
func _initialize(): change_scene_to_file("res://scenes/main.tscn")
func _process(d):
	t += d
	var m = current_scene
	if m == null: return false
	if t > 0.5 and not done:
		done = true
		var e := InputEventAction.new(); e.action = "coin"; e.pressed = true; Input.parse_input_event(e)
		var e2 := InputEventAction.new(); e2.action = "coin"; e2.pressed = false; Input.parse_input_event(e2)
	if t > 0.8 and t < 0.9:
		print("state=", m.state, " bet=", m.bet, " medals=", root.get_node("MedalWallet").medals)
		m._idle = 3.0
	if t > 4.5:
		print("after: state=", m.state, " bet=", m.bet, " msg=", m.lbl_msg.text, " medals=", root.get_node("MedalWallet").medals)
		return true
	return false
