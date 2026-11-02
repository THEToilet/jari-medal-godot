class_name RubbleMound
extends Node2D
## 解体後に残るがれきの山。黒フチ付きのかたまりを山形に積んで描く（ほかの絵柄に合わせる）。
## 原点は山の足元の中心。
var width: float = 300.0
var height: float = 70.0
var base_col: Color = Color(0.62, 0.55, 0.5)
var seed_v: int = 1
var grow: float = 0.0:
	set(v):
		grow = v
		queue_redraw()

const OUT := Color(0.06, 0.04, 0.05)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h: float = height * grow
	# 山の土台（シルエット）
	var poly := PackedVector2Array([Vector2(-width / 2.0, 4)])
	for i in 9:
		var x: float = lerpf(-width / 2.0, width / 2.0, (i + 0.5) / 9.0)
		var k: float = 1.0 - absf(x) / (width / 2.0)
		poly.append(Vector2(x, -h * (0.35 + 0.65 * k) * rng.randf_range(0.8, 1.1)))
	poly.append(Vector2(width / 2.0, 4))
	var outl := PackedVector2Array()
	for p in poly:
		outl.append(p * 1.0 + Vector2(0, 0))
	draw_colored_polygon(poly, base_col.darkened(0.25))
	draw_polyline(poly, OUT, 7.0)
	# 上にのったかたまり（コンクリ片・鉄骨・木材）
	var n: int = int(width / 28.0)
	for i in n:
		var x: float = rng.randf_range(-width * 0.42, width * 0.42)
		var k: float = 1.0 - absf(x) / (width / 2.0)
		var y: float = -h * (0.25 + 0.6 * k) * rng.randf_range(0.6, 1.0)
		var r: float = rng.randf_range(10, 22)
		var kind: int = rng.randi_range(0, 3)
		var col: Color = base_col.lightened(rng.randf_range(-0.15, 0.2))
		if kind == 3:
			# 鉄骨（細長い棒）
			var a: float = rng.randf_range(-0.8, 0.8)
			var d := Vector2(cos(a), sin(a)) * r * 1.6
			draw_line(Vector2(x, y) - d, Vector2(x, y) + d, OUT, 9.0)
			draw_line(Vector2(x, y) - d, Vector2(x, y) + d, Color(0.55, 0.3, 0.2), 4.5)
			continue
		var pts := PackedVector2Array()
		var m: int = rng.randi_range(4, 6)
		var rot: float = rng.randf() * TAU
		for j in m:
			var ang: float = rot + TAU * j / m
			pts.append(Vector2(x, y) + Vector2(cos(ang), sin(ang) * 0.75) * r * rng.randf_range(0.7, 1.1))
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, OUT, 4.0)
