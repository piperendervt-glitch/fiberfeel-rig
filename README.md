# fiberfeel-rig

光ファイバーマクロベンド領域における PDMS エバネッセント結合効果の事前登録型検証実験リグ。

## 概要

POF（Plastic Optical Fiber）のクラッド露出領域に PDMS が密着した際、屈折率近接によりエバネッセント波が漏出して伝送光量が機械的曲率変化（ベンドロス）とは独立に減少することを実験的に検証する。

詳細は `preregistration/2026-04-29_v1.md` を参照。

## ディレクトリ構成

```
fiberfeel-rig/
├── CLAUDE.md                # Claude Code 向け編集ルール
├── README.md
├── LICENSE                  # コード MIT
├── LICENSE-docs             # ドキュメント CC-BY-4.0
├── preregistration/         # プレレジ本文と逸脱ログ
│   ├── 2026-04-29_v1.md     # 凍結対象、編集禁止
│   └── deviations.md        # 追記専用
├── hardware/                # 3D プリント部品 (.scad は後追加)
├── measurement/             # 測定ソフトウェア
│   ├── capture.py           # picamera2 で RAW 取得
│   ├── conditions.yaml      # §6 機械可読版
│   └── run_config.yaml      # 測定直前に random_seed と ExposureTime_us を確定
├── analysis/                # 解析パイプライン
│   ├── pipeline.py          # §9 の実装
│   ├── decision_rules.py    # §10 の実装、編集禁止
│   └── roi_config.yaml      # §5.2 確定後にコミット
├── data/
│   ├── raw/                 # RAW フレーム（git 管理外）
│   └── checksums.txt        # SHA-256 ログ
└── reports/                 # 結果レポート
```

## ライセンス

- コード（`*.py`, `*.scad` 等）: MIT License (`LICENSE`)
- ドキュメント・プレレジ・データ: CC-BY-4.0 (`LICENSE-docs`)

## ステータス

- プレレジ v1: DRAFT（凍結タグ未押下）
- 凍結タグ: `prereg-frozen`（v1.1 確定値は `prereg-v1.1-frozen`）

詳細な凍結手続は `preregistration/2026-04-29_v1.md` §14。
