// ============================================
// bend_jig_r10.scad
// POF を R=10mm の U字（180°）に拘束する治具。
// 上面はフラット、ゲルパッド（35×35mm）が曲げ部全体を覆える広さ。
// 印刷向き：上面（U字溝側）を上向き。サポート不要。
// ============================================

include <params.scad>

// --- ローカル寸法 ---
plate_w = 60;          // x 方向
plate_d = 40;          // y 方向
plate_h = 6;           // z 方向（板厚）

bend_center_x = 40;    // U 字中心（プレート右寄り）
bend_center_y = 20;    // プレート Y 中央
inlet_y       = bend_center_y - bend_radius_mm;  // = 10
outlet_y      = bend_center_y + bend_radius_mm;  // = 30

// 溝形状：直径 pof_channel_width_mm の円筒を path に沿って差し引く。
// 円筒中心は plate_h より少し下に置き、上面に円弧の一部だけが顔を出す形。
// 深さ pof_channel_depth_mm 達成のため、軸位置 = plate_h - (depth - radius)。
channel_axis_z = plate_h - (pof_channel_depth_mm - pof_channel_width_mm / 2);

// 取付ネジ
mount_hole_d   = 3.5;          // M3 貫通クリアランス
mount_inset    = 5;            // 端からの距離

// 入口テーパ
taper_extra_d  = 1.0;
taper_len      = 1.0;

eps = 0.01;

module pof_straight_groove(y, length, x0 = 0) {
    // y 一定の直線溝を x = x0 - eps から +length の方向へ
    translate([x0 - eps, y, channel_axis_z])
        rotate([0, 90, 0])
            cylinder(d = pof_channel_width_mm, h = length + 2 * eps);
}

module pof_arc_groove() {
    // 半径 bend_radius_mm の半円弧。
    // rotate_extrude(angle=180) は 0°→180° の弧を生成し +X 開始。
    // それを Z 軸まわり -90° して開始位置を -Y にずらすと、
    //   始点 = (bend_center_x + 0, bend_center_y - R)  = (40, 10)
    //   経由 = (bend_center_x + R, bend_center_y    )  = (50, 20)
    //   終点 = (bend_center_x + 0, bend_center_y + R)  = (40, 30)
    // となり inlet/outlet 直線部に滑らかに接続する。
    translate([bend_center_x, bend_center_y, channel_axis_z])
        rotate([0, 0, -90])
            rotate_extrude(angle = 180)
                translate([bend_radius_mm, 0])
                    circle(d = pof_channel_width_mm);
}

module entry_taper(y) {
    // 入口側 (x=0) に 1mm のじょうご状テーパ
    translate([-eps, y, channel_axis_z])
        rotate([0, 90, 0])
            cylinder(
                d1 = pof_channel_width_mm + taper_extra_d,
                d2 = pof_channel_width_mm,
                h  = taper_len + eps
            );
}

module mount_holes() {
    for (xy = [
        [mount_inset,            mount_inset           ],
        [plate_w - mount_inset,  mount_inset           ],
        [mount_inset,            plate_d - mount_inset ],
        [plate_w - mount_inset,  plate_d - mount_inset ],
    ])
        translate([xy[0], xy[1], -eps])
            cylinder(d = mount_hole_d, h = plate_h + 2 * eps);
}

module bend_jig_r10() {
    difference() {
        // ベースプレート
        cube([plate_w, plate_d, plate_h]);

        // 直線部（入口・出口）。x = 0 から arc 接続点 (x = bend_center_x) まで。
        pof_straight_groove(inlet_y,  bend_center_x);
        pof_straight_groove(outlet_y, bend_center_x);

        // U 字曲げ部
        pof_arc_groove();

        // 入口テーパ
        entry_taper(inlet_y);
        entry_taper(outlet_y);

        // 4 隅 M3 貫通
        mount_holes();
    }
}

bend_jig_r10();
