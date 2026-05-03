# hardware/

3D プリント部品とジグの設計ファイル。詳細仕様はプレレジ §4 を正とする。
寸法は `params.scad` で集中管理し、各部品の `.scad` は冒頭で `include <params.scad>` する。

## ファイル一覧

| ファイル | 用途 | 主な寸法（params.scad より） |
|---|---|---|
| `params.scad` | 共通パラメータ。寸法変更はここを編集して再エクスポートする | — |
| `bend_jig_r10.scad` | POF を R=10mm の U字（180°）に拘束する曲げ治具 | 60 × 40 × 6 mm、溝 `pof_channel_width_mm × pof_channel_depth_mm` |
| `gel_mold.scad` | ゲル/PDMSパッド成形モールド | 38 × 38 × 7 mm、キャビティ 30 × 30 × 3 mm、抜き勾配 1° |
| `led_fiber_coupler.scad` | 5mm 砲弾型 LED と POF 端面を同軸に保持 | φ15 × 18 mm |
| `led_back_cap.scad` | LED 砲弾の根元を覆い、`led_fiber_coupler` の LED 穴を底面側から密閉する遮光蓋 | φ15 × 5 mm + 圧入突起 φ5.1 × 2 mm |
| `camera_fiber_coupler.scad` | Pi HQ Camera M12 + ファイバーホルダ（同ファイル内に2モジュール） | ベース 120 × 60 × 4 mm、ホルダ 25 × 25 × 30 mm |
| `weight_guide.scad` | ゲルパッド上に錘を中心配置するガイド | 35 × 35 × 7 mm、凹み φ25 × 5 mm |
| `enclosure.scad` | 遮光ボックス本体 + 蓋（同ファイル内に2モジュール、`display_mode` で出力切替） | 外形 180 × 180 × 100 mm、壁 1.6 mm、蓋 厚 2 mm + lip 5 mm |

> **検証ステータス**: OpenSCAD レンダ・印刷とも未実施。CAD 上で形状を確認してから実印刷に移ること。
> 寸法と機械的整合性は Phase 0 (shakedown) で実機検証する前提。

## 印刷設定（Bambu Lab A1 mini 推奨値）

- **材質**：PETG（推奨、寸法精度・耐久性）または PLA（簡易プロトタイプ）
- **層厚**：0.2mm（標準）、ゲル接触面は 0.1mm 推奨
- **充填率**：30%（ジャイロイド）
- **壁厚**：3 perimeters
- **サポート**：基本的に不要（設計上、サポート要らずの向きを指定済み）
- **Ironing**：`gel_mold.scad` の底面、`weight_guide.scad` の凹み面で ON

## 印刷向き（各 .scad ファイル冒頭にも記載）

| ファイル | 印刷向き |
|---|---|
| `bend_jig_r10.scad` | 上面（U字溝側）を上向き。サポート不要。|
| `gel_mold.scad` | 開口部を上向き、底面 build plate 密着。|
| `led_fiber_coupler.scad` | 軸を垂直に立て、LED 挿入側を上にして印刷。|
| `led_back_cap.scad` | 円盤を build plate に密着、圧入突起を上向き。サポート不要。黒フィラメント + infill 50%↑ 推奨。|
| `camera_fiber_coupler.scad` | ベースはプレートをフラットに。ホルダは POF 穴を水平にして真円度確保。|
| `weight_guide.scad` | 凹み側を上に。|
| `enclosure.scad` | 本体・蓋とも開口部を上向き。サポート不要。`display_mode = 0` で本体、`= 1` で蓋を STL エクスポート。|

## 印刷順序の推奨

Phase 0 着手のための最小セット（先印刷）：

1. `bend_jig_r10.scad`（30 分）
2. `led_fiber_coupler.scad`（20 分）
3. `led_back_cap.scad`（5 分、`led_fiber_coupler` とセットで使う）
4. `camera_fiber_coupler.scad` ベース + ファイバーホルダ（45 分）
5. `gel_mold.scad` ×3（並列、60 分）

合計約 2.5 時間。一晩走らせれば翌朝に揃う。

遮光ボックス（暗室必須の本格運用に進む段階で印刷、サイズ大）：

5. `enclosure.scad`（`display_mode = 0` で本体、180 × 180 × 100 mm、推定 8〜12 時間、最大の部品）
6. `enclosure.scad`（`display_mode = 1` で蓋、推定 2〜3 時間）

