extends Node3D
## 仮想筐体：2Dのゲーム（scenes/main.tscn）を SubViewport で描いて、3D筐体の画面に映す。
## ゲーム側には手を入れず、筐体と同じ入出力だけでつなぐ。
##  - 入力：ボタン → InputMap "tap"、メダル投入口 → "coin" を SubViewport に流す
##  - 出力：ゲームの finished(払い出し枚数) → 受け皿にメダルを物理で落とす
## 操作：ボタン（または画面のどこか）をクリック/タップ ＝ ボタン、投入口をクリック/タップ ＝ メダル投入
##       キーボードは Space/Enter ＝ ボタン、C ＝ メダル投入（2D版と同じ）、F3 ＝ 払い出しの確認（デバッグ）

const MAX_MEDALS := 150          # 受け皿に残すメダルの上限（古いものから消す）
const MEDAL_R := 0.0125
const MEDAL_H := 0.0025

@onready var cabinet: Node3D = $Cabinet
@onready var game_viewport: SubViewport = $GameViewport
@onready var game: Node = $GameViewport/Game
@onready var camera: Camera3D = $Camera3D

var _button_cap: MeshInstance3D
var _cap_rest: Vector3
var _coin_slot: Node3D
var _pocket: MeshInstance3D
var _led_mat: StandardMaterial3D
var _led_mode := "idle"
var _win_left := 0.0
var _t := 0.0
var _tap_down := false
var _payout_queue := 0
var _payout_timer := 0.0
var _medals: Array[RigidBody3D] = []
var _medal_mesh: CylinderMesh
var _medal_shape: BoxShape3D
var _cam_full: Transform3D
var _cam_zoom: Transform3D
var _cam_tray: Transform3D
var _cam_view := "full"
var _cam_tween: Tween


func _ready() -> void:
	_button_cap = cabinet.find_child("ButtonCap", true, false)
	_cap_rest = _button_cap.position
	_coin_slot = cabinet.find_child("CoinSlot", true, false)
	_pocket = cabinet.find_child("PayoutPocket", true, false)

	# 画面にゲームを映す
	var screen: MeshInstance3D = cabinet.find_child("Screen", true, false)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = game_viewport.get_texture()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = sm

	# ポップのロゴ
	var logo: MeshInstance3D = cabinet.find_child("TopperLogo", true, false)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = load("res://assets/title_logo.png")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	logo.material_override = lm
	var decal: MeshInstance3D = cabinet.find_child("FrontDecal", true, false)
	if decal:
		decal.visible = false   # 前面の絵は未定

	# LED は1つのマテリアルを共有して色を一括で変える
	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n: Node in cabinet.find_children("LED_*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = _led_mat

	# クリック判定と、メダルが溜まるくぼみの当たり
	_button_cap.create_convex_collision()
	(cabinet.find_child("CoinSlotPlate", true, false) as MeshInstance3D).create_convex_collision()
	_build_pocket_collision()

	_medal_mesh = CylinderMesh.new()
	_medal_mesh.top_radius = MEDAL_R
	_medal_mesh.bottom_radius = MEDAL_R
	_medal_mesh.height = MEDAL_H
	_medal_mesh.radial_segments = 12
	_medal_mesh.rings = 1
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.85, 0.86, 0.9)
	mm.metallic = 0.4
	mm.roughness = 0.3
	_medal_mesh.material = mm
	# 当たりは薄い箱（円柱より薄くても安定する）
	_medal_shape = BoxShape3D.new()
	_medal_shape.size = Vector3(MEDAL_R * 1.8, MEDAL_H * 2.0, MEDAL_R * 1.8)

	# カメラ：全体 ↔ 画面とボタンに寄る
	_cam_full = camera.global_transform
	var screen_pos := screen.global_position
	var target := screen_pos.lerp(_button_cap.global_position, 0.35)
	_cam_zoom = Transform3D(Basis(), target + Vector3(0, 0.1, 0.95)).looking_at(target, Vector3.UP)
	var tray := _pocket.get_aabb().get_center()
	_cam_tray = Transform3D(Basis(), tray + Vector3(0, 0.32, 1.15)).looking_at(tray + Vector3(0, 0.1, 0), Vector3.UP)

	game.finished.connect(_on_finished)


## くぼみの当たりは箱で作る（薄いメダルがメッシュの当たりをすり抜けないように）
func _build_pocket_collision() -> void:
	var box := _pocket.get_aabb()   # くぼみの内側（Cabinet座標）
	var lo := box.position + Vector3(0, 0.007, 0)   # 物理の沈み込みぶん底を上げる（見た目でメダルが底に乗るように）
	var hi := box.end
	var t := 0.05
	var body := StaticBody3D.new()
	cabinet.add_child(body)
	var parts := [
		[Vector3((lo.x + hi.x) / 2, lo.y - t / 2, (lo.z + hi.z) / 2), Vector3(hi.x - lo.x + 2 * t, t, hi.z - lo.z)],   # 底
		[Vector3(lo.x - t / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2), Vector3(t, hi.y - lo.y, hi.z - lo.z)],             # 左
		[Vector3(hi.x + t / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2), Vector3(t, hi.y - lo.y, hi.z - lo.z)],             # 右
		[Vector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - t / 2), Vector3(hi.x - lo.x, hi.y - lo.y, t)],             # 奥
	]
	for p: Array in parts:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = p[1]
		cs.shape = bs
		cs.position = p[0]
		body.add_child(cs)


