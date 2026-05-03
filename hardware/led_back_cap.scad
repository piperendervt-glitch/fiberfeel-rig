// ============================================
// led_back_cap.scad
// LED 砲弾の根元（リード側）を密閉する遮光蓋。
// led_fiber_coupler の LED 挿入穴（z=0 端面）に底面側から圧入し、
// LED の側方／後方放射が coupler 底面から漏れるのを止める。
// 軸方向：圧入突起 = +Z 方向。
// 印刷向き：円盤を build plate に密着、突起を上向き。サポート不要。
// 推奨：黒 PETG / 黒 PLA、infill 50% 以上（光漏れ防止）。
// ============================================

include <params.scad>

$fn = 64;

module led_back_cap() {
    difference() {
        union() {
            // ベース円盤（外径 = led_fiber_coupler 外径）
            cylinder(
                d = led_back_cap_diameter_mm,
                h = led_back_cap_thickness_mm
            );
            // 圧入用突起（led_fiber_coupler の LED 穴に嵌める）
            translate([0, 0, led_back_cap_thickness_mm])
                cylinder(
                    d = led_back_cap_press_fit_diameter_mm,
                    h = led_back_cap_press_fit_depth_mm
                );
        }

        // LED リード線通し穴 ×2（標準 0.1" ピッチ = 2.54mm）
        for (x = [-led_back_cap_lead_hole_pitch_mm / 2,
                   led_back_cap_lead_hole_pitch_mm / 2]) {
            translate([x, 0, -0.5])
                cylinder(
                    d = led_back_cap_lead_hole_diameter_mm,
                    h = led_back_cap_thickness_mm
                        + led_back_cap_press_fit_depth_mm + 1
                );
        }
    }
}

led_back_cap();
