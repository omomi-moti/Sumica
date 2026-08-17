import Foundation
//間取りの座標データ
enum LayoutCatalog {
    static let myRoom = LayoutDefinition(
        type: .myRoom,
        geometries: [
            .desk: AreaGeometry(x: 0...0.571, y: 0...0.129, height: 0.14),
            .floor: AreaGeometry(x: 0...0.571, y: 0.129...0.300, height: 0.01),
            .bed: AreaGeometry(x: 0...0.571, y: 0.300...0.429, height: 0.09),
            .bath: AreaGeometry(x: 0...0.286, y: 0.429...0.714, height: 0.11),
            .toilet: AreaGeometry(x: 0...0.286, y: 0.714...1.0, height: 0.11),
        ]
    )

    static let all: [LayoutDefinition] = [myRoom]
}