# ---------------------------------------------------------------- 入力

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		# キーはそのままゲームへ（Space/Enter=ボタン、C=投入、F2=デバッグ補充）
		if not e.echo:
			if e.pressed and e.physical_keycode == KEY_F3:
				_on_finished(10)   # デバッグ：払い出しの確認（10枚）
				return
			if e.is_action_pressed("tap"):
				_press_anim(true)
			elif e.is_action_released("tap"):
				_press_anim(false)
			elif e.is_action_pressed("coin"):
				_refill_if_empty()
				_coin_anim()
		game_viewport.push_input(e)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		# スマホのタップもマウスとして届く（emulate_mouse_from_touch）
		if e.pressed:
			if _pick(e.position) == "coin":
				_insert_coin()
			else:
				_tap(true)   # 投入口以外はどこを押してもボタン扱い（スマホで連打しやすく）
		elif _tap_down:
			_tap(false)
		get_viewport().set_input_as_handled()


func _pick(pos: Vector2) -> String:
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 10.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return ""
	var n: Node = hit.collider
	while n and n != cabinet:
		if n == _coin_slot:
			return "coin"
		n = n.get_parent()
	return ""


func _tap(down: bool) -> void:
	_tap_down = down
	_press_anim(down)
	_send_action("tap", down)


func _insert_coin() -> void:
	_refill_if_empty()
	_coin_anim()
	_send_action("coin", true)
	_send_action("coin", false)


func _refill_if_empty() -> void:
	# 仮想筐体ではメダルが尽きたら補充する（ブラウザの2D版と同じ）
	if MedalWallet.medals <= 0:
		MedalWallet.add(50)


func _send_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	game_viewport.push_input(ev)


func _press_anim(down: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_button_cap, "position", _cap_rest - Vector3(0, 0.01, 0) if down else _cap_rest, 0.04)


func _coin_anim() -> void:
	# メダルが投入口に吸い込まれる
	var m := MeshInstance3D.new()
	m.mesh = _medal_mesh
	_coin_slot.add_child(m)
	m.rotation = Vector3(0, 0, PI / 2)   # 縦向き（スリットに合わせる）
	m.position = Vector3(0, -0.012, 0.06)
	var tw := create_tween()
	tw.tween_property(m, "position:z", -0.01, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- 出力

func _on_finished(payout: int) -> void:
	if payout <= 0:
		return
	_payout_queue += payout
	_win_left = 3.0 + payout * 0.08


func _spawn_medal() -> void:
	var b := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = _medal_shape
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _medal_mesh
	b.add_child(mi)
	b.mass = 0.006
	b.continuous_cd = true
	b.linear_damp = 0.5
	cabinet.add_child(b)
	# くぼみの奥の穴から押し出す
	var hole: Node3D = cabinet.find_child("PayoutChute", true, false)
	b.global_position = hole.global_position + Vector3(randf_range(-0.07, 0.07), -0.005, 0.02)
	b.rotation = Vector3(randf_range(-1.2, 1.2), randf() * TAU, randf_range(-1.2, 1.2))
	b.linear_velocity = Vector3(randf_range(-0.08, 0.08), 0.05, randf_range(0.12, 0.3))
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_medals.append(b)
	if _medals.size() > MAX_MEDALS:
		_medals.pop_front().queue_free()


func _process(dt: float) -> void:
	_t += dt
	_win_left = maxf(0.0, _win_left - dt)
	# 払い出し：1枚ずつ（多いときは間隔を詰める）
	if _payout_queue > 0:
		_payout_timer -= dt
		if _payout_timer <= 0.0:
			_spawn_medal()
			_payout_queue -= 1
			_payout_timer = 0.05 if _payout_queue > 10 else 0.1

	var playing: bool = game.is_in_play()
	# LED
	if _win_left > 0.0:
		_led_mat.albedo_color = Color(1, 1, 1) if int(_t * 12.0) % 2 == 0 else Color(1, 0.75, 0.1)
	elif playing or int(game.bet) > 0:
		_led_mat.albedo_color = Color(1, 0.55, 0.15)
	else:
		_led_mat.albedo_color = Color.from_hsv(fmod(_t * 0.15, 1.0), 0.55, 1.0)

	# カメラ：遊んでいる間は画面とボタンに寄る。払い出し中は受け皿、それ以外は全体
	var view := "full"
	if playing:
		view = "zoom"
	elif _win_left > 0.0:
		view = "tray"
	if view != _cam_view:
		_cam_view = view
		if _cam_tween:
			_cam_tween.kill()
		var to: Transform3D = {"full": _cam_full, "zoom": _cam_zoom, "tray": _cam_tray}[view]
		_cam_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_cam_tween.tween_property(camera, "global_transform", to, 0.7)
