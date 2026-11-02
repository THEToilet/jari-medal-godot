extends Cabinet
## ビル解体台。
## 流れ: WAIT → BET（メダル投入1〜5枚・ビル選択）→ ZOOM → CHARGE（5秒連打で力をこめる）
##       → DETONATE（押せー！で起爆）→ RESULT（煽り → 崩壊 or 残る）→ WAIT
## 操作: C=メダル投入（筐体のメダル投入口の代わり）/ Space・Enter・クリック=ボタン（筐体のボタンの代わり）/ F2=メダル+50（デバッグ）
## 画面は筐体に組み込む前提：ボタン・投入口・払い出し口は筐体側にあるので画面には出さない。
## ビル選択：ビルがランダムな並びで右から左へ流れ続け、中央に来たビルでボタン。

enum S { WAIT, BET, ZOOM, CHARGE, DETONATE, RESULT }

const BUILDINGS := [
	{"name": "ものおき", "file": "wooden-shed", "payout": 1, "fixed": 0.98, "tempo": 0.6},
	{"name": "おうち", "file": "red-roof-house", "payout": 2, "tempo": 0.7},
	{"name": "アパート", "file": "two-story-apartment", "payout": 5, "tempo": 0.85},
	{"name": "ざっきょビル", "file": "four-story-mixed-use", "payout": 8, "tempo": 1.0},
	{"name": "マンション", "file": "eight-story-apartment", "payout": 10, "tempo": 1.0},
	{"name": "こうそうビル", "file": "fifteen-story-office", "payout": 20, "tempo": 1.0},
	{"name": "タワー", "file": "landmark-tower", "payout": 30, "tempo": 1.0},
]

## 結果ごとの煽りパターンと重み
const PATTERNS := {
	true: {"straight": 0.5, "comeback": 0.5},
	false: {"near_miss": 0.6, "solid": 0.4},
}

const MAX_BET := 5
const RTP := 0.9
const AVG_MASH := 1.05
const MASH_MAX_BONUS := 0.1
const POWER_PER_TAP := 0.03
const GROUND_Y := 770.0
const ROW_SCALE := 0.8
const STRIP_H := 330.0        # ビル選択で並べるときの高さ（全部同じ高さにそろえる）
const SLOT_W := 440.0          # 流れるビルの間隔
const CENTER_X := 960.0
const STRIP_HALF := 4          # 中央から左右に何棟ぶん並べるか
## 払い出し数字画像の表示高さ（枚数が多いほど大きく）
const ARROW_Y := 40.0            # ▼の高さ（固定）
const CENTER_ZOOM := 0.22        # 中央でどれだけ大きくなるか（+35%）
const CENTER_ZOOM_WIDTH := 0.9  # 大きくなる範囲（ビル間隔の何倍か。小さいほど中央だけで急に大きくなる）
const NUM_H := {1: 66.0, 2: 70.0, 5: 78.0, 8: 84.0, 10: 92.0, 20: 104.0, 30: 120.0}
const ZOOM_MAX_H := 700.0
const ZOOM_MAX_SCALE := 1.2
const PIECE_LAYER := 2
const DETONATE_LOCK := 0.8
const PLUNGER_X := 1570.0     # 起爆器の箱の中心（現場監督が右に立って押す）
const PLUNGER_Y := 1040.0
const WORKER_POS := Vector2(300, 1075)   # 発電機を回す作業員（足元）
const WORKER_SCALE := 1.3
const WORKER_HEAD := Vector2(262, 625)     # 作業員の頭のあたり（汗を出す位置）
const GEN_OUT := Vector2(0.80, 0.80)     # コマ画像内の発電機の出力位置（0〜1）
const PLUNGER_SCALE := 1.22
const PUSH_BOX := Vector2(55, 376)   # foreman_push 画像内の、起爆器の箱の下端中央（px）
const PUSH_CYCLE := [1, 2, 3, 0]     # 連打中のコマ順（押し込む→底→戻す→構え）
const PUSH_SLAM := 4                 # 起爆の大ジャンプ
## PC確認用の表示（MEDAL × n）。筐体に載せるときは false にする
const SHOW_DEBUG_MEDAL := true
const RESULT_TIME := [3.0, 4.0, 5.5]   # リザルト画面の最低表示時間（ランク別）

@export_group("演出の尺")
@export var time_scale: float = 1.0
@export var slot_time: float = 1.0        ## ビル選択：1棟ぶん進むのにかかる時間（秒）
@export var dwell_time: float = 0.45      ## 中央（選択ゾーン）に来たら止まる時間（秒）
@export_enum("sin", "tan") var scroll_curve: int = 0  ## 速度カーブ。sin=中央で一瞬止まる波 / tan=中央でじわっと粘って間は速く
@export var linger: float = 2.5           ## tanカーブの粘り具合（大きいほど中央で長く粘り、間はビュンと速い）
@export var charge_time: float = 5.0
@export var t_smoke: float = 1.0
@export var t_tilt: float = 1.5
@export var t_hold: float = 1.5
@export var t_clear: float = 1.0

var state: S = S.WAIT
var buildings: Array[Building] = []
var chosen: Building
var power: float = 0.0

var _armed: bool = false
var _released: bool = false
var _charge_left: float = 0.0
var _shake_amt: float = 0.0
var _timed_out: bool = false
var _tex: Dictionary = {}
var _queue: Array[int] = []    # 次に流すビル（シャッフル済み）
var _last_idx: int = -1
var _centered: Building
var _travel_p: float = 0.0     # 次のビルへの移動の進み具合 0〜1（0=ビルが中央）
var _dwell: float = 0.0        # 中央で止まっている残り時間
var _arrow_y: float = 300.0
var _crowd: float = 0.0        # 見物人の盛り上がり 0〜1
var _crowd_base_y: float = 0.0

var cam: Camera2D
var world: Node2D
var fx: Node2D
var dynamo: Dynamo
var cable: Cable
var tray: MedalTray
var plunger: Sprite2D
var cable_gen: Cable
var links: LinkWires
var charge_box: ChargeBox
var _charge_lv: int = 0
## 起爆器の箱（foreman_push の絵の中）の中心と大きさ（画面px）
const BOX_CENTER_OFF := Vector2(0, -57)
const BOX_SIZE := Vector2(128, 114)
## 電気が溜まる段階。power がこの値を超えるたびにレベルアップ（最後が MAX）
const CHARGE_STEPS := [0.2, 0.45, 0.7, 0.95]
var meter: ChargeMeter
var _pump: Tween
var _push_i: int = 0
var debris: CPUParticles2D
var bomb_marks: BombMarks
var foreman: Sprite2D
var worker: Sprite2D
var crowd: Sprite2D
var bust: Sprite2D

var ui: Control
var lbl_medals: Label
var lbl_credit: Label
var insert_sign: InsertSign
var title_logo: Sprite2D
## 待機画面のタイトルロゴ（中心位置と表示幅）
const TITLE_POS := Vector2(960, 370)
const TITLE_W := 1100.0
## タイトルは起動直後と、待機のまましばらく放置されたときだけ出す
const TITLE_IDLE := 0.0
var _title_boot: bool = true
var _wait_t: float = 0.0
var _medals_txt: String = ""
var debug_pattern: String = ""   # テスト用：煽りパターンを固定
## デモ（アトラクト）：待機のまま DEMO_AFTER 秒たったら、自動で1プレイ見せる
const DEMO_AFTER := 12.0
## シーンを作り直したいとき（デモ中のメダル投入）。つながっていれば reload_current_scene の代わりにこれを出す
signal restart_requested
var demo: bool = false
var _aborting: bool = false
var demo_label: Control
var _result_lock: bool = false   # リザルト表示中はメダルを受け付けない
## メダルを入れたのに選ばないまましばらく経ったら、選び方の案内を出す
const SELECT_HINT_AFTER := 6.0
const SELECT_HINT_Y := 8.0          # 案内は▼の上。出ている間は▼を下へずらす
var _arrow_push: float = 0.0
var _bet_idle: float = 0.0
var select_hint: Control
var _preloaded: Array[Resource] = []
var _burst: CPUParticles2D
var _fps_acc: float = 0.0
var _fear: int = 0                # 積まれた箱の数（作業員のビビり具合）
var sweat: SweatDrops
var has_worker_scared: bool = false
var _worker_scared_tex: Texture2D
var rack: Array[RigidBody2D] = []        # ベットするごとに画面下に降ってくるダイナマイト（物理）
var base_sticks: Array[RigidBody2D] = []  # ビルの足元に仕掛けたダイナマイト（物理）
var marker: SelectMarker
var tag_layer: Node2D
var uplight: UpLight
var uplight_front: UpLight
var font: Font
var lbl_msg: Label
var lbl_timer: Label
var fuse: FuseTimer
var btn_hint: ButtonHint
var lbl_idle: Label
var lbl_big: Label
var arrow: Label
var flash: ColorRect
var lbl_payout: Label
var msg_img: TextureRect
var big_img: TextureRect
var _text_img: Dictionary = {}
var _crank_frames: Array[Texture2D] = []   # assets/chara/worker_crank_0〜.png（作業員がハンドルを回すコマ送り）
var _crank_phase: float = 0.0
var result: ResultScreen
var beam: Polygon2D


# ---------------------------------------------------------------- 初期化

func _ready() -> void:
	_setup_input()
	_load_textures()
	_build_world()
	_build_ui()
	result.setup(font, _tex["chara/foreman_4"], _tex["chara/worker_2"])
	MedalWallet.changed.connect(_on_medals_changed)
	idle_warning.connect(_on_idle_warning)
	idle_timeout.connect(func() -> void: _timed_out = true)
	_on_medals_changed(MedalWallet.medals)
	Sfx.play_bgm()
	_reset()
	# デモ中にメダルが入って画面を作り直したときは、そのメダルをここで受け付ける
	var coin: bool = Engine.has_meta("pending_coin")
	if coin:
		Engine.remove_meta("pending_coin")
		_title_boot = false
		if title_logo:
			title_logo.modulate.a = 0.0
	if Engine.has_meta("fade_in"):
		Engine.remove_meta("fade_in")
		Fader.fade_in(0.3)
	if coin:
		await get_tree().process_frame
		_insert(true)


