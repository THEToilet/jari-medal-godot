extends Node3D
## 仮想筐体：2Dのゲーム（scenes/main.tscn）を SubViewport で描いて、3D筐体の画面に映す。
## 舞台は「人のいないショッピングモールの角のゲームコーナー」：蛍光灯、リノリウムの床、両隣にも同じ筐体。
## ゲーム側には手を入れず、筐体と同じ入出力だけでつなぐ。
##  - 入力：ボタン → InputMap "tap"、メダル投入 → "coin" を SubViewport に流す
##  - 出力：ゲームの finished(払い出し枚数) → LED を光らせる
## 操作：ボタンが乗っている板（かボタン）をクリック/タップ ＝ ボタン、右上の「メダル」ボタン ＝ メダル投入
##       キーボードは Space/Enter ＝ ボタン、C ＝ メダル投入（2D版と同じ）、F2 ＝ メダル補充（デバッグ）

const GAME_SCENE := preload("res://scenes/main.tscn")
const CRT := preload("res://virtual/crt_screen.gdshader")
const CABINET_SCENE := preload("res://virtual/jari_cabinet.glb")
const CAMERA_OFFSET := Vector3(0, 0.32, 1.5)       # 画面とボタンの間から見た、カメラの位置（立って覗き込むくらい）
const NEIGHBOR_X := [-1.32, -0.66, 0.66, 1.32]     # 両隣の筐体の位置（幅60cm＋すき間6cm）
const NEIGHBOR_SCREENS := ["res://assets/bg.png", "res://assets/splash.png", "res://assets/result/burst_gold.png", "res://assets/bg.png"]

@onready var cabinet: Node3D = $Cabinet
@onready var game_viewport: SubViewport = $GameViewport
@onready var game: Node = $GameViewport/Game
@onready var camera: Camera3D = $Camera3D

var _button_cap: MeshInstance3D
var _cap_rest: Vector3
var _led_mat: StandardMaterial3D
var _neighbor_leds: Array[StandardMaterial3D] = []
var _win_left := 0.0
var _t := 0.0
var _tap_down := false
var _deck: MeshInstance3D


func _ready() -> void:
	_button_cap = cabinet.find_child("ButtonCap", true, false)
	_cap_rest = _button_cap.position
	# ボタンの当たり判定：ボタンが乗っている板とボタン本体
	_deck = cabinet.find_child("ShellDeck", true, false)
	_deck.create_trimesh_collision()
	_button_cap.create_convex_collision()

	# 自分の筐体：画面にゲームを映す（ブラウン管風のシェーダー越し）
	_led_mat = _dress_cabinet(cabinet, game_viewport.get_texture())

	# 両隣の筐体（画面は止まった絵）
	for i in NEIGHBOR_X.size():
		var c: Node3D = CABINET_SCENE.instantiate()
		c.position = Vector3(NEIGHBOR_X[i], 0, 0)
		add_child(c)
		_neighbor_leds.append(_dress_cabinet(c, load(NEIGHBOR_SCREENS[i])))

	_build_room()
	_build_coin_button()

	# カメラは固定：画面とボタンが近くに見える位置
	var screen: Node3D = cabinet.find_child("Screen", true, false)
	var target := screen.global_position.lerp(_button_cap.global_position, 0.25)
	camera.global_transform = Transform3D(Basis(), target + CAMERA_OFFSET).looking_at(target, Vector3.UP)

	# 暗転（Autoload）は筐体の画面の中だけにかける
	Fader.reparent.call_deferred(game_viewport)
	_hook_game()


