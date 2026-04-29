# CLAUDE.md — fiberfeel-rig

このリポジトリは事前登録型実験（SBCE: Strict Boundary Controlled Experiment 運用）のリグです。
プレレジと解析仕様を独立に保存し、結果が出た後で解析を変えられない構造になっています。

## 自動編集禁止ファイル

以下のファイル／ディレクトリは Claude Code から **絶対に自動編集してはいけません**：

- `preregistration/2026-04-29_v1.md`
  - プレレジ v1 本体。凍結タグ前であっても、ユーザー以外による改変は禁止。
- `analysis/decision_rules.py`
  - プレレジ §10 の決定ルール実装。仕様と実装の乖離を防ぐため不可触。
- `data/raw/` 配下の既存ファイル
  - 生データは追記のみ。既存セッションの上書き・削除・改名はすべて禁止。
- `preregistration/deviations.md` の **既存エントリ**
  - 追記は許可。ただし過去エントリの削除・編集は禁止。

## 許可される操作

- `preregistration/deviations.md` への新規エントリ追記（テンプレート遵守、§12 参照）
- `measurement/capture.py`, `analysis/pipeline.py` の編集
- `measurement/run_config.yaml`, `analysis/roi_config.yaml`, `measurement/conditions.yaml` の編集
- `hardware/`, `reports/`, `README.md`, `.gitignore` の編集
- `data/raw/<新規 session_id>/` ディレクトリの作成（既存には触れない）
- `data/checksums.txt` への追記（既存行は変更しない）

## プレレジと解析コードの整合性

- 整合性チェックは可能。乖離を発見した場合は **プレレジを正とし、解析コード側を合わせる方向** で修正提案する。
- プレレジを書き換える方向の修正は不可（凍結対象、§13）。
- 整合性問題を発見したら、まず `deviations.md` への記録が必要かをユーザーに確認すること。

## 凍結対象（§13 参照、再掲）

測定開始後に変更不可：
- §2 仮説集合
- §3 予測マトリクス
- §6 条件定義
- §8 バイアス対策の枠組み
- §9 解析事前仕様
- §10 決定ルール

非凍結（実測値で確定後 v1.1 タグ）：
- §4 ExposureTime_us
- §5.1 σ_baseline、μ_baseline
- §5.2 ROI 中心 (cx, cy)・半径 r
- §6 random_seed

## 作業時の注意

- ファイルを編集する前に必ず読むこと（グローバル CLAUDE.md と一致）。
- 解析パイプラインに変更を入れる場合、プレレジ §9 の擬似コードと突き合わせて差分を明示すること。
- 「Positive 結果が出るまで延長」は決定ルール上禁止（§11）。Claude Code 側からそのような提案は出さないこと。
