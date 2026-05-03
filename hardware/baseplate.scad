// ============================================
// baseplate.scad
// Phase 1 装置のベースプレート。enclosure 床上に M3×4 で固定し、
// その上に bend_jig（昇降パッド経由）, camera_fiber_coupler, led_cradle を載せる。
//
// 座標系：左下隅原点。+X / +Y は enclosure 内部と同方向。
//   - bend_jig は (115..175, 67.5..107.5)、上に 17.1mm の昇降パッド統合
//   - camera_fiber_coupler 4 隅 M3 ボス：(5, 72.5),(115, 72.5),(5, 122.5),(115, 122.5)
//   - led_cradle 4 隅 M3 ボス（camera プレート貫通）：params.scad で計算済
//   - 4 隅 M3 通し穴（enclosure 既存ナットトラップ整合、inset 17.5）
//
// 印刷向き：底面を build plate に密着、昇降パッドは下から上方向。サポート不要。
// ============================================

include <params.scad>

eps = 0.01;

// ----------------------------------------------------------------
// 4 隅 M3 通し穴 + boss 逃げ座面（enclosure 床の Ø12 boss を逃がす）
// ----------------------------------------------------------------
module corner_mount_holes() {
    for (xi = [baseplate_mount_inset_mm,
               baseplate_x_mm - baseplate_mount_inset_mm])
        for (yi = [baseplate_mount_inset_mm,
                   baseplate_y_mm - baseplate_mount_inset_mm]) {
            // M3 通し穴
            translate([xi, yi, -eps])
                cylinder(d = m3_clearance_d_common_mm,
                         h = baseplate_thickness_mm + 2 * eps);
            // 底面側 Ø13×1.6mm 座面（enclosure 床 boss 逃げ）
            translate([xi, yi, -eps])
                cylinder(d = baseplate_boss_clear_d_mm,
                         h = baseplate_boss_clear_h_mm + eps);
        }
}

// ----------------------------------------------------------------
// camera_fiber_coupler 4 隅マウント（M3 セルフタップ Ø2.7、深さ baseplate 厚分）
// camera プレートの 4 隅は part-local (0,0),(120,0),(0,60),(120,60)。
// camera_origin = (0, 67.5) で配置するため baseplate 座標 = part-local + origin。
// 各隅から内側 inset (5mm) の位置に M3 穴。
// ----------------------------------------------------------------
module camera_coupler_mount_holes() {
    inset = camera_coupler_mount_inset_mm;
    for (xi = [inset, 120 - inset])
        for (yi = [inset, 60 - inset]) {
            x = camera_coupler_origin_x_mm + xi;
            y = camera_coupler_origin_y_mm + yi;
            translate([x, y, -eps])
                cylinder(d = m3_clearance_d_common_mm,
                         h = baseplate_thickness_mm + 2 * eps);
        }
}

// ----------------------------------------------------------------
// led_cradle 4 隅マウント（baseplate に貫通穴、cradle 底まで）
// ボルトは cradle 底 → camera プレート → baseplate を貫通し、baseplate 底でナット止め。
// ----------------------------------------------------------------
module led_cradle_mount_holes() {
    for (xi = led_cradle_bolts_part_local_x)
        for (yi = led_cradle_bolts_part_local_y) {
            x = camera_coupler_origin_x_mm + xi;
            y = camera_coupler_origin_y_mm + yi;
            translate([x, y, -eps])
                cylinder(d = m3_clearance_d_common_mm,
                         h = baseplate_thickness_mm + 2 * eps);
            // 底面側 M3 ナットポケット
            translate([x, y, -eps])
                rotate([0, 0, 30])
                    cylinder(d = m3_nut_pocket_d_mm,
                             h = m3_nut_pocket_h_mm + eps,
                             $fn = 6);
        }
}

// ----------------------------------------------------------------
// bend_jig 昇降パッド：bend_jig の底面サイズ 60×40 ぶん、高さ 17.1mm
// 上面に bend_jig 4 隅 M3 用ナットポケット
// （bend_jig.scad は 4 隅 Ø3.5 通しなので、ボルトは bend_jig 上から → 昇降下面ナットへ）
// ----------------------------------------------------------------
module bend_jig_riser() {
    bj_x0 = bend_jig_origin_x_mm;
    bj_y0 = bend_jig_origin_y_mm;
    difference() {
        translate([bj_x0, bj_y0, baseplate_thickness_mm])
            cube([60, 40, bend_jig_riser_h_mm]);

        // bend_jig の 4 隅 M3 mount_inset = 5mm 位置に対応する貫通穴 + ナット
        for (xi = [5, 60 - 5])
            for (yi = [5, 40 - 5]) {
                translate([bj_x0 + xi, bj_y0 + yi,
                           baseplate_thickness_mm - eps])
                    cylinder(d = m3_clearance_d_common_mm,
                             h = bend_jig_riser_h_mm + 2 * eps);
                // 上端側からのナットポケット（bend_jig 底面と接する側）
                translate([bj_x0 + xi, bj_y0 + yi,
                           baseplate_thickness_mm + bend_jig_riser_h_mm
                           - m3_nut_pocket_h_mm])
                    rotate([0, 0, 30])
                        cylinder(d = m3_nut_pocket_d_mm,
                                 h = m3_nut_pocket_h_mm + eps,
                                 $fn = 6);
            }
    }
}

// ----------------------------------------------------------------
// ベースプレート本体
// ----------------------------------------------------------------
module baseplate() {
    union() {
        difference() {
            cube([baseplate_x_mm, baseplate_y_mm, baseplate_thickness_mm]);
            corner_mount_holes();
            camera_coupler_mount_holes();
            led_cradle_mount_holes();
        }
        bend_jig_riser();
    }
}

baseplate();
