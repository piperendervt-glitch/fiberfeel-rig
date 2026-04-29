// ============================================
// weight_guide.scad
// ゲルパッド上に錘 (0..50 g) を中心配置するためのガイドプレート。
// 上面：錘が座る円形凹み。底面：（任意の）十字リブで接触面積を限定。
// 印刷向き：凹み側を上に。凹み内面に ironing 推奨。
// ============================================

include <params.scad>

guide_x = weight_pad_outer_mm;        // 35
guide_y = weight_pad_outer_mm;        // 35
guide_z = 7;

recess_d = weight_recess_diameter_mm;        // 25
recess_h = weight_recess_depth_mm;           // 5

// 十字リブ（接触面積を中心 1 点近傍に集約）
rib_thickness = 0.5;     // ゲル接触面からの突き出し厚（z 方向）
rib_width     = 4;       // リブの幅（X 軸リブの Y 幅、Y 軸リブの X 幅）

eps = 0.01;

module weight_recess() {
    // 上面 (z = guide_z) から深さ recess_h、底は平面
    translate([guide_x / 2, guide_y / 2, guide_z - recess_h])
        cylinder(d = recess_d, h = recess_h + eps);
}

module bottom_cross_rib() {
    // 底面 (z = 0) から下方向に rib_thickness 突き出す十字。
    // ゲル接触面積を中心の細い領域に絞り、加重を中心に集中させる。
    translate([(guide_x - rib_width) / 2, 0, -rib_thickness])
        cube([rib_width, guide_y, rib_thickness]);
    translate([0, (guide_y - rib_width) / 2, -rib_thickness])
        cube([guide_x, rib_width, rib_thickness]);
}

module weight_guide(with_rib = true) {
    union() {
        difference() {
            cube([guide_x, guide_y, guide_z]);
            weight_recess();
        }
        if (with_rib)
            bottom_cross_rib();
    }
}

// --- レンダ選択 ---
// 比較実験用に「リブ有り」「リブ無し」の 2 形態を用意。
// 既定はリブ有り。リブ無し版を印刷したい場合は下行を切り替える。
weight_guide(with_rib = true);
// weight_guide(with_rib = false);