func _setup_input() -> void:
	var defs := {
		"tap": [KEY_SPACE, KEY_ENTER],
		"coin": [KEY_C],
		"debug_add": [KEY_F2],
	}
	for action: String in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k: int in defs[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("tap", jb)


func _load_textures() -> void:
	var names := ["bg", "crank-dynamo-box", "dynamite", "dynamite_crate", "plunger-detonator", "chara/foreman_push_0", "chara/foreman_push_1",
		"chara/foreman_push_2", "chara/foreman_push_3", "chara/foreman_push_4", "explosion-cloud",
		"dust-cloud", "gold-star-medal", "cracks-overlay"]
	for b: Dictionary in BUILDINGS:
		names.append(b.file)
	for i in 6:
		names.append("chara/foreman_%d" % i)
	for i in 4:
		names.append("chara/worker_%d" % i)
	for i in 3:
		names.append("chara/bust_%d" % i)
	names.append("chara/spectators")
	for n: String in names:
		_tex[n] = load("res://assets/%s.png" % n)


func _build_world() -> void:
	cam = Camera2D.new()
	cam.position = Vector2(960, 540)
	add_child(cam)

	var bg := Sprite2D.new()
	bg.texture = _tex["bg"]
	bg.centered = false
	add_child(bg)

	beam = Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(CENTER_X - 70, 210), Vector2(CENTER_X + 70, 210),
		Vector2(CENTER_X + SLOT_W / 2.0, GROUND_Y + 30), Vector2(CENTER_X - SLOT_W / 2.0, GROUND_Y + 30)])
	beam.color = Color(1, 0.95, 0.5, 0.28)
	add_child(beam)

	uplight = UpLight.new()
	add_child(uplight)

	world = Node2D.new()
	add_child(world)
	tag_layer = Node2D.new()     # ビルの数字の札（ビルの手前、キャラの奥）
	add_child(tag_layer)

	var ground := StaticBody2D.new()
	ground.collision_layer = PIECE_LAYER
	ground.collision_mask = PIECE_LAYER
	var gs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-400, GROUND_Y + 10)
	seg.b = Vector2(2320, GROUND_Y + 10)
	gs.shape = seg
	ground.add_child(gs)
	add_child(ground)

	# 画面下のダイナマイト受け皿（ゆるいお椀型）
	var tray_body := StaticBody2D.new()
	tray_body.collision_layer = STICK_LAYER
	tray_body.collision_mask = STICK_LAYER
	for seg_pts in [[Vector2(CENTER_X - 320, RACK_Y - 90), Vector2(CENTER_X - 170, RACK_Y)],
			[Vector2(CENTER_X - 170, RACK_Y), Vector2(CENTER_X + 170, RACK_Y)],
			[Vector2(CENTER_X + 170, RACK_Y), Vector2(CENTER_X + 320, RACK_Y - 90)]]:
		var c2 := CollisionShape2D.new()
		var sg := SegmentShape2D.new()
		sg.a = seg_pts[0]
		sg.b = seg_pts[1]
		c2.shape = sg
		tray_body.add_child(c2)
	add_child(tray_body)

	marker = SelectMarker.new()
	marker.visible = false
	add_child(marker)
	uplight_front = UpLight.new()
	uplight_front.front = true
	add_child(uplight_front)
	# 数字の札は光の手前、電線は建物の手前に描く
	move_child(tag_layer, get_child_count() - 1)

	cable = Cable.new()
	cable.visible = false
	cable_gen = Cable.new()     # 発電機 → スイッチ
	cable_gen.visible = false
	add_child(cable_gen)
	add_child(cable)
	links = LinkWires.new()
	links.z_index = 5
	links.visible = false
	add_child(links)

	bomb_marks = BombMarks.new()
	bomb_marks.tex = _tex["dynamite"]
	add_child(bomb_marks)

	debris = CPUParticles2D.new()
	debris.emitting = false
	debris.amount = 16
	debris.lifetime = 1.2
	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	debris.gravity = Vector2(0, 700)
	debris.initial_velocity_min = 20
	debris.initial_velocity_max = 80
	debris.direction = Vector2(0, 1)
	debris.spread = 60
	debris.scale_amount_min = 4
	debris.scale_amount_max = 9
	debris.color = Color(0.55, 0.45, 0.35)
	add_child(debris)

	fx = Node2D.new()
	add_child(fx)

	worker = _chara(WORKER_POS, WORKER_SCALE)
	_worker_idle()
	# 最初の投入でカクッとしないよう、クレーンの絵と音は先に読み込んでおく
	for pre in ["res://assets/crane_hook.png", "res://assets/crane_rope.png"]:
		if ResourceLoader.exists(pre):
			_preloaded.append(load(pre))
	for st in range(1, 6):
		_stage_tex(st)   # 入れ物の絵も先に読み込む
	sweat = SweatDrops.new()
	sweat.position = WORKER_HEAD
	sweat.z_index = 8
	add_child(sweat)
	if ResourceLoader.exists("res://assets/chara/worker_crank_scared.png"):
		_worker_scared_tex = load("res://assets/chara/worker_crank_scared.png")
		has_worker_scared = true

	dynamo = Dynamo.new()
	dynamo.position = Vector2(380, 905)
	dynamo.scale = Vector2(0.85, 0.85)
	dynamo.setup(_tex["crank-dynamo-box"], _tex["dust-cloud"])
	dynamo.visible = false   # 発電機は使わない（回転の計算だけ流用）。電気は起爆器に溜める
	add_child(dynamo)

	tray = MedalTray.new()
	tray.setup(_tex["gold-star-medal"])
	tray.z_index = 9
	result = ResultScreen.new()


	# 起爆器：ボタンを押すほどここに電気が溜まる（足元基準）
	# 現場監督＋起爆器（コマ送り）。原点は起爆器の箱の下端中央
	plunger = Sprite2D.new()
	plunger.centered = false
	plunger.position = Vector2(PLUNGER_X, PLUNGER_Y)
	_set_push_frame(0)
	plunger.scale = Vector2(PLUNGER_SCALE, PLUNGER_SCALE)
	add_child(plunger)
	# 起爆器の箱に電気が溜まる表示（ランプ＋漏れる光）
	# 箱の後ろから光が漏れるように、起爆器の絵の「後ろ」に描く
	charge_box = ChargeBox.new()
	charge_box.position = BOX_CENTER_OFF / PLUNGER_SCALE
	charge_box.box_size = BOX_SIZE / PLUNGER_SCALE
	charge_box.visible = false
	charge_box.show_behind_parent = true
	plunger.add_child(charge_box)
	meter = ChargeMeter.new()
	meter.position = Vector2(PLUNGER_X + 150, PLUNGER_Y - 10)
	meter.visible = false
	add_child(meter)

	foreman = _chara(Vector2(1640, 1030), 0.8)
	_pose(foreman, "chara/foreman_0")
	foreman.visible = false   # 現場監督は起爆器のところにいる
	# キャラは数字の札より手前
	move_child(worker, get_child_count() - 1)
	move_child(plunger, get_child_count() - 1)

	# 見物人は柵の手前の右奥（ビルから離れた安全な場所）。自前のバリケード付き
	crowd = _chara(Vector2(1745, GROUND_Y - 38), 0.5)
	_pose(crowd, "chara/spectators")
	_crowd_base_y = crowd.position.y
	crowd.visible = false   # 観客は出さない
	move_child(crowd, world.get_index())

	bust = Sprite2D.new()
	bust.centered = false
	bust.z_index = 10
	bust.visible = false
	add_child(bust)
	add_child(result)
	add_child(tray)


func _set_push_frame(i: int) -> void:
	var t: Texture2D = _tex["chara/foreman_push_%d" % i]
	plunger.texture = t
	plunger.offset = -PUSH_BOX


## 作業員：発電機の前で待機（1コマ目）
func _worker_idle() -> void:
	if _crank_frames.is_empty():
		_pose(worker, "chara/worker_2")
	else:
		_set_worker_frame(0)


func _set_worker_frame(i: int) -> void:
	var ft: Texture2D = _crank_frames[i]
	worker.texture = ft
	worker.offset = Vector2(-ft.get_width() / 2.0, -ft.get_height())


## 発電機の出力 → スイッチ への電線
func _layout_gen_cable() -> void:
	if worker.texture == null:
		return
	# ビビり顔の絵はサイズが違うので、位置はクランクの1コマ目で計算する
	var t: Texture2D = _crank_frames[0] if not _crank_frames.is_empty() else worker.texture
	var sz: Vector2 = t.get_size() * WORKER_SCALE
	var out := WORKER_POS + Vector2(-sz.x / 2.0 + sz.x * GEN_OUT.x, -sz.y + sz.y * GEN_OUT.y)
	cable_gen.set_ends(out, Vector2(PLUNGER_X - 55, PLUNGER_Y - 50))


func _chara(pos: Vector2, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = pos
	s.scale = Vector2(sc, sc)
	add_child(s)
	return s


## キャラのポーズ切替（足元基準でポンと弾む）
func _pose(s: Sprite2D, key: String) -> void:
	var t: Texture2D = _tex[key]
	if s.texture == t:
		return
	s.texture = t
	s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	var base: Vector2 = s.get_meta("base_scale", s.scale)
	s.set_meta("base_scale", base)
	s.scale = Vector2(base.x * 1.1, base.y * 0.9)
	create_tween().tween_property(s, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 親方の顔カットイン（画面左下からスライド）
func _cut_in(key: String, hold: float) -> void:
	var t: Texture2D = _tex[key]
	bust.texture = t
	bust.visible = true
	bust.position = Vector2(-t.get_width(), 1080 - t.get_height())
	var tw := create_tween()
	tw.tween_property(bust, "position:x", 10.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(bust, "position:x", -t.get_width(), 0.2)
	tw.tween_callback(func() -> void: bust.visible = false)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	# 同梱フォント（ブラウザ版でも日本語が出るように）。無ければシステムフォント
	if ResourceLoader.exists("res://assets/fonts/NotoSansJP-Black-subset.otf"):
		font = load("res://assets/fonts/NotoSansJP-Black-subset.otf")
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Hiragino Sans", "Noto Sans CJK JP", "sans-serif"])
		sf.font_weight = 800
		font = sf
	theme.default_font = font
	ui.theme = theme
	layer.add_child(ui)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(1920, 1080)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash)

	# PC確認用：手持ちメダル（筐体では物理メダルなのでゲームとは無関係）
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	mono.font_weight = 700
	lbl_medals = Label.new()
	lbl_medals.add_theme_font_override("font", mono)
	lbl_medals.add_theme_font_size_override("font_size", 26)
	lbl_medals.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var dbg := StyleBoxFlat.new()
	dbg.bg_color = Color(0, 0, 0, 0.45)
	dbg.content_margin_left = 10
	dbg.content_margin_right = 10
	dbg.content_margin_top = 4
	dbg.content_margin_bottom = 4
	lbl_medals.add_theme_stylebox_override("normal", dbg)
	lbl_medals.position = Vector2(10, 10)
	lbl_medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_medals.visible = SHOW_DEBUG_MEDAL
	ui.add_child(lbl_medals)
	# クレジット（投入済み枚数）。アーケードっぽく右下に
	lbl_credit = Label.new()
	lbl_credit.add_theme_font_override("font", mono)
	lbl_credit.add_theme_font_size_override("font_size", 40)
	lbl_credit.add_theme_color_override("font_color", Color.WHITE)
	lbl_credit.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_credit.add_theme_constant_override("outline_size", 10)
	lbl_credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_credit.size = Vector2(400, 0)
	lbl_credit.position = Vector2(1920 - 400 - 24, 1080 - 64)
	lbl_credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lbl_credit)
	insert_sign = InsertSign.new()
	insert_sign.position = Vector2(960, 945)
	insert_sign.setup(font)
	ui.add_child(insert_sign)
	_build_select_hint()
	if ResourceLoader.exists("res://assets/title_logo.png"):
		title_logo = Sprite2D.new()
		title_logo.texture = load("res://assets/title_logo.png")
		title_logo.position = TITLE_POS
		title_logo.scale = Vector2.ONE * (TITLE_W / title_logo.texture.get_width())
		ui.add_child(title_logo)
	lbl_msg = _label(54, Color.WHITE, 16)
	_center(lbl_msg, Vector2(960, 24), 1200)
	lbl_timer = _label(72, Color(1, 0.95, 0.4), 18)
	_center(lbl_timer, Vector2(1560, 150), 500)
	lbl_timer.visible = false
	fuse = FuseTimer.new()
	fuse.dyn_tex = _tex["dynamite"]
	fuse.position = Vector2(960 - FuseTimer.LEN / 2.0 + 40, 90)
	fuse.visible = false
	ui.add_child(fuse)
	btn_hint = ButtonHint.new()
	btn_hint.tex = load("res://assets/red-arcade-button.png")
	btn_hint.position = Vector2(CENTER_X, BTN_Y)   # 画面中央にでかでかと
	btn_hint.visible = false
	ui.add_child(btn_hint)
	_build_touch_ui()
	lbl_idle = _label(150, Color(1, 0.2, 0.2), 24)
	_center(lbl_idle, Vector2(960, 300), 600)
	lbl_big = _label(170, Color(1, 0.85, 0.05), 30)
	_center(lbl_big, Vector2(960, 200), 1800)
	lbl_big.pivot_offset = Vector2(900, 110)
	lbl_big.visible = false
	arrow = _label(90, Color(1, 0.88, 0.1), 20)
	arrow.text = "▼"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.size = Vector2(160, 0)
	arrow.visible = false

	for i in 8:
		var cp: String = "res://assets/chara/worker_crank_%d.png" % i
		if not ResourceLoader.exists(cp):
			break
		_crank_frames.append(load(cp))
	for k in ["stop", "charge", "push", "boom", "lose", "max", "oshii"]:
		var tp: String = "res://assets/text/%s.png" % k
		if ResourceLoader.exists(tp):
			_text_img[k] = load(tp)
	msg_img = TextureRect.new()
	msg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	msg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_img.visible = false
	lbl_msg.add_child(msg_img)
	big_img = TextureRect.new()
	big_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_img.visible = false
	lbl_big.add_child(big_img)
	lbl_payout = _label(150, Color(1, 0.85, 0.1), 28)
	_center(lbl_payout, Vector2(960, 330), 900)
	lbl_payout.visible = false


func _label(size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	return l


func _center(l: Label, top_center: Vector2, width: float) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(width, 0)
	l.position = Vector2(top_center.x - width / 2.0, top_center.y)


# ---------------------------------------------------------------- 状態

func _enter(s: S) -> void:
	state = s
	match s:
		S.BET, S.DETONATE:
			start_idle()
		_:
			stop_idle()


## ビルを選んだあと〜結果まで（メダル投入を受け付けない間。デモは除く）。仮想筐体のカメラ切り替えに使う
func is_in_play() -> bool:
	return state >= S.ZOOM and not demo


func _reset() -> void:
	if demo:
		# デモが終わったらタイトルに戻す
		demo = false
		debug_pattern = ""
		_title_boot = true
		if demo_label:
			demo_label.visible = false
	_wait_t = 0.0
	_enter(S.WAIT)
	power = 0.0
	chosen = null
	dynamo.power = 0.0
	cable.power = 0.0
	cable.visible = false
	links.visible = false
	cable_gen.power = 0.0
	cable_gen.visible = false   # 選ぶ間は出さない（並べたダイナマイトにかぶるので）
	charge_box.visible = false
	plunger.position = Vector2(PLUNGER_X, PLUNGER_Y)
	plunger.rotation = 0.0
	_layout_gen_cable()
	plunger.modulate = Color.WHITE
	_set_push_frame(0)
	_push_i = 0
	meter.visible = false
	meter.power = 0.0
	debris.emitting = false
	bomb_marks.count = 0
	_clear_sticks()
	_crowd = 0.1
	_pose(foreman, "chara/foreman_0")
	_worker_idle()
	Sfx.hum_level = 0.0
	lbl_timer.text = ""
	fuse.visible = false
	btn_hint.visible = false
	_hide_mash_text()
	_reset_fear()
	lbl_big.visible = false
	lbl_payout.visible = false
	_build_strip()
	_update_bet_label()
	insert_sign.visible = true
	if _timed_out:
		_timed_out = false
		_say("じかんぎれ… メダルかいしゅう")
		await get_tree().create_timer(2.0).timeout
		if state != S.WAIT:
			return
	_say_wait()


## 選び方の案内（assets/text/select.png があれば画像、無ければ文字）
func _build_select_hint() -> void:
	var tp: String = "res://assets/text/select.png"
	if ResourceLoader.exists(tp):
		var r := TextureRect.new()
		r.texture = load(tp)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var h: float = 150.0
		r.size = Vector2(h * r.texture.get_width() / r.texture.get_height(), h)
		select_hint = r
	else:
		var l := Label.new()
		l.text = "ボタンで たてものを えらんでね！"
		l.add_theme_font_size_override("font_size", 64)
		l.add_theme_color_override("font_color", Color(1, 0.92, 0.2))
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.05))
		l.add_theme_constant_override("outline_size", 22)
		if font:
			l.add_theme_font_override("font", font)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(1100, 90)
		select_hint = l
	select_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_hint.position = Vector2(960 - select_hint.size.x / 2.0, SELECT_HINT_Y)
	select_hint.pivot_offset = select_hint.size / 2.0
	select_hint.visible = false
	ui.add_child(select_hint)


