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
led_body_depth_mm = 10.0;                     // Ø5.1 LED 穴の長さ。LED 砲弾 8mm + 2mm の余裕（嵌合許容差）。
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

// ============================================================
// Phase 1 装置レイアウト（U 字 180°、既存 bend_jig 維持）
// ============================================================

// --- POF 全長と内訳（pof_total_length_mm を変えれば余裕値 pof_slack_mm が連動）---
pof_total_length_mm        = 150;     // 切断値
pof_led_insert_mm          = 10;      // led_fiber_coupler 内部の挿入長
pof_camera_insert_mm       = 10;      // camera_fiber_coupler holder 内部の挿入長
pof_polish_margin_mm       = 10;      // 端面研磨マージン（両端合計）
pof_led_straight_mm        = 35;      // LED 側直線部（bend_jig 内 + air）
pof_camera_straight_mm     = 35;      // カメラ側直線部（同上）
pof_arc_180_mm             = bend_radius_mm * 3.14159265;  // ≈ 31.416
pof_slack_mm = pof_total_length_mm
             - (pof_led_insert_mm + pof_led_straight_mm
                + pof_arc_180_mm
                + pof_camera_straight_mm + pof_camera_insert_mm
                + pof_polish_margin_mm);   // = 18.58（参考）

// --- 共通 POF 軸 z（ベースプレート天面からの高さ）---
// camera_fiber_coupler の sensor_center_z = plate_z + hq_body_height_mm/2
//                                        = 4 + 19 = 23 が固定（カメラ筐体高 38 由来）。
// fiber_holder POF はこの 23mm に整列させた設計（既存）。
// bend_jig の POF 軸はパーツ底面から 5.9mm。これを 23mm に持ち上げるため 17.1mm 昇降。
pof_axis_z_above_baseplate_mm = 23.0;
bend_jig_pof_axis_z_local_mm  = 5.9;   // bend_jig_r10.scad の channel_axis_z 実測値
bend_jig_riser_h_mm = pof_axis_z_above_baseplate_mm
                    - bend_jig_pof_axis_z_local_mm;   // = 17.1

// --- ベースプレート（既存 enclosure 内部 176.8×176.8 に収める）---
baseplate_x_mm           = 175;
baseplate_y_mm           = 175;
baseplate_thickness_mm   = 5;
// enclosure 4 隅ナットトラップ位置：(20, 20), (160, 20), (20, 160), (160, 160) in enclosure 外形座標
// baseplate を中央配置（enclosure (2.5, 2.5)..(177.5, 177.5)）→ baseplate-local 17.5
baseplate_mount_inset_mm = 17.5;
// enclosure 床上の Ø12×1mm boss を逃がす座面凹
baseplate_boss_clear_d_mm = 13.0;
baseplate_boss_clear_h_mm = 1.6;

// --- 共通 M3 寸法 ---
m3_clearance_d_common_mm = 3.4;
m3_nut_af_mm             = 5.5;                           // 二面間
m3_nut_pocket_d_mm       = m3_nut_af_mm / cos(30) + 0.2;  // 外接円 + 印刷余裕
m3_nut_pocket_h_mm       = 2.4;

// --- bend_jig 配置（baseplate-local、左下原点）---
// 右側に寄せ、左方向に LED/camera coupler を伸ばす。
// bend_jig 60×40。POF 出口は -X 側（local x=0 面）の y=10, y=30。
bend_jig_origin_x_mm = 115;
bend_jig_origin_y_mm = (baseplate_y_mm - 40) / 2;        // = 67.5（中央 Y）
// baseplate 上での POF inlet/outlet 位置
pof_inlet_baseplate_y_mm  = bend_jig_origin_y_mm + 10;   // = 77.5
pof_outlet_baseplate_y_mm = bend_jig_origin_y_mm + 30;   // = 97.5
pof_x_at_bend_jig_face_mm = bend_jig_origin_x_mm;        // = 115（bend_jig 左面）

// --- bend_jig 上面 重り位置決め凹（Ø35×1mm、PDMS パッド中央に位置）---
weight_recess_on_jig_d_mm = 35.0;
weight_recess_on_jig_h_mm = 1.0;

