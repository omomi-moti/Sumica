import Foundation
//区間をenumで定義
enum AreaKind: String, CaseIterable {
    case desk
    case floor
    case bed
    case bath
    case toilet

    var displayName: String {
        switch self {
        case .desk: "机まわり"
        case .floor: "床"
        case .bed: "ベッドまわり"
        case .bath: "風呂"
        case .toilet: "トイレ"
        }
    }
}
