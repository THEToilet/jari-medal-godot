class_name UpLight
extends Node2D
## 選択ゾーンの光。中央のビルの足元から、光がぼわーっと湧き上がる。
## ビルの後ろに置く（光の柱）＋ 光の粒が下から上へ昇っていく。

var base: Vector2 = Vector2(960, 770)   # ビルの足元の中心
var width: float = 300.0
var height: float = 500.0
var strength: float = 0.0               # 0〜1（中央で止まっている間 1）
var front: bool = false                 # true：ビルの手前に重ねる薄い光（足元を照らす）
var _t: float = 0.0
var _rise: float = 0.0                  # 湧き上がりの進み具合
var _particles: CPUParticles2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_particles = CPUParticles2D.new()
	_particles.amount = 40
	_particles.lifetime = 1.8
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2(0, -1)
	_particles.spread = 8.0
	_particles.gravity = Vector2(0, -30)
	_particles.initial_velocity_min = 70.0
	_particles.initial_velocity_max = 160.0
	_particles.scale_amount_min = 3.0
	_particles.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.95, 0.6, 0.0))
	ramp.add_point(0.15, Color(1, 0.95, 0.6, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 0.9, 0.0))
	_particles.color_ramp = ramp
	_particles.emitting = false
	_particles.use_parent_material = true
	add_child(_particles)


func _process(delta: float) -> void:
	_t += delta
	# 止まると下から湧き上がり、動き出すとすっと引く
	_rise = lerpf(_rise, strength, minf(1.0, delta * 18.0))   # ほぼ遅れなく追従
	_particles.position = base
	_particles.emission_rect_extents = Vector2(width * 0.45, 4)
	_particles.emitting = false   # 光の粒は出さない
	queue_redraw()


func _draw() -> void:
	if _rise <= 0.01:
		return
	var pulse: float = 0.85 + 0.15 * sin(_t * 5.0)
	var h: float = height * _rise * (0.3 if front else 1.0)
	var amp: float = 0.22 if front else 2.6
	# 光の柱：下ほど明るく、上に行くほど消える。何層か重ねてふんわり
	for k in 6:
		var w: float = width * (0.7 + 0.18 * k)
		var hk: float = h * (1.0 - 0.08 * k)
		var a: float = 0.16 * amp * _rise * pulse * (1.0 - k * 0.12)
		var bottom := Color(1.0, 0.92, 0.55, a)
		var top := Color(1.0, 0.95, 0.7, 0.0)
		var pts := PackedVector2Array([
			base + Vector2(-w / 2.0, 0), base + Vector2(w / 2.0, 0),
			base + Vector2(w * 0.35, -hk), base + Vector2(-w * 0.35, -hk)])
		draw_polygon(pts, PackedColorArray([bottom, bottom, top, top]))
	if not front:
		# 中心の白い芯（コントラストを上げる）
		var cw: float = width * 0.45
		var core := PackedVector2Array([base + Vector2(-cw / 2.0, 0), base + Vector2(cw / 2.0, 0),
			base + Vector2(cw * 0.3, -h), base + Vector2(-cw * 0.3, -h)])
		var cb := Color(1, 1, 0.92, 0.55 * _rise * pulse)
		var ct := Color(1, 1, 0.95, 0.0)
		draw_polygon(core, PackedColorArray([cb, cb, ct, ct]))
		return
	# 足元の光だまり
	draw_set_transform(base, 0.0, Vector2(1.0, 0.2))
	for k in 4:
		draw_circle(Vector2.ZERO, width * (0.4 + 0.08 * k), Color(1, 0.9, 0.5, 0.18 * _rise * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
