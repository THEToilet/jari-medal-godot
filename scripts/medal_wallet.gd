extends Node
## 持ちメダルの一元管理（Autoload）。ゲーム側は spend / add だけを使う。

signal changed(amount: int)

var medals: int = 50:
	set(v):
		medals = v
		changed.emit(v)


func spend(n: int) -> bool:
	if medals < n:
		return false
	medals -= n
	return true


func add(n: int) -> void:
	medals += n
