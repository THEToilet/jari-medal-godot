class_name LinkWires
extends Node2D
## ビルの足元に並べたダイナマイト同士をつなぐ短い発破線（山なり）。
## 起爆の瞬間は power で青白く光る。
var anchors: PackedVector2Array = PackedVector2Array()   # つなぐ点（左から順）
## 0→1 で左から順に線がつながっていく
var reveal: float = 1.0:
	set(v):
		reveal = v
		queue_redraw()
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
	# 全部の弧の線分を集めて、色ごとに1回ずつ描く（軽量化）
	var segs := PackedVector2Array()
	var segs_n: int = anchors.size() - 1
	for j in segs_n:
		var i: int = segs_n - 1 - j
		var part: float = clampf(reveal * segs_n - j, 0.0, 1.0)
		if part <= 0.0:
			continue
		var a: Vector2 = anchors[i + 1]
		var b: Vector2 = anchors[i]
		var lift: float = 26.0 + a.distance_to(b) * 0.15
		var prev: Vector2 = a
		for k in range(1, 13):
			var u: float = float(k) / 12.0 * part
			var q: Vector2 = a.lerp(b, u) + Vector2(0, -lift * 4.0 * u * (1.0 - u))
			segs.append(prev); segs.append(q)
			prev = q
	if segs.size() > 0:
		if power > 0.05:
			draw_multiline(segs, Color(GLOW, 0.35 * power), 26.0)
		draw_multiline(segs, OUT, 11.0)
		draw_multiline(segs, WIRE.lerp(GLOW, power * 0.8), 5.0)
	for idx in anchors.size():
		var shown: bool = idx == segs_n or reveal * segs_n >= float(segs_n - idx)
		if not shown:
			continue
		var p: Vector2 = anchors[idx]
		draw_circle(p, 8.0, OUT)
		draw_circle(p, 4.5, Color(0.75, 0.77, 0.82))
