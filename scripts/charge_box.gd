class_name ChargeBox
extends Node2D
## 起爆器の箱に電気が溜まっていく演出（ゲージは出さない）。
## 溜まるほど箱のまわりの青白い光が大きく明るくなり、ビリビリが増えていく。
## レベルが上がるたびにバチッと閃光。
## 原点は箱の中心。

const LAMPS := 4
const OUT := Color(0.06, 0.04, 0.05)
const OFF := Color(0.22, 0.25, 0.3)
const ON := Color(0.6, 0.9, 1.0)
const CORE := Color(0.95, 1.0, 1.0)
const AURA := Color(0.3, 0.6, 1.0)

var box_size: Vector2 = Vector2(128, 114)
var power: float = 0.0
var level: int = 0
var _flash: float = 0.0
static var _glow_tex: Texture2D


func _ready() -> void:
	if _glow_tex == null:
		# ぼかした青白い光の画像を1枚だけ作る（円を何重にも描くより軽い）
		var g := Gradient.new()
		g.set_color(0, Color(0.85, 0.95, 1.0, 0.9))
		g.add_point(0.35, Color(0.4, 0.7, 1.0, 0.55))
		g.set_color(g.get_point_count() - 1, Color(0.25, 0.5, 1.0, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_glow_tex = gt
var _t: float = 0.0


## レベルが上がった瞬間：バチッと光って、ランプが1つ増える
func level_up(lv: int) -> void:
	level = lv
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.5)
	if visible:
		queue_redraw()


func _draw() -> void:
	var hw: Vector2 = box_size / 2.0
	# 箱のまわりから漏れる光（溜まるほど大きく明るく、ゆらゆら）
	if power > 0.02:
		var wob: float = 1.0 + sin(_t * 18.0) * 0.05 * power
		var r: float = (hw.x * 0.7 + 60.0 + 110.0 * power) * wob
		draw_texture_rect(_glow_tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 1, 1, 0.45 + 0.55 * power))
		# 箱のまわりをはい回るビリビリ（溜まるほど本数が増えて長く）
		var n: int = int(power * 6.0)
		var segs := PackedVector2Array()
		for i in n:
			var a: float = randf() * TAU
			var p := Vector2(cos(a) * hw.x * 0.9, sin(a) * hw.y * 0.9)
			for s2 in 3 + int(power * 3.0):
				var q: Vector2 = p + Vector2(cos(a), sin(a)) * randf_range(10, 22) + Vector2(randf_range(-12, 12), randf_range(-12, 12))
				segs.append(p); segs.append(q)
				p = q
		if segs.size() > 0:
			draw_multiline(segs, Color(AURA, 0.45), 10.0)
			draw_multiline(segs, Color(OUT, 0.9), 6.0)
			draw_multiline(segs, ON, 3.5)
			draw_multiline(segs, CORE, 1.5)
	# レベルアップの閃光：輪と放射状のビリビリ
	if _flash > 0.0:
		var fr: float = hw.x + (1.0 - _flash) * 160.0
		draw_arc(Vector2.ZERO, fr, 0, TAU, 40, Color(CORE, _flash), 10.0 * _flash + 2.0)
		var fl: float = hw.x * 1.4
		draw_texture_rect(_glow_tex, Rect2(-fl, -fl, fl * 2.0, fl * 2.0), false, Color(1, 1, 1, _flash))
		var fsegs := PackedVector2Array()
		for i in 8:
			var a: float = TAU * i / 8.0 + _t * 3.0
			var p := Vector2.ZERO
			for s in 4:
				var q: Vector2 = p + Vector2(cos(a), sin(a)) * (22.0 + 10.0 * level) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
				fsegs.append(p); fsegs.append(q)
				p = q
		draw_multiline(fsegs, Color(AURA, 0.5 * _flash), 12.0)
		draw_multiline(fsegs, Color(CORE, _flash), 4.0)
