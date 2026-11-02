class_name SweatDrops
extends Node2D
## 頭のまわりに飛ぶ汗（マンガの汗マーク）。level 0 で出ない、1〜3 で数と速さが増える
var level: int = 0

const OUT := Color(0.06, 0.04, 0.05)
const BLUE := Color(0.55, 0.85, 1.0)
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	visible = level > 0
	if visible:
		queue_redraw()


func _draw() -> void:
	var n: int = clampi(level, 0, 3)
	# 頭の右上・左上にしずく。ぴょこぴょこ揺れる
	var spots := [Vector2(60, -20), Vector2(-50, -10), Vector2(80, 30)]
	for i in n:
		var ph: float = fmod(_t * (1.6 + 0.5 * level) + i * 0.37, 1.0)
		var p: Vector2 = spots[i] + Vector2(signf(spots[i].x) * ph * 12.0, ph * 18.0)
		var sz: float = 20.0 + i * 3.0
		_drop(p, sz, deg_to_rad(signf(spots[i].x) * 25.0), 1.0 - ph * 0.5)


func _drop(p: Vector2, sz: float, rot: float, a: float) -> void:
	draw_set_transform(p, rot, Vector2.ONE)
	var pts := PackedVector2Array([Vector2(0, -sz * 1.4)])
	for k in 13:
		var ang: float = PI * float(k) / 12.0
		pts.append(Vector2(cos(ang) * sz * 0.8 * (1 if k < 13 else 1), sin(ang) * sz * 0.8).rotated(0) + Vector2(0, 0))
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(q * 1.25)
	draw_colored_polygon(outline, Color(OUT, a))
	draw_colored_polygon(pts, Color(BLUE, a))
	draw_circle(Vector2(-sz * 0.25, -sz * 0.1), sz * 0.22, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
