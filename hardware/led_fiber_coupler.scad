// ============================================
// led_fiber_coupler.scad
// 5mm 砲弾型 LED と POF 端面を同軸に保持するシリンダ。
// 軸方向：LED 側 → POF 側 = +Z 方向。
// 印刷向き：軸を垂直に立て、LED 挿入側を上にして印刷。サポート不要。
// ============================================

include <params.scad>

// --- 外形 ---
coupler_d = 15;     // シリンダ直径
coupler_l = 18;     // 全長 = led_body_depth_mm (8) + pof_side_l (10)

// 各セグメント
pof_side_l         = coupler_l - led_body_depth_mm;   // = 10
lead_zagri_d       = 7.0;
side_monitor_d     = 1.5;

// M3 ナットトラップ（側面に配置、POF 中心軸を避ける位置）
nut_trap_z         = 14;     // POF 領域内、軸を貫通させても POF 穴 (φ1.2) と干渉しない位置
nut_across_flats   = 6.5;    // M3 ナットの二面幅
nut_pocket_depth   = 2.5;    // ナット厚
m3_clearance_d     = 3.4;    // M3 ねじ通し
m3_extra_engagement = 3.0;   // ナットの先までさらに通す距離

eps = 0.01;

module led_fiber_coupler() {
    difference() {
        cylinder(d = coupler_d, h = coupler_l);

        // --- LED 側 (z = 0 端面) ---
        // (1) LED 本体の埋め込み穴 φ5.1 × 8mm
        translate([0, 0, -eps])
            cylinder(d = led_diameter_mm, h = led_body_depth_mm + eps);

        // (2) リード逃げザグリ φ7 × 5mm（同じ端面、本体穴より浅く広い）
        translate([0, 0, -eps])
            cylinder(d = lead_zagri_d, h = led_lead_clearance_mm + eps);

        // --- POF 側 (z = coupler_l 端面) ---
        // POF チャネル φ1.2 × 10mm（LED 端面と突き当たる）
        translate([0, 0, coupler_l - pof_side_l])
            cylinder(d = pof_channel_width_mm, h = pof_side_l + eps);

        // --- 側面の光モニタ穴（任意）---
        // LED ↔ POF 接合面付近を視認できる位置（z = coupler_l/2 = 9）。
        // 直径方向に貫通。X 軸に沿わせる（ナットトラップは Y 軸方向で別位置）。
        translate([0, 0, coupler_l / 2])
            rotate([0, 90, 0])
                cylinder(d = side_monitor_d, h = coupler_d + 2, center = true);

        // --- 底面 M3 ナットトラップ（任意、ベンチ固定用）---
        // -Y 側の側壁から内側へ、POF 穴を避ける深さに収める。
        translate([0, -coupler_d / 2 - eps, nut_trap_z])
            rotate([-90, 0, 0]) {
                // ナット用ヘキサポケット（六角、二面幅 = nut_across_flats）
                cylinder(
                    d = nut_across_flats / cos(30),
                    h = nut_pocket_depth + eps,
                    $fn = 6
                );
                // ねじ通し穴（ナット越しにさらに少し通す）
                cylinder(
                    d = m3_clearance_d,
                    h = nut_pocket_depth + m3_extra_engagement + eps
                );
            }
    }
}

led_fiber_coupler();
