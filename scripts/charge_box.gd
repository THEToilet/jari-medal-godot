class_name ChargeBox
extends Node2D
## 起爆器の箱に電気が溜まっていく表示。箱の前面にランプが4つ並び、
## レベルが上がるたびに1つずつ点いて、箱のまわりから青白い光が漏れ出す。
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
		var wob: float = 1.0 + sin(_t * 18.0) * 0.04 * power
		for k in 3:
			var r: float = (hw.x + 20.0 + 40.0 * power + k * 18.0) * wob
			draw_circle(Vector2.ZERO, r, Color(AURA, (0.10 + 0.14 * power) / (k + 1)))
	# レベルアップの閃光：輪と放射状のビリビリ
	if _flash > 0.0:
		var fr: float = hw.x + (1.0 - _flash) * 160.0
		draw_arc(Vector2.ZERO, fr, 0, TAU, 40, Color(CORE, _flash), 10.0 * _flash + 2.0)
		draw_circle(Vector2.ZERO, hw.x * 1.2, Color(CORE, 0.5 * _flash))
		for i in 8:
			var a: float = TAU * i / 8.0 + _t * 3.0
			var p := Vector2.ZERO
			var bolt := PackedVector2Array([p])
			for s in 4:
				p += Vector2(cos(a), sin(a)) * (22.0 + 10.0 * level) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
				bolt.append(p)
			draw_polyline(bolt, Color(AURA, 0.5 * _flash), 12.0)
			draw_polyline(bolt, Color(CORE, _flash), 4.0)
	# ランプの台
	var lw: float = 24.0
	var gap: float = 6.0
	var total: float = LAMPS * lw + (LAMPS - 1) * gap
	var panel := Rect2(-total / 2.0 - 10.0, -18.0, total + 20.0, 36.0)
	draw_rect(panel.grow(4), OUT)
	draw_rect(panel, Color(0.12, 0.13, 0.16))
	for i in LAMPS:
		var c := Vector2(-total / 2.0 + lw / 2.0 + i * (lw + gap), 0)
		var lit: bool = i < level
		draw_circle(c, lw / 2.0 + 2.0, OUT)
		if lit:
			var blink: float = 0.85 + 0.15 * sin(_t * 20.0 + i)
			draw_circle(c, lw / 2.0 + 8.0, Color(AURA, 0.35 * blink))
			draw_circle(c, lw / 2.0, ON * blink)
			draw_circle(c + Vector2(-3, -3), lw * 0.18, CORE)
		else:
			draw_circle(c, lw / 2.0, OFF)
