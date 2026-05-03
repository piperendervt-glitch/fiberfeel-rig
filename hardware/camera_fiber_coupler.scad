// ============================================
// camera_fiber_coupler.scad
// Pi HQ Camera M12 をクレードル（コの字 + 上面開放 + 前面開放）で保持し、
// 対面のレールで POF ホルダを T 字スロットでスライド固定するベース
// + 別パーツのファイバーホルダ。
//
// 印刷向き：
//   - ベースはプレートをフラットに置いて印刷
//     （クレードル開口部が上向きなのでサポート不要）
//   - ファイバーホルダは POF 穴を水平にして印刷（穴の真円度確保）
// ============================================

include <params.scad>

// --- ベースプレート ---
plate_x = 120;
plate_y = 60;
plate_z = 4;

// --- カメラクレードル：コの字（後ろ + 左右壁、前面と上面は開放）---
back_wall_t      = 2;                              // 後ろ壁厚 (X 方向、x = 0..back_wall_t)
side_wall_t      = 2;                              // 左右壁厚 (Y 方向)

cradle_x         = 40;                             // クレードル占有 X 領域（spec）
cradle_inner_x   = hq_body_depth_mm;               // 19、カメラ奥行（レンズ方向）
cradle_inner_y   = hq_body_width_mm + 0.5;         // 38.5、嵌合クリアランス
cradle_h         = hq_body_height_mm + 2;          // 40、壁の高さ（カメラ上面 + 2mm）

cradle_y_outer   = cradle_inner_y + 2 * side_wall_t;     // = 42.5
cradle_y_offset  = (plate_y - cradle_y_outer) / 2;       // = 8.75
cradle_inner_y0  = cradle_y_offset + side_wall_t;        // = 10.75（cavity Y 開始）

// カメラはクレードル内でプレート上面 (z = plate_z) に直置き想定。
// センサ中心高さ：body 中央近傍と仮定（spec「センサーは body 中心から 0–4mm 程度」）。
sensor_center_z  = plate_z + hq_body_height_mm / 2;       // = 4 + 19 = 23

// --- ファイバーアーム / レール / スロット ---
arm_x_start      = cradle_x;                       // 40、クレードル直後から
arm_x_end        = plate_x;                        // 120
arm_x_len        = arm_x_end - arm_x_start;        // = 80

slot_w           = 8;
slot_l           = fiber_arm_slot_length_mm;       // 40
slot_depth       = 4;                              // spec §「T字スロット ... 深さ 4mm」
rail_y_outer     = 16;                             // スロット壁含むレール幅

// --- ファイバーホルダの主寸法 ---
holder_x         = 25;                             // スライド方向の長さ
holder_y         = 25;
holder_z         = 30;                             // 高さ
key_h            = slot_depth;                     // T 字キー高 = スロット深 = 4
key_w            = slot_w;                         // T 字キー幅 = スロット幅 = 8

// ----------------------------------------------------------------
// ★ 修正2 — ホルダ POF 穴の Z 整合（明示計算）
// ----------------------------------------------------------------
// fiber_hole_z_in_block_mm: ホルダ ブロック底面からの POF 穴中心高さ。
// holder_z = 30 のジオメトリ中央に置く（=15）→ 印刷向きが反転しても対称。
fiber_hole_z_in_block_mm = holder_z / 2;           // = 15

// rail_top_z の決め方は次の制約から逆算：
//   ホルダ世界 hole z = rail_top_z + fiber_hole_z_in_block_mm = sensor_center_z
//                    => rail_top_z = sensor_center_z - fiber_hole_z_in_block_mm
//                                  = 23 - 15 = 8 mm
// 旧コードの "rail_top_z = sensor_center_z + slot_depth/2 = 25" は誤り
// （ホルダ底をレール上に乗せるとホルダ穴がレール上面 +15mm = 40mm に行く）。
rail_top_z       = sensor_center_z - fiber_hole_z_in_block_mm;   // = 8
rail_height      = rail_top_z - plate_z;                         // = 4

