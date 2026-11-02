# じゃりメダル ビル解体（プロトタイプ）

Godot 4.6以上 / GL Compatibility / 1920×1080

## ブラウザ版（スマホでも遊べる）
main ブランチに push すると、GitHub Actions が Web 版を書き出して GitHub Pages に公開する（`.github/workflows/pages.yml`）。
スマホでは右上の「メダル投入」ボタンでメダルを入れ、画面タップがボタンの代わり。メダルが尽きたら投入ボタンで自動補充される。

## 仮想筐体（3D）
`virtual/virtual_cabinet.tscn` は、ゲーム（`scenes/main.tscn`）を3Dの筐体の画面に映して遊ぶシーン。Web版（GitHub Pages）はこちらが起動する（`project.godot` の `run/main_scene.web`）。PCの `play.bat` や実機は今までどおり2Dのまま。

- ゲームは SubViewport の中で動かしていて、筐体のボタン → `tap`、投入口 → `coin` を流し込むだけ。ゲーム側には `is_in_play()` を足したのと、筐体の画面の中ではスマホ用の投入ボタンを出さないようにした以外、手を入れていない
- ゲームの `finished(払い出し枚数)` を受けて、払い出し口のくぼみにメダルを物理で落とす
- カメラは待機中＝全体、プレイ中＝画面とボタン、払い出し中＝受け皿に自動で切り替わる

| 操作 | 仮想筐体 |
|---|---|
| メダル投入 | 投入口をクリック/タップ、または C |
| ボタン | 投入口以外のどこかをクリック/タップ、または Space / Enter |
| 払い出しの確認（デバッグ） | F3（10枚） |

筐体モデル（`virtual/jari_cabinet.glb`）は `tools/cabinet/build_cabinet.py` で生成している（numpy のみ）。形や色を変えるときはそちらを直して `python3 tools/cabinet/build_cabinet.py` を実行する。詳しくは `tools/cabinet/README.md`。

## 起動
- `play.bat` … ゲームを起動
- `edit.bat` … Godotエディタで開く

初回は Godot の実行ファイル（Godot_v4.x_win64.exe）を自動で探し、見つかった場所を `godot_path.txt` に保存する。
見つからない場合はウィンドウに exe をドラッグ＆ドロップすればOK。
起動のたびに素材のインポートを走らせる（新しい画像を追加しても読み込まれる）。ゲームのログは `godot.log` に出る。場所を変えたら `godot_path.txt` を消すか書き換える。
環境変数 `GODOT` に exe のパスを入れておけばそれを最優先で使う。

## 遊び方
画面は筐体に組み込む前提。ボタン・メダル投入口・払い出し口は筐体側にあるので、PCではキーで代用する。

| 操作 | キー |
|---|---|
| メダル投入（1〜5枚＝爆弾の数） | C |
| 決定・連打・起爆（ボタンは1個） | Space ／ Enter ／ 左クリック |
| メダル+50（デバッグ） | F2 |

流れ：メダル投入（入れるほど画面下にダイナマイトが並ぶ）→ ランダムな並びで流れてくるビルを、中央に来たところでボタンで選択 → 5秒間連打（作業員が発電機を回して、中央のスイッチに電気を溜める） → 「押せー！」で起爆 → 煽り → 崩壊 or 残る

## ファイル構成
- `scripts/medal_wallet.gd` 持ちメダル（Autoload）
- `scripts/sfx.gd` 仮の効果音シンセ（Autoload）。本番の音素材ができたら差し替え
- `scripts/cabinet.gd` 筐体の共通基底（60秒タイムアウト、残り10秒で警告、時間切れでメダル回収）
- `scripts/demolition_cabinet.gd` ビル解体台本体（状態遷移・確率・演出）
- `scripts/building.gd` ビル（傾き・ヒビ・崩壊の破片化）
- `scripts/charge_meter.gd` 起爆器の横の「電気の溜まり」メーター
- `scripts/dynamo.gd` 発電機（現在は非表示。回転の計算だけ流用）
- `scripts/cable.gd` 電線
- `assets/chara/` 親方（foreman_0〜5）・作業員（worker_0〜3）・親方の顔（bust_0〜2）・見物人
- `scripts/result_screen.gd` 解体成功時のリザルト画面（払い出し枚数でランクが上がり豪華になる）。`assets/result/` に画像（burst_gold / burst_rainbow / title_0〜2 / get）があれば使う
- `scripts/up_light.gd` ビル選択の、足元から湧き上がる光
- `scripts/insert_sign.gd` 待機中の「メダルをいれてね」看板
- `scripts/medal_tray.gd` 払い出し演出（崩れたビルからメダルが噴き出して画面下へ落ちる。実際の払い出しは筐体の下から）

## 差し替え用の素材（置けば自動で使う。無ければ代わりの表示）
- `assets/text/stop.png` `charge.png` `push.png` `boom.png` `lose.png` … 画面の文字（ボタンでストップ！／ちからをこめろー！／おせーっ！！／ドカーン！！／のこった…）
- `assets/chara/worker_crank_0.png`〜 … 作業員が発電機を回すコマ送り（ボタン1回で1コマ進む）
- `assets/sfx/*.wav|ogg` … 効果音・BGM（boom, rumble, coin, tap, creak, fanfare_0〜2, bgm）。今は仮で合成した音が入っている

## 調整ポイント（demolition_cabinet.gd）
- `BUILDINGS` 払い出し・物置の固定確率・演出テンポ
- `NUM_H` 払い出し数字画像の大きさ（枚数ごと）
- `RTP` 払い出し率（0.9）、`MASH_MAX_BONUS` 連打ボーナス上限（×1.1）、`POWER_PER_TAP`
- `PATTERNS` 煽りパターンの出現比率
- `RESULT_TIME` リザルト画面の最低表示時間（ランク別）
- インスペクタ `slot_time` 1棟ぶん進む時間（1.0秒）、`dwell_time` 中央で止まる時間（0.45秒）、`scroll_curve` 速度カーブ（sin / tan）、`linger` tanカーブの粘り具合
- `assets/num/<枚数>.png` 払い出し数字の画像（ビルの右下に表示）。無ければ文字で表示
- インスペクタの「演出の尺」→ `time_scale` で煽り全体を一括短縮

抽選結果は出力パネルに `[抽選] …` として表示される（調整用）。
