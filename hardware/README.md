# hardware/

3D プリント部品とジグの設計ファイル。詳細仕様はプレレジ §4 を正とする。

## 予定される部品

| 部品 | ファイル | 用途 |
|---|---|---|
| ベンドジグ | `bend_jig_R10.scad` (TBD) | R=10 mm の固定曲げを与えるチャンネル付きホルダ。`channel_width_mm: 1.2`, `channel_depth_mm: 0.7`。 |
| エンクロージャ | `enclosure.scad` (TBD) | 黒色フィラメント製の遮光ボックス。Pi HQ Camera と LED ホルダを内蔵。 |
| LED ホルダ | `led_holder.scad` (TBD) | 650 nm LED を定位置で保持。ファイバ端面とのアライメント用。 |
| カメラマウント | `camera_mount.scad` (TBD) | Pi HQ Camera の取付ブラケット。ファイバ端面とのワーキングディスタンス固定。 |
| PDMS スペーサ | `sham_spacer_1mm.scad` (TBD) | C-CTRL-SHAM 用、PDMS パッドを 1 mm 浮かせる。 |

## プリント条件（推奨）

- 材料：黒色 PETG または黒色 PLA（プレレジ §4 `jig.print_material`, `enclosure.material`）
- 充填：30%, ウォール 3 周以上（剛性とフラットネス確保のため）
- 層厚：0.2 mm（チャンネル底面の段差を抑制）
- ベンドジグの曲げ R は g-code 出力後にノギスで実測検証すること。

## 検証

- ベンドジグ：実装後にノギスで内側 R を 10 mm ± 0.2 mm に収まっているか確認。
- エンクロージャ：プレレジ §8.4 の C-CTRL-DARK で μ_baseline の 1% 以下を確認できなければ再構築。

設計ファイル（`*.scad` / `*.stl` / `*.3mf`）は確定次第このディレクトリにコミットする。