## 筐体の見た目をそろえる（画面・ポップ・LED）。LED のマテリアルを返す
func _dress_cabinet(c: Node3D, screen_tex: Texture2D) -> StandardMaterial3D:
	var screen: MeshInstance3D = c.find_child("Screen", true, false)
	var sm := ShaderMaterial.new()
	sm.shader = CRT   # 強さはシェーダーの uniform で調整
	sm.set_shader_parameter("screen_tex", screen_tex)
	screen.material_override = sm

	var logo: MeshInstance3D = c.find_child("TopperLogo", true, false)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = load("res://assets/title_logo.png")
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	logo.material_override = lm
	var decal: MeshInstance3D = c.find_child("FrontDecal", true, false)
	if decal:
		decal.visible = false   # 前面の絵は未定

	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n: Node in c.find_children("LED_*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = led
	return led


## モールの角のゲームコーナー：リノリウムの床、うしろの壁、天井と蛍光灯
func _build_room() -> void:
	# 床
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://virtual/linoleum.gdshader")
	floor_mesh.material = fm
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	add_child(floor_mi)

	# うしろの壁（下に巾木）
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.74, 0.73, 0.70)
	wall_mat.roughness = 0.9
	_box(Vector3(12, 2.8, 0.1), Vector3(0, 1.4, -0.42), wall_mat)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.45, 0.43, 0.4)
	_box(Vector3(12, 0.08, 0.02), Vector3(0, 0.04, -0.36), base_mat)

	# 天井（白いボード）と蛍光灯
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_color = Color(0.8, 0.8, 0.78)
	_box(Vector3(12, 0.05, 8), Vector3(0, 2.8, 2), ceil_mat)
	var tube_mat := StandardMaterial3D.new()
	tube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tube_mat.albedo_color = Color(0.97, 0.99, 1.0)
	for x: float in [-1.8, 0.0, 1.8]:
		for z: float in [0.2, 2.0]:
			_box(Vector3(1.2, 0.03, 0.12), Vector3(x, 2.765, z), tube_mat)
			var l := OmniLight3D.new()
			l.position = Vector3(x, 2.6, z)
			l.light_color = Color(0.93, 0.97, 1.0)   # 昼白色の蛍光灯
			l.light_energy = 0.55
			l.omni_range = 4.5
			l.omni_attenuation = 0.8
			add_child(l)
	# 真上からの弱い光（足元の影用）
	var d := DirectionalLight3D.new()
	d.rotation_degrees = Vector3(-80, 10, 0)
	d.light_energy = 0.25
	d.light_color = Color(0.95, 0.97, 1.0)
	d.shadow_enabled = true
	add_child(d)


func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	add_child(mi)


## 右上のメダル投入ボタン（見た目はシンプルに）
func _build_coin_button() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var b := Button.new()
	b.text = "メダル"
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(180, 90)
	b.position = Vector2(1920 - 180 - 24, 24)
	if ResourceLoader.exists("res://assets/fonts/NotoSansJP-Black-subset.otf"):
		b.add_theme_font_override("font", load("res://assets/fonts/NotoSansJP-Black-subset.otf"))
	b.add_theme_font_size_override("font_size", 36)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0, 0, 0, 0.65)
	b.add_theme_stylebox_override("pressed", sp)
	b.pressed.connect(_insert_coin)
	layer.add_child(b)


func _hook_game() -> void:
	game.finished.connect(_on_finished)
	game.restart_requested.connect(_restart_game)


## デモ中にメダルが入ったとき：ゲームの画面だけを作り直す（2D版の reload_current_scene の代わり）
func _restart_game() -> void:
	var old := game
	game = GAME_SCENE.instantiate()
	old.name = "OldGame"
	old.queue_free()
	game.name = "Game"
	game_viewport.add_child(game)
	game_viewport.move_child(Fader, -1)   # 暗転を一番上に
	_hook_game()


# ---------------------------------------------------------------- 入力

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		# キーはそのままゲームへ（Space/Enter=ボタン、C=投入、F2=デバッグ補充）
		if not e.echo:
			if e.is_action_pressed("tap"):
				_press_anim(true)
			elif e.is_action_released("tap"):
				_press_anim(false)
			elif e.is_action_pressed("coin"):
				_refill_if_empty()
		game_viewport.push_input(e)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		# ボタンが乗っている板かボタンを押したときだけボタン扱い（スマホのタップもマウスとして届く）
		if e.pressed:
			if _hits_button_area(e.position):
				_tap(true)
		elif _tap_down:
			_tap(false)
		get_viewport().set_input_as_handled()


func _hits_button_area(pos: Vector2) -> bool:
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 10.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return false
	var owner_mesh: Node = (hit.collider as Node).get_parent()
	return owner_mesh == _deck or owner_mesh == _button_cap


func _tap(down: bool) -> void:
	_tap_down = down
	_press_anim(down)
	_send_action("tap", down)


func _insert_coin() -> void:
	_refill_if_empty()
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


# ---------------------------------------------------------------- 出力

func _on_finished(payout: int) -> void:
	if payout > 0:
		_win_left = 3.0 + payout * 0.08


func _process(dt: float) -> void:
	_t += dt
	_win_left = maxf(0.0, _win_left - dt)
	var playing: bool = game.is_in_play()
	# LED：当たりで点滅、遊んでいる間はオレンジ、待機中はゆっくり色が変わる
	if _win_left > 0.0:
		_led_mat.albedo_color = Color(1, 1, 1) if int(_t * 12.0) % 2 == 0 else Color(1, 0.75, 0.1)
	elif playing or int(game.bet) > 0:
		_led_mat.albedo_color = Color(1, 0.55, 0.15)
	else:
		_led_mat.albedo_color = Color.from_hsv(fmod(_t * 0.15, 1.0), 0.55, 1.0)
	for i in _neighbor_leds.size():
		_neighbor_leds[i].albedo_color = Color.from_hsv(fmod(_t * 0.15 + 0.23 * (i + 1), 1.0), 0.55, 1.0)
