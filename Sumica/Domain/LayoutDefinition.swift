import Foundation
//1つの間取りの定義
struct LayoutDefinition {
    let type: LayoutType
    let geometries: [AreaKind: AreaGeometry]
}
