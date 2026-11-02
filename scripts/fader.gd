extends CanvasLayer
## 画面の切り替え用の暗転（Autoload）。シーンを作り直しても消えないので、切り替えの継ぎ目を隠せる。
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.size = Vector2(1920, 1080)
	add_child(_rect)


var _snap: TextureRect


## 今の画面を写真に撮って上に貼る（作り直したあと、これを溶かして新しい画面に切り替える）
func snapshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if _snap == null:
		_snap = TextureRect.new()
		_snap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_snap.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_snap)
	_snap.texture = ImageTexture.create_from_image(img)
	_snap.position = Vector2.ZERO
	_snap.size = Vector2(1920, 1080)
	_snap.modulate.a = 1.0
	_snap.visible = true


## 貼った写真をふわっと溶かす
func dissolve(dur: float = 0.4) -> void:
	if _snap == null or not _snap.visible:
		return
	var tw := create_tween()
	tw.tween_property(_snap, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_snap.visible = false


func fade_out(dur: float = 0.15) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, dur)
	await tw.finished


func fade_in(dur: float = 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, dur)
	await tw.finished