slot_z_top       = rail_top_z;                                   // = 8
slot_z_bottom    = slot_z_top - slot_depth;                      // = 4 = plate_z
                                                                 // → スロット底はプレート上面に一致
                                                                 //   （4mm レールに 4mm 深スロット = レール底材無し）

// 整合チェック（コメントとして数値を残す）：
//   fiber_hole_world_z = rail_top_z + fiber_hole_z_in_block_mm
//                      = 8 + 15 = 23 mm
//   sensor_center_z    = 23 mm
//   |差| = 0 mm  → 許容 22..24 内。OK。
// もし実機で大きくずれる場合は hq_body_height_mm を補正するか、
// fiber_hole_z_in_block_mm を 14..17 の範囲で調整して再印刷。
fiber_hole_world_z = rail_top_z + fiber_hole_z_in_block_mm;      // = 23（参考値）

// レール / スロット位置（XY）
rail_y_start     = (plate_y - rail_y_outer) / 2;
slot_x_start     = arm_x_start + (arm_x_len - slot_l) / 2;
slot_y_start     = (plate_y - slot_w) / 2;

// 固定ねじ
m3_clearance_d   = 3.4;
clamp_pitch      = 10;

// 通気スリット（クレードル床のセンサ直下、プレート貫通）
vent_n           = 4;
vent_w           = 3;
vent_pitch       = 5;
vent_x0          = 4;

// アパーチャ
aperture_w       = 5;
aperture_h       = 5;
aperture_depth   = 3;

eps = 0.01;

// ============================================
// (1) ベース + クレードル(コの字) + ファイバーアームレール
// ============================================
module camera_fiber_coupler_base() {
    difference() {
        union() {
            // ベースプレート
            cube([plate_x, plate_y, plate_z]);

            // ★ 修正1 — クレードルは加算的に「3 壁」のみ構築。
            // 前面 (+X) と上面 (+Z) は構造を一切置かない＝光路と上方装着が確保される。

            // 後ろ壁（-X 側、x = 0..back_wall_t）
            translate([0, cradle_y_offset, plate_z])
                cube([back_wall_t, cradle_y_outer, cradle_h]);

            // 左壁（-Y 側、y = cradle_y_offset..cradle_y_offset + side_wall_t）
            translate([0, cradle_y_offset, plate_z])
                cube([cradle_x, side_wall_t, cradle_h]);

            // 右壁（+Y 側）
            translate([0, cradle_y_offset + cradle_y_outer - side_wall_t, plate_z])
                cube([cradle_x, side_wall_t, cradle_h]);

            // ファイバーアームレール
            translate([arm_x_start, rail_y_start, plate_z])
                cube([arm_x_len, rail_y_outer, rail_height]);
        }

        // --- 床面通気スリット（プレート貫通、カメラ底面冷却） ---
        for (i = [0 : vent_n - 1])
            translate([
                vent_x0 + i * vent_pitch,
                cradle_inner_y0 + 5,
                -eps
            ])
                cube([
                    vent_w,
                    cradle_inner_y - 10,
                    plate_z + 2 * eps
                ]);

        // --- T 字スロット（rail 上面に開口、プレート上面まで貫通） ---
        translate([slot_x_start, slot_y_start, slot_z_bottom - eps])
            cube([slot_l, slot_w, slot_depth + 2 * eps]);

        // --- ホルダ固定 M3 クランプ穴（プレート底からレール頂部まで貫通）---
        // 旧コードはレールのみ貫通でプレート裏からの挿入不可だった。
        for (sx = [slot_x_start + clamp_pitch / 2
                   : clamp_pitch
                   : slot_x_start + slot_l - clamp_pitch / 2 + eps])
            translate([sx, plate_y / 2, -eps])
                cylinder(
                    d = m3_clearance_d,
                    h = plate_z + rail_height + 2 * eps
                );

        // --- HQ Camera M12 PCB 取り付け穴（後ろ壁を X 方向に貫通）---
        // PCB を後ろ壁前面に密着させる前提：
        //   PCB 中心 y = plate_y / 2 = 30、PCB 底面 z = plate_z = 4。
        //   穴中心 = PCB エッジから hq_mount_offset_mm、ピッチ hq_mount_pitch_mm。
        //   絶対座標：y ∈ {15, 45}, z ∈ {10.25, 40.25}（pitch 30mm）。
        for (dy = [-hq_mount_pitch_mm / 2, hq_mount_pitch_mm / 2])
            for (zc = [plate_z + hq_mount_offset_mm,
                       plate_z + hq_mount_offset_mm + hq_mount_pitch_mm])
                translate([-eps, plate_y / 2 + dy, zc])
                    rotate([0, 90, 0])
                        cylinder(
                            d = hq_mount_hole_d_mm,
                            h = back_wall_t + 2 * eps
                        );

        // --- baseplate 取付：plate 4 隅 M3 通し穴（外周 inset 5mm）---
        for (xi = [camera_coupler_mount_inset_mm,
                   plate_x - camera_coupler_mount_inset_mm])
            for (yi = [camera_coupler_mount_inset_mm,
                       plate_y - camera_coupler_mount_inset_mm])
                translate([xi, yi, -eps])
                    cylinder(d = m3_clearance_d_common_mm,
                             h = plate_z + 2 * eps);

        // --- bend_jig 昇降逃げ切欠き（plate +X 端、bend_jig footprint と重なる領域）---
        translate([bj_riser_notch_x0_mm, bj_riser_notch_y0_mm, -eps])
            cube([bj_riser_notch_x1_mm - bj_riser_notch_x0_mm,
                  bj_riser_notch_y1_mm - bj_riser_notch_y0_mm,
                  plate_z + 2 * eps]);

        // --- LED cradle ボルト通し穴（cradle 4 隅、plate を貫通して baseplate へ）---
        for (xi = led_cradle_bolts_part_local_x)
            for (yi = led_cradle_bolts_part_local_y)
                translate([xi, yi, -eps])
                    cylinder(d = m3_clearance_d_common_mm,
                             h = plate_z + 2 * eps);
    }
}

