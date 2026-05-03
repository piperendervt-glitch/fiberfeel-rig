// ============================================
// enclosure.scad
// 180 × 180 × 100 mm 遮光ボックス本体 + 蓋。
// 後ろ壁にケーブル通し穴 ×2、内部にバッフル板で迷光遮蔽。
// 底面 4 隅に M3 ナットトラップ（ベース板固定用）。
// 蓋は外周にぴったり乗り、内側 lip でラビリンス遮光。
//
// 印刷向き：本体・蓋とも開口部を上にしてプリント（サポート不要）。
// 別 STL として出力するため display_mode を切り替えてエクスポート。
// ============================================

include <params.scad>

// ----------------------------------------------------------------
// 表示モード（OpenSCAD レンダ・STL エクスポート用）
//   0: 本体のみ → enclosure_body.stl
//   1: 蓋のみ   → enclosure_lid.stl
//   2: 両方を組み立て表示（外観確認用、エクスポートには使わない）
// ----------------------------------------------------------------
display_mode = 2;

// ----------------------------------------------------------------
// 派生定数
// ----------------------------------------------------------------
eps                = 0.01;
corner_r           = 5;                       // 外形角丸半径
floor_z            = enclosure_floor_mm;      // 床上面の z
cavity_top_z       = enclosure_outer_z_mm;    // 主キャビティ上端 = 壁上端

// ナットトラップ寸法（M3、底側から挿入）
m3_clearance_d     = 3.4;
m3_nut_flat_to_flat = 5.5;
m3_nut_pocket_d    = m3_nut_flat_to_flat / cos(30) + 0.2;  // 外接円径（hex の頂点間）+ 印刷余裕
m3_nut_pocket_h    = 2.4;
nut_inset          = 20;                      // 4 隅から内側へ
// 底厚 (2.0) より深い (2.4) ナットポケットを完全に閉じるため、
// ポケット直上に小ボスを追加して天面を確保する。
nut_boss_d         = 12;
nut_boss_h         = max(m3_nut_pocket_h - floor_z + 0.6, 0.6);  // = 1.0mm

// ケーブル通し穴 + バッフル板
cable_z_center     = enclosure_outer_z_mm * 0.5;   // 壁高さ中央 (= 50)
cable_x_spacing    = 60;                            // 2 穴の中心間距離
baffle_thickness   = 1.6;
baffle_w           = 20;
baffle_h           = 30;
baffle_offset_in   = 5;                             // 穴の前 5mm 内側

// 蓋 lip
lid_lip_thickness  = enclosure_wall_mm;             // 凸枠の径方向厚み

// ----------------------------------------------------------------
// ヘルパ：角丸ボックス
//   底面 z=0 から高さ z、底面サイズ x×y、角丸半径 r。
// ----------------------------------------------------------------
module rounded_box(x, y, z, r) {
    // 4 隅シリンダの hull で角丸プリズムを作る。r は x/2, y/2 未満を要求。
    rr = max(r, 0.01);
    hull() {
        for (xi = [rr, x - rr])
            for (yi = [rr, y - rr])
                translate([xi, yi, 0])
                    cylinder(r = rr, h = z);
    }
}

// ----------------------------------------------------------------
// (1) ボックス本体
// ----------------------------------------------------------------
// 構造：
//   - 外形 enclosure_outer_x_mm × y × z の角丸ブロック
//   - 床厚 enclosure_floor_mm、壁厚 enclosure_wall_mm の上面開放キャビティ
//   - 後ろ壁 (+Y) にケーブル通し穴 2 つ、内側にバッフル板で直線光遮蔽
//   - 底面 4 隅にナットトラップ（M3、底側から）+ クリアランス穴
//
// 蓋の段差について（実装メモ）：
//   仕様の "外周から (wall + clearance) 内側に深さ lid_lip mm の段差リムを彫る"
//   を文字通り解釈すると壁厚 (1.6) を超える内寄せ (1.9) となり壁が消失するため、
//   ここでは「壁上面を蓋外周の支えとして用い、蓋 lip がキャビティ内に降りる
//   ラビリンス構造」として実装した。蓋外周は本体外周にぴったり一致し、
//   lip は壁内面と clearance (0.3mm) の隙間でスライドする（後述の lid 参照）。
// ----------------------------------------------------------------
module enclosure_body() {
    difference() {
        union() {
            // 外形（角丸プリズム）
            rounded_box(
                enclosure_outer_x_mm,
                enclosure_outer_y_mm,
                enclosure_outer_z_mm,
                corner_r
            );

            // ナットトラップ補強ボス（床上面に追加）
            for (xi = [nut_inset, enclosure_outer_x_mm - nut_inset])
                for (yi = [nut_inset, enclosure_outer_y_mm - nut_inset])
                    translate([xi, yi, floor_z])
                        cylinder(d = nut_boss_d, h = nut_boss_h);

            // バッフル板（後ろ壁側、ケーブル穴の前）
            for (i = [0 : cable_pass_count - 1]) {
                cx = enclosure_outer_x_mm / 2
                     + (i - (cable_pass_count - 1) / 2) * cable_x_spacing;
                translate([
                    cx - baffle_w / 2,
                    enclosure_outer_y_mm - enclosure_wall_mm
                        - baffle_offset_in - baffle_thickness,
                    floor_z
                ])
                    cube([baffle_w, baffle_thickness, baffle_h]);
            }
        }

        // 主キャビティ（上面開放）
        translate([enclosure_wall_mm, enclosure_wall_mm, floor_z])
            rounded_box(
                enclosure_outer_x_mm - 2 * enclosure_wall_mm,
                enclosure_outer_y_mm - 2 * enclosure_wall_mm,
                cavity_top_z - floor_z + eps,
                max(corner_r - enclosure_wall_mm, 0.5)
            );

        // ケーブル通し穴（後ろ壁 +Y 側、X 方向に並んだ 2 穴）
        for (i = [0 : cable_pass_count - 1]) {
            cx = enclosure_outer_x_mm / 2
                 + (i - (cable_pass_count - 1) / 2) * cable_x_spacing;
            translate([cx, enclosure_outer_y_mm + eps, cable_z_center])
                rotate([90, 0, 0])
                    cylinder(
                        d = cable_pass_diameter_mm,
                        h = enclosure_wall_mm + 2 * eps
                    );
        }

        // M3 ネジ通し穴（底面貫通、4 隅）
        for (xi = [nut_inset, enclosure_outer_x_mm - nut_inset])
            for (yi = [nut_inset, enclosure_outer_y_mm - nut_inset])
                translate([xi, yi, -eps])
                    cylinder(
                        d = m3_clearance_d,
                        h = floor_z + nut_boss_h + 2 * eps
                    );

        // M3 ナットポケット（底側から、6 角形 2.4mm 深さ）
        for (xi = [nut_inset, enclosure_outer_x_mm - nut_inset])
            for (yi = [nut_inset, enclosure_outer_y_mm - nut_inset])
                translate([xi, yi, -eps])
                    rotate([0, 0, 30])  // フラット面を X/Y 軸に揃える
                        cylinder(
                            d = m3_nut_pocket_d,
                            h = m3_nut_pocket_h + eps,
                            $fn = 6
                        );
    }
}

