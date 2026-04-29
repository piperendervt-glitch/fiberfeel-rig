# fiberfeel-rig

光ファイバーマクロベンド領域における PDMS エバネッセント結合効果の事前登録型検証実験リグ。

## 概要

POF（Plastic Optical Fiber）のクラッド露出領域に PDMS が密着した際、屈折率近接によりエバネッセント波が漏出して伝送光量が機械的曲率変化（ベンドロス）とは独立に減少することを実験的に検証する。

実験仕様の正は `preregistration/2026-04-29_v1.md`。

## 運用方針 (SBCE)

このリポジトリは事前登録型実験（**SBCE: Strict Boundary Controlled Experiment**）の運用例。
測定開始前にプレレジを git タグで凍結し、結果を見てから解析や仮説を変える経路を遮断する。

### Phase 区分とプレレジ管轄

| Phase | プレレジ管轄 | 実行ツール |
|---|---|---|
| Phase 0: 動作検証 | **管轄外**（engineering shakedown） | `python -m measurement.capture --mode shakedown` |
| Phase 1: 仮説切り分け | 管轄内（凍結後） | `--mode baseline` で σ_baseline 確定 → `--mode phase1` |
| Phase 2: 次元スイープ | 管轄内 | Phase 1 で `D-H1-SUPPORT` または `D-H3-CHECK` 発火後のみ |
| Phase 3: 加重応答 | 管轄内 | Phase 2 完了後のみ |

Phase 0（shakedown）は機械可動チェック・露光当たり付け・遮光漏れ目視等に限定し、得られたフレームは `data/raw/` 配下にも `analysis/pipeline.py` の入力にも入れない。手元のエンジニアリングノートに残すまで。

### データ形式

Phase 1 以降は RAW フレームを numpy `.npy` で保存する：

```
data/raw/<session_id>/<condition_id>_<frame_idx:03d>.npy
data/raw/<session_id>/metadata.yaml      # capture 時刻、露光、ゲイン、condition_id 等
```

`pipeline.py` の `load_session_frames()` は `np.load` のみで読めるため、RAW デコーダ（rawpy / libraw）への依存を持たない。

### 凍結とタグ

- `prereg-frozen` … プレレジ v1 本文の凍結ポイント。タグ作成日時が Phase 1 開始時刻の客観証拠（プレレジ §14）。
- `prereg-v1.1-frozen` … 非凍結項目（ExposureTime_us、random_seed、σ_baseline、μ_baseline、ROI 中心座標と半径）が確定した時点。

凍結後は `preregistration/2026-04-29_v1.md` を編集しない。実運用上の逸脱はすべて `preregistration/deviations.md` への追記として記録する（追記専用、過去エントリの編集禁止、プレレジ §12）。

### Claude Code との関係

`CLAUDE.md` で以下を自動編集禁止に設定している：

- `preregistration/2026-04-29_v1.md`（プレレジ本体）
- `analysis/decision_rules.py`（§10 決定ルールの実装）
- `data/raw/` 配下の既存セッション
- `preregistration/deviations.md` の既存エントリ（追記は許可）

詳細は `CLAUDE.md` と `preregistration/2026-04-29_v1.md` を参照。

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
│   ├── capture.py           # picamera2 で RAW 取得 (shakedown / baseline / phase1)
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

- プレレジ v1: 凍結済み（タグ `prereg-frozen`）
- v1.1（非凍結項目の実測値確定）: 未押下（ExposureTime_us、random_seed、σ_baseline、ROI が埋まり次第 `prereg-v1.1-frozen` を打つ）

詳細な凍結手続は `preregistration/2026-04-29_v1.md` §14。
