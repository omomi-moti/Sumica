import Foundation
//Domain に渡す区画の状態
struct AreaSnapshot: Identifiable {
    let id: UUID
    let kind: AreaKind
    let lastVerifiedCleanAt: Date
    let halfLife: TimeInterval
}