## スマホ・ブラウザ用：画面にメダル投入ボタンを出す（筐体では出さない）
func _build_touch_ui() -> void:
	if get_viewport() != get_tree().root:
		return   # 仮想筐体（3D）の画面の中では出さない。筐体の投入口を使う
	if not (OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")):
		return
	var b := Button.new()
	b.text = "メダル\nいれる"
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(200, 160)
	b.position = Vector2(1920 - 200 - 24, 24)
	b.add_theme_font_size_override("font_size", 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.75, 0.1)
	sb.border_color = Color(0.1, 0.06, 0.05)
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(28)
	b.add_theme_stylebox_override("normal", sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(1, 0.6, 0.05)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", Color(0.15, 0.08, 0.05))
	b.add_theme_color_override("font_pressed_color", Color(0.15, 0.08, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.15, 0.08, 0.05))
	b.pressed.connect(func() -> void:
		if demo:
			_abort_demo(true)
			return
		if MedalWallet.medals <= 0:
			MedalWallet.add(50)   # ブラウザ版はメダルが尽きたら自動で補充
		_insert())
	ui.add_child(b)


func _say_wait() -> void:
	if MedalWallet.medals <= 0:
		_say("メダルがない… [F2]でほじゅう")
	else:
		_say("")
	insert_sign.visible = true


func _say(t: String, key: String = "") -> void:
	# assets/text/<key>.png があれば画像で出す
	if key != "" and _text_img.has(key):
		lbl_msg.text = ""
		msg_img.texture = _text_img[key]
		var h: float = 120.0
		msg_img.size = Vector2(h * msg_img.texture.get_width() / msg_img.texture.get_height(), h)
		msg_img.position = Vector2(lbl_msg.size.x / 2.0 - msg_img.size.x / 2.0, -6)
		msg_img.visible = true
		msg_img.pivot_offset = msg_img.size / 2.0
		msg_img.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(msg_img, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		lbl_msg.text = t
		msg_img.visible = false


## ---- ビル選択ストリップ（ランダム順で流れ続ける）

func _build_strip() -> void:
	for b in buildings:
		_free_building(b)
	buildings.clear()
	_queue.clear()
	_centered = null
	_travel_p = 0.0
	_dwell = dwell_time
	for i in range(-STRIP_HALF, STRIP_HALF + 1):
		_spawn_building(CENTER_X + i * SLOT_W)
	beam.visible = false
	arrow.visible = false
	_refresh_strip()


func _next_index() -> int:
	if _queue.is_empty():
		var order: Array[int] = []
		for i in BUILDINGS.size():
			order.append(i)
		order.shuffle()
		if order[0] == _last_idx:          # 同じビルが連続しないように
			var t: int = order[0]
			order[0] = order[order.size() - 1]
			order[order.size() - 1] = t
		_queue = order
	_last_idx = _queue.pop_front()
	return _last_idx


func _spawn_building(x: float) -> void:
	var d: Dictionary = BUILDINGS[_next_index()]
	var b := Building.new()
	b.setup(d, _tex[d.file], _tex["cracks-overlay"])
	b.position = Vector2(x, GROUND_Y)
	b.set_meta("base", ROW_SCALE)
	b.scale = Vector2.ONE * float(b.get_meta("base"))
	world.add_child(b)
	var l := _label(38, Color.WHITE, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(240, 0)
	b.set_meta("tag", l)
	# 払い出し枚数の画像（assets/num/<枚数>.png があれば使う。なければ文字）
	var num_path: String = "res://assets/num/%d.png" % int(d.payout)
	if ResourceLoader.exists(num_path):
		var t: Texture2D = load(num_path)
		var nr := TextureRect.new()
		nr.texture = t
		nr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		nr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var nh: float = NUM_H.get(int(d.payout), 70.0)
		nr.size = Vector2(nh * t.get_width() / t.get_height(), nh)
		nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ビルと色がかぶらないよう、紺の札＋白フチを敷く
		var plate := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.12, 0.3, 0.95)
		sb.border_color = Color.WHITE
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(20)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(4, 6)
		plate.add_theme_stylebox_override("panel", sb)
		var pad := Vector2(22, 12)
		plate.size = nr.size + pad * 2.0
		nr.position = pad
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.pivot_offset = plate.size / 2.0
		plate.rotation = deg_to_rad(-8)
		plate.add_child(nr)
		tag_layer.add_child(plate)   # キャラより奥（数字はキャラの後ろ）
		b.set_meta("num", plate)
	buildings.append(b)
	_refresh_one(b)


func _free_building(b: Building) -> void:
	if b.has_meta("tag"):
		(b.get_meta("tag") as Label).queue_free()
	if b.has_meta("num"):
		(b.get_meta("num") as Control).queue_free()
	b.queue_free()


## 波のような速度で流し続ける。中央付近で遅く、ビルとビルの間で速い
func _scroll(delta: float) -> void:
	if _dwell > 0.0:
		_dwell -= delta
		_centered = centered_building()
		_update_tags(delta)
		return
	var p0: float = _travel_p
	var p1: float = p0 + delta / slot_time
	var dx: float
	if p1 >= 1.0:
		p1 -= 1.0
		# 次のビルが中央に来た：ピタッと合わせて少し止まる
		dx = SLOT_W * (_curve(1.0) - _curve(p0))
		p1 = 0.0
		_dwell = dwell_time
		Sfx.play("beep", 1600.0, 0.04)
	else:
		dx = SLOT_W * (_curve(p1) - _curve(p0))
	_travel_p = p1
	for b in buildings:
		b.position.x -= dx
	if buildings[0].position.x < CENTER_X - SLOT_W * (STRIP_HALF + 0.5):
		_free_building(buildings.pop_front())
		_spawn_building(buildings[buildings.size() - 1].position.x + SLOT_W)
	_centered = centered_building()
	_update_tags(delta)


## ビルの大きさ（中央は少し大きく）と数字の札の位置を更新
func _update_tags(delta: float) -> void:
	if _centered:
		var sz: Vector2 = _centered.size() * _centered.scale
		# 光は中央の定位置から湧く。ビルが中央に近づくほど強くなる（止まる前から光り始める）
		var dd: float = absf(_centered.position.x - CENTER_X) / (SLOT_W * 0.5)
		var near: float = clampf(1.0 - dd, 0.0, 1.0)
		near = near * near * (3.0 - 2.0 * near)
		for ul in [uplight, uplight_front]:
			ul.base = Vector2(CENTER_X, GROUND_Y)
			ul.width = lerpf(ul.width, sz.x + 40.0, minf(1.0, delta * 10.0))
			ul.height = lerpf(ul.height, sz.y + 200.0, minf(1.0, delta * 10.0))
			ul.strength = near
		# ▼はビルの頭の上でぴょこぴょこ
		# ▼は画面上部の中央に固定（ビルの高さに関係なく同じ位置）
		var want_push: float = 95.0 if (select_hint and select_hint.visible) else 0.0
		_arrow_push = lerpf(_arrow_push, want_push, 0.2)
		arrow.position = Vector2(CENTER_X - 80, ARROW_Y + _arrow_push + sin(Time.get_ticks_msec() * 0.01) * 10)
	for b in buildings:
		# 中央に近づくほど大きく（ガウス型：端ではほぼ変わらず、中央付近でグッと大きくなる）
		var d: float = (b.position.x - CENTER_X) / (SLOT_W * CENTER_ZOOM_WIDTH)
		var sc: float = float(b.get_meta("base")) * (1.0 + CENTER_ZOOM * exp(-d * d))
		b.scale = Vector2(sc, sc)
		var l: Label = b.get_meta("tag")
		l.position = Vector2(b.position.x - 120, GROUND_Y + 8)
		if b.has_meta("num"):
			# ビルの右下に値札のように重ねる
			var nr: Control = b.get_meta("num")
			var near: bool = b == _centered and absf(b.position.x - CENTER_X) < SLOT_W * 0.15
			var pulse: float = 1.0   # 数字は大小させない
			# 右端に数字の幅の3割がかぶる位置、足元を地面より少し下に
			# ビルの拡大・脈動には追従させない（札は流れる動きだけ）
			var right: float = b.position.x + b.size().x * float(b.get_meta("base")) / 2.0
			nr.position = Vector2(right - nr.size.x * 0.7, GROUND_Y + 16.0 - nr.size.y)
			nr.scale = Vector2(pulse, pulse)


## 進み具合 u(0〜1) → 位置(0〜1)。u=0,1 でビルが中央
func _curve(u: float) -> float:
	if scroll_curve == 0:
		# sin波：速度が 1-cos の波。中央で一瞬だけ止まる
		return u - sin(TAU * u) / TAU
	# tan系：中央付近はじわじわ、間はビュンと速い（止まりはしない）
	var k: float = maxf(linger, 0.01)
	return 0.5 + atan(k * (2.0 * u - 1.0)) / (2.0 * atan(k))


## 中央に一番近いビル
func centered_building() -> Building:
	var best: Building = null
	for b in buildings:
		if best == null or absf(b.position.x - CENTER_X) < absf(best.position.x - CENTER_X):
			best = b
	return best


func _refresh_strip() -> void:
	for b in buildings:
		_refresh_one(b)


func _refresh_one(b: Building) -> void:
	var d: Dictionary = b.data
	var l: Label = b.get_meta("tag")
	if b.has_meta("num"):
		l.text = ""    # 数字は画像で表示
	else:
		l.text = "%dまい" % d.payout
		l.add_theme_font_size_override("font_size", 38)


const RACK_Y := 1062.0
const STICK_LAYER := 16
const BASE_STICK_H := 105.0
const RACK_H := 150.0          # 画面下に積むダイナマイト箱の高さ
const RACK_STEP := 46.0
const RACK_ROW_H := 44.0
const STICKS_PER_COIN := 1     # メダル1枚につきダイナマイト箱いくつ
## ダイナマイト箱の画像の中での位置（0〜1）：導火線の先、木箱のふちの高さ
const CRATE_FUSES := [Vector2(0.26, 0.015), Vector2(0.54, 0.015), Vector2(0.76, 0.041), Vector2(0.12, 0.088), Vector2(0.92, 0.143), Vector2(0.54, 0.12), Vector2(0.07, 0.21)]
const CRATE_RIM_Y := 0.437
const HOOK_CHAIN_H := 46.0     # フックから箱の上面までのチェーンの長さ
const HOOK_DOWN := 0.42        # フックが降りてくる時間
const FLY_TIME := 0.42         # 箱がビルの足元へ跳ぶ時間
const FLY_GAP := 0.11          # 1個ずつ跳ぶ間隔
const FLY_ARC := 170.0         # 跳ぶ高さ
const BTN_Y := 860.0           # 連打・起爆ボタンの位置（土台の下端）
const WIRE_RUN := 0.35         # 発破線が伸びる時間
## 入れ物の格上げ（メダル1枚目〜5枚目）。束 → 木箱 → 大きい木箱 → パレットの木枠 → コンテナ
## 絵は assets/pile/stage_<N>.png。無い段階は木箱の絵を大きさだけ変えて代用する
const STAGE_H := [100.0, 145.0, 195.0, 250.0, 320.0]   # 画面下での表示の高さ
const BASE_RATIO := 0.62                              # ビルの足元に置くときの縮み具合
const PILE_GAP := -28.0                               # 並べるときのすき間（マイナスで少し重ねる）
## 絵ごとの位置（0〜1）：チェーンをかける高さ、導火線の先。絵が届いたら合わせる
const STAGE_RIM := {1: 0.35, 2: 0.437, 3: 0.46, 4: 0.47, 5: 0.26}
const STAGE_FUSES := {
	1: [Vector2(0.5, 0.02), Vector2(0.24, 0.12), Vector2(0.76, 0.12)],
	2: [Vector2(0.26, 0.015), Vector2(0.54, 0.015), Vector2(0.76, 0.041), Vector2(0.12, 0.088), Vector2(0.92, 0.143), Vector2(0.54, 0.12), Vector2(0.07, 0.21)],
	3: [Vector2(0.2, 0.07), Vector2(0.38, 0.03), Vector2(0.5, 0.13), Vector2(0.67, 0.03), Vector2(0.84, 0.14), Vector2(0.07, 0.31)],
	4: [Vector2(0.27, 0.12), Vector2(0.55, 0.02), Vector2(0.73, 0.17), Vector2(0.42, 0.3), Vector2(0.12, 0.36)],
	5: [Vector2(0.45, 0.38), Vector2(0.52, 0.6), Vector2(0.3, 0.93), Vector2(0.75, 0.93)],
}
var _pile_stage: int = 0
var _old_piles: Array[Node2D] = []


## 山積みの i 番目の位置（下の段から左詰め）
static func pile_pos(i: int, step: float, row_h: float) -> Vector2:
	return DemolitionCabinetPile.pos(i, step, row_h)


func _update_bet_label() -> void:
	lbl_credit.text = "CREDIT %d" % (0 if demo else bet)   # デモ中は本物のメダルは入っていない
	# メダル1枚ごとに、クレーンが一回り大きい入れ物を吊ってきて横に並べる（束 → … → コンテナ）
	if bet < _pile_stage:
		_clear_sticks()
	var k: int = 0
	while _pile_stage < bet:
		_pile_stage += 1
		var n: int = _pile_stage
		var h: float = STAGE_H[n - 1]
		var d: RigidBody2D = _make_container(n, h, STICK_LAYER)
		d.freeze = true
		d.set_meta("stage", n)
		add_child(d)
		rack.append(d)
		# 並びを真ん中に寄せ直す（すでに置いてある分はスッと横へ）
		var pos: Array[Vector2] = _pile_layout(rack.size(), 1.0, Vector2(CENTER_X, RACK_Y))
		for i in rack.size() - 1:
			var o: Node2D = rack[i]
			var mv := o.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			mv.tween_property(o, "position:x", pos[i].x, 0.25)
			# まだ吊られている途中ならフックと影も一緒に
			for key in ["hook", "shadow"]:
				if o.has_meta(key):
					mv.tween_property(o.get_meta(key), "position:x", pos[i].x, 0.25)
		_crane_drop(d, pos[rack.size() - 1], n, k * 0.08)
		k += 1


## 置いたダイナマイトへ、起爆器から線がスルスル伸びて「カチッ」と差さり、
## そこからダイナマイト同士の線が右から左へ順につながっていく
func _run_wire() -> void:
	cable.grow = 0.0
	cable.visible = true
	links.reveal = 0.0
	links.visible = true
	var gt := create_tween()
	gt.tween_property(cable, "grow", 1.0, WIRE_RUN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await gt.finished
	Sfx.play_pitch("chain", 1.6, -6.0)
	_spark_burst(cable.points[cable.points.size() - 1] if cable.points.size() > 0 else Vector2(CENTER_X, GROUND_Y), 0)
	var segs: int = maxi(links.anchors.size() - 1, 0)
	if segs > 0:
		var lt := create_tween()
		lt.tween_property(links, "reveal", 1.0, 0.07 * segs + 0.03)
		await lt.finished
	await get_tree().create_timer(0.1).timeout


## 起爆器からの発破線を、足元に並べたダイナマイトのいちばん右（いちばん大きい）につなぐ。
## ダイナマイト同士も短い線でつなぐ
func _wire_pile(dest: Array[Vector2]) -> void:
	var start := Vector2(PLUNGER_X - 50, PLUNGER_Y - 50)
	if dest.is_empty():
		cable.set_ends(start, Vector2(CENTER_X, GROUND_Y - 10), 0.0)
		links.set_anchors(PackedVector2Array())
		return
	var anchors := PackedVector2Array()
	for i in dest.size():
		var t: Texture2D = _stage_tex(i + 1)
		var h: float = STAGE_H[i] * BASE_RATIO
		var w: float = h * t.get_width() / t.get_height()
		# 入れ物の右上あたりの金具
		anchors.append(dest[i] + Vector2(w * 0.32, -h * 0.05))
	var last: Vector2 = anchors[anchors.size() - 1]
	var lt: Texture2D = _stage_tex(dest.size())
	var lh: float = STAGE_H[dest.size() - 1] * BASE_RATIO
	var end := Vector2(dest[dest.size() - 1].x + lh * lt.get_width() / lt.get_height() * 0.5 + 4.0, dest[dest.size() - 1].y + lh * 0.15)
	anchors[anchors.size() - 1] = end
	cable.set_ends(start, end, 1.0)
	links.set_anchors(anchors)
	links.reveal = 0.0
	links.visible = false   # 線が届いてから出す


## 並べた入れ物の中心位置。n 個を足元 base を中心に左から小さい順に並べる
func _pile_layout(n: int, sc: float, base: Vector2) -> Array[Vector2]:
	var ws: Array[float] = []
	var total: float = 0.0
	for i in n:
		var t: Texture2D = _stage_tex(i + 1)
		var w: float = STAGE_H[i] * sc * t.get_width() / t.get_height()
		ws.append(w)
		total += w
	total += PILE_GAP * sc * (n - 1)
	var out: Array[Vector2] = []
	var x: float = base.x - total / 2.0
	for i in n:
		out.append(Vector2(x + ws[i] / 2.0, base.y - STAGE_H[i] * sc / 2.0))
		x += ws[i] + PILE_GAP * sc
	return out


## クレーンのフックが上から箱を吊って降ろし、外して「ドスン」。n は何個目か
func _crane_drop(d: RigidBody2D, to: Vector2, n: int, delay: float) -> void:
	var h: float = STAGE_H[n - 1]
	var ct: Texture2D = _stage_tex(n)
	var hang: Vector2 = to + Vector2(0, -34)          # 外す直前の高さ
	var start: Vector2 = to + Vector2(0, -820)
	# チェーンは入れ物のふちの両端にかける
	var rim: float = STAGE_RIM[2] if ct == _tex["dynamite_crate"] else float(STAGE_RIM.get(n, 0.2))
	var top_off: Vector2 = Vector2(0, -h / 2.0 + h * rim - HOOK_CHAIN_H)
	d.position = start
	var hook := CraneHook.new()
	hook.chain_w = h * ct.get_width() / ct.get_height() * 0.92
	hook.chain_h = HOOK_CHAIN_H
	hook.crate = d
	hook.position = start + top_off
	hook.z_index = 6
	add_child(hook)
	# 着地点の影（箱が近づくほど濃く大きく）
	var sh := DropShadow.new()
	sh.position = Vector2(to.x, to.y + h * 0.48)
	sh.w = h * ct.get_width() / ct.get_height() * 1.2
	sh.k = 0.0
	sh.z_index = 2
	add_child(sh)
	d.set_meta("hook", hook)
	d.set_meta("shadow", sh)
	var tw := d.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(Sfx.play_pitch.bind("crane", randf_range(0.95, 1.05), -6.0))
	tw.set_parallel(true)
	tw.tween_property(sh, "k", 0.75, HOOK_DOWN)
	# 縦だけ動かす（横は並べ直しで動くことがあるので別にする）
	tw.tween_property(d, "position:y", hang.y, HOOK_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hook, "position:y", hang.y + top_off.y, HOOK_DOWN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 吊られて少し揺れる
	tw.tween_property(d, "rotation", deg_to_rad(4), HOOK_DOWN * 0.5)
	tw.set_parallel(false)
	tw.tween_property(d, "rotation", deg_to_rad(-2), 0.08)
	tw.tween_property(d, "rotation", 0.0, 0.06)
	# 外す → 落ちてドスン
	tw.tween_callback(func() -> void:
		hook.attached = false
		Sfx.play_pitch("chain", randf_range(0.9, 1.1), -8.0))
	tw.set_parallel(true)
	tw.tween_property(d, "position:y", to.y, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sh, "k", 1.0, 0.1)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _crate_thud(d, Vector2(d.position.x, to.y), n))
	tw.tween_callback(func() -> void:
		d.remove_meta("shadow")
		d.remove_meta("hook")
		sh.queue_free())
	# フックは上へ戻って消える
	var up := hook.create_tween()
	up.tween_interval(delay + HOOK_DOWN + 0.18)
	up.tween_property(hook, "position:y", -260.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	up.tween_callback(hook.queue_free)


func _crate_thud(d: Node2D, at: Vector2, n: int) -> void:
	if state != S.BET:
		return
	_shake(5.0 + n * 2.5, 0.22)
	# 積むほど低く重い音
	Sfx.play_pitch("thud", 1.1 - n * 0.08, -2.0 + n * 1.0)
	_squash(d)
	var h: float = STAGE_H[n - 1]
	_spark_burst(at + Vector2(0, -h * 0.45), n)
	_react_to_crate(n)
	# 土煙（左右にぽふっ）
	for sx in [-1.0, 1.0]:
		var sm := Sprite2D.new()
		sm.texture = _tex["dust-cloud"]
		sm.position = at + Vector2(sx * STAGE_H[n - 1] * 0.45, STAGE_H[n - 1] * 0.4)
		sm.scale = Vector2(0.08, 0.08)
		var big: float = 1.0 + 0.18 * (n - 1)   # 積むほど土煙も大きく
		sm.flip_h = sx < 0.0
		sm.z_index = 7
		fx.add_child(sm)
		var tw := sm.create_tween().set_parallel(true)
		tw.tween_property(sm, "scale", Vector2(0.28, 0.2) * big, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sm, "position:x", sm.position.x + sx * 60.0 * big, 0.4)
		tw.tween_property(sm, "modulate:a", 0.0, 0.45).set_delay(0.1)
		tw.chain().tween_callback(sm.queue_free)
	# 5個目（MAX）だけ特別：フラッシュ＋大きく揺れて「MAX!!」
	if n >= MAX_BET:
		Sfx.play_pitch("fullpower", 1.0, 0.0)
		_shake(22.0, 0.5)
		flash.color = Color(1, 1, 0.9, 0.85)
		create_tween().tween_property(flash, "color:a", 0.0, 0.35)
		_big("フルパワー！", Color(1, 0.85, 0.1), "max")
		var ft := create_tween()
		ft.tween_interval(0.9)
		ft.tween_property(big_img, "modulate:a", 0.0, 0.25)
		ft.tween_callback(func() -> void:
			big_img.visible = false
			big_img.modulate.a = 1.0
			lbl_big.visible = false)


## ビルの足元に跳んできた箱の着地（小さくドスッ）
func _land_crate(f: Sprite2D, i: int) -> void:
	f.rotation = 0.0
	Sfx.play_pitch("thud", 1.25 + i * 0.03, -8.0)
	_shake(3.0, 0.12)
	var base: Vector2 = f.scale
	var half: float = f.texture.get_height() / 2.0
	var tw := f.create_tween()
	tw.tween_method(func(v: float) -> void:
		f.scale = Vector2(base.x * (2.0 - v), base.y * v)
		f.offset.y = half * (1.0 / v - 1.0), 0.75, 1.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 前の段階の入れ物を「ボフン」と煙で消す（新しいのが上から乗った瞬間）
func _swap_out_old(n: int, at: Vector2) -> void:
	var keep: Array[Node2D] = []
	for o in _old_piles:
		if not is_instance_valid(o):
			continue
		if int(o.get_meta("stage", 0)) < n:
			o.queue_free()
		else:
			keep.append(o)
	_old_piles = keep
	var poof := Sprite2D.new()
	poof.texture = _tex["dust-cloud"]
	poof.position = at + Vector2(0, -STAGE_H[n - 1] * 0.2)
	poof.scale = Vector2(0.15, 0.15)
	poof.z_index = 7
	fx.add_child(poof)
	var big: float = STAGE_H[n - 1] / 300.0 + 0.25
	var tw := poof.create_tween().set_parallel(true)
	tw.tween_property(poof, "scale", Vector2(big * 1.3, big), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(poof, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tw.chain().tween_callback(poof.queue_free)


func _stage_tex(n: int) -> Texture2D:
	var key: String = "stage_%d" % n
	if not _tex.has(key):
		var path: String = "res://assets/pile/stage_%d.png" % n
		_tex[key] = load(path) if ResourceLoader.exists(path) else _tex["dynamite_crate"]
	return _tex[key]


## 電気が届いた瞬間、足元のダイナマイトの導火線に一斉に火がつく
func _light_fuses() -> void:
	for b in base_sticks:
		if not is_instance_valid(b):
			continue
		for c in b.get_children():
			if c is FuseSpark:
				(c as FuseSpark).lit = true


## 着地でグシャッと潰れて戻る（足元は固定）
func _squash(d: Node2D) -> void:
	if not is_instance_valid(d):
		return
	var spr: Sprite2D = d.get_child(0)
	var base: Vector2 = spr.scale
	var half: float = spr.texture.get_height() / 2.0
	var tw := spr.create_tween()
	tw.tween_method(func(v: float) -> void:
		spr.scale = Vector2(base.x * (2.0 - v), base.y * v)
		spr.offset.y = half * (1.0 / v - 1.0), 0.72, 1.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## 着地で導火線から火花がパッと散る（積むほど多く）
func _spark_burst(at: Vector2, n: int) -> void:
	# 粒子の部品は1つだけ作って使い回す（毎回作ると重い）
	if _burst == null:
		_burst = CPUParticles2D.new()
		_burst.one_shot = true
		_burst.explosiveness = 1.0
		_burst.amount = 30
		_burst.lifetime = 0.45
		_burst.direction = Vector2.UP
		_burst.spread = 70.0
		_burst.initial_velocity_min = 180.0
		_burst.gravity = Vector2(0, 900)
		_burst.scale_amount_min = 4.0
		_burst.scale_amount_max = 8.0
		# 火花ではなく土ぼこりと木くず（まだ火はついていない）
		var g := Gradient.new()
		g.set_color(0, Color(0.85, 0.72, 0.5))
		g.set_color(1, Color(0.55, 0.42, 0.3, 0))
		_burst.color_ramp = g
		_burst.z_index = 8
		_burst.emitting = false
		fx.add_child(_burst)
	_burst.position = at
	_burst.initial_velocity_max = 380.0 + n * 40.0
	_burst.restart()


## 積まれるたびのキャラの反応：監督はうれしそうに跳ね、作業員は数が増えるほどビビる
func _react_to_crate(n: int) -> void:
	var hop: float = 10.0 + n * 3.0 + (14.0 if n >= MAX_BET else 0.0)
	var ft := plunger.create_tween()
	ft.tween_property(plunger, "position:y", PLUNGER_Y - hop, 0.09).set_ease(Tween.EASE_OUT)
	ft.tween_property(plunger, "position:y", PLUNGER_Y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_fear = n
	sweat.level = n - 3        # 4個目から汗（控えめ）
	# ビクッ
	var wt := worker.create_tween()
	wt.tween_property(worker, "position:x", WORKER_POS.x - 10.0 - n * 2.0, 0.05)
	wt.tween_property(worker, "position:x", WORKER_POS.x, 0.12)
	if has_worker_scared and n >= 3:
		_set_worker_scared(true)


## 作業員のビビり顔（assets/chara/worker_crank_scared.png があるときだけ）
func _set_worker_scared(on: bool) -> void:
	if on and _worker_scared_tex:
		worker.texture = _worker_scared_tex
		worker.offset = Vector2(-_worker_scared_tex.get_width() / 2.0, -_worker_scared_tex.get_height())
	else:
		_worker_idle()


func _reset_fear() -> void:
	_fear = 0
	if sweat:
		sweat.level = 0
	_worker_idle()


## 積むほど危ない：山がガタガタ震える（BET中に毎フレーム）
func _rack_jitter() -> void:
	var amp: float = maxf(0.0, float(_pile_stage - 1)) * 1.1
	for d in rack:
		var spr: Node2D = d.get_child(0)
		spr.position = Vector2(randf_range(-amp, amp), randf_range(-amp * 0.4, amp * 0.4))
	# 作業員のガクブル（4個目から）
	var wa: float = maxf(0.0, float(_fear) - 3.0) * 1.5
	worker.offset.x = -worker.texture.get_width() / 2.0 + randf_range(-wa, wa)


## ダイナマイト箱の山の i 番目の中心位置（下段3つ → 上段2つ）。base は山の足元中央
func _crate_slot(i: int, h: float, base: Vector2) -> Vector2:
	var t: Texture2D = _tex["dynamite_crate"]
	var w: float = h * t.get_width() / t.get_height()
	var rows := [3, 2]
	var r: int = 0 if i < 3 else 1
	var c: int = i if i < 3 else i - 3
	var n: int = rows[r]
	# 後ろの段は半分くらい上にずらして、手前の段の後ろにかぶせる
	return base + Vector2((c - (n - 1) / 2.0) * w * 0.98, -h / 2.0 - r * h * 0.5)


## 後ろの段の箱は奥に描いて少し暗く
func _crate_depth(d: Node2D, i: int) -> void:
	if i >= 3:
		d.z_index = 3
		d.modulate = Color(0.82, 0.8, 0.78)


## ダイナマイト箱（当たり判定つき）。差してあるダイナマイトの導火線で火花がチラつく
func _make_stick(h: float, layer: int) -> RigidBody2D:
	return _make_container(2, h, layer)


## n 段階目の入れ物（当たり判定つき）。導火線の先で火花がチラつく
func _make_container(n: int, h: float, layer: int) -> RigidBody2D:
	var t: Texture2D = _stage_tex(n)
	var sc: float = h / t.get_height()
	var body := RigidBody2D.new()
	body.collision_layer = layer
	body.collision_mask = layer
	body.z_index = 4
	body.mass = 2.0
	body.lock_rotation = true   # 箱は傾かずにまっすぐ積み重なる
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.1
	body.physics_material_override = mat
	var spr := Sprite2D.new()
	spr.texture = t
	spr.scale = Vector2(sc, sc)
	body.add_child(spr)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(t.get_width() * 0.9, t.get_height() * 0.94) * sc
	cs.shape = rs
	cs.position = Vector2(0, t.get_height() * 0.03 * sc)
	body.add_child(cs)
	var fuses: Array = STAGE_FUSES[2] if t == _tex["dynamite_crate"] else STAGE_FUSES.get(n, [])
	for tip in fuses:
		var sp := FuseSpark.new()
		sp.position = Vector2((tip.x - 0.5) * t.get_width(), (tip.y - 0.5) * t.get_height()) * sc
		sp.size = h / 180.0
		body.add_child(sp)
	return body


func _clear_sticks() -> void:
	for d in rack:
		d.queue_free()
	rack.clear()
	for o in _old_piles:
		if is_instance_valid(o):
			o.queue_free()
	_old_piles.clear()
	_pile_stage = 0
	for d in base_sticks:
		d.queue_free()
	base_sticks.clear()


func _on_medals_changed(m: int) -> void:
	lbl_medals.text = "MEDAL × %d" % m
	_medals_txt = lbl_medals.text


func _on_idle_warning(s: int) -> void:
	if s < 0:
		lbl_idle.text = ""
		return
	lbl_idle.text = str(s)
	Sfx.play("beep", 1200.0, 0.12)


# ---------------------------------------------------------------- 入力

func _unhandled_input(e: InputEvent) -> void:
	if demo:
		# デモ中：ボタンかメダルで本番に戻る（メダルはそのまま受け付ける）
		if e.is_action_pressed("coin"):
			_abort_demo(true)
		elif _is_tap_press(e) or e.is_action_pressed("debug_add"):
			_abort_demo(false)
		return
	if e.is_action_pressed("debug_add"):
		MedalWallet.add(50)
		if state == S.WAIT:
			_say_wait()
		return
	match state:
		S.WAIT:
			if e.is_action_pressed("coin"):
				_insert()
		S.BET:
			if e.is_action_pressed("coin"):
				_insert()
			elif _is_tap_press(e):
				_confirm()
		S.CHARGE:
			if _is_tap_press(e):
				_on_tap()
		S.DETONATE:
			if _is_tap_release(e):
				_released = true
			elif _is_tap_press(e):
				touch()
				if _armed and _released:
					_detonate()


func _is_tap_press(e: InputEvent) -> bool:
	if e.is_action_pressed("tap"):
		return true
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


func _is_tap_release(e: InputEvent) -> bool:
	if e.is_action_released("tap"):
		return true
	return e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT


func _tap_held() -> bool:
	return Input.is_action_pressed("tap") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _insert(silent: bool = false) -> void:
	if _result_lock:
		return
	if state != S.WAIT and state != S.BET:
		return
	_bet_idle = 0.0
	if bet >= MAX_BET:
		Sfx.play("beep", 300.0, 0.15)
		return
	if not demo and not MedalWallet.spend(1):
		_say("メダルがない… [F2]でほじゅう")
		Sfx.play("beep", 300.0, 0.2)
		return
	bet += 1
	if not silent:
		Sfx.play("coin", 1500.0, 0.25)
	if state == S.WAIT:
		_enter(S.BET)
		_pose(foreman, "chara/foreman_2")
	else:
		touch()
	insert_sign.visible = false
	_say("")   # 説明はしない（▼とスポットライトで伝える）
	_update_bet_label()
	_refresh_strip()


func _confirm() -> void:
	var c: Building = centered_building()
	touch()
	chosen = c
	_enter(S.ZOOM)
	marker.visible = false
	arrow.visible = false
	uplight.strength = 0.0
	uplight_front.strength = 0.0
	# 決めたビルがドン！と大きくなる
	Sfx.play("beep", 2000.0, 0.12)
	var base: float = c.scale.x
	var pop := create_tween()
	pop.tween_property(c, "scale", Vector2.ONE * base * 1.3, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(c, "scale", Vector2.ONE * base, 0.15)
	await pop.finished
	_zoom()


# ---------------------------------------------------------------- ZOOM → CHARGE

func _zoom() -> void:
	_enter(S.ZOOM)
	marker.visible = false
	uplight.visible = false
	uplight_front.visible = false
	arrow.visible = false
	for b in buildings:
		(b.get_meta("tag") as Label).visible = false
		if b.has_meta("num"):
			(b.get_meta("num") as Control).visible = false
	_say("")
	# 中央にピタッと止める
	var snap: float = CENTER_X - chosen.position.x
	var st := create_tween().set_parallel(true)
	for b in buildings:
		st.tween_property(b, "position:x", b.position.x + snap, 0.12)
	await st.finished
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for b in buildings:
		if b != chosen:
			tw.tween_property(b, "modulate:a", 0.0, 0.35)
	var s: float = minf(ZOOM_MAX_SCALE, ZOOM_MAX_H / chosen.size().y)
	tw.tween_property(chosen, "position", Vector2(960, GROUND_Y), 0.6)
	tw.tween_property(chosen, "scale", Vector2(s, s), 0.6)
	await tw.finished
	for b in buildings:
		if b != chosen:
			b.visible = false
	# スイッチ（起爆器）が下からせり上がる
	_layout_gen_cable()
	cable_gen.visible = true
	# 発電機→起爆器の線は、寄ったあとにスルスルと伸びてくる
	cable_gen.grow = 0.0
	create_tween().tween_property(cable_gen, "grow", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	meter.visible = false   # 電気ゲージは出さない
	# 起爆器→ダイナマイトの線は、ダイナマイトを置いてから伸ばす
	cable.visible = false
	# 並べた入れ物が、小さい順に1個ずつ山なりにピョンと跳んでビルの足元へ
	var dest: Array[Vector2] = _pile_layout(rack.size(), BASE_RATIO, Vector2(CENTER_X, GROUND_Y + 4))
	_wire_pile(dest)
	var flyers: Array[Sprite2D] = []
	var last: Tween = null
	for i in rack.size():
		var d: RigidBody2D = rack[i]
		var n: int = int(d.get_meta("stage", 1))
		var src: Sprite2D = d.get_child(0)
		var f := Sprite2D.new()
		f.texture = src.texture
		f.scale = src.scale
		f.global_position = d.global_position
		f.z_index = 4
		f.set_meta("stage", n)
		add_child(f)
		flyers.append(f)
		var from: Vector2 = f.global_position
		var to: Vector2 = dest[i]
		var sc0: Vector2 = src.scale
		var sc1: Vector2 = src.scale * BASE_RATIO
		var spin: float = deg_to_rad(randf_range(-12, 12))
		var jt := f.create_tween()
		jt.tween_interval(i * FLY_GAP)
		jt.tween_method(func(u: float) -> void:
			f.global_position = from.lerp(to, u) + Vector2(0, -FLY_ARC * 4.0 * u * (1.0 - u))
			f.scale = sc0.lerp(sc1, u)
			f.rotation = spin * sin(u * PI), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		jt.tween_callback(_land_crate.bind(f, i))
		last = jt
	for d in rack:
		d.queue_free()
	rack.clear()
	if last != null:
		await last.finished
		await get_tree().create_timer(0.25).timeout
	for f in flyers:
		var n: int = int(f.get_meta("stage", 1))
		var b: RigidBody2D = _make_container(n, STAGE_H[n - 1] * BASE_RATIO, PIECE_LAYER)
		b.freeze = true
		b.position = f.global_position
		add_child(b)
		base_sticks.append(b)
		f.queue_free()
	await _run_wire()
	debris.position = chosen.position + Vector2(0, -chosen.size().y * s / 2.0)
	debris.emission_rect_extents = Vector2(chosen.size().x * s / 2.0, chosen.size().y * s / 2.0)
	await get_tree().create_timer(0.3).timeout
	_start_charge()


func _start_charge() -> void:
	# 回し始めたら汗は引っ込めて、いつものクランクの絵に戻す
	_reset_fear()
	_charge_lv = 0
	charge_box.level = 0
	charge_box.power = 0.0
	charge_box.visible = true
	power = 0.0
	_charge_left = charge_time
	_enter(S.CHARGE)
	_say("")
	# ボタン連打の合図
	btn_hint.interval = 0.6
	btn_hint.size_px = 400.0
	btn_hint.reset()
	_fade_in_button()
	_show_mash_text()
	_pose(foreman, "chara/foreman_1")
	Sfx.hum_level = 0.3


func _on_tap() -> void:
	power = minf(power + POWER_PER_TAP, 1.0)
	dynamo.kick()
	Sfx.play("tap", 0.0, 0.05)
	btn_hint.press()
	_bump_mash_text()
	_check_charge_level()
	# 押すたびに作業員が発電機のハンドルを1コマ回す
	if not _crank_frames.is_empty():
		_crank_phase += 1.0
		_set_worker_frame(int(_crank_phase) % _crank_frames.size())
	# 現場監督はスイッチに手をかけて待つ。電気が溜まるほど力が入る
	_set_push_frame(3 if power > 0.5 else 0)
	chosen.set_shake(power * 3.0)
	debris.emitting = power > 0.45


func _process(delta: float) -> void:
	super(delta)
	# デバッグ表示：フレームレート（カクつき確認用）
	_fps_acc += delta
	if SHOW_DEBUG_MEDAL and _fps_acc > 0.5:
		_fps_acc = 0.0
		if _medals_txt == "":
			_medals_txt = lbl_medals.text
		lbl_medals.text = "%s   FPS %d" % [_medals_txt, Engine.get_frames_per_second()]
	if links.visible:
		links.power = cable.power
	if title_logo:
		if state == S.WAIT:
			_wait_t += delta
		else:
			_wait_t = 0.0
			_title_boot = false
		if state == S.WAIT and not demo and not _result_lock and _wait_t > DEMO_AFTER:
			_run_demo()
		var want: bool = state == S.WAIT and (_title_boot or _wait_t > TITLE_IDLE)
		title_logo.modulate.a = move_toward(title_logo.modulate.a, 1.0 if want else 0.0, delta * 3.0)
		title_logo.visible = title_logo.modulate.a > 0.0
	if _shake_amt > 0.0:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_amt
	else:
		cam.offset = Vector2.ZERO
	if state == S.BET:
		_bet_idle += delta
	else:
		_bet_idle = 0.0
	if select_hint:
		var show_hint: bool = state == S.BET and _bet_idle > SELECT_HINT_AFTER
		if show_hint and not select_hint.visible:
			select_hint.scale = Vector2(0.4, 0.4)
			create_tween().tween_property(select_hint, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		select_hint.visible = show_hint
		if show_hint:
			select_hint.rotation = deg_to_rad(sin(_bet_idle * 3.0) * 2.0)
	if state == S.WAIT or state == S.BET:
		_scroll(delta)
		marker.visible = false
		uplight.visible = state == S.BET
		uplight_front.visible = state == S.BET
		arrow.visible = state == S.BET
		if state == S.BET:
			_rack_jitter()
	if false and crowd.visible:
		var hop: float = absf(sin(Time.get_ticks_msec() * (0.006 + 0.014 * _crowd))) * (2.0 + 16.0 * _crowd)
		crowd.position.y = _crowd_base_y - hop
	if state == S.CHARGE:
		_charge_left -= delta
		fuse.visible = true
		fuse.ratio = clampf(_charge_left / charge_time, 0.0, 1.0)
		dynamo.power = power
		meter.power = power
		cable.power = 0.0   # スイッチを押すまで建物側には流れない
		# 線の光り方は段階ごとにグッと上がる（段階の間は少しずつ）
		var lv_f: float = float(_charge_lv) / float(CHARGE_STEPS.size())
		cable_gen.power = clampf(lv_f * 0.85 + power * 0.15, 0.0, 1.0)
		cable_gen.flow = maxf(cable_gen.flow - delta * 120.0, dynamo.spin)
		charge_box.power = lv_f
		# 箱（と監督）が溜まるほどガタガタ
		var jit: float = lv_f * 2.5
		plunger.position = Vector2(PLUNGER_X + randf_range(-jit, jit), PLUNGER_Y + randf_range(-jit * 0.5, jit * 0.5))
		Sfx.hum_level = 0.25 + 0.6 * dynamo.spin / 30.0
		Sfx.hum_pitch = float(_charge_lv) * 0.25 + power * 0.15 + dynamo.spin / 40.0
		pass
		_crowd = 0.2 + power * 0.6
		if _charge_left <= 0.0:
			_enter_detonate()


# ---------------------------------------------------------------- DETONATE

func _enter_detonate() -> void:
	_hide_mash_text()
	plunger.position = Vector2(PLUNGER_X, PLUNGER_Y)
	lbl_timer.text = ""
	fuse.visible = false
	btn_hint.visible = false
	debris.emitting = false
	Sfx.hum_level = 0.12
	Sfx.hum_pitch = power
	_enter(S.DETONATE)
	# 起爆の合図：同じボタンアニメを大きく、ゆっくり
	btn_hint.interval = 1.2
	btn_hint.size_px = 460.0
	btn_hint.reset()
	_fade_in_button()
	_armed = false
	_released = not _tap_held()
	_say("")
	flash.color = Color(0, 0, 0, 0.45)
	_big("おせーーっ！！", Color(1, 0.3, 0.2), "push")
	_pose(foreman, "chara/foreman_2")
	_cut_in("chara/bust_1", 0.9)
	await get_tree().create_timer(DETONATE_LOCK).timeout
	if state != S.DETONATE:
		return
	flash.color = Color(0, 0, 0, 0)
	_armed = true
	while state == S.DETONATE:
		var tw := create_tween()
		tw.tween_property(plunger, "modulate", Color(1.25, 1.2, 1.0), 0.15)
		tw.tween_property(plunger, "modulate", Color.WHITE, 0.15)
		await tw.finished


func _detonate() -> void:
	_enter(S.RESULT)
	# 押したボタンはしっかり押し込んで見せてから消す
	btn_hint.slam()
	Sfx.play_pitch("press", 1.0, 2.0)
	_shake(6.0, 0.15)
	var bt := btn_hint.create_tween()
	bt.tween_property(btn_hint, "scale", Vector2(1.06, 0.94), 0.06)
	bt.tween_property(btn_hint, "scale", Vector2.ONE, 0.12)
	bt.tween_interval(0.2)
	bt.tween_property(btn_hint, "modulate:a", 0.0, 0.25)
	bt.tween_callback(func() -> void: btn_hint.visible = false)
	var lt := lbl_big.create_tween()
	lt.tween_property(lbl_big, "modulate:a", 0.0, 0.2)
	lt.tween_callback(func() -> void: lbl_big.visible = false)
	await get_tree().create_timer(0.35).timeout
	plunger.modulate = Color.WHITE
	Sfx.hum_level = 0.0
	# ここで初めてスイッチを押し込む：大ジャンプで叩き込む
	_set_push_frame(PUSH_SLAM)
	var pt := create_tween()
	pt.tween_property(plunger, "position:y", PLUNGER_Y - 30, 0.08)
	pt.tween_property(plunger, "position:y", PLUNGER_Y, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	pt.tween_interval(0.6)
	pt.tween_callback(_set_push_frame.bind(2))
	var p: float = chance(chosen.data, bet, power)
	var win: bool = randf() < p
	if demo:
		win = true   # デモは必ず成功して見せる
		debug_pattern = "straight"
	print("[抽選] %s 爆弾%d パワー%.2f → 確率%.1f%% → %s" % [chosen.data.name, bet, power, p * 100.0, "崩壊" if win else "残る"])
	# スイッチを押した瞬間、溜めた電気が一気に建物へ走る
	create_tween().tween_property(cable_gen, "power", 0.0, 0.3)
	# 起爆器に溜めた電気が一気に抜けていく
	var drain := create_tween()
	drain.tween_property(charge_box, "power", 0.0, 0.4)
	drain.tween_callback(func() -> void:
		charge_box.level = 0
		charge_box.visible = false)
	cable.flow = 40.0
	var surge := create_tween()
	surge.tween_property(cable, "power", 1.0, 0.12)
	surge.tween_callback(_light_fuses)
	surge.tween_interval(0.35)
	await surge.finished
	create_tween().tween_property(cable, "power", 0.0, 0.3)
	cable.flow = 0.0
	await _play_result(win)


## 崩壊確率。案1（比例型）。物置は固定。
func chance(d: Dictionary, bombs: int, pw: float) -> float:
	if d.has("fixed"):
		return float(d.fixed)
	var q: float = RTP / (float(d.payout) * AVG_MASH)
	return minf(q * bombs * (1.0 + MASH_MAX_BONUS * pw), 0.95)


# ---------------------------------------------------------------- RESULT（煽り）

func _play_result(win: bool) -> void:
	var k: float = time_scale * float(chosen.data.get("tempo", 1.0))
	var pat: String = _weighted(PATTERNS[win]) if debug_pattern == "" else debug_pattern
	var was_demo: bool = demo
	_pose(foreman, "chara/foreman_3")
	_crowd = 1.0
	await _explode()
	await _smoke_cover(t_smoke * k)
	_crowd = 0.15
	match pat:
		"straight":
			_creak()
			chosen.set_crack(1.0, t_tilt * k)
			await chosen.tilt(7.0, t_tilt * k).finished
			await _collapse()
		"comeback":
			_creak()
			chosen.set_crack(0.6, t_tilt * k)
			await chosen.tilt(4.0, t_tilt * k * 0.7).finished
			chosen.set_shake(1.0)
			_say("……")
			await get_tree().create_timer(t_hold * k).timeout
			chosen.set_shake(0.0)
			Sfx.play("creak", 120.0, 0.6)
			await chosen.tilt(11.0, 0.3).finished
			await _collapse()
		"near_miss":
			_creak()
			Sfx.play("rumble", 0.0, t_tilt * k * 1.3)
			chosen.set_crack(0.9, t_tilt * k)
			await chosen.tilt(15.0, t_tilt * k * 1.3).finished
			await get_tree().create_timer(0.25 * k).timeout
			var back := chosen.tilt(0.0, t_clear * k)
			back.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			await back.finished
			await _smoke_clear(t_clear * k)
			# 持ちこたえたビルのてっぺんから、かけらが1つだけポロッ…
			await _top_chunk_falls()
		"solid":
			chosen.set_shake(4.0)
			Sfx.play("rumble", 0.0, t_tilt * k * 1.2)
			chosen.set_crack(0.3, t_tilt * k)
			await get_tree().create_timer(t_tilt * k * 1.2).timeout
			chosen.set_shake(0.0)
			await _smoke_clear(t_clear * k)
	var payout: int = int(chosen.data.payout) if win else 0
	if win:
		_say("")
		_pose(foreman, "chara/foreman_4")
		_crowd = 1.0
		_hop(foreman)
		await get_tree().create_timer(0.5).timeout
		# リザルト画面
		var rank: int = ResultScreen.rank_of(payout)
		var num_path: String = "res://assets/num/%d.png" % payout
		var num_tex: Texture2D = load(num_path) if ResourceLoader.exists(num_path) else null
		Sfx.set_bgm_volume(-30.0)
		result.show_result(payout, chosen.data.name, num_tex)
		_fanfare(rank)
		# リザルトを出している裏で、次のプレイの待機画面に戻しておく（閉じたらすぐ遊べる）
		_result_lock = true
		ui.visible = false
		var min_show := get_tree().create_timer(RESULT_TIME[rank])
		await get_tree().create_timer(0.45).timeout
		_end(payout)
		await get_tree().create_timer(0.15).timeout
		await tray.payout(payout, Vector2(CENTER_X, 560), not was_demo)
		if min_show.time_left > 0.0:
			await min_show.timeout
		ui.visible = true
		await result.hide_result()
		_result_lock = false
		Sfx.set_bgm_volume(-10.0)
		return
	else:
		_say("")
		if pat == "near_miss":
			_big("おしい……！", Color(1.0, 0.75, 0.2), "oshii")
		else:
			_big("しっぱい……", Color(0.5, 0.75, 1.0), "lose")
		Sfx.play_pitch("lose", 1.0, -2.0)
		_pose(foreman, "chara/foreman_5")
		_crowd = 0.0
		_zukkoke()
		# ビルは「えっへん」と胸を張る
		var bt := chosen.create_tween()
		bt.tween_property(chosen, "scale", chosen.scale * Vector2(1.04, 1.06), 0.15)
		bt.tween_property(chosen, "scale", chosen.scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_cut_in("chara/bust_2", 1.0)
	await get_tree().create_timer(0.6 if win else 2.0).timeout
	_end(payout)


## デモ：メダル3枚 → 高いビルを選ぶ → 連打 → 起爆 → 成功、を自動で見せる
func _run_demo() -> void:
	demo = true
	_wait_t = 0.0
	_title_boot = false
	if demo_label == null:
		_build_demo_badge()
	demo_label.visible = true
	var picks: Array = []
	for d in BUILDINGS:
		if int(d.payout) >= 8:
			picks.append(d)
	var target: Dictionary = picks[randi() % picks.size()]
	for i in 3:
		await get_tree().create_timer(0.6).timeout
		if not demo:
			return
		_insert()
	# ねらいのビルが真ん中で止まったら選ぶ（来なければ時間切れで今のを選ぶ）
	var waited: float = 0.0
	while demo and state == S.BET:
		var c: Building = centered_building()
		if (c and c.data == target and _dwell > 0.0) or waited > 15.0:
			await get_tree().create_timer(0.2).timeout
			if demo and state == S.BET:
				_confirm()
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	# 連打
	while demo and state != S.CHARGE and state != S.WAIT:
		await get_tree().process_frame
	while demo and state == S.CHARGE:
		_on_tap()
		await get_tree().create_timer(randf_range(0.11, 0.16)).timeout
	# 起爆
	while demo and state == S.DETONATE and not _armed:
		await get_tree().process_frame
	if demo and state == S.DETONATE:
		await get_tree().create_timer(0.5).timeout
		if demo and state == S.DETONATE:
			_detonate()


## 左上の「デモプレイ」札：赤い札に黄色のフチ、白い文字、点滅ランプ。ゆらゆら揺れる
func _build_demo_badge() -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.12, 0.1)
	sb.border_color = Color(1.0, 0.82, 0.1)
	sb.set_border_width_all(7)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(5, 7)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(330, 92)
	p.position = Vector2(26, 56)
	p.pivot_offset = p.size / 2.0
	p.rotation = deg_to_rad(-4)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 黒い外フチ
	var outer := Panel.new()
	var so := StyleBoxFlat.new()
	so.bg_color = Color(0, 0, 0, 0)
	so.border_color = Color(0.06, 0.04, 0.05)
	so.set_border_width_all(5)
	so.set_corner_radius_all(26)
	outer.add_theme_stylebox_override("panel", so)
	outer.position = Vector2(-5, -5)
	outer.size = p.size + Vector2(10, 10)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(outer)
	# 点滅ランプ
	var lamp := Panel.new()
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(1, 1, 0.85)
	sl.border_color = Color(0.06, 0.04, 0.05)
	sl.set_border_width_all(4)
	sl.set_corner_radius_all(16)
	lamp.add_theme_stylebox_override("panel", sl)
	lamp.size = Vector2(32, 32)
	lamp.position = Vector2(22, 30)
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lamp)
	var bl := lamp.create_tween().set_loops()
	bl.tween_property(lamp, "modulate:a", 0.15, 0.4)
	bl.tween_property(lamp, "modulate:a", 1.0, 0.4)
	var l := Label.new()
	l.text = "デモプレイ"
	l.add_theme_font_size_override("font_size", 54)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.05))
	l.add_theme_constant_override("outline_size", 16)
	if font:
		l.add_theme_font_override("font", font)
	l.position = Vector2(66, 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	# ゆらゆら
	var sw := p.create_tween().set_loops()
	sw.tween_property(p, "rotation", deg_to_rad(-1), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sw.tween_property(p, "rotation", deg_to_rad(-5), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ui.add_child(p)
	demo_label = p


## デモを途中でやめて本番に戻る（画面を作り直すのがいちばん確実）
func _abort_demo(with_coin: bool) -> void:
	if _aborting:
		return
	_aborting = true
	if with_coin:
		Engine.set_meta("pending_coin", true)
		Sfx.play("coin", 1500.0, 0.25)   # 入れた瞬間に音で応える
	Engine.time_scale = 1.0
	Sfx.hum_level = 0.0
	demo = false
	# すっと暗転して作り直し、明けたら本番（継ぎ目を見せない）
	await Fader.fade_out(0.15)
	Engine.set_meta("fade_in", true)
	if restart_requested.get_connections().is_empty():
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()   # 仮想筐体の中：ゲームの画面だけを作り直してもらう


## 失敗：監督が起爆器ごとズッコける
func _zukkoke() -> void:
	var tw := plunger.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(plunger, "position:y", PLUNGER_Y - 40.0, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(plunger, "rotation_degrees", 28.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(plunger, "position:y", PLUNGER_Y, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_shake(6.0, 0.15)
		Sfx.play_pitch("thud", 1.3, -4.0))
	tw.tween_interval(1.0)
	tw.tween_property(plunger, "rotation_degrees", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 惜しかったとき：てっぺんのかけらが1つだけ落ちて、ポテッ、コロコロ
func _top_chunk_falls() -> void:
	var t: Texture2D = chosen.tex
	var sc: float = chosen.scale.x
	var h: float = chosen.size().y * sc
	var c := Sprite2D.new()
	c.texture = t
	c.region_enabled = true
	var cw: float = minf(110.0, t.get_width() * 0.3)
	c.region_rect = Rect2(t.get_width() * 0.55, 0, cw, cw * 0.8)
	c.scale = Vector2(sc, sc) * 1.2
	var from := Vector2(CENTER_X + chosen.size().x * sc * 0.1, GROUND_Y - h + 10.0)
	var to := Vector2(from.x + 70.0, GROUND_Y - 8.0)
	c.position = from
	c.z_index = 7
	fx.add_child(c)
	chosen.set_shake(1.5)
	await get_tree().create_timer(0.35).timeout
	chosen.set_shake(0.0)
	Sfx.play_pitch("plink", 1.0, 0.0)
	var tw := c.create_tween()
	tw.tween_property(c, "position", to, clampf(h / 900.0, 0.3, 0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "rotation", 3.0, 0.6)
	tw.tween_property(c, "position", to + Vector2(30, -26), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", to + Vector2(50, 0), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "position", to + Vector2(62, -8), 0.07)
	tw.tween_property(c, "position", to + Vector2(70, 0), 0.07)
	tw.tween_interval(2.5)
	tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)
	await get_tree().create_timer(0.6).timeout


## リザルトのファンファーレ（ランクが上がるほど長い）
func _fanfare(rank: int) -> void:
	if Sfx.has_file("fanfare_%d" % rank):
		Sfx.play("fanfare_%d" % rank)
		return
	var notes: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	if rank >= 1:
		notes.append_array([784.0, 1047.0, 1319.0])
	if rank >= 2:
		notes.append_array([1047.0, 1319.0, 1568.0, 2093.0])
	for f in notes:
		Sfx.play("beep", f, 0.14)
		await get_tree().create_timer(0.11).timeout
	Sfx.play("beep", notes.back(), 0.7)


func _weighted(table: Dictionary) -> String:
	var r: float = randf()
	var acc: float = 0.0
	for key: String in table:
		acc += float(table[key])
		if r < acc:
			return key
	return table.keys().back()


func _explode() -> void:
	# 爆発で発破線がビル側からちぎれて吹き飛ぶ（残さない）
	var ct := create_tween()
	ct.tween_property(cable, "cut", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	ct.tween_callback(func() -> void: cable.visible = false)
	links.visible = false
	bomb_marks.count = 0
	for d in base_sticks:
		d.queue_free()
	base_sticks.clear()
	var s: float = chosen.scale.x
	var h: float = chosen.size().y * s
	var ex := Sprite2D.new()
	ex.texture = _tex["explosion-cloud"]
	ex.position = Vector2(960, GROUND_Y - minf(h * 0.35, 200.0))
	ex.scale = Vector2(0.15, 0.15)
	fx.add_child(ex)
	var target: float = clampf(maxf(chosen.size().x * s, h) / 500.0, 0.8, 1.6)
	Sfx.play("boom", 0.0, 1.4)
	flash.color = Color(1, 1, 1, 0.9)
	create_tween().tween_property(flash, "color:a", 0.0, 0.35)
	_shake(28.0, 0.6)
	var tw := create_tween()
	tw.tween_property(ex, "scale", Vector2(target, target), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ex, "modulate:a", 0.0, 0.6)
	tw.tween_callback(ex.queue_free)
	_big("ドカーーン!!", Color(1, 0.85, 0.05), "boom")
	_window_puffs()
	# ヒットストップ
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(lbl_big, "modulate:a", 0.0, 0.3)


var _smokes: Array[Sprite2D] = []

func _smoke_cover(dur: float) -> void:
	# 建物の真ん中を軸に、上から下まで同じ太さの土煙の柱（ばらつきは少しだけ）。
	# 数・大きさ・ずれは建物ごとに決まった値（毎回同じ形で自然に隠れる）
	var s: float = chosen.scale.x
	var w: float = chosen.size().x * s
	var h: float = chosen.size().y * s
	var tex: Texture2D = _tex["dust-cloud"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(chosen.data.file))
	var big: float = maxf(w * 1.3, 400.0)       # 雲の幅（上から下まで同じ太さの四角い柱）
	var small: float = big
	var n: int = 3 + int(h / 160.0)
	var specs: Array = []   # [位置, 幅, 何番目の高さか(0〜1)]
	for i in n:
		var t: float = float(i) / float(maxi(n - 1, 1))
		var cw: float = lerpf(big, small, t) * rng.randf_range(0.85, 1.15)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = CENTER_X + side * rng.randf_range(0.0, w * 0.12)
		var y: float = GROUND_Y - 20.0 - t * h * 0.92
		specs.append([Vector2(x, y), cw, t])
	for sp in specs:
		var sm := Sprite2D.new()
		sm.texture = tex
		sm.position = sp[0]
		var sc: float = float(sp[1]) / tex.get_width()
		sm.scale = Vector2(0.15, 0.15) * sc
		sm.modulate.a = 0.0
		sm.flip_h = rng.randf() < 0.5
		sm.rotation = deg_to_rad(rng.randf_range(-8, 8))
		sm.z_index = 5
		fx.add_child(sm)
		_smokes.append(sm)
		var tw := create_tween()
		tw.tween_interval(dur * 0.3 * float(sp[2]))   # 下から順に湧き上がる
		tw.tween_property(sm, "scale", Vector2(sc, sc), dur * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sm, "modulate:a", 1.0, dur * 0.3)
		tw.parallel().tween_property(sm, "position:x", sm.position.x + rng.randf_range(-15, 15), dur * 4.0)
	await get_tree().create_timer(dur * 0.8).timeout


func _smoke_clear(dur: float) -> void:
	for sm in _smokes:
		var tw := create_tween()
		tw.tween_property(sm, "modulate:a", 0.0, dur)
		tw.tween_callback(sm.queue_free)
	_smokes.clear()
	await get_tree().create_timer(dur).timeout


func _collapse() -> void:
	var sc: float = chosen.scale.x
	var w: float = chosen.size().x * sc
	var h: float = chosen.size().y * sc
	var floors: int = clampi(int(h / 90.0), 2, 9)
	var dur: float = clampf(0.6 + h / 900.0, 0.8, 1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(chosen.data.file)) + 1
	var lean: float = -1.0 if rng.randf() < 0.5 else 1.0
	Sfx.play("boom", 0.0, 0.9)
	Sfx.play("rumble", 0.0, 1.6)
	_shake(14.0, dur + 0.4)
	# 煙を薄くして、中で沈んでいくビルが見えるように
	for sm in _smokes:
		sm.create_tween().tween_property(sm, "modulate:a", 0.18, 0.3)
	chosen.rotation_degrees = 0.0
	var im := chosen.implode(dur, lean, floors)
	# 階が抜けるたびにドスン＋足元から土煙が横へ
	for i in floors:
		var at: float = dur * float(i) / floors
		get_tree().create_timer(at).timeout.connect(func() -> void:
			Sfx.play_pitch("thud", 0.7 + 0.05 * i, 0.0)
			_ground_dust(w, 0.6 + 0.12 * i)
			_rubble_chips(w, 3))
	await im.finished
	# 沈みきった瞬間：大きな土煙の波とがれきの山
	_shake(24.0, 0.5)
	Sfx.play("rumble", 0.0, 1.2)
	_ground_dust(w, 1.1)
	_rubble_pile(w)
	await get_tree().create_timer(0.7).timeout
	await _smoke_clear(0.8)


## 足元から左右へ地面をはうように広がる土煙
func _ground_dust(w: float, size_k: float) -> void:
	for side in [-1.0, 1.0]:
		var sm := Sprite2D.new()
		sm.texture = _tex["dust-cloud"]
		sm.position = Vector2(CENTER_X + side * w * 0.3, GROUND_Y - 30.0)
		sm.scale = Vector2(0.15, 0.1)
		sm.flip_h = side < 0.0
		sm.z_index = 2   # キャラより奥
		fx.add_child(sm)
		var tgt := Vector2(0.42, 0.26) * size_k
		var tw := sm.create_tween().set_parallel(true)
		tw.tween_property(sm, "scale", tgt, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sm, "position:x", sm.position.x + side * (90.0 + 80.0 * size_k), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sm, "modulate:a", 0.0, 0.8).set_delay(0.6)
		tw.chain().tween_callback(sm.queue_free)


## 沈むところから壁のかけらが横へはじけ飛ぶ（物理は使わずアニメで）
func _rubble_chips(w: float, n: int) -> void:
	var t: Texture2D = chosen.tex
	var sc: float = chosen.scale.x
	for i in n:
		var c := Sprite2D.new()
		c.texture = t
		c.region_enabled = true
		var cw: float = randf_range(22, 40)
		c.region_rect = Rect2(randf_range(0, t.get_width() - cw), randf_range(t.get_height() * 0.3, t.get_height() * 0.9), cw, cw * randf_range(0.6, 1.0))
		c.scale = Vector2(sc, sc)
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var from := Vector2(CENTER_X + side * w * randf_range(0.2, 0.45), GROUND_Y - randf_range(10, 40))
		var to := from + Vector2(side * randf_range(80, 220), randf_range(10, 30))
		var lift: float = randf_range(60, 160)
		var spin: float = randf_range(-6, 6)
		c.position = from
		c.z_index = 7
		fx.add_child(c)
		var tw := c.create_tween()
		tw.tween_method(func(u: float) -> void:
			c.position = from.lerp(to, u) + Vector2(0, -lift * 4.0 * u * (1.0 - u))
			c.rotation = spin * u, 0.0, 1.0, randf_range(0.45, 0.7))
		tw.tween_property(c, "modulate:a", 0.0, 0.5).set_delay(0.6)
		tw.tween_callback(c.queue_free)


## 沈みきったあとに残るがれきの山
func _rubble_pile(w: float) -> void:
	var mound := RubbleMound.new()
	mound.width = clampf(w * 1.15, 180.0, 520.0)
	mound.height = clampf(w * 0.22, 40.0, 110.0)
	mound.seed_v = hash(str(chosen.data.file))
	# 建物の色に寄せる（絵の真ん中あたりの色）
	var img: Image = chosen.tex.get_image()
	if img.is_compressed():
		img.decompress()
	var c: Color = img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.6))
	mound.base_col = Color(0.6, 0.55, 0.5).lerp(Color(c, 1.0), 0.35)
	mound.position = Vector2(CENTER_X, GROUND_Y + 8.0)
	mound.z_index = 3
	fx.add_child(mound)
	var tw := mound.create_tween()
	tw.tween_property(mound, "grow", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.8)
	tw.tween_property(mound, "modulate:a", 0.0, 0.6)
	tw.tween_callback(mound.queue_free)


## 起爆の瞬間、各階の窓から一斉に「ボフッ」と煙が噴き出す（発破解体の名物）
func _window_puffs() -> void:
	var sc: float = chosen.scale.x
	var w: float = chosen.size().x * sc
	var h: float = chosen.size().y * sc
	var floors: int = clampi(int(h / 90.0), 2, 9)
	for i in floors:
		var y: float = GROUND_Y - h * (float(i) + 0.5) / floors
		for side in [-1.0, 1.0]:
			var sm := Sprite2D.new()
			sm.texture = _tex["dust-cloud"]
			sm.position = Vector2(CENTER_X + side * w * 0.5, y)
			sm.scale = Vector2(0.03, 0.03)
			sm.flip_h = side < 0.0
			sm.z_index = 6
			fx.add_child(sm)
			var k: float = clampf(w / 900.0, 0.12, 0.3)
			var tw := sm.create_tween().set_parallel(true)
			tw.tween_property(sm, "scale", Vector2(k, k * 0.8), 0.25).set_delay(i * 0.03).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(sm, "position:x", sm.position.x + side * 70.0, 0.5).set_delay(i * 0.03)
			tw.tween_property(sm, "modulate:a", 0.0, 0.6).set_delay(0.5)
			tw.chain().tween_callback(sm.queue_free)


func _hop(s: Sprite2D) -> void:
	var y: float = s.position.y
	var tw := create_tween().set_loops(3)
	tw.tween_property(s, "position:y", y - 50.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _creak() -> void:
	Sfx.play("creak", randf_range(90.0, 140.0), 0.9)


func _shake(amount: float, dur: float) -> void:
	_shake_amt = amount
	var tw := create_tween()
	tw.tween_property(self, "_shake_amt", 0.0, dur)


func _big(text: String, color: Color, key: String = "") -> void:
	if key != "" and _text_img.has(key):
		lbl_big.text = ""
		big_img.texture = _text_img[key]
		var h: float = {"boom": 420.0, "push": 280.0}.get(key, 300.0)
		var cy: float = {"push": -15.0}.get(key, 110.0)   # 画面の上のほう、ボタンにかぶらない高さに
		big_img.size = Vector2(h * big_img.texture.get_width() / big_img.texture.get_height(), h)
		big_img.position = Vector2(900.0 - big_img.size.x / 2.0, cy - h / 2.0)
		big_img.visible = true
	else:
		lbl_big.text = text
		big_img.visible = false
	lbl_big.add_theme_color_override("font_color", color)
	lbl_big.visible = true
	lbl_big.modulate.a = 1.0
	lbl_big.rotation = deg_to_rad(-6)
	lbl_big.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(lbl_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 連打・起爆のボタンをふわっと出す（下から少し浮き上がりながら）
func _fade_in_button() -> void:
	btn_hint.visible = true
	btn_hint.modulate.a = 0.0
	btn_hint.scale = Vector2(0.85, 0.85)
	var base_y: float = BTN_Y
	btn_hint.position.y = base_y + 40.0
	var tw := btn_hint.create_tween().set_parallel(true)
	tw.tween_property(btn_hint, "modulate:a", 1.0, 0.35)
	tw.tween_property(btn_hint, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn_hint, "position:y", base_y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 溜まった電気の段階が上がったら、起爆器がバチッと光ってランプが増え、音が上がる
func _check_charge_level() -> void:
	var lv: int = 0
	for th in CHARGE_STEPS:
		if power >= th:
			lv += 1
	if lv <= _charge_lv:
		return
	_charge_lv = lv
	charge_box.level_up(lv)
	var is_max: bool = lv >= CHARGE_STEPS.size()
	Sfx.play_pitch("chargeup", 0.75 + 0.22 * lv, -4.0 + lv)
	_shake(3.0 + lv * 2.5, 0.2)
	# 線にも一瞬どっと流れる
	cable_gen.flow = 60.0
	if is_max:
		Sfx.play_pitch("chargeup", 2.0, 0.0)
		flash.color = Color(0.8, 0.95, 1.0, 0.55)
		create_tween().tween_property(flash, "color:a", 0.0, 0.4)
		_shake(16.0, 0.4)


## 連打フェーズの「れんだ！」文字。押すたびにポンと弾む
const MASH_POS := Vector2(960, 250)
const MASH_H := 240.0
var mash_text: Sprite2D
var _mash_base: float = 1.0


func _show_mash_text() -> void:
	if mash_text == null:
		var tp: String = "res://assets/text/charge.png"
		if not ResourceLoader.exists(tp):
			return
		mash_text = Sprite2D.new()
		mash_text.texture = load(tp)
		mash_text.position = MASH_POS
		_mash_base = MASH_H / mash_text.texture.get_height()
		ui.add_child(mash_text)
	mash_text.visible = true
	mash_text.rotation = deg_to_rad(-5)
	mash_text.scale = Vector2.ONE * _mash_base * 0.3
	create_tween().tween_property(mash_text, "scale", Vector2.ONE * _mash_base, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bump_mash_text() -> void:
	if mash_text == null or not mash_text.visible:
		return
	mash_text.scale = Vector2.ONE * _mash_base * 1.12
	mash_text.rotation = deg_to_rad(randf_range(-8, -2))
	create_tween().tween_property(mash_text, "scale", Vector2.ONE * _mash_base, 0.12)


func _hide_mash_text() -> void:
	if mash_text:
		mash_text.visible = false


func _press_anim(s: Sprite2D) -> void:
	var base: Vector2 = s.scale
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(base.x * 1.08, base.y * 0.8), 0.06)
	tw.tween_property(s, "scale", base, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 爆弾マーク

class BombMarks extends Node2D:
	## ビルの足元に積んだダイナマイトの山。assets/dynamite.png を使う。
	const STICK_H := 90.0         # 1本の表示高さ
	const STEP := 32.0            # 横の間隔
	const ROW_H := 30.0           # 段の高さ
	const FUSE_TIP := Vector2(0.65, 0.02)  # 画像内の導火線の先端位置（0〜1）。火花がここに出る
	var tex: Texture2D
	var count: int = 0:
		set(v):
			count = v
			queue_redraw()
	var _w: float = 0.0

	func place(base: Vector2, width: float, n: int) -> void:
		position = base
		_w = width
		count = n

	func _process(_delta: float) -> void:
		if count > 0:
			queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var sc: float = STICK_H / tex.get_height()
		var sz: Vector2 = tex.get_size() * sc
		for i in count:
			var p: Vector2 = DemolitionCabinetPile.pos(i, STEP, ROW_H)
			var tilt: float = deg_to_rad(sin(i * 12.9898) * 9.0)
			draw_set_transform(p, tilt, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-sz.x / 2.0, -sz.y, sz.x, sz.y), false)
			# 導火線の火花（ちらつき）
			var spark := Vector2(-sz.x / 2.0 + sz.x * FUSE_TIP.x, -sz.y + sz.y * FUSE_TIP.y)
			var r: float = 4.0 + randf() * 3.0
			draw_circle(spark, r + 3.0, Color(1, 0.5, 0.1, 0.7))
			draw_circle(spark, r, Color(1, 0.95, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class DemolitionCabinetPile:
	## 山積みの並べ方（ラックと足元で共通）
	const ROWS := [7, 5, 3]

	static func pos(i: int, step: float, row_h: float) -> Vector2:
		var r: int = 0
		while r < ROWS.size() - 1 and i >= ROWS[r]:
			i -= ROWS[r]
			r += 1
		return Vector2((i - (ROWS[r] - 1) / 2.0) * step + (r % 2) * 4.0, -r * row_h)



## 導火線の火花
class FuseSpark extends Node2D:
	var size: float = 1.0
	var _acc: float = randf() * 0.07
	var lit: bool = false     # 起爆するまでは火をつけない

	func _process(delta: float) -> void:
		if not lit:
			if visible:
				visible = false
			return
		visible = true
		# ちらつきは1秒に15回くらいで十分（毎フレーム描き直すと重い）
		_acc += delta
		if _acc >= 0.066:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var r: float = (3.0 + randf() * 3.0) * size
		draw_circle(Vector2.ZERO, r + 3.0 * size, Color(1, 0.5, 0.1, 0.75))
		draw_circle(Vector2.ZERO, r, Color(1, 0.95, 0.4))


## 選択ゾーン：中央のビルを囲む黄黒のカギカッコ＋足元のターゲット
class SelectMarker extends Node2D:
	const OUT := Color(0.08, 0.05, 0.05)
	var rect: Rect2
	var locked: bool = false
	var _t: float = 0.0
	var _gap: float = 40.0

	func _process(delta: float) -> void:
		_t += delta
		_gap = lerpf(_gap, 10.0 if locked else 40.0, minf(1.0, delta * 14.0))
		queue_redraw()

	func _draw() -> void:
		if rect.size.x <= 0.0:
			return
		var g: float = _gap + sin(_t * 8.0) * 3.0
		var r: Rect2 = rect.grow(g)
		# 足元のターゲット（楕円の二重丸）
		var base := Vector2(r.get_center().x, rect.end.y + 4)
		var rad: float = rect.size.x * 0.55 + 30.0
		draw_set_transform(base, 0.0, Vector2(1.0, 0.22))
		draw_arc(Vector2.ZERO, rad, 0, TAU, 48, OUT, 30.0)
		draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(0.95, 0.15, 0.12), 18.0)
		draw_arc(Vector2.ZERO, rad * 0.6, 0, TAU, 48, OUT, 22.0)
		draw_arc(Vector2.ZERO, rad * 0.6, 0, TAU, 48, Color.WHITE, 12.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 四隅のカギカッコ
		var col: Color = Color(1, 0.85, 0.1) if not locked or fmod(_t, 0.3) < 0.2 else Color.WHITE
		var L: float = clampf(minf(r.size.x, r.size.y) * 0.25, 30.0, 70.0)
		for c in [[r.position, Vector2(1, 0), Vector2(0, 1)],
				[Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
				[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)],
				[r.end, Vector2(-1, 0), Vector2(0, -1)]]:
			var p: Vector2 = c[0]
			var pts := PackedVector2Array([p + c[1] * L, p, p + c[2] * L])
			draw_polyline(pts, OUT, 20.0)
			draw_polyline(pts, col, 10.0)
