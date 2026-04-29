// ============================================
// gel_mold.scad
// 30 x 30 x 3 mm のゲル/PDMS パッドを成形するモールド。
// 抜き勾配 1°、底面四隅に離型補助突起、上面外周に 0.5mm フィレット、
// 一辺の上部に overflow 切欠き。
// 印刷向き：開口部を上、底面 build plate 密着、ironing 推奨。サポート不要。
// ============================================

include <params.scad>

// --- 外形 ---
mold_outer_x = pad_size_mm + 2 * mold_wall_mm;          // 30 + 8 = 38
mold_outer_y = pad_size_mm + 2 * mold_wall_mm;          // 38
mold_outer_z = mold_floor_mm + pad_thickness_mm + 1;    // 3 + 3 + 1 = 7

// 上面外周のフィレット半径
top_fillet_r = 0.5;

// オーバーフロー切欠き（一辺上部）
overflow_w = 5;
overflow_d = 1;

// 底面離型用突起
bump_d = 2;
bump_h = 1;
bump_inset = 4;   // キャビティ床の隅から内側へどれだけ寄せるか

// キャビティのテーパ：底（小）→ 開口（大）
taper_delta_per_side = tan(mold_taper_deg) * pad_thickness_mm;
top_pad_size_mm = pad_size_mm + 2 * taper_delta_per_side;

eps = 0.01;

module rounded_top_box(x, y, z, r) {
    // 下半分は平らな箱、上面外周だけ半径 r で丸める
    hull() {
        cube([x, y, z - r]);
        for (cx = [r, x - r], cy = [r, y - r])
            translate([cx, cy, z - r])
                sphere(r = r);
    }
}

module tapered_cavity() {
    // キャビティは「テーパ部 (PDMS 充填領域)」+「ストレート開口部 (rim を貫通)」の
    // 2 段構成。前者だけでは外形 (mold_outer_z = 7) と pad_thickness_mm (3) +
    // mold_floor_mm (3) の差 1mm がフタになって上面が閉じてしまう。

    // (1) PDMS 充填領域：1° の抜き勾配付き、高さ = pad_thickness_mm
    translate([mold_outer_x / 2, mold_outer_y / 2, mold_floor_mm])
        linear_extrude(
            height = pad_thickness_mm,
            scale  = top_pad_size_mm / pad_size_mm
        )
            square([pad_size_mm, pad_size_mm], center = true);

    // (2) Rim 開口部：垂直壁で外形天面 (+ フィレット分) を確実に貫通させる
    rim_clear_h = mold_outer_z - mold_floor_mm - pad_thickness_mm
                  + top_fillet_r + 2 * eps;
    translate([mold_outer_x / 2, mold_outer_y / 2,
               mold_floor_mm + pad_thickness_mm - eps])
        linear_extrude(height = rim_clear_h)
            square([top_pad_size_mm, top_pad_size_mm], center = true);
}

module overflow_notch() {
    // +Y 側の壁の上端を 5mm 幅 × 1mm 深さで切り欠き
    translate([
        (mold_outer_x - overflow_w) / 2,
        mold_outer_y - mold_wall_mm + eps,
        mold_outer_z - overflow_d
    ])
        cube([overflow_w, mold_wall_mm + 2 * eps, overflow_d + eps]);
}

module bottom_bumps() {
    // 外側底面 (z = 0) から下方向に 1mm 突き出すフット 4 個。
    // 役割：(a) 離型時にモールドを反転させた時、開口部 rim がベンチに密着するのを
    //   防ぐ。(b) Bottom View 検証で位置確認が可能になる。
    // pad 領域 XY 直下、bump_inset で隅から内側に寄せて配置する。
    cavity_x0 = (mold_outer_x - pad_size_mm) / 2;
    cavity_y0 = (mold_outer_y - pad_size_mm) / 2;
    for (dx = [bump_inset, pad_size_mm - bump_inset],
         dy = [bump_inset, pad_size_mm - bump_inset])
        translate([cavity_x0 + dx, cavity_y0 + dy, -bump_h])
            cylinder(d = bump_d, h = bump_h);
}

module gel_mold() {
    union() {
        difference() {
            rounded_top_box(mold_outer_x, mold_outer_y, mold_outer_z, top_fillet_r);
            tapered_cavity();
            overflow_notch();
        }
        bottom_bumps();
    }
}

// --- 並列印刷ヘルパ ---
// PDMS-CLEAR / 染料入り 等、複数同時硬化したい場合に使う。
// デフォルトは 1 個レンダ。トリオを出したい時は下行を有効化。
module gel_mold_trio() {
    gap = 2;
    for (i = [0, 1, 2])
        translate([i * (mold_outer_x + gap), 0, 0])
            gel_mold();
}

gel_mold();
// gel_mold_trio();
