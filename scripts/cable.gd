class_name Cable
extends Node2D
## 発破線。赤と黒の2本をねじった太い線に、両端の金具。ほかの素材に合わせて太い黒フチ。
## 電気は雷切みたいな青白い光。パワーが溜まるほど線が青白く光り、
## 電気の粒が速く・大きく・多く流れ、稲妻がバチバチ枝分かれしてまとわりつく。
## cut を 0→1 にすると、ビル側の端からちぎれて縮んでいく（爆発で吹き飛ぶ）。

const WIRE := Color(0.88, 0.15, 0.12)        # 赤い線
const WIRE_B := Color(0.16, 0.16, 0.2)       # 黒い線
const WIRE_HI := Color(1.0, 0.6, 0.5)        # ハイライト
const OUTLINE := Color(0.06, 0.04, 0.05)
const GLOW := Color(0.45, 0.8, 1.0)          # 青白い光
const CORE := Color(0.92, 0.98, 1.0)         # 稲妻の芯（ほぼ白）
const AURA := Color(0.25, 0.55, 1.0)         # 稲妻の外側の青
const TWIST := 2.0 * PI * 10.0 / 46.0        # ねじれの細かさ（46pxで1周）
const TW_AMP := 6.0                          # ねじれの幅

var points: PackedVector2Array = PackedVector2Array()
var power: float = 0.0
var flow: float = 0.0
var cut: float = 0.0
## 0→1 で起爆器側から線が伸びていく（先端に金具が付いたまま進む）
var grow: float = 1.0
var _last_grow: float = -1.0
var _phase: float = 0.0
var _t: float = 0.0
var _last_cut: float = -1.0
var _dirty: bool = true


## curl > 0 のときは弧を描いて、最後は右から水平に b へ差し込む
func set_ends(a: Vector2, b: Vector2, curl: float = 0.0) -> void:
	var curve := Curve2D.new()
	if curl > 0.0:
		# 起爆器から左へゆるく弧を描いて、最後は右から水平に差し込む
		curve.add_point(a, Vector2.ZERO, Vector2(-(a.x - b.x) * 0.35, 30.0) * curl)
		curve.add_point(b, Vector2((a.x - b.x) * 0.55, 0.0) * curl, Vector2.ZERO)
	else:
		var mid := Vector2((a.x + b.x) / 2.0, maxf(a.y, b.y) + 60.0)
		curve.add_point(a, Vector2.ZERO, (mid - a) * 0.6)
		curve.add_point(b, (mid - b) * 0.6, Vector2.ZERO)
	curve.bake_interval = 10.0
	points = curve.get_baked_points()
	cut = 0.0
	_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_phase = fmod(_phase + delta * (0.25 + flow * 0.09), 1.0)
	# 電気が流れていない間は絵が変わらないので描き直さない（軽量化）
	if visible and (power > 0.01 or cut != _last_cut or grow != _last_grow or _dirty):
		_last_cut = cut
		_last_grow = grow
		_dirty = power > 0.01
		queue_redraw()


func _draw() -> void:
	var pts: PackedVector2Array = _visible_points()
	if pts.size() < 2:
		return
	# 光の外周（パワーに応じて太く明るく）
	if power > 0.05:
		draw_polyline(pts, Color(AURA, 0.15 + 0.25 * power), 44.0 + 30.0 * power, true)
		draw_polyline(pts, Color(GLOW, 0.25 + 0.35 * power), 28.0 + 14.0 * power, true)
	_draw_twisted(pts)
	var last: int = pts.size() - 1
	_draw_clamp(pts[0], pts[1] - pts[0])
	if cut <= 0.0:
		# 伸びている途中も先端は金具（差し込む前のプラグ）
		_draw_clamp(pts[last], pts[last - 1] - pts[last])
	else:
		_draw_frayed(pts[last], pts[last] - pts[last - 1])
	_draw_power(pts)


func _visible_points() -> PackedVector2Array:
	var keep: float = minf(1.0 - cut, grow)
	if points.size() < 2 or keep >= 1.0:
		return points
	var n: int = int(float(points.size()) * keep)
	return points.slice(0, maxi(n, 0))


func _at(pts: PackedVector2Array, t: float) -> Vector2:
	return pts[clampi(int(t * (pts.size() - 1)), 0, pts.size() - 1)]


