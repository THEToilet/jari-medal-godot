class_name Dynamo
extends Node2D
## 発電機。メーターの針は絵の上にコードで描き直している。

const GAUGE_CENTER := Vector2(-3, 41)
const GAUGE_R := 47.0
const A0 := deg_to_rad(200.0)
const A1 := deg_to_rad(340.0)

var power: float = 0.0
var spin: float = 0.0
var sprite: Sprite2D
var gauge: Gauge
var steam: CPUParticles2D
var _bounce: Tween


func setup(t: Texture2D, puff: Texture2D = null) -> void:
	sprite = Sprite2D.new()
	sprite.texture = t
	add_child(sprite)
	gauge = Gauge.new()
	gauge.dyn = self
	sprite.add_child(gauge)
	steam = CPUParticles2D.new()
	steam.position = Vector2(-60, -150)
	steam.amount = 24
	steam.lifetime = 1.0
	steam.direction = Vector2(0, -1)
	steam.spread = 25.0
	steam.initial_velocity_min = 80.0
	steam.initial_velocity_max = 160.0
	steam.gravity = Vector2(0, -40)
	steam.texture = puff
	steam.scale_amount_min = 0.05 if puff else 10.0
	steam.scale_amount_max = 0.11 if puff else 22.0
	steam.color = Color(1, 1, 1, 0.85)
	steam.emitting = false
	add_child(steam)


func kick() -> void:
	spin = minf(spin + 6.0, 30.0)
	if _bounce:
		_bounce.kill()
	_bounce = create_tween()
	sprite.scale = Vector2(1.08, 0.92)
	sprite.position.y = 6
	_bounce.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce.parallel().tween_property(sprite, "position:y", 0.0, 0.12)


func _process(delta: float) -> void:
	spin = move_toward(spin, 0.0, 14.0 * delta)
	steam.emitting = power > 0.6 and spin > 4.0
	sprite.rotation = sin(Time.get_ticks_msec() * 0.05) * 0.01 * spin
	gauge.queue_redraw()


class Gauge extends Node2D:
	var dyn: Dynamo

	func _draw() -> void:
		var power: float = dyn.power
		var spin: float = dyn.spin
		var c: Vector2 = Dynamo.GAUGE_CENTER
		draw_circle(c, Dynamo.GAUGE_R, Color(0.97, 0.94, 0.86))
		draw_arc(c, Dynamo.GAUGE_R - 9, lerpf(Dynamo.A0, Dynamo.A1, 0.75), Dynamo.A1, 16, Color(0.85, 0.1, 0.1), 9.0)
		for i in 9:
			var a: float = lerpf(Dynamo.A0, Dynamo.A1, i / 8.0)
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (Dynamo.GAUGE_R - 16), c + d * (Dynamo.GAUGE_R - 4), Color.BLACK, 3.0)
		var jitter: float = randf_range(-1, 1) * 0.02 * spin / 30.0
		var na: float = lerpf(Dynamo.A0, Dynamo.A1, clampf(power + jitter, 0.0, 1.0))
		var nd := Vector2(cos(na), sin(na))
		draw_line(c, c + nd * (Dynamo.GAUGE_R - 8), Color(0.1, 0.1, 0.1), 7.0)
		draw_line(c, c + nd * (Dynamo.GAUGE_R - 8), Color(0.9, 0.15, 0.1), 4.0)
		draw_circle(c, 9, Color(0.85, 0.65, 0.15))
		draw_arc(c, 9, 0, TAU, 16, Color.BLACK, 2.5)
