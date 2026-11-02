class_name DropShadow
extends Node2D
## 上から落ちてくる物の、地面に落ちる影。k 0〜1 で薄く小さい → 濃く大きい
var w: float = 120.0
var k: float = 0.0:
	set(v):
		k = v
		queue_redraw()


func _draw() -> void:
	var rw: float = w * (0.35 + 0.65 * k) * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, rw, Color(0, 0, 0, 0.12 + 0.3 * k))
	draw_circle(Vector2.ZERO, rw * 0.65, Color(0, 0, 0, 0.08 + 0.15 * k))
