import HealthKit

// iPhone本体の「ヘルスケア」アプリ（Healthアプリ）に接続するための認可（許可）ダイアログを表示する
class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization() {
        // 歩数（stepCount）データを「読み取る」権限のみをリクエスト
        // 読み書きするデータ型を設定
        let readTypes: Set = [HKObjectType.quantityType(forIdentifier: .stepCount)!]
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            // 認可後の処理
        }
    }
}