// ============================================
// (2) ファイバーホルダ（別パーツ）
//   底面 T 字キーをレール上面のスロットに落とし込み、
//   M3 を上から貫通させてプレート裏のナットでクランプ固定。
// ============================================
module fiber_holder() {
    difference() {
        union() {
            // ホルダ本体（レール上に乗る）
            cube([holder_x, holder_y, holder_z]);
            // 底面 T 字キー
            translate([0, (holder_y - key_w) / 2, -key_h])
                cube([holder_x, key_w, key_h]);
        }

        // 中心 POF 貫通穴（X 方向、カメラ側 (-X) ↔ 反対側 (+X)）
        // ★ 修正2 — 高さは fiber_hole_z_in_block_mm で明示
        translate([-eps, holder_y / 2, fiber_hole_z_in_block_mm])
            rotate([0, 90, 0])
                cylinder(
                    d = pof_channel_width_mm,
                    h = holder_x + 2 * eps
                );

        // POF 出射穴前方の開口（カメラ側 -X 端面、5×5×3mm）
        // 開口の中心高さも fiber_hole_z_in_block_mm に合わせる
        translate([
            -eps,
            (holder_y - aperture_w) / 2,
            fiber_hole_z_in_block_mm - aperture_h / 2
        ])
            cube([aperture_depth + eps, aperture_w, aperture_h]);

        // M3 クランプ穴（垂直貫通）
        translate([holder_x / 2, holder_y / 2, -key_h - eps])
            cylinder(
                d = m3_clearance_d,
                h = holder_z + key_h + 2 * eps
            );
    }
}

// ============================================
// 配置とレンダ選択
// ============================================
camera_fiber_coupler_base();

// レール上にホルダをプレビュー配置（中央位置）。
// 印刷時はベースとは別に取り出して、ホルダ単体で印刷向きを決めること。
holder_x_preview = arm_x_start + (arm_x_len - holder_x) / 2;
holder_y_preview = (plate_y - holder_y) / 2;
translate([holder_x_preview, holder_y_preview, rail_top_z])
    fiber_holder();
