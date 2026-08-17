import Foundation
//運用しながら調整する値
enum Tuning {
    //タスク完了時に戻る割合
    static let microTaskRatio = 0.4
    //表示上のクランプ。描画層でのみ適用する
    static let dirtinessDisplayCap = 0.6
    //通知が飛ぶ汚れ度
    static let notificationThreshold = 0.5
    //何日分の通知を予約するか
    static let notificationDays = 3
    //ペースの既定値。設定の3択は 0.7 / 1.0 / 1.5
    static let defaultPaceMultiplier = 1.0
    //汚れ度が 0.5 に達するまでの時間。通知が飛ぶまでの日数と一致する
    static func halfLife(for kind: AreaKind) -> TimeInterval {
        switch kind {
        case .desk: 1.5 * 86_400
        case .floor: 3.5 * 86_400
        case .bed: 6.0 * 86_400
        case .bath: 3.5 * 86_400
        case .toilet: 3.5 * 86_400
        }
    }
}
