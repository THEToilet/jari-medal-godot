class_name Cabinet
extends Node2D
## メダルゲーム筐体の共通基底。
## 各ゲームは _reset() を実装し、終了時に _end(払い出し枚数) を呼ぶ。
## 操作待ちの状態に入るときは start_idle()、入力のたびに touch() を呼ぶ。

signal finished(payout: int)
signal idle_warning(seconds_left: int)
signal idle_timeout

const IDLE_LIMIT := 60.0
const WARN_AT := 10.0

var bet: int = 0
var _idle: float = -1.0
var _last_warn: int = -1


func start_idle() -> void:
	_idle = IDLE_LIMIT
	_last_warn = -1
	idle_warning.emit(-1)


func stop_idle() -> void:
	_idle = -1.0
	idle_warning.emit(-1)


func touch() -> void:
	if _idle >= 0.0:
		start_idle()


func idle_left() -> float:
	return _idle


func _process(delta: float) -> void:
	if _idle < 0.0:
		return
	_idle -= delta
	if _idle <= WARN_AT:
		var s: int = ceili(_idle)
		if s != _last_warn and s > 0:
			_last_warn = s
			idle_warning.emit(s)
	if _idle <= 0.0:
		stop_idle()
		_on_timeout()


func _on_timeout() -> void:
	bet = 0  # 投入済みメダルは回収
	idle_timeout.emit()
	_reset()


func _end(payout: int) -> void:
	stop_idle()
	bet = 0
	finished.emit(payout)
	_reset()


func _reset() -> void:
	pass
