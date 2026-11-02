class_name InsertSign
extends Node2D
## 待機中に大きく出す「メダルをいれてね」看板。
## オレンジの板＋赤枠に、工事現場っぽい黄黒のシマシマと鋲を足したアレンジ。
## 画像があれば優先して使う:
##   assets/insert_sign.png       … 文字入りの看板（文字はコードで描かない）
##   assets/insert_sign_board.png … 文字なしの板（文字はコードで上に載せる）

const W := 780.0
const H := 430.0
const IMG_W := 760.0    # 文字入り画像の表示幅
const BODY := Color(1.0, 0.66, 0.12)
const BODY_DARK := Color(0.85, 0.48, 0.05)
const FRAME := Color(0.88, 0.12, 0.08)
const TEXT := Color(0.25, 0.88, 1.0)
const TEXT_OUTLINE := Color(0.04, 0.16, 0.62)

var _lines: Array[Label] = []
var _t: float = 0.0
var _img: Texture2D
var _img_has_text: bool = false


func setup(font: Font) -> void:
	if ResourceLoader.exists("res://assets/insert_sign.png"):
		_img = load("res://assets/insert_sign.png")
		_img_has_text = true
	elif ResourceLoader.exists("res://assets/insert_sign_board.png"):
		_img = load("res://assets/insert_sign_board.png")
	if _img_has_text:
		return
	var texts := ["メダルを", "いれてね"]
	for i in texts.size():
		var l := Label.new()
		l.text = texts[i]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 150)
		l.add_theme_color_override("font_color", TEXT)
		l.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
		l.add_theme_constant_override("outline_size", 30)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("shadow_offset_x", 8)
		l.add_theme_constant_override("shadow_offset_y", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(W, 0)
		l.position = Vector2(-W / 2.0, -H / 2.0 + 58 + i * 160)
		l.pivot_offset = Vector2(W / 2.0, 90)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_lines.append(l)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# 大小だけ（左右の揺れなし）
	var s: float = 1.0 + sin(_t * 4.4) * 0.04
	scale = Vector2(s, s)
	# 2行が交互にピョコピョコ
	for i in _lines.size():
		var hop: float = maxf(0.0, sin(_t * 6.0 - i * PI))
		_lines[i].scale = Vector2(1.0 + hop * 0.06, 1.0 + hop * 0.06)


func _draw() -> void:
	if _img:
		# 幅 W に合わせて表示（縦横比はそのまま）
		var w: float = IMG_W if _img_has_text else W * 1.1
		var sz := Vector2(w, w * _img.get_height() / _img.get_width())
		draw_texture_rect(_img, Rect2(-sz / 2.0, sz), false)
		return
	var r := Rect2(-W / 2.0, -H / 2.0, W, H)
	# 影
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(30)
	draw_style_box(shadow, Rect2(r.position + Vector2(14, 18), r.size))
	# 本体＋赤枠
	var box := StyleBoxFlat.new()
	box.bg_color = BODY
	box.border_color = FRAME
	box.set_border_width_all(16)
	box.set_corner_radius_all(30)
	draw_style_box(box, r)
	# 板の継ぎ目
	var inner := r.grow(-26)
	var midy: float = inner.position.y + inner.size.y * 0.5
	draw_line(Vector2(inner.position.x, midy), Vector2(inner.end.x, midy), BODY_DARK, 6.0)
	draw_line(Vector2(inner.position.x + inner.size.x * 0.55, inner.position.y + 30), Vector2(inner.position.x + inner.size.x * 0.55, midy), BODY_DARK, 6.0)
	draw_line(Vector2(inner.position.x + inner.size.x * 0.4, midy), Vector2(inner.position.x + inner.size.x * 0.4, inner.end.y - 30), BODY_DARK, 6.0)
	# 上下の黄黒シマシマ
	_hazard(Rect2(inner.position.x, inner.position.y, inner.size.x, 26))
	_hazard(Rect2(inner.position.x, inner.end.y - 26, inner.size.x, 26))
	# 鋲
	for p in [Vector2(inner.position.x + 22, midy), Vector2(inner.end.x - 22, midy),
			Vector2(inner.position.x + 22, inner.position.y + 48), Vector2(inner.end.x - 22, inner.position.y + 48),
			Vector2(inner.position.x + 22, inner.end.y - 48), Vector2(inner.end.x - 22, inner.end.y - 48)]:
		draw_circle(p, 10, Color(1, 0.85, 0.3))
		draw_arc(p, 10, 0, TAU, 16, Color(0.45, 0.25, 0.05), 3.0)


func _hazard(band: Rect2) -> void:
	draw_rect(band, Color(1, 0.86, 0.1))
	var w: float = 30.0
	var x: float = band.position.x - band.size.y
	while x < band.end.x:
		var pts := PackedVector2Array([
			Vector2(x, band.end.y), Vector2(x + w, band.end.y),
			Vector2(x + w + band.size.y, band.position.y), Vector2(x + band.size.y, band.position.y)])
		for k in pts.size():
			pts[k].x = clampf(pts[k].x, band.position.x, band.end.x)
		draw_colored_polygon(pts, Color(0.1, 0.1, 0.1))
		x += w * 2.0
	draw_rect(band, Color(0.1, 0.1, 0.1), false, 3.0)