## 赤と黒の2本をねじった発破線
func _draw_twisted(pts: PackedVector2Array) -> void:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var front := PackedFloat32Array()
	for i in pts.size():
		var tg: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-tg.y, tg.x)
		var ph: float = float(i) * TWIST
		a.append(pts[i] + n * sin(ph) * TW_AMP)
		b.append(pts[i] - n * sin(ph) * TW_AMP)
		front.append(cos(ph))
	var hot: float = power * 0.8
	var col_a: Color = WIRE.lerp(GLOW, hot)
	var col_b: Color = WIRE_B.lerp(GLOW.darkened(0.35), hot)
	# 2本まとめた太い黒フチ
	draw_polyline(pts, OUTLINE, TW_AMP * 2.0 + 20.0, true)
	draw_polyline(b, col_b, 11.0, true)
	draw_polyline(a, col_a, 11.0, true)
	# 手前に来ている側を区間ごとに描き直して「ねじれ」を出す
	var i: int = 0
	while i < pts.size() - 1:
		var on_a: bool = front[i] >= 0.0
		var src: PackedVector2Array = a if on_a else b
		var seg := PackedVector2Array()
		while i < pts.size() - 1 and (front[i] >= 0.0) == on_a:
			seg.append(src[i])
			i += 1
		seg.append(src[i])
		if seg.size() < 2:
			continue
		draw_polyline(seg, OUTLINE, 17.0, true)
		draw_polyline(seg, col_a if on_a else col_b, 11.0, true)
		var hi := PackedVector2Array()
		for q in seg:
			hi.append(q + Vector2(-1.5, -2.5))
		var hc: Color = WIRE_HI if on_a else Color(0.5, 0.5, 0.58)
		draw_polyline(hi, hc.lerp(Color.WHITE, power), 3.0, true)


## 線の端の金具
func _draw_clamp(p: Vector2, dir: Vector2) -> void:
	draw_set_transform(p, dir.angle(), Vector2.ONE)
	draw_rect(Rect2(-8, -17, 38, 34), OUTLINE)
	draw_rect(Rect2(-2, -11, 26, 22), Color(0.7, 0.72, 0.77))
	draw_rect(Rect2(-2, -11, 26, 7), Color(0.93, 0.95, 0.98))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## ちぎれた先端：焦げて火花がチリチリ
func _draw_frayed(p: Vector2, dir: Vector2) -> void:
	draw_circle(p, 15.0, OUTLINE)
	draw_circle(p, 10.0, Color(0.28, 0.22, 0.2))
	for k in 4:
		var d: Vector2 = dir.normalized().rotated(randf_range(-1.1, 1.1)) * randf_range(12, 30)
		draw_line(p, p + d, OUTLINE, 6.0)
		draw_line(p, p + d, Color(1, 0.85, 0.35), 3.0)


func _draw_power(pts: PackedVector2Array) -> void:
	if power <= 0.01:
		return
	# 電気の粒
	var n: int = 3 + int(power * 10.0)
	for i in n:
		var p: Vector2 = _at(pts, fmod(_phase + float(i) / n, 1.0))
		var r: float = 7.0 + power * 9.0
		draw_circle(p, r * 2.2, Color(AURA, 0.25))
		draw_circle(p, r + 3.0, OUTLINE)
		draw_circle(p, r, GLOW)
		draw_circle(p, r * 0.6, CORE)
		if power > 0.5:
			_star(p, r * 2.2, Color(CORE, 0.95))
	# まとわりつく稲妻（枝分かれ）
	if power > 0.35:
		var bolts: int = 1 + int((power - 0.35) * 14.0)
		var amp: float = 14.0 + 26.0 * power
		for b in bolts:
			var t0: float = randf_range(0.02, 0.85)
			var bolt := PackedVector2Array()
			for s in 8:
				var p: Vector2 = _at(pts, t0 + s * 0.022)
				bolt.append(p + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)))
			_bolt(bolt, 1.0)
			var br := PackedVector2Array([bolt[randi_range(2, 5)]])
			var dir: Vector2 = Vector2.UP.rotated(randf_range(-2.0, 2.0))
			for s in 3:
				br.append(br[br.size() - 1] + dir * 22.0 + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
			_bolt(br, 0.6)
	# 先端でスパーク
	if power > 0.75 and cut <= 0.0:
		var end: Vector2 = pts[pts.size() - 1]
		for k in 4:
			var dir: Vector2 = Vector2.UP.rotated(randf_range(-1.4, 1.4))
			var bolt := PackedVector2Array()
			var p2: Vector2 = end
			for s in 5:
				bolt.append(p2)
				p2 += dir * 20.0 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
			_bolt(bolt, 0.9)


## 雷切風の稲妻：青いオーラ → 黒フチ → 水色 → 白い芯
func _bolt(pts: PackedVector2Array, w: float) -> void:
	draw_polyline(pts, Color(AURA, 0.35), 22.0 * w)
	draw_polyline(pts, OUTLINE, 10.0 * w)
	draw_polyline(pts, GLOW, 6.0 * w)
	draw_polyline(pts, CORE, 2.5 * w)


func _star(c: Vector2, size: float, col: Color) -> void:
	var a: float = _t * 6.0
	for k in 2:
		var d := Vector2(cos(a + k * PI / 2.0), sin(a + k * PI / 2.0)) * size
		draw_line(c - d, c + d, col, 2.5)
