class_name FuseTimer
extends Node2D
## 残り時間の表示：燃えていく導火線＋ダイナマイト。
## 左端に縦に立てたダイナマイト（線はその右側の真ん中から伸びる）へ向かって、右から火花が導火線を焼きながら進む。
## 残り4割を切ると導火線が赤く点滅し、ダイナマイトが震える。

const OUT := Color(0.08, 0.05, 0.05)
const LEN := 620.0
const DYN_H := 130.0        # ダイナマイトの表示高さ

var ratio: float = 1.0      # 残り時間の割合 1→0
var dyn_tex: Texture2D
var _t: float = 0.0
var _sparks: Array[Dictionary] = []


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var tip := Vector2(LEN * ratio, sin(LEN * ratio * 0.045) * 6.0)
	for i in 3:
		_sparks.append({"p": tip, "v": Vector2(randf_range(-60, 160), randf_range(-220, 60)), "life": randf_range(0.2, 0.45)})
	var alive: Array[Dictionary] = []
	for s in _sparks:
		s.v.y += 500.0 * delta
		s.p += s.v * delta
		s.life -= delta
		if s.life > 0.0:
			alive.append(s)
	_sparks = alive
	queue_redraw()


func _draw() -> void:
	var hurry: bool = ratio < 0.4
	var shake := Vector2(randf_range(-3, 3), randf_range(-3, 3)) if hurry else Vector2.ZERO
	# 燃え残った導火線（波打つロープ）
	var pts := PackedVector2Array()
	var n: int = 40
	for i in n + 1:
		var x: float = LEN * ratio * i / n
		pts.append(Vector2(x, sin(x * 0.045) * 6.0))
	if ratio > 0.002:
		draw_polyline(pts, OUT, 16.0, true)
		var col: Color = Color(0.85, 0.7, 0.45)
		if hurry and fmod(_t, 0.3) < 0.15:
			col = Color(1.0, 0.45, 0.3)
		draw_polyline(pts, col, 9.0, true)
		for i in range(0, n, 2):
			draw_line(pts[i] + Vector2(0, -4), pts[i] + Vector2(6, 4), Color(0.55, 0.4, 0.25), 2.0)
	# 焼けた跡（灰色の点線）
	var x0: float = LEN * ratio
	var x: float = x0 + 14.0
	while x < LEN:
		draw_circle(Vector2(x, sin(x * 0.045) * 6.0), 3.0, Color(0.3, 0.28, 0.28, 0.6))
		x += 18.0
	# 左端のダイナマイト（縦に立てる。導火線の先が原点に来る）
	if dyn_tex:
		var sz := Vector2(DYN_H * dyn_tex.get_width() / dyn_tex.get_height(), DYN_H)
		# 線の左端がダイナマイトの右側の真ん中に来るように置く（つなげない）
		var off := Vector2(-sz.x * 0.9, -sz.y * 0.5)
		draw_texture_rect(dyn_tex, Rect2(off + shake, sz), false)
	# 火花
	var tip := Vector2(x0, sin(x0 * 0.045) * 6.0)
	var r: float = 14.0 + 4.0 * sin(_t * 30.0)
	draw_circle(tip, r + 6.0, Color(1, 0.45, 0.1, 0.55))
	draw_circle(tip, r, Color(1, 0.8, 0.2))
	draw_circle(tip, r * 0.5, Color.WHITE)
	for s in _sparks:
		draw_circle(s.p, 3.0 * s.life / 0.45 + 1.0, Color(1, 0.9, 0.4))
