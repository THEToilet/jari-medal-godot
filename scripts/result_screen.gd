class_name ResultScreen
extends Node2D
## 解体成功時のリザルト画面。
## 払い出し枚数でランクが上がり、演出が豪華になる。
##   rank 0（1〜5枚）  : 回転する光線＋紙吹雪
##   rank 1（8〜20枚） : 金色の光線＋紙吹雪多め＋花火
##   rank 2（30枚）    : 虹色の光線＋花火連発＋フラッシュ
## assets/result/ に画像があれば優先して使う（無ければコードで描く）:
##   burst_gold.png / burst_rainbow.png … 背景の放射光線（rank0,1 は gold、rank2 は rainbow）
##   title_0.png / title_1.png / title_2.png … タイトル文字（解体成功！ / 解体大成功！！ / 超・大解体！！！）
##   get.png … 「メダルゲット！」のリボン

const CENTER := Vector2(960, 470)
const RAY_COLORS := [
	[Color(1, 0.95, 0.6), Color(1, 0.8, 0.3)],
	[Color(1, 0.88, 0.25), Color(1, 0.6, 0.1)],
	[Color(1, 0.3, 0.4), Color(1, 0.7, 0.2), Color(1, 1, 0.3), Color(0.3, 0.9, 0.4), Color(0.3, 0.7, 1), Color(0.7, 0.4, 1)],
]
const CONFETTI_COLORS := [Color(1, 0.3, 0.35), Color(1, 0.85, 0.2), Color(0.3, 0.8, 1), Color(0.4, 0.9, 0.4), Color(1, 0.5, 0.9), Color.WHITE]

var rank: int = 0
var _t: float = 0.0
var _alpha: float = 0.0
var _confetti: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _next_fw: float = 0.0

var title: Label
var title_spr: Sprite2D
var burst: Sprite2D
var halo: Halo
var get_spr: Sprite2D
var _img: Dictionary = {}
var sub: Label
var get_lbl: Label
var num: Sprite2D
var hero: Sprite2D
var buddy: Sprite2D


func setup(font: Font, hero_tex: Texture2D, buddy_tex: Texture2D) -> void:
	z_index = 8
	visible = false
	for k in ["burst_gold", "burst_rainbow", "title_0", "title_1", "title_2", "get"]:
		var path: String = "res://assets/result/%s.png" % k
		if ResourceLoader.exists(path):
			_img[k] = load(path)
	burst = Sprite2D.new()
	burst.position = CENTER
	add_child(burst)
	halo = Halo.new()
	halo.position = CENTER
	halo.visible = false
	add_child(halo)
	hero = _sprite(hero_tex, Vector2(380, 1010), 1.7)
	buddy = _sprite(buddy_tex, Vector2(1560, 1010), 1.6)
	num = Sprite2D.new()
	num.position = CENTER + Vector2(0, 20)
	add_child(num)
	title = _make_label(font, 150, Color(1, 0.9, 0.15), Color(0.55, 0.05, 0.05), 34)
	title.position = Vector2(0, 60)
	sub = _make_label(font, 56, Color.WHITE, Color(0.1, 0.1, 0.3), 16)
	sub.position = Vector2(0, 930)
	get_lbl = _make_label(font, 90, Color(1, 0.95, 0.4), Color(0.4, 0.15, 0.0), 24)
	get_lbl.position = Vector2(0, 690)
	get_lbl.text = "メダル ゲット！"
	title_spr = Sprite2D.new()
	title_spr.position = Vector2(960, 130)
	add_child(title_spr)
	get_spr = Sprite2D.new()
	get_spr.position = Vector2(960, 800)
	add_child(get_spr)
	if _img.has("get"):
		get_spr.texture = _img["get"]
		var gs: float = 820.0 / get_spr.texture.get_width()
		get_spr.scale = Vector2(gs, gs)
		get_lbl.visible = false


