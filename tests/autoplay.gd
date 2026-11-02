extends SceneTree
# テスト用：自動で1プレイ（または複数）回してスクショを撮る
var t := 0.0
var main: Node
var step := 0
var shots := {}
var plays := 0
var max_plays := int(OS.get_environment("PLAYS") if OS.get_environment("PLAYS") != "" else "1")
var target := int(OS.get_environment("TARGET") if OS.get_environment("TARGET") != "" else "6")
var bets := int(OS.get_environment("BETS") if OS.get_environment("BETS") != "" else "3")
var next_tap := 0.0
var phase_t := 0.0

func _initialize():
	change_scene_to_file("res://scenes/main.tscn")

func key(action: String, pressed: bool):
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)

func tapk(action: String):
	key(action, true); key(action, false)

func shot(name: String):
	if shots.has(name): return
	shots[name] = true
	var img := root.get_texture().get_image()
	if img: img.save_png("/tmp/shots/%s.png" % name)

func _process(delta: float) -> bool:
	t += delta
	phase_t += delta
	main = current_scene
	if main == null: return false
	var st: int = main.get("state")
	match st:
		0: # WAIT
			if plays >= max_plays and phase_t > 1.0:
				print("DONE medals=", root.get_node("MedalWallet").medals)
				return true
			if phase_t > 1.0:
				shot("p%d_0_wait" % plays)
				for i in bets: tapk("coin")
				phase_t = 0
		1: # BET
			if phase_t > 0.7:
				var cc0 = main.centered_building()
				if absf(cc0.position.x - 960.0) < 1.0 and main.get("_dwell") < 0.15:
					shot("p%d_1b_bet" % plays)
				if absf(cc0.position.x - 960.0) > 150.0:
					shot("p%d_1c_bet" % plays)
			if phase_t > 1.0:
				shot("p%d_1_bet" % plays)
				var c = main.centered_building()
				var want = main.BUILDINGS[target].payout
				if c.data.payout == want and absf(c.position.x - 960.0) < 30.0:
					tapk("tap")
					phase_t = 0
		3: # CHARGE
			if phase_t > next_tap:
				tapk("tap")
				next_tap = phase_t + 0.09
			if phase_t > 1.0: shot("p%d_2a_charge" % plays)
			if phase_t > 3.0: shot("p%d_2_charge" % plays)
			if phase_t > 4.6: shot("p%d_2b_charge" % plays)
		4: # DETONATE
			if phase_t > 1.2:
				shot("p%d_3_detonate" % plays)
				tapk("tap")
				phase_t = 0
				next_tap = 0
		5: # RESULT
			if phase_t > 0.15: shot("p%d_4a_surge" % plays)
			if phase_t > 0.3: shot("p%d_4_boom" % plays)
			if phase_t > 0.9: shot("p%d_4c_boom" % plays)
			if phase_t > 1.6: shot("p%d_5_smoke" % plays)
			if phase_t > 4.0: shot("p%d_6_tilt" % plays)
			if phase_t > 7.5: shot("p%d_7_after" % plays)
	if st != 5 and main.get("_last_st") == 5:
		plays += 1
	main.set_meta("x", 0)
	if not main.has_meta("prev"): main.set_meta("prev", st)
	if main.get_meta("prev") == 5 and st != 5:
		plays += 1
	if main.get_meta("prev") != st: phase_t = 0
	main.set_meta("prev", st)
	if t > 120: print("TIMEOUT"); return true
	return false
