class_name MedalTray
extends Node2D
## 払い出し演出。実際のメダルは筐体の下から出る想定なので、
## 画面上では「崩れたビルからメダルが噴き出し、画面下へ落ちていく」だけを見せる。
## 1枚ごとに持ちメダル（PC確認用）を加算する。

const GRAVITY := 1800.0
const BOTTOM := 1160.0

var coin_tex: Texture2D
var _coins: Array[Dictionary] = []   # {spr, vel, spin}


func setup(t: Texture2D) -> void:
	coin_tex = t


## origin から n 枚噴き出させる
func payout(n: int, origin: Vector2) -> void:
	var interval: float = clampf(1.4 / maxf(n, 1), 0.035, 0.12)
	for i in n:
		_spawn(origin)
		MedalWallet.add(1)
		Sfx.play("coin", randf_range(1800.0, 2400.0), 0.18)
		await get_tree().create_timer(interval).timeout
	# 全部落ちきるまで待つ
	while not _coins.is_empty():
		await get_tree().process_frame


func _spawn(origin: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = coin_tex
	var s: float = randf_range(0.7, 1.0)
	spr.scale = Vector2(s, s)
	spr.position = origin + Vector2(randf_range(-40, 40), 0)
	add_child(spr)
	_coins.append({
		"spr": spr,
		"vel": Vector2(randf_range(-420, 420), randf_range(-1100, -750)),
		"spin": randf_range(-12, 12),
	})


func _process(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for c in _coins:
		var spr: Sprite2D = c.spr
		var v: Vector2 = c.vel
		v.y += GRAVITY * delta
		c.vel = v
		spr.position += v * delta
		spr.rotation += float(c.spin) * delta
		# 回転するメダルっぽく横幅を伸縮
		spr.scale.x = absf(cos(spr.rotation * 1.5)) * spr.scale.y
		if spr.position.y > BOTTOM:
			spr.queue_free()
		else:
			alive.append(c)
	_coins = alive
