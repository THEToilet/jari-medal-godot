class_name Cable
extends Node2D
## 発破線。赤と黒の2本をねじった太い線に、両端の金具。ほかの素材に合わせて太い黒フチ。
## 電気は雷切みたいな青白い光。パワーが溜まるほど線が青白く光り、
## 電気の粒が速く・大きく・多く流れ、稲妻がバチバチ枝分かれしてまとわりつく。
## cut を 0→1 にすると、ビル側の端からちぎれて縮んでいく（爆発で吹き飛ぶ）。
##
## 軽量化のため3層に分けている：
##   自分（いちばん奥）… 電気の光の外周（パワーがあるときだけ）
##   _wire … ねじり線と金具。形が変わったときだけ描き直す
##   _fx   … 電気の粒・稲妻。毎フレーム描くが、まとめ描き（multiline・同じ画像）で命令数を抑える

const WIRE := Color(0.88, 0.15, 0.12)        # 赤い線
const WIRE_B := Color(0.16, 0.16, 0.2)       # 黒い線
const WIRE_HI := Color(1.0, 0.6, 0.5)        # ハイライト
const OUTLINE := Color(0.06, 0.04, 0.05)
const GLOW := Color(0.45, 0.8, 1.0)          # 青白い光
const CORE := Color(0.92, 0.98, 1.0)         # 稲妻の芯（ほぼ白）
const AURA := Color(0.25, 0.55, 1.0)         # 稲妻の外側の青
const TWIST := 2.0 * PI * 10.0 / 46.0        # ねじれの細かさ（46pxで1周）
const TW_AMP := 6.0                          # ねじれの幅
const MAX_BOLTS := 6                         # 稲妻の本数の上限

var points: PackedVector2Array = PackedVector2Array()
var power: float = 0.0
var flow: float = 0.0
var cut: float = 0.0
## 0→1 で起爆器側から線が伸びていく（先端に金具が付いたまま進む）
var grow: float = 1.0

var _a := PackedVector2Array()       # ねじり線の赤
var _b := PackedVector2Array()       # ねじり線の黒
var _front := PackedFloat32Array()   # 赤が手前か（+）黒が手前か（-）
var _phase: float = 0.0
var _t: float = 0.0
var _shown: int = -1                 # 今描いてある点の数
var _wire: WireLayer
var _fx: FxLayer

static var _dot: Texture2D


func _ready() -> void:
	_wire = WireLayer.new()
	_wire.cable = self
	add_child(_wire)
	_fx = FxLayer.new()
	_fx.cable = self
	add_child(_fx)
	if _dot == null:
		_dot = _make_dot()


## curl > 0 のときは弧を描いて、最後は右から水平に b へ差し込む
func set_ends(a: Vector2, b: Vector2, curl: float = 0.0) -> void:
	var curve := Curve2D.new()
	if curl > 0.0:
		curve.add_point(a, Vector2.ZERO, Vector2(-(a.x - b.x) * 0.35, 30.0) * curl)
		curve.add_point(b, Vector2((a.x - b.x) * 0.55, 0.0) * curl, Vector2.ZERO)
	else:
		var mid := Vector2((a.x + b.x) / 2.0, maxf(a.y, b.y) + 60.0)
		curve.add_point(a, Vector2.ZERO, (mid - a) * 0.6)
		curve.add_point(b, (mid - b) * 0.6, Vector2.ZERO)
	curve.bake_interval = 10.0
	points = curve.get_baked_points()
	cut = 0.0
	# ねじり線の形はここで1回だけ計算しておく
	_a.clear(); _b.clear(); _front.clear()
	for i in points.size():
		var tg: Vector2 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-tg.y, tg.x)
		var ph: float = float(i) * TWIST
		_a.append(points[i] + n * sin(ph) * TW_AMP)
		_b.append(points[i] - n * sin(ph) * TW_AMP)
		_front.append(cos(ph))
	_shown = -1


func _process(delta: float) -> void:
	_t += delta
	_phase = fmod(_phase + delta * (0.25 + flow * 0.09), 1.0)
	if not visible or _wire == null:
		return
	var k: int = _visible_count()
	if k != _shown:
		_shown = k
		_wire.queue_redraw()
	if power > 0.01 or _fx.had_power:
		queue_redraw()
		_fx.queue_redraw()


func _visible_count() -> int:
	var keep: float = minf(1.0 - cut, grow)
	if keep >= 1.0:
		return points.size()
	return clampi(int(float(points.size()) * keep), 0, points.size())


func _visible_points() -> PackedVector2Array:
	return points.slice(0, _visible_count())


func _at(pts: PackedVector2Array, t: float) -> Vector2:
	return pts[clampi(int(t * (pts.size() - 1)), 0, pts.size() - 1)]


## 自分：光の外周（線の下に敷く）
func _draw() -> void:
	if power <= 0.05:
		return
	var pts: PackedVector2Array = _visible_points()
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(AURA, 0.15 + 0.25 * power), 44.0 + 30.0 * power)
	draw_polyline(pts, Color(GLOW, 0.25 + 0.35 * power), 28.0 + 14.0 * power)


