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
pof_channel_width_led_side_mm = 1.5;  // 縦穴専用、収縮余裕大

// --- 曲げ半径 ---
bend_radius_mm = 10.0;
bend_straight_run_mm = 30;                    // 曲げ部前後の直線部長さ

// --- LED ---
led_diameter_mm = 5.1;                        // 5mm砲弾型 + クリアランス
led_body_depth_mm = 8.0;                      // LED本体（リード除く）の埋め込み深さ
led_lead_clearance_mm = 5.0;                  // リード逃げの空間

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
hq_mount_pitch_mm = 25.5;       // M2.5 穴の縦・横ピッチ
hq_mount_hole_d_mm = 2.8;       // M2.5 通し穴径（クリアランス込み）
hq_mount_offset_mm = 6.25;      // PCB エッジから穴中心

// --- 共通 ---
default_wall_mm = 2.0;
$fn = 60;
