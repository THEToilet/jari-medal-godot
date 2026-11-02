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


func fade_out(dur: float = 0.15) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, dur)
	await tw.finished


func fade_in(dur: float = 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 0.0, dur)
	await tw.finished
