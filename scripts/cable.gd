class_name Cable
extends Node2D
## 発電機からビルへの電線。ほかの素材に合わせて太い黒フチ＋ベタ塗り。
## パワーが溜まるほど、電線が黄色く光り、電気の粒が速く・大きく・多く流れ、
## 満タン近くでは電線全体にビリビリの稲妻がまとわりつく。

const WIRE := Color(0.86, 0.16, 0.12)        # 赤い被覆
const WIRE_HI := Color(1.0, 0.55, 0.45)      # ハイライト
const OUTLINE := Color(0.08, 0.05, 0.05)
const GLOW := Color(1.0, 0.92, 0.25)

var points: PackedVector2Array = PackedVector2Array()
var power: float = 0.0
var flow: float = 0.0
var _phase: float = 0.0
var _t: float = 0.0


func set_ends(a: Vector2, b: Vector2) -> void:
	var curve := Curve2D.new()
	var mid := Vector2((a.x + b.x) / 2.0, maxf(a.y, b.y) + 60.0)
	curve.add_point(a, Vector2.ZERO, (mid - a) * 0.6)
	curve.add_point(b, (mid - b) * 0.6, Vector2.ZERO)
	curve.bake_interval = 10.0
	points = curve.get_baked_points()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_phase = fmod(_phase + delta * (0.25 + flow * 0.09), 1.0)
	queue_redraw()


func _at(t: float) -> Vector2:
	return points[clampi(int(t * (points.size() - 1)), 0, points.size() - 1)]


func _draw() -> void:
	if points.size() < 2:
		return
	# 光の外周（パワーに応じて太く明るく）
	if power > 0.05:
		var g := GLOW
		g.a = 0.25 + 0.35 * power
		draw_polyline(points, g, 26.0 + 22.0 * power, true)
	# 黒フチ → 被覆 → ハイライト
	draw_polyline(points, OUTLINE, 20.0, true)
	draw_polyline(points, WIRE.lerp(GLOW, power * 0.75), 12.0, true)
	var hi := PackedVector2Array()
	for p in points:
		hi.append(p + Vector2(-2, -3))
	draw_polyline(hi, WIRE_HI.lerp(Color.WHITE, power), 3.0, true)

	if power <= 0.01:
		return
	# 電気の粒（黒フチ付きの黄色い玉＋キラッ）
	var n: int = 3 + int(power * 10.0)
	for i in n:
		var t: float = fmod(_phase + float(i) / n, 1.0)
		var p: Vector2 = _at(t)
		var r: float = 7.0 + power * 9.0
		draw_circle(p, r + 3.0, OUTLINE)
		draw_circle(p, r, GLOW)
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color.WHITE)
		if power > 0.5:
			_star(p, r * 2.0, Color(1, 1, 0.8, 0.9))
	# 満タン近く：電線にまとわりつく稲妻
	if power > 0.6:
		var bolts: int = 1 + int((power - 0.6) * 10.0)
		for b in bolts:
			var t0: float = randf_range(0.05, 0.8)
			var bolt := PackedVector2Array()
			for s in 7:
				var p: Vector2 = _at(t0 + s * 0.025)
				bolt.append(p + Vector2(randf_range(-22, 22), randf_range(-22, 22)))
			draw_polyline(bolt, OUTLINE, 9.0)
			draw_polyline(bolt, Color(1, 1, 0.5), 4.0)
	# ビル側の端でスパーク
	if power > 0.75:
		var end: Vector2 = points[points.size() - 1]
		for k in 4:
			var dir: Vector2 = Vector2.UP.rotated(randf_range(-1.4, 1.4))
			var bolt := PackedVector2Array()
			var p2: Vector2 = end
			for s in 5:
				bolt.append(p2)
				p2 += dir * 20.0 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
			draw_polyline(bolt, OUTLINE, 8.0)
			draw_polyline(bolt, Color(1, 0.95, 0.3), 4.0)


func _star(c: Vector2, size: float, col: Color) -> void:
	var a: float = _t * 6.0
	for k in 2:
		var d := Vector2(cos(a + k * PI / 2.0), sin(a + k * PI / 2.0)) * size
		draw_line(c - d, c + d, col, 2.5)
