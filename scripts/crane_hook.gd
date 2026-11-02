class_name CraneHook
extends Node2D
## クレーンのフック（仮：コードで描画）。画面の上からワイヤーで吊り下がり、
## チェーンでダイナマイト箱を吊る。assets/crane_hook.png があればそちらを使う。
## 原点はフックの下端（チェーンの付け根）。

var chain_w: float = 90.0     # チェーンを広げる幅（箱の上面の幅）
var chain_h: float = 46.0     # 付け根から箱の上面までの高さ
var attached: bool = true
var crate: Node2D               # 吊っている箱（消えたらチェーンも外す）
var _tex: Texture2D

const OUT := Color(0.06, 0.04, 0.05)
const YEL := Color(1.0, 0.78, 0.1)
const STEEL := Color(0.62, 0.64, 0.7)


func _ready() -> void:
	if ResourceLoader.exists("res://assets/crane_hook.png"):
		_tex = load("res://assets/crane_hook.png")


func _process(_d: float) -> void:
	if attached and crate != null and not is_instance_valid(crate):
		attached = false
	queue_redraw()


func _draw() -> void:
	var top: float = -global_position.y - 60.0   # 画面の上の外まで
	if _tex:
		var h: float = 190.0
		var w: float = h * _tex.get_width() / _tex.get_height()
		draw_line(Vector2(0, top), Vector2(0, -h * 0.9), OUT, 9.0)
		draw_line(Vector2(0, top), Vector2(0, -h * 0.9), Color(0.25, 0.25, 0.3), 4.0)
		draw_texture_rect(_tex, Rect2(-w / 2.0, -h, w, h), false)
	else:
		# ワイヤー
		draw_line(Vector2(0, top), Vector2(0, -120), OUT, 10.0)
		draw_line(Vector2(0, top), Vector2(0, -120), Color(0.3, 0.3, 0.36), 4.0)
		# フックブロック（黄色＋しましま）
		var blk := Rect2(-38, -132, 76, 66)
		draw_rect(blk.grow(6), OUT)
		draw_rect(blk, YEL)
		for k in 3:
			var x0: float = -38.0 + k * 30.0
			draw_colored_polygon(PackedVector2Array([Vector2(x0, -80), Vector2(x0 + 14, -80), Vector2(x0 + 28, -66), Vector2(x0 + 14, -66)]), OUT)
		draw_circle(Vector2(-22, -116), 6, OUT)
		draw_circle(Vector2(22, -116), 6, OUT)
		draw_circle(Vector2(-22, -116), 3.5, STEEL)
		draw_circle(Vector2(22, -116), 3.5, STEEL)
		# フック（J字）
		draw_line(Vector2(0, -66), Vector2(0, -34), OUT, 18.0)
		draw_line(Vector2(0, -66), Vector2(0, -34), STEEL, 9.0)
		draw_arc(Vector2(-10, -22), 14, -0.2, PI + 0.4, 16, OUT, 18.0)
		draw_arc(Vector2(-10, -22), 14, -0.2, PI + 0.4, 16, STEEL, 9.0)
	# チェーン（箱の上面の両端へ）
	if attached:
		for sx in [-1.0, 1.0]:
			var a := Vector2(0, -8)
			var b := Vector2(sx * chain_w * 0.5, chain_h)
			var n: int = 6
			for i in n:
				var p: Vector2 = a.lerp(b, (i + 0.5) / n)
				draw_circle(p, 7.0, OUT)
				draw_circle(p, 4.0, STEEL)
