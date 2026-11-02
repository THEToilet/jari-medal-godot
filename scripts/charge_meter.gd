class_name ChargeMeter
extends Node2D
## 起爆器の横に立てる「電気の溜まり」メーター。太い黒フチ＋ベタ塗り。
## 原点は足元の中心。power 0〜1。

const W := 58.0
const H := 250.0
const OUTLINE := Color(0.08, 0.05, 0.05)

var power: float = 0.0
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-W / 2.0, -H, W, H)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.2, 0.18, 0.22)
	frame.border_color = OUTLINE
	frame.set_border_width_all(7)
	frame.set_corner_radius_all(16)
	draw_style_box(frame, r)
	# 中身（下から溜まる）
	var inner := r.grow(-12)
	var h: float = inner.size.y * clampf(power, 0.0, 1.0)
	if h > 1.0:
		var col: Color = Color(0.95, 0.25, 0.15).lerp(Color(1, 0.9, 0.2), power)
		if power > 0.9 and fmod(_t, 0.2) < 0.1:
			col = Color(1, 1, 0.85)
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(8)
		draw_style_box(fill, Rect2(inner.position.x, inner.end.y - h, inner.size.x, h))
		draw_rect(Rect2(inner.position.x + 5, inner.end.y - h + 4, 6, maxf(h - 8, 0)), Color(1, 1, 1, 0.45))
	# 目盛り
	for i in range(1, 5):
		var y: float = inner.end.y - inner.size.y * i / 5.0
		draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + 14, y), OUTLINE, 3.0)
	# てっぺんの稲妻マーク
	var top := Vector2(0, -H - 34)
	var bolt := PackedVector2Array([top + Vector2(6, -26), top + Vector2(-14, 4), top + Vector2(0, 4),
		top + Vector2(-6, 28), top + Vector2(14, -4), top + Vector2(0, -4)])
	var outline_bolt := PackedVector2Array(bolt)
	outline_bolt.append(bolt[0])
	draw_colored_polygon(bolt, Color(1, 0.9, 0.2).lerp(Color.WHITE, power * 0.5))
	draw_polyline(outline_bolt, OUTLINE, 5.0)
