# 筐体モデルの生成

`python3 build_cabinet.py` で `virtual/jari_cabinet.glb` を書き出す（numpy のみ）。
`python3 render_preview.py out.png 600 800 28` で確認用の画像を出せる（最後の数字は見る角度）。

ローポリ（約1,300ポリゴン）で、丸みは少ない頂点＋スムーズシェーディングで出している。
単位は m、Y上、正面が +Z。幅60cm × 奥行57cm × 高さ1.52m。

## 調整するところ（build_cabinet.py）
- `PROFILE` … 側面シルエットの点と角の丸み
- `DECK_DEG` / `DECK_Y` … ボタン面の傾き（水平から、既定40°）と手前の高さ。環境変数 `DECK_DEG` でも変えられる
- `face_with_recess(...)` の引数 … 払い出し口・モニターのくぼみの位置/大きさ/深さ
- `color_group` と `M_*` … どの区間を何色にするか（今は 前面=オレンジ、ボタン面とモニター面=チャコール、ほか=白）
- `ARC` / `SIDE_R` … 丸みの分割数と左右の縁の丸み（ポリゴン数に直結）

## glb のノード名（virtual_cabinet.gd から名前で探している）
- `Shell` / `ShellFront` / `ShellDeck` / `ShellFace` … 本体（色ごと）
- `PayoutPocket` / `PayoutChute` … 払い出し口のくぼみと奥の穴
- `MonitorRecess` / `Monitor` → `Screen` … モニター（ここにゲームの画面を貼る）
- `Pop` → `TopperLogo` … モニター上のロゴ帯（`assets/title_logo.png` を貼る）
- `FrontDecal` … 前面の絵の場所（今は非表示）
- `ControlPanel` → `Button` → `ButtonCap` … ボタン
- `CoinSlot` → `CoinSlotPlate` … 投入口
- `LED_*` … LEDライン
