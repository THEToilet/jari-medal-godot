class_name ButtonHint
extends Node2D
## 「ボタンを押せ」の合図アニメ。assets/button/press_0〜3.png のコマ送りで
## ボタンがペコペコ押し込まれ、底まで押したコマで衝撃の輪が広がる。
## 連打中も起爆待ちも同じアニメで、間隔と大きさだけ変える。原点は土台の下端中央。

const FRAMES := 4
## 1周の中で各コマに切り替わるタイミング（0〜1）。構え→半分→底→戻り
const SWITCH := [0.0, 0.35, 0.5, 0.72]

var tex: Texture2D               # 互換用（未使用）
var interval: float = 0.14       # 1回押す間隔（秒）
var size_px: float = 170.0       # ボタンの表示幅
var _frames: Array[Texture2D] = []
var _t: float = 0.0
var _last: int = 0
var _rings: Array[float] = []


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
	var f: int = _frame_at(fmod(_t, interval) / interval)
	if f == 2 and _last != 2:
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
	var t: Texture2D = _frames[_frame_at(fmod(_t, interval) / interval)]
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
