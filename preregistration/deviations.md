# 逸脱記録 (deviations log)

このファイルはプレレジ `2026-04-29_v1.md` §12 に従うプレレジからの逸脱を記録する。

## ルール

- **追記専用。** 過去エントリの削除・編集を禁止する（Claude Code への指示は `CLAUDE.md` 参照）。
- エントリは時系列順に下方向へ追加する。
- すべての逸脱は本ファイルへの記録後に実施すること。事後追記は理由を明示する。
- 1 件 1 ブロック。テンプレート逸脱は禁止。

## エントリテンプレート

各逸脱は以下の形式で追記する：

```
## YYYY-MM-DD HH:MM
- 逸脱内容：
- 理由：
- 影響範囲：
- 担当：Robosheep
```

---

<!-- ここから下に時系列で追記 -->

---

## 2026-05-03: σ_baseline measurement condition deviation

**Status**: Recorded prior to σ_baseline measurement.
**Affects**: §5.1 baseline measurement procedure, §11 prediction matrix
evaluation (operational definition of σ_baseline).
**Does NOT affect**: §10 decision rules, hypothesis statements (H0–H4),
condition definitions (C-P1-01 through C-P1-06).

### Preregistration §5.1 specifies

> "Direct fiber (no bend, no PDMS contact, no load), connected through
> the LED-fiber coupler to the camera-fiber coupler, with the enclosure
> closed. Acquire 300 frames at 1 fps."

### Actual measurement condition

bend_jig (R=10mm) is permanently installed in the apparatus during Phase 0
hardware construction. POF is routed through bend_jig as part of the
standard operating configuration. No physical fixture exists to hold POF
in a straight orientation without bend_jig, and hand-held positioning
does not provide reproducible "straight" geometry.

σ_baseline / μ_baseline will therefore be measured with:
- POF routed through bend_jig (R=10mm bend)
- No PDMS / no gel / no load
- LED on
- Same enclosure closure as Phase 1
- 300 frames at 1 fps
- ExposureTime_us = 2000 (Phase 0 calibrated value)

### Justification

1. **Phase 1 conditions (§6) all use bent-fiber configuration.** All six
   experimental conditions C-P1-01..C-P1-06 are defined with the fiber
   bent through bend_jig. Baseline measured in the same configuration
   provides a more directly relevant noise floor than a hypothetical
   straight-fiber baseline that is never realized in actual experiments.

2. **σ_baseline functions as operational noise floor.** All effect sizes
   in §11 prediction matrix are differences from this baseline. The
   straight-fiber σ would underestimate noise relative to the actual
   measurement environment, leading to over-confident statistical decisions
   in §10 decision rules.

3. **Bend-induced scattering is part of the apparatus, not the effect of
   interest.** H1 (evanescent coupling) and H2 (additional bend loss)
   are about *changes* in the measured signal due to PDMS/gel contact,
   not the baseline bend loss itself. A bend-aware baseline correctly
   isolates these effects.

### Implications for analysis pipeline

- σ_baseline (this measurement) is the denominator unit for all §11
  effect sizes.
- C-CTRL-DARK condition (LED off, §6) still serves as a check for purely
  electronic noise; comparison between (this baseline) and DARK isolates
  optical-system contributions.
- C-CTRL-SHAM condition (PDMS held 1mm above POF) tests whether non-contact
  PDMS introduces effects, using the same bent-fiber baseline.

### SBCE compliance

This deviation is recorded:
- BEFORE σ_baseline measurement is executed
- BEFORE any Phase 1 condition data is acquired
- BEFORE prereg-v1.1-frozen tag is applied

The deviation does not modify §10 decision rules, hypotheses, or condition
definitions. It only specifies the operational meaning of "σ_baseline" used
when comparing Phase 1 results to §11 predictions.

### Engineering context

Phase 0 hardware construction history (summarized):
- bend_jig_r10 was 3D-printed and integrated into the apparatus during
  Phase 0
- Multiple iterations of led_fiber_coupler (white→black, depth 18→24→26mm,
  led_back_cap added) addressed light leakage
- enclosure_lid was redesigned to remove handle through-hole
- σ_baseline measurement is the final Phase 0 step before
  prereg-v1.1-frozen and Phase 1 launch

---

## 2026-05-03 17:28: テンプレート違反訂正
- 逸脱内容：直前のエントリ（σ_baseline measurement condition deviation, commit e61985f）が冒頭ルール「テンプレート逸脱は禁止」に違反したため、訂正として直後にテンプレート準拠版を追記する
- 理由：技術的詳細を盛り込もうとして既存テンプレートを無視したため。既存エントリは「追記専用」ルールにより削除しないが、SBCE 規律として正式形式での記録を併存させる
- 影響範囲：deviations.md の運用上のみ。前エントリの技術的内容は次エントリに要約版で引き継ぐ
- 担当：Robosheep

---

## 2026-05-03 17:28: σ_baseline 測定構成の逸脱
- 逸脱内容：σ_baseline / μ_baseline 測定を、§5.1 が要求する「直線ファイバー」ではなく bend_jig (R=10mm) 装着状態で実施する。POF は bend_jig を通って曲がった状態のまま、PDMS / gel 無し、無加重、LED on、enclosure 閉、ExposureTime_us=2000、300 フレーム × 1 fps で取得する
- 理由：Phase 1 全条件 (C-P1-01..06) は bend_jig 装着構成で実施されるため、同一構成で測定したノイズフロアの方が effect size 評価に直接的。直線ファイバーを再現性よく保持する物理ジグが存在しない
- 影響範囲：σ_baseline の運用的定義のみ。§10 判定ルール、仮説 H0–H4、条件定義 (C-P1-01..06, C-CTRL-*) は不変。詳細は commit e61985f のエントリ参照
- 担当：Robosheep
