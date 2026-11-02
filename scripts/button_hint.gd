class_name ButtonHint
extends Node2D
## 「ボタンを押せ」の合図アニメ。assets/button/press_0〜3.png のコマ送りで
## 「離した」「押した」の2コマだけで切り替え、押した瞬間に衝撃の輪が広がる。
## 連打中も起爆待ちも同じアニメで、間隔と大きさだけ変える。原点は土台の下端中央。

const FRAMES := 4
## 使うコマ（press_N の N）。離した→押した の2コマだけ
const USE := [0, 2]
## 1周の中で各コマに切り替わるタイミング（0〜1）
const SWITCH := [0.0, 0.55]

var tex: Texture2D               # 互換用（未使用）
var interval: float = 0.14       # 1回押す間隔（秒）
var size_px: float = 170.0       # ボタンの表示幅
var _frames: Array[Texture2D] = []
var _t: float = 0.0
var _last: int = 0
var _rings: Array[float] = []
var _since_press: float = 99.0
## 最後に押されてからこの秒数は「押したら凹む」だけ。それを過ぎたら自動で押して促す
const IDLE_AUTO := 1.2
const PRESS_HOLD := 0.09


## プレイヤーがボタンを押した瞬間に呼ぶ（凹ませて輪を出す）
func press() -> void:
	_since_press = 0.0
	_rings.append(0.0)


func reset() -> void:
	_since_press = 99.0
	_t = 0.0


func _cur() -> int:
	if _since_press < IDLE_AUTO:
		return 1 if _since_press < PRESS_HOLD else 0
	return _frame_at(fmod(_t, interval) / interval)


func _ready() -> void:
	for i in FRAMES:
		var p: String = "res://assets/button/press_%d.png" % i
		if ResourceLoader.exists(p):
			_frames.append(load(p))


func _frame_at(ph: float) -> int:
	var f: int = 0
	for i in SWITCH.size():
		if ph >= SWITCH[i]:
			f = i
	return f


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_since_press += delta
	var auto: bool = _since_press >= IDLE_AUTO
	var f: int = _cur()
	if auto and f == 1 and _last != 1:
		_rings.append(0.0)       # 底まで押した瞬間
	_last = f
	var alive: Array[float] = []
	for r in _rings:
		if r + delta < 0.35:
			alive.append(r + delta)
	_rings = alive
	queue_redraw()


func _draw() -> void:
	if _frames.is_empty():
		return
	var t: Texture2D = _frames[mini(USE[_cur()], _frames.size() - 1)]
	var w: float = size_px
	var h: float = w * t.get_height() / t.get_width()
	# 衝撃の輪（土台のまわりに広がる）
	for r in _rings:
		var k: float = r / 0.35
		var rad: float = w * (0.5 + 0.55 * k)
		draw_set_transform(Vector2(0, -h * 0.22), 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, rad, 0, TAU, 40, Color(1, 0.9, 0.3, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(t, Rect2(-w / 2.0, -h, w, h), false)