func _sprite(t: Texture2D, pos: Vector2, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	s.position = pos
	s.scale = Vector2(sc, sc)
	add_child(s)
	return s


func _make_label(font: Font, size: int, col: Color, outline: Color, osize: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", osize)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	l.add_theme_constant_override("shadow_offset_x", 6)
	l.add_theme_constant_override("shadow_offset_y", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1920, 0)
	l.pivot_offset = Vector2(960, size * 0.6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


static func rank_of(payout: int) -> int:
	if payout >= 30:
		return 2
	if payout >= 8:
		return 1
	return 0


func show_result(payout: int, building_name: String, num_tex: Texture2D) -> void:
	rank = rank_of(payout)
	_t = 0.0
	_confetti.clear()
	_sparks.clear()
	_next_fw = 0.3
	visible = true
	title.text = ["かいたいせいこう！", "かいたいだいせいこう！！", "ちょう・だいかいたい！！！"][rank]
	var tkey: String = "title_%d" % rank
	title.visible = not _img.has(tkey)
	title_spr.visible = _img.has(tkey)
	if _img.has(tkey):
		title_spr.texture = _img[tkey]
		var tw_px: float = [1150.0, 1300.0, 1500.0][rank]
		var ts: float = tw_px / title_spr.texture.get_width()
		title_spr.set_meta("s", ts)
		title_spr.scale = Vector2(0.1, 0.1) * ts
		create_tween().tween_property(title_spr, "scale", Vector2(ts, ts), 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var bkey: String = "burst_rainbow" if rank == 2 else "burst_gold"
	burst.visible = _img.has(bkey)
	if _img.has(bkey):
		burst.texture = _img[bkey]
		var bs: float = 2400.0 / maxf(burst.texture.get_width(), burst.texture.get_height())
		burst.scale = Vector2(bs, bs)
		burst.modulate.a = 0.0
		create_tween().tween_property(burst, "modulate:a", 0.92, 0.3)
	halo.visible = burst.visible
	halo.rank = rank
	sub.text = "%s を かいたいした！" % building_name
	num.texture = num_tex
	var target_h: float = [240.0, 290.0, 340.0][rank]
	var ns: float = target_h / num_tex.get_height() if num_tex else 1.0
	# 登場アニメ
	var tw := create_tween()
	tw.tween_property(self, "_alpha", 1.0, 0.25)
	title.scale = Vector2(0.1, 0.1)
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	num.scale = Vector2.ZERO
	var nt := create_tween()
	nt.tween_interval(0.35)
	nt.tween_property(num, "scale", Vector2(ns * 1.35, ns * 1.35), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	nt.tween_property(num, "scale", Vector2(ns, ns), 0.18)
	for l in [sub, get_lbl, get_spr]:
		l.modulate.a = 0.0
		var lt := create_tween()
		lt.tween_interval(0.6)
		lt.tween_property(l, "modulate:a", 1.0, 0.25)
	for c in [hero, buddy]:
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.3)
	_burst_confetti(80 + rank * 70)


func hide_result() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_alpha", 0.0, 0.35)
	for n in [title, sub, get_lbl, num, hero, buddy, title_spr, get_spr, burst, halo]:
		tw.tween_property(n, "modulate:a", 0.0, 0.3)
	await tw.finished
	visible = false
	for n in [title, sub, get_lbl, num, hero, buddy, title_spr, get_spr, burst, halo]:
		n.modulate.a = 1.0


func _burst_confetti(n: int) -> void:
	for i in n:
		_confetti.append({
			"p": Vector2(randf_range(0, 1920), randf_range(-600, -20)),
			"v": Vector2(randf_range(-60, 60), randf_range(150, 380)),
			"c": CONFETTI_COLORS.pick_random(),
			"r": randf() * TAU,
			"rs": randf_range(-8, 8),
			"w": randf_range(10, 20),
		})


func _firework(at: Vector2) -> void:
	var col: Color = CONFETTI_COLORS.pick_random()
	for i in 36:
		var a: float = TAU * i / 36.0
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(250, 520), "life": 1.0, "c": col})


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# キャラが跳ねる
	hero.position.y = 1010 - absf(sin(_t * 7.0)) * 60.0
	buddy.position.y = 1010 - absf(sin(_t * 7.0 + 1.5)) * 40.0
	title.rotation = sin(_t * 3.0) * 0.04
	title_spr.rotation = sin(_t * 3.0) * 0.04
	burst.rotation = _t * [0.25, 0.45, 0.8][rank]
	halo.pulse = 1.0 + sin(_t * 6.0) * 0.04
	halo.queue_redraw()
	get_spr.rotation = sin(_t * 4.0) * 0.03
	num.rotation = sin(_t * 2.4) * 0.06
	get_lbl.scale = Vector2.ONE * (1.0 + absf(sin(_t * 5.0)) * 0.06)
	# 紙吹雪
	for c in _confetti:
		c.p += c.v * delta
		c.r += c.rs * delta
		c.p.x += sin(_t * 3.0 + c.w) * 40.0 * delta
		if c.p.y > 1120:
			c.p.y = randf_range(-80, -10)
	# 花火（rank1以上）
	if rank >= 1:
		_next_fw -= delta
		if _next_fw <= 0.0:
			_next_fw = [9.9, 0.7, 0.28][rank]
			_firework(Vector2(randf_range(250, 1670), randf_range(150, 500)))
			Sfx.play("beep", randf_range(1800.0, 2600.0), 0.06)
	var alive: Array[Dictionary] = []
	for sp in _sparks:
		sp.v *= 0.96
		sp.v.y += 250.0 * delta
		sp.p += sp.v * delta
		sp.life -= delta * 0.9
		if sp.life > 0.0:
			alive.append(sp)
	_sparks = alive
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.05, 0.03, 0.15, 0.68 * _alpha))
	# 回転する光線（画像が無いとき）。ほかの素材に合わせてベタ塗り＋黒フチ
	if not burst.visible:
		var cols: Array = RAY_COLORS[rank]
		var n: int = 16
		var spin: float = _t * [0.25, 0.45, 0.8][rank]
		for i in n:
			var a0: float = spin + TAU * i / n
			var a1: float = a0 + TAU / n * 0.5
			var col: Color = cols[i % cols.size()]
			col.a = _alpha
			var tri := PackedVector2Array([CENTER,
				CENTER + Vector2(cos(a0), sin(a0)) * 1600.0,
				CENTER + Vector2(cos(a1), sin(a1)) * 1600.0])
			draw_colored_polygon(tri, col)
			tri.append(CENTER)
			draw_polyline(tri, Color(0.1, 0.05, 0.05, _alpha), 6.0)
		draw_circle(CENTER, 210.0, Color(1, 0.97, 0.8, _alpha))
		draw_arc(CENTER, 210.0, 0, TAU, 48, Color(0.1, 0.05, 0.05, _alpha), 8.0)
	# 虹ランクはフラッシュ点滅
	if rank == 2 and fmod(_t, 0.5) < 0.08:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(1, 1, 1, 0.25 * _alpha))
	# 紙吹雪
	for c in _confetti:
		draw_set_transform(c.p, c.r, Vector2(1.0, absf(sin(c.r * 2.0)) + 0.3))
		draw_rect(Rect2(-c.w / 2.0, -c.w / 4.0, c.w, c.w / 2.0), c.c)
		draw_rect(Rect2(-c.w / 2.0, -c.w / 4.0, c.w, c.w / 2.0), Color(0.1, 0.05, 0.05), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 花火
	for sp in _sparks:
		var col: Color = sp.c
		col.a = sp.life
		draw_circle(sp.p, 5.0 * sp.life + 2.0, col)


## 光線画像の中心に敷く白い円（数字を読みやすくする）
class Halo extends Node2D:
	var rank: int = 0
	var pulse: float = 1.0

	func _draw() -> void:
		var r: float = [200.0, 230.0, 260.0][rank] * pulse
		draw_circle(Vector2.ZERO, r + 14.0, Color(0.1, 0.05, 0.05))
		draw_circle(Vector2.ZERO, r, Color(1, 0.98, 0.85))
		for k in 3:
			draw_circle(Vector2.ZERO, r * (0.85 - k * 0.2), Color(1, 1, 1, 0.25))