## 電気の粒の画像（黒フチ＋青白＋白い芯）をコードで1枚作る
static func _make_dot() -> Texture2D:
	var sz: int = 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz / 2.0, sz / 2.0)
	for y in sz:
		for x in sz:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c) / (sz / 2.0)
			var col := Color(0, 0, 0, 0)
			if d < 0.3:
				col = CORE
			elif d < 0.5:
				col = GLOW
			elif d < 0.62:
				col = OUTLINE
			elif d < 1.0:
				col = Color(AURA, 0.3 * (1.0 - (d - 0.62) / 0.38))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## ねじり線と金具（形が変わったときだけ描き直す）
class WireLayer extends Node2D:
	var cable: Cable

	func _draw() -> void:
		var k: int = cable._visible_count()
		if k < 2:
			return
		var pts: PackedVector2Array = cable.points.slice(0, k)
		var a: PackedVector2Array = cable._a.slice(0, k)
		var b: PackedVector2Array = cable._b.slice(0, k)
		draw_polyline(pts, OUTLINE, TW_AMP * 2.0 + 20.0)
		draw_polyline(b, WIRE_B, 11.0)
		draw_polyline(a, WIRE, 11.0)
		# 黒が手前に来ている区間だけ上から描き直す（ねじれ）。区間はまとめて1回で描く
		var segb := PackedVector2Array()
		var hia := PackedVector2Array()
		var hib := PackedVector2Array()
		var off := Vector2(-1.5, -2.5)
		for i in k - 1:
			if cable._front[i] < 0.0:
				segb.append(b[i]); segb.append(b[i + 1])
				hib.append(b[i] + off); hib.append(b[i + 1] + off)
			else:
				hia.append(a[i] + off); hia.append(a[i + 1] + off)
		if segb.size() > 0:
			draw_multiline(segb, OUTLINE, 17.0)
			draw_multiline(segb, WIRE_B, 11.0)
		if hia.size() > 0:
			draw_multiline(hia, WIRE_HI, 3.0)
		if hib.size() > 0:
			draw_multiline(hib, Color(0.5, 0.5, 0.58), 3.0)
		var last: int = k - 1
		_clamp(pts[0], pts[1] - pts[0])
		if cable.cut <= 0.0:
			_clamp(pts[last], pts[last - 1] - pts[last])
		else:
			draw_circle(pts[last], 15.0, OUTLINE)
			draw_circle(pts[last], 10.0, Color(0.28, 0.22, 0.2))

	func _clamp(p: Vector2, dir: Vector2) -> void:
		draw_set_transform(p, dir.angle(), Vector2.ONE)
		draw_rect(Rect2(-8, -17, 38, 34), OUTLINE)
		draw_rect(Rect2(-2, -11, 26, 22), Color(0.7, 0.72, 0.77))
		draw_rect(Rect2(-2, -11, 26, 7), Color(0.93, 0.95, 0.98))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 電気の粒・稲妻（まとめ描き）
class FxLayer extends Node2D:
	var cable: Cable
	var had_power: bool = false

	func _draw() -> void:
		var p: float = cable.power
		had_power = p > 0.01
		if not had_power:
			return
		var pts: PackedVector2Array = cable._visible_points()
		if pts.size() < 2:
			return
		# 線そのものが青白く光る（上から半透明で重ねる）
		draw_polyline(pts, Color(GLOW, 0.55 * p), 12.0)
		# 電気の粒：同じ画像なのでまとめて1回で描かれる
		var n: int = 3 + int(p * 10.0)
		var r: float = (7.0 + p * 9.0) * 2.2
		for i in n:
			var c: Vector2 = cable._at(pts, fmod(cable._phase + float(i) / n, 1.0))
			draw_texture_rect(Cable._dot, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
		# 稲妻：全部の線分を集めて、色ごとに1回ずつ描く
		var bolts_l: Array[PackedVector2Array] = []   # 本体の稲妻（つなぎ目がきれいな折れ線で描く）
		var thin := PackedVector2Array()
		if p > 0.35:
			var bolts: int = mini(1 + int((p - 0.35) * 10.0), MAX_BOLTS)
			var amp: float = 14.0 + 26.0 * p
			for k in bolts:
				var t0: float = randf_range(0.02, 0.85)
				var line := PackedVector2Array()
				for s in 7:
					line.append(cable._at(pts, t0 + s * 0.025) + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)))
				bolts_l.append(line)
				var mid: Vector2 = line[3]
				var dir: Vector2 = Vector2.UP.rotated(randf_range(-2.0, 2.0))
				for s in 2:
					var q2: Vector2 = mid + dir * 22.0 + Vector2(randf_range(-12, 12), randf_range(-12, 12))
					thin.append(mid); thin.append(q2)
					mid = q2
		if p > 0.75 and cable.cut <= 0.0:
			var end: Vector2 = pts[pts.size() - 1]
			for k in 3:
				var dir: Vector2 = Vector2.UP.rotated(randf_range(-1.4, 1.4))
				var q: Vector2 = end
				for s in 3:
					var q2: Vector2 = q + dir * 20.0 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
					thin.append(q); thin.append(q2)
					q = q2
		for line in bolts_l:
			draw_polyline(line, Color(AURA, 0.35), 22.0)
		for line in bolts_l:
			draw_polyline(line, OUTLINE, 10.0)
		for line in bolts_l:
			draw_polyline(line, GLOW, 6.0)
		for line in bolts_l:
			draw_polyline(line, CORE, 2.5)
		if thin.size() > 0:
			draw_multiline(thin, OUTLINE, 6.0)
			draw_multiline(thin, GLOW, 3.5)
			draw_multiline(thin, CORE, 1.5)