// ----------------------------------------------------------------
// (2) 蓋
// ----------------------------------------------------------------
// 構造（蓋座標、底面 z=0、上面 z=lid_thickness、lip は z=-lid_lip..0）：
//   - メインプレート：外形 outer_x × outer_y × lid_thickness
//   - 下面 lip：外周から (wall + clearance) 内側に lid_lip 高さの凸枠
//     （内側に肉を残さず枠状の中空構造）
// 蓋全体の Z 寸法 = lid_thickness + lid_lip = 7mm。
//
// 嵌合：
//   - 蓋の外周は本体外周と一致（外光が漏れない）
//   - lip 外面は本体キャビティ壁から clearance (0.3mm) 離れてスライド
//   - lip 高さ分のラビリンスで直線光を遮断
// ----------------------------------------------------------------
module enclosure_lid() {
    // 蓋座標：メインプレート底面が z=0、上面が z=lid_thickness。
    // lip はメインプレートの下に伸びる（z=-lid_lip..0）。
    union() {
        // メインプレート
        rounded_box(
            enclosure_outer_x_mm,
            enclosure_outer_y_mm,
            enclosure_lid_thickness_mm,
            corner_r
        );

        // lip（下方向に張り出す凸枠）
        translate([
            enclosure_wall_mm + enclosure_lid_clearance_mm,
            enclosure_wall_mm + enclosure_lid_clearance_mm,
            -enclosure_lid_lip_mm
        ])
            difference() {
                // lip 外形
                rounded_box(
                    enclosure_outer_x_mm
                        - 2 * (enclosure_wall_mm + enclosure_lid_clearance_mm),
                    enclosure_outer_y_mm
                        - 2 * (enclosure_wall_mm + enclosure_lid_clearance_mm),
                    enclosure_lid_lip_mm + eps,
                    max(corner_r - enclosure_wall_mm
                        - enclosure_lid_clearance_mm, 0.5)
                );
                // 中空（lip は枠形状）
                translate([lid_lip_thickness, lid_lip_thickness, -eps])
                    rounded_box(
                        enclosure_outer_x_mm
                            - 2 * (enclosure_wall_mm
                                   + enclosure_lid_clearance_mm
                                   + lid_lip_thickness),
                        enclosure_outer_y_mm
                            - 2 * (enclosure_wall_mm
                                   + enclosure_lid_clearance_mm
                                   + lid_lip_thickness),
                        enclosure_lid_lip_mm + 3 * eps,
                        max(corner_r - enclosure_wall_mm
                            - enclosure_lid_clearance_mm
                            - lid_lip_thickness, 0.5)
                    );
            }
    }
}

// ----------------------------------------------------------------
// (3) 表示／エクスポート
// ----------------------------------------------------------------
if (display_mode == 0) {
    enclosure_body();
} else if (display_mode == 1) {
    // 蓋の lip が下を向くよう lid_lip 分だけ上方に持ち上げて表示
    translate([0, 0, enclosure_lid_lip_mm])
        enclosure_lid();
} else {
    // 組立表示：蓋を本体上に乗せた高さに配置
    // 蓋座標原点（メインプレート底面）が z = enclosure_outer_z_mm に来るよう平行移動
    enclosure_body();
    translate([0, 0, enclosure_outer_z_mm])
        enclosure_lid();
}
