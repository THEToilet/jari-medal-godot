extends Node
## 効果音・BGM（Autoload）。音はすべて assets/sfx/<名前>.wav（または .ogg）を鳴らす。
##   boom / rumble / coin / tap / creak / beep … 効果音
##   fanfare_0 / fanfare_1 / fanfare_2 … リザルトのファンファーレ（ランク別）
##   bgm … ループするBGM
##   hum … 発電機のうなり音（ループ。hum_level / hum_pitch で音量と高さを変える）
## ※以前は GDScript で波形を1サンプルずつ計算していたが、Web版（シングルスレッド）で
##   音が遅れる原因になるのでやめた。ファイル再生だけなら Web は「サンプル再生」で軽く鳴る。

const POOL := 12
const HUM_BASE_HZ := 100.0     # hum.wav の音の高さ

## 発電機のうなり音。hum_level 0〜1 で音量、hum_pitch で高さ。
var hum_level: float = 0.0
var hum_pitch: float = 1.0

var _files: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _bgm: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _hum_vol: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in ["boom", "rumble", "coin", "tap", "creak", "beep", "hum", "thud", "crane", "chain", "chargeup", "fanfare_0", "fanfare_1", "fanfare_2", "bgm"]:
		for ext in ["ogg", "wav"]:
			var path: String = "res://assets/sfx/%s.%s" % [k, ext]
			if ResourceLoader.exists(path):
				_files[k] = load(path)
				break
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -10.0
	_bgm.finished.connect(func() -> void: _bgm.play())   # ループ
	add_child(_bgm)
	_hum = AudioStreamPlayer.new()
	if _files.has("hum"):
		var s: AudioStream = _files["hum"]
		if s is AudioStreamWAV:
			var w: AudioStreamWAV = s
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2   # 16bit モノラルのフレーム数
		_hum.stream = s
	_hum.volume_db = -80.0
	add_child(_hum)


func has_file(kind: String) -> bool:
	return _files.has(kind)


## BGM 開始／停止
func play_bgm() -> void:
	if _files.has("bgm") and not _bgm.playing:
		_bgm.stream = _files["bgm"]
		_bgm.play()


func set_bgm_volume(db: float) -> void:
	create_tween().tween_property(_bgm, "volume_db", db, 0.3)


## kind: "beep" / "coin" / "boom" / "tap" / "rumble" / "creak" / "fanfare_N"
## beep だけは freq で音の高さが変わる。ほかは freq / dur を使わない（互換のため残す）
func play(kind: String, freq: float = 440.0, dur: float = 0.15) -> void:
	if not _files.has(kind):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _files[kind]
	if kind == "beep":
		p.pitch_scale = clampf(freq / 880.0, 0.25, 4.0)
	elif kind in ["coin", "tap"]:
		p.pitch_scale = randf_range(0.95, 1.05)
	else:
		p.pitch_scale = 1.0
	p.volume_db = {"tap": -8.0, "coin": -6.0, "creak": -4.0, "beep": -10.0}.get(kind, 0.0)
	p.play()


## 高さと音量を指定して鳴らす（積むほど低く重くする、などに使う）
func play_pitch(kind: String, pitch: float, vol_db: float = 0.0) -> void:
	if not _files.has(kind):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _files[kind]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.play()


func _process(delta: float) -> void:
	if _hum.stream == null:
		return
	_hum_vol = lerpf(_hum_vol, hum_level, minf(delta * 6.0, 1.0))
	if _hum_vol > 0.01:
		if not _hum.playing:
			_hum.play()
		_hum.volume_db = linear_to_db(_hum_vol * 0.8)
		_hum.pitch_scale = clampf((60.0 + 140.0 * hum_pitch) / HUM_BASE_HZ, 0.5, 2.5)
	elif _hum.playing:
		_hum.stop()
