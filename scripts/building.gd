class_name Building
extends Node2D
## ビル1棟。原点は「建物の足元の中心」。
## 傾き・揺れ・ヒビ・崩壊（破片化）を担当する。

var data: Dictionary
var sprite: Sprite2D
var cracks: Sprite2D
var tex: Texture2D
var _shake_amp: float = 0.0
var _base_pos: Vector2


func setup(d: Dictionary, t: Texture2D, crack_tex: Texture2D) -> void:
	data = d
	tex = t
	sprite = Sprite2D.new()
	sprite.texture = t
	sprite.centered = false
	sprite.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(sprite)
	cracks = Sprite2D.new()
	cracks.texture = crack_tex
	cracks.position = Vector2(0, -t.get_height() / 2.0)
	var s: float = maxf(t.get_width() / float(crack_tex.get_width()), t.get_height() / float(crack_tex.get_height())) * 1.1
	cracks.scale = Vector2(s, s)
	cracks.modulate.a = 0.0
	sprite.add_child(cracks)


func size() -> Vector2:
	return Vector2(tex.get_width(), tex.get_height())


## 画面上の当たり判定（クリック用）
func hit(global_point: Vector2) -> bool:
	var local: Vector2 = to_local(global_point)
	var sz: Vector2 = size()
	return Rect2(-sz.x / 2.0, -sz.y, sz.x, sz.y).has_point(local)


func set_shake(amp: float) -> void:
	if _shake_amp == 0.0 and amp > 0.0:
		_base_pos = sprite.position
	_shake_amp = amp
	if amp == 0.0:
		sprite.position = _base_pos


func _process(_delta: float) -> void:
	if _shake_amp > 0.0:
		sprite.position = _base_pos + Vector2(randf_range(-1, 1), randf_range(-0.4, 0.4)) * _shake_amp


func set_crack(amount: float, dur: float) -> void:
	create_tween().tween_property(cracks, "modulate:a", amount, dur)


## 足元を支点に傾ける（度）
func tilt(deg: float, dur: float) -> Tween:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation_degrees", deg, dur)
	return tw


## 崩壊：絵をブロックに切り分けて RigidBody2D としてばらまく
func collapse(parent: Node, ground_layer: int) -> void:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var sz: Vector2 = size()
	var cols: int = clampi(int(sz.x / 70.0), 3, 6)
	var rows: int = clampi(int(sz.y / 70.0), 3, 12)
	var cw: float = sz.x / cols
	var ch: float = sz.y / rows
	var xf: Transform2D = sprite.get_global_transform()
	var center_local := Vector2(0, -sz.y * 0.35)
	for r in rows:
		for c in cols:
			var rect := Rect2(c * cw, r * ch, cw, ch)
			if not _has_pixels(img, rect):
				continue
			var local_center: Vector2 = sprite.offset + rect.get_center()
			var body := RigidBody2D.new()
			body.collision_layer = ground_layer
			body.collision_mask = ground_layer
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.region_enabled = true
			spr.region_rect = rect
			spr.scale = xf.get_scale()
			body.add_child(spr)
			var shape := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = rect.size * xf.get_scale() * 0.85
			shape.shape = rs
			body.add_child(shape)
			parent.add_child(body)
			body.global_transform = Transform2D(xf.get_rotation(), xf.origin + xf.basis_xform(local_center))
			var away: Vector2 = (local_center - center_local).normalized()
			var power: float = randf_range(250.0, 650.0)
			body.linear_velocity = Vector2(away.x * power, -absf(away.y) * power * 0.6 - randf_range(50, 250))
			body.angular_velocity = randf_range(-8.0, 8.0)
			_fade_later(body, randf_range(3.5, 5.0))
	sprite.visible = false


func _has_pixels(img: Image, rect: Rect2) -> bool:
	var hits: int = 0
	for i in 5:
		for j in 5:
			var p := Vector2i(int(rect.position.x + rect.size.x * (i + 0.5) / 5.0), int(rect.position.y + rect.size.y * (j + 0.5) / 5.0))
			if p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5:
				hits += 1
	return hits >= 3


func _fade_later(body: Node2D, t: float) -> void:
	var tw := body.create_tween()
	tw.tween_interval(t)
	tw.tween_property(body, "modulate:a", 0.0, 0.8)
	tw.tween_callback(body.queue_free)