ボックスは Bambu Lab A1 mini のビルドプレート (180 × 180 mm) ぎりぎり。スカートを 0 にし、
ベッドレベリングを十分取ってから走らせること。

> 並列印刷ヘルパ：`gel_mold.scad` 末尾に `gel_mold_trio()` モジュールあり。
> PDMS-CLEAR / 黒染料入り / 白染料入り の 3 種を同時硬化したい時は、
> 既定の `gel_mold();` をコメントアウトして `gel_mold_trio();` を有効化する。

## 組み立て手順

### Phase 0 装置組立 — LED back cap 装着

1. LED 砲弾を `led_fiber_coupler` の LED 穴（z=0 端面、底面側）に挿入する。
2. LED のリード線 2 本を `led_back_cap` の Ø1.2mm 穴（ピッチ 2.54mm）に通す。
3. `led_back_cap` の圧入部（上面突起）を `led_fiber_coupler` の LED 穴に押し込み、円盤フランジが coupler 底面に密着する位置まで進める。
4. LED が完全に固定され、リード線だけが back cap の下面から出ている状態を確認する。
5. リード線を Arduino 側の 5V / GND（150Ω 抵抗経由）に接続する。

## 組立確認チェックリスト

- [ ] POF が `bend_jig_r10` の溝に滑らかに収まる（押し込み時にコア破損なし）
- [ ] POF 端面が `led_fiber_coupler` 内で LED 発光面に当接
- [ ] POF 反対端が `camera_fiber_coupler` のファイバーホルダ穴に挿入できる
- [ ] HQ Camera M12 がカメラクレードルにガタなく収まる
- [ ] `gel_mold` で硬化後、人肌のゲルが破損なく離型可能
- [ ] `weight_guide` が gel pad 上で安定して座る
- [ ] 蓋が本体にスッと被さり、外光が漏れないこと
- [ ] ケーブル通し穴がバッフル板で迷光遮蔽されていること
- [ ] 底面 M3 ナットトラップにナットが収まること
- [ ] `led_back_cap` が `led_fiber_coupler` の LED 穴に圧入できる
- [ ] LED リード線が back cap の小穴を通って外部に出ている
- [ ] back cap 装着後、coupler 底面から LED 光が漏れないこと（暗室で目視確認）

## 既知の調整ポイント

1. **`camera_to_fiber_distance_mm = 70`**：暫定値。Phase 0 で SC0947（焦点距離 2.7mm、最短 5cm 程度）の実測ピント距離を確認後、`params.scad` を更新して `camera_fiber_coupler.scad` を再印刷。
2. **POF ジャケット仕様**：CK-40E1 に PE ジャケットがない場合、熱収縮チューブ（1.5mm ID, AWG #16 用）でジャケット相当を作成。`bend_jig_r10` の溝幅に余裕があるので追加加工不要。
3. **センサ Z 高さ整合**：`camera_fiber_coupler.scad` 内で
   `sensor_center_z = plate_z + hq_body_height_mm / 2 = 23 mm` と推定し、
   `rail_top_z = sensor_center_z + slot_depth/2 = 25 mm` でホルダ穴と整合させている。
   Phase 0 でカメラ実装位置を実測し、ズレがあれば `params.scad` の
   `hq_body_height_mm` を補正するか、レール高さを直接調整する。

## 材料・離型の補足（gel_mold）

- 人肌のゲルはウレタン系。型材との相性は信越シリコーン「バリヤーコート No.7」が推奨だが、
  3D プリント PETG / PLA 直接でも離型可能（要 剥離フィルム or テフロンテープ補助）。
- `gel_mold.scad` の四隅突起（`ejection_bumps()`）が離型補助になる。
- 上面外周 0.5mm フィレットは怪我防止と取り出しやすさのため。

## OpenSCAD 注意

- `rotate_extrude(angle=...)` は OpenSCAD 2019.05 以降の機能。古いバージョンでは
  `bend_jig_r10.scad` の U 字溝が描画できないので、最新版を使うこと。
- `$fn = 60` を `params.scad` で固定。POF 穴 (φ1.2) のような小径は十分丸く出る一方、
  大径シリンダ（クレードル等）の処理時間は許容範囲。