// --- LED cradle（led_fiber_coupler を保持）---
// LED coupler は Ø15×26mm、軸を X 方向（+X が POF 側）。
// POF 軸 baseplate y = 77.5、世界 z = baseplate_thickness + 23 = 28。
led_cradle_axis_y_mm = pof_inlet_baseplate_y_mm;          // = 77.5
led_cradle_axis_z_mm = pof_axis_z_above_baseplate_mm;     // = 23
led_cradle_x_face_mm = bend_jig_origin_x_mm;              // POF 端面が bend_jig 面に密着
led_cradle_x_back_mm = led_cradle_x_face_mm
                     - 26;                                // = 89（LED 側端）
led_cradle_outer_w_mm = 24;                               // Y 寸法（外形）
led_cradle_outer_h_mm = led_cradle_axis_z_mm + 7.5 + 3;   // 円筒上端 + 天面 3mm = 33.5
led_cradle_wall_mm    = 2.5;
// マウント M3 は cradle 底面 4 隅。camera_fiber_coupler プレートを貫通して
// baseplate に到達するため、screw 長は cradle_h + camera_plate_z (4) + bp_t (5) ≈ 16+ 必要。
led_cradle_mount_inset_mm = 4;

// --- camera_fiber_coupler 配置 ---
// part-local POF 軸 y=30、baseplate 上で y=97.5 に整列 → part 原点 y = 67.5。
// part-local +X 面が POF 入口、bend_jig 左面（baseplate x=115）に向ける。
// part 長 120 → part 原点 x は 115 - 120 = -5（baseplate 外）。
// 解決：part を baseplate x = 0..120 に置き、bend_jig は baseplate x=115..175。
// POF holder は slot 最 +X 位置（part-local x=75..100）に固定し、空気間を 15mm 許容。
// このため pof_camera_straight_mm の運用は 15mm air + 20mm 内 bend_jig として再解釈。
// （bend_jig groove 40mm のうち POF が使うのは 20mm = 残 20mm 余白）
camera_coupler_origin_x_mm = 0;
camera_coupler_origin_y_mm = pof_outlet_baseplate_y_mm - 30;   // = 67.5（part-local Y=30 を整列）
// 4 隅 M3 マウント（plate 120×60 の 4 隅から 5mm inset）
camera_coupler_mount_inset_mm = 5.0;

// --- camera_fiber_coupler プレートに開ける bend_jig 昇降逃げ穴 ---
// bend_jig 昇降は baseplate (115..175, 67.5..107.5) を占める。camera プレート
// (0..120, 67.5..127.5) と (115..120, 67.5..107.5) で 5×40 の重なりがある。
// プレートに切欠きを設けて昇降を逃がす（camera_fiber_coupler.scad で実装）。
bj_riser_notch_x0_mm = 115 - camera_coupler_origin_x_mm;       // = 115（part-local）
bj_riser_notch_x1_mm = 120;                                    // part-local +X 面まで
bj_riser_notch_y0_mm = bend_jig_origin_y_mm
                     - camera_coupler_origin_y_mm;             // = 0（part-local）
bj_riser_notch_y1_mm = bj_riser_notch_y0_mm + 40;              // = 40

// --- LED cradle のマウントネジ穴を camera_fiber_coupler プレートに通すクリアランス位置 ---
// cradle 4 隅、led 軸中心 (LED_axis_y, LED_axis_x ∈ [89..115]) から inset 4 で計算。
led_cradle_bolts_part_local_x = [
    led_cradle_x_back_mm - camera_coupler_origin_x_mm + led_cradle_mount_inset_mm,            // = 93
    led_cradle_x_face_mm - camera_coupler_origin_x_mm - led_cradle_mount_inset_mm,            // = 111
];
led_cradle_bolts_part_local_y = [
    led_cradle_axis_y_mm - led_cradle_outer_w_mm / 2 - camera_coupler_origin_y_mm + led_cradle_mount_inset_mm,   // = 9.5
    led_cradle_axis_y_mm + led_cradle_outer_w_mm / 2 - camera_coupler_origin_y_mm - led_cradle_mount_inset_mm,   // = 25.5
];

// --- 重り凹（weight_guide 内、Ø35×25mm、円柱磁石/六角ナット両対応）---
weight_guide_outer_mm        = 45;     // 旧 35 → 45（凹 35 + 壁 5×2）
weight_guide_thickness_mm    = 28;     // 凹深 25 + 床 3
weight_cavity_d_mm           = 35.0;
weight_cavity_h_mm           = 25.0;
weight_floor_thickness_mm    = 3.0;
