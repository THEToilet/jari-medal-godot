class_name LinkWires
extends Node2D
## ビルの足元に並べたダイナマイト同士をつなぐ短い発破線（山なり）。
## 起爆の瞬間は power で青白く光る。
var anchors: PackedVector2Array = PackedVector2Array()   # つなぐ点（左から順）
var power: float = 0.0:
	set(v):
		power = v
		queue_redraw()

const OUT := Color(0.06, 0.04, 0.05)
const WIRE := Color(0.88, 0.15, 0.12)
const GLOW := Color(0.45, 0.8, 1.0)


func set_anchors(pts: PackedVector2Array) -> void:
	anchors = pts
	queue_redraw()


func _draw() -> void:
	for i in anchors.size() - 1:
		var a: Vector2 = anchors[i]
		var b: Vector2 = anchors[i + 1]
		var lift: float = 26.0 + a.distance_to(b) * 0.15
		var pts := PackedVector2Array()
		for k in 13:
			var u: float = float(k) / 12.0
			pts.append(a.lerp(b, u) + Vector2(0, -lift * 4.0 * u * (1.0 - u)))
		if power > 0.05:
			draw_polyline(pts, Color(GLOW, 0.35 * power), 26.0, true)
		draw_polyline(pts, OUT, 11.0, true)
		draw_polyline(pts, WIRE.lerp(GLOW, power * 0.8), 5.0, true)
	for p in anchors:
		draw_circle(p, 8.0, OUT)
		draw_circle(p, 4.5, Color(0.75, 0.77, 0.82))
