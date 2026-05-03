// ============================================
// led_fiber_coupler.scad
// 5mm 砲弾型 LED と POF 端面を同軸に保持するシリンダ。
// 軸方向：LED 側 → POF 側 = +Z 方向。
// 印刷向き：軸を垂直に立て、LED 挿入側（z=0）を build plate 側にして印刷。サポート不要。
//
// z マップ（底面 z=0 から）:
//   z =  0 ..  5   Ø7    リード逃げザグリ（led_back_cap の Ø6.9 boss が圧入される）
//   z =  5 .. 15   Ø5.1  LED 本体穴（10mm、LED 砲弾 8mm を余裕をもって収納）
//   z = 15 .. 16   実体  LED 上面と POF 端面を隔てる 1mm の壁
//   z = 16 .. 26   Ø1.8  POF 縦穴
// ============================================

include <params.scad>

// --- 外形 ---
coupler_d = 15;                                            // シリンダ直径

// セグメント長（積み上げ式に定義）
led_pof_wall_t   = 1.0;                                    // LED 上面と POF 端面の間の壁厚
pof_side_l       = 10.0;                                   // POF 縦穴の長さ
coupler_l        = led_lead_clearance_mm                   // 5
                 + led_body_depth_mm                       // 10
                 + led_pof_wall_t                          // 1
                 + pof_side_l;                             // 10  → 計 26

lead_zagri_d     = 7.0;
side_monitor_d   = 1.5;

// LED 本体穴の z 開始位置（リード逃げの上に積む）
led_body_z0      = led_lead_clearance_mm;                  // = 5
// POF 縦穴の z 開始位置（壁の上）
pof_z0           = led_body_z0 + led_body_depth_mm + led_pof_wall_t;  // = 16

// M3 ナットトラップ（POF セクション中央付近）
nut_trap_z         = pof_z0 + pof_side_l / 2;              // = 21
nut_across_flats   = 6.5;
nut_pocket_depth   = 2.5;
m3_clearance_d     = 3.4;
m3_extra_engagement = 3.0;

eps = 0.01;

module led_fiber_coupler() {
    difference() {
        cylinder(d = coupler_d, h = coupler_l);

        // --- LED 側 (z = 0 端面) ---
        // (1) リード逃げザグリ Ø7 × 5mm（底面端から）
        translate([0, 0, -eps])
            cylinder(d = lead_zagri_d, h = led_lead_clearance_mm + eps);

        // (2) LED 本体の埋め込み穴 Ø5.1 × 8mm（リード逃げの上に積む）
        translate([0, 0, led_body_z0])
            cylinder(d = led_diameter_mm, h = led_body_depth_mm);

        // --- POF 側 (z = coupler_l 端面) ---
        // POF チャネル Ø1.8 × 10mm（縦穴の熱収縮を見込んで径を大きく取る）
        translate([0, 0, pof_z0])
            cylinder(d = pof_channel_width_led_side_mm, h = pof_side_l + eps);

        // --- 側面の光モニタ穴（任意）---
        // LED 上面と POF 端面の間の壁（z=15..16）を貫く位置で、両側を覗ける。
        // 直径方向に貫通。X 軸に沿わせる。
        translate([0, 0, led_body_z0 + led_body_depth_mm + led_pof_wall_t / 2])  // = 15.5
            rotate([0, 90, 0])
                cylinder(d = side_monitor_d, h = coupler_d + 2, center = true);

        // --- 側面 M3 ナットトラップ（任意、ベンチ固定用）---
        // -Y 側の側壁から内側へ。POF 中心穴 (Ø1.8) には届かない深さ。
        translate([0, -coupler_d / 2 - eps, nut_trap_z])
            rotate([-90, 0, 0]) {
                cylinder(
                    d = nut_across_flats / cos(30),
                    h = nut_pocket_depth + eps,
                    $fn = 6
                );
                cylinder(
                    d = m3_clearance_d,
                    h = nut_pocket_depth + m3_extra_engagement + eps
                );
            }
    }
}

led_fiber_coupler();
