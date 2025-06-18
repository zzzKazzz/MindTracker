import HealthKit
import Foundation

// iPhone本体の「ヘルスケア」アプリ（Healthアプリ）に接続するための認可（許可）ダイアログを表示する
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var weeklySteps: [Int] = []

    private init() {
        checkAuthorizationStatus()
    }

    func requestAuthorization() {
        // HealthKitが利用可能かチェック
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }

        // 読み取りたいデータ型を設定
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Required health data types are unavailable")
            return
        }

        let readTypes: Set<HKObjectType> = [stepCountType, activeEnergyType, heartRateType]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                    return
                }

                if success {
                    print("HealthKit authorization granted")
                    self?.isAuthorized = true
                    self?.fetchTodaySteps()
                    self?.fetchWeeklySteps()
                } else {
                    print("HealthKit authorization denied")
                    self?.isAuthorized = false
                }
            }
        }
    }

    private func checkAuthorizationStatus() {
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        let status = healthStore.authorizationStatus(for: stepCountType)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .sharingAuthorized)
            if self.isAuthorized {
                self.fetchTodaySteps()
                self.fetchWeeklySteps()
            }
        }
    }

    // MARK: - Data Fetching Methods

    func fetchTodaySteps() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching today's steps: \(error.localizedDescription)")
                    return
                }

                if let result = result, let sum = result.sumQuantity() {
                    let steps = Int(sum.doubleValue(for: HKUnit.count()))
                    self?.todaySteps = steps
                    print("Today's steps: \(steps)")
                } else {
                    self?.todaySteps = 0
                }
            }
        }

        healthStore.execute(query)
    }

    func fetchWeeklySteps() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepCountType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: sevenDaysAgo,
            intervalComponents: DateComponents(day: 1)
        )

        query.initialResultsHandler = { [weak self] _, results, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching weekly steps: \(error.localizedDescription)")
                    return
                }

                var weeklyData: [Int] = []

                results?.enumerateStatistics(from: sevenDaysAgo, to: now) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let steps = Int(sum.doubleValue(for: HKUnit.count()))
                        weeklyData.append(steps)
                    } else {
                        weeklyData.append(0)
                    }
                }

                self?.weeklySteps = weeklyData
                print("Weekly steps: \(weeklyData)")
            }
        }

        healthStore.execute(query)
    }
}
