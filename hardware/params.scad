// ============================================
// fiberfeel-rig 共通パラメータ
// ============================================

// --- ファイバー ---
// 三菱レイヨン エスカ CK-40E1 (PMMA SI POF, 1.0mm OD)
pof_diameter_mm = 1.0;
pof_clearance_mm = 0.2;                       // 印刷誤差吸収
pof_channel_width_mm = pof_diameter_mm + pof_clearance_mm;
pof_channel_depth_mm = pof_diameter_mm * 0.7; // 上面はゲル接触可能に

// --- LED カプラ専用：縦穴の収縮余裕 ---
pof_channel_width_led_side_mm = 1.8;  // 縦穴専用、収縮余裕大（実機検証で 1.5 → 1.8 に拡大）

// --- 曲げ半径 ---
bend_radius_mm = 10.0;
bend_straight_run_mm = 30;                    // 曲げ部前後の直線部長さ

// --- LED ---
led_diameter_mm = 5.1;                        // 5mm砲弾型 + クリアランス
led_body_depth_mm = 8.0;                      // LED 本体（リード除く）の埋め込み深さ。Ø5.1 LED 穴の長さ。
led_lead_clearance_mm = 5.0;                  // リード逃げ Ø7 ザグリの深さ。LED 穴より底面側に積む。

// --- LED back cap（led_fiber_coupler の LED 側穴を密閉する遮光蓋）---
led_back_cap_diameter_mm           = 15.0;    // led_fiber_coupler 外径と同じ
led_back_cap_thickness_mm          = 5.0;     // 円盤厚
led_back_cap_lead_hole_diameter_mm = 1.2;     // LED リード線通し穴
led_back_cap_lead_hole_pitch_mm    = 2.54;    // 標準 0.1" ピッチ
led_back_cap_press_fit_diameter_mm = 6.9;     // Ø7 リード逃げザグリに圧入（0.1mm のしめしろ）。LED 領域 Ø5.1 には侵入しない。
led_back_cap_press_fit_depth_mm    = 5.0;     // Ø7 ザグリ（深さ 5mm）全体を埋め、円盤を coupler 底面に密着させる。

// --- ゲル/PDMS パッド ---
pad_size_mm = 30;                             // 30 x 30 mm
pad_thickness_mm = 3;                         // 3 mm 厚
mold_wall_mm = 4;
mold_floor_mm = 3;
mold_taper_deg = 1;                           // 抜き勾配

// --- 錘ガイド ---
weight_pad_outer_mm = 35;
weight_recess_diameter_mm = 25;
weight_recess_depth_mm = 5;

// --- カメラカプラ ---
// Pi HQ Camera M12 ボディ寸法
hq_body_width_mm = 38;
hq_body_height_mm = 38;
hq_body_depth_mm = 19;
camera_to_fiber_distance_mm = 70;             // 暫定、Phase 0 で調整
fiber_arm_slot_length_mm = 40;                // ±20mm の調整代

// --- HQ Camera 取り付け穴 ---
// Robosheep 実機合わせ：30×30mm 正方ピッチ、M2.5 通し穴 d=3.1（印刷収縮余裕込み）
hq_mount_pitch_mm = 30.0;       // M2.5 穴の縦・横ピッチ（実測値）
hq_mount_hole_d_mm = 3.1;       // M2.5 通し穴径（クリアランス＋印刷収縮余裕込み）
hq_mount_offset_mm = 6.25;      // PCB エッジから穴中心

// --- 遮光ボックス ---
enclosure_outer_x_mm = 180;
enclosure_outer_y_mm = 180;
enclosure_outer_z_mm = 100;
enclosure_wall_mm = 1.6;          // 壁厚（4 perimeters @ 0.4mm nozzle）
enclosure_floor_mm = 2.0;         // 底厚
enclosure_lid_thickness_mm = 2.0; // 蓋の厚さ
enclosure_lid_lip_mm = 5.0;       // 蓋の被せ深さ
enclosure_lid_clearance_mm = 0.3; // 蓋と本体の遊び

// ケーブル通し穴（迷光対策で L 字パス）
cable_pass_diameter_mm = 12;      // ケーブル束を通す穴径
cable_pass_count = 2;             // 必要な穴数（FFC + 電源）

// --- 共通 ---
default_wall_mm = 2.0;
$fn = 60;
