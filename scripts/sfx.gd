extends Node
## 効果音・BGM（Autoload）。
## assets/sfx/<名前>.wav（または .ogg）があればそれを鳴らす。無ければ簡易シンセで代用。
##   boom / rumble / coin / tap / creak … 効果音
##   fanfare_0 / fanfare_1 / fanfare_2 … リザルトのファンファーレ（ランク別）
##   bgm … ループするBGM
## 「beep」（カウントダウンや選択音）と発電機のうなり音はシンセで鳴らす。

const RATE := 22050.0
const POOL := 12

## 発電機のうなり音。hum_level 0〜1 で音量、hum_pitch で高さ。
var hum_level: float = 0.0
var hum_pitch: float = 1.0

var _player: AudioStreamPlayer
var _pb: AudioStreamGeneratorPlayback
var _hum_phase: float = 0.0
var _hum_vol: float = 0.0
var _voices: Array[Dictionary] = []
var _lp: float = 0.0

var _files: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _bgm: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	_player.stream = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback() as AudioStreamGeneratorPlayback

	for k in ["boom", "rumble", "coin", "tap", "creak", "fanfare_0", "fanfare_1", "fanfare_2", "bgm"]:
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
## ファイルがあればファイルを鳴らす（freq はピッチの揺らぎにだけ使う）
func play(kind: String, freq: float = 440.0, dur: float = 0.15) -> void:
	if _files.has(kind):
		var p: AudioStreamPlayer = _pool[_next]
		_next = (_next + 1) % POOL
		p.stream = _files[kind]
		p.pitch_scale = randf_range(0.95, 1.05) if kind in ["coin", "tap"] else 1.0
		p.volume_db = {"tap": -8.0, "coin": -6.0, "creak": -4.0}.get(kind, 0.0)
		p.play()
		return
	if _voices.size() > 24:
		_voices.pop_front()
	_voices.append({"kind": kind, "t": 0.0, "dur": dur, "freq": freq, "phase": 0.0})


func _process(_delta: float) -> void:
	if _pb == null:
		return
	var n: int = _pb.get_frames_available()
	var dt: float = 1.0 / RATE
	for i in n:
		_hum_vol = lerpf(_hum_vol, hum_level, 0.0008)
		var s: float = 0.0
		if _hum_vol > 0.002:
			_hum_phase = fmod(_hum_phase + (60.0 + 140.0 * hum_pitch) * dt, 1.0)
			var saw: float = _hum_phase * 2.0 - 1.0
			s += saw * 0.16 * _hum_vol
		for v in _voices:
			var t: float = v.t
			var d: float = v.dur
			if t >= d:
				continue
			var env: float = 1.0 - t / d
			match v.kind:
				"beep":
					v.phase = fmod(v.phase + v.freq * dt, 1.0)
					s += (1.0 if v.phase < 0.5 else -1.0) * 0.12 * env
				"coin":
					v.phase += v.freq * dt
					s += (sin(v.phase * TAU) + 0.5 * sin(v.phase * TAU * 2.76)) * 0.18 * env * env
				"tap":
					s += (randf() * 2.0 - 1.0) * 0.25 * env * env * env
				"boom":
					_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.08)
					v.phase += (55.0 - 30.0 * t / d) * dt
					s += (_lp * 1.6 + sin(v.phase * TAU) * 0.6) * env
				"rumble":
					_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.03)
					s += _lp * 1.2 * sin(PI * t / d)
				"creak":
					v.phase += (v.freq + 30.0 * sin(t * 25.0)) * dt
					s += sin(v.phase * TAU) * 0.12 * sin(PI * t / d)
			v.t = t + dt
		s = clampf(s, -1.0, 1.0)
		_pb.push_frame(Vector2(s, s))
	var alive: Array[Dictionary] = []
	for v in _voices:
		if v.t < v.dur:
			alive.append(v)
	_voices = alive
