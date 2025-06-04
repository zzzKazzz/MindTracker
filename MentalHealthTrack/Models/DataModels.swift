import Foundation

// MARK: - Data Models
struct ActivityEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let activity: String
    let feeling: String
    let moodScore: Int // 1-10
    let energyLevel: Int // 1-10
    let stressLevel: Int // 1-10
    let tags: [String]
    
    init(id: UUID = UUID(), timestamp: Date = Date(), activity: String, feeling: String, moodScore: Int, energyLevel: Int, stressLevel: Int, tags: [String] = []) {
        self.id = id
        self.timestamp = timestamp
        self.activity = activity
        self.feeling = feeling
        self.moodScore = moodScore
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.tags = tags
    }
}

struct DailyInsight: Identifiable, Codable {
    let id: UUID
    let date: Date
    let dominantMood: String
    let averageMoodScore: Double
    let averageEnergyLevel: Double
    let averageStressLevel: Double
    let topActivities: [String]
    let insights: [String]
    let recommendations: [String]
    
    init(id: UUID = UUID(), date: Date, dominantMood: String, averageMoodScore: Double, averageEnergyLevel: Double, averageStressLevel: Double, topActivities: [String], insights: [String], recommendations: [String]) {
        self.id = id
        self.date = date
        self.dominantMood = dominantMood
        self.averageMoodScore = averageMoodScore
        self.averageEnergyLevel = averageEnergyLevel
        self.averageStressLevel = averageStressLevel
        self.topActivities = topActivities
        self.insights = insights
        self.recommendations = recommendations
    }
}

struct WeeklyReport: Identifiable, Codable {
    let id: UUID
    let weekStartDate: Date
    let totalEntries: Int
    let averageMoodScore: Double
    let averageEnergyLevel: Double
    let averageStressLevel: Double
    let mostFrequentActivities: [String]
    let moodTrend: MoodTrend
    let insights: [String]
    let careerRecommendations: [String]
    
    init(id: UUID = UUID(), weekStartDate: Date, totalEntries: Int, averageMoodScore: Double, averageEnergyLevel: Double, averageStressLevel: Double, mostFrequentActivities: [String], moodTrend: MoodTrend, insights: [String], careerRecommendations: [String]) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.totalEntries = totalEntries
        self.averageMoodScore = averageMoodScore
        self.averageEnergyLevel = averageEnergyLevel
        self.averageStressLevel = averageStressLevel
        self.mostFrequentActivities = mostFrequentActivities
        self.moodTrend = moodTrend
        self.insights = insights
        self.careerRecommendations = careerRecommendations
    }
}

enum MoodTrend: String, Codable, CaseIterable {
    case improving = "向上"
    case stable = "安定"
    case declining = "低下"
    case fluctuating = "変動"
}

struct HealthMetrics: Codable {
    let date: Date
    let stepCount: Double
    let activeCalories: Double
    let heartRate: Double?
    let sleepHours: Double?
    
    init(date: Date, stepCount: Double, activeCalories: Double, heartRate: Double? = nil, sleepHours: Double? = nil) {
        self.date = date
        self.stepCount = stepCount
        self.activeCalories = activeCalories
        self.heartRate = heartRate
        self.sleepHours = sleepHours
    }
}

struct ScreenTimeData: Codable {
    let date: Date
    let totalScreenTime: TimeInterval // 秒
    let appUsage: [String: TimeInterval] // アプリ名: 使用時間（秒）
    let pickupCount: Int
    
    init(date: Date, totalScreenTime: TimeInterval, appUsage: [String: TimeInterval], pickupCount: Int) {
        self.date = date
        self.totalScreenTime = totalScreenTime
        self.appUsage = appUsage
        self.pickupCount = pickupCount
    }
}

struct UserProfile: Codable {
    var name: String
    var age: Int?
    var occupation: String?
    var goals: [String]
    var preferences: UserPreferences
    var createdAt: Date
    var lastUpdated: Date
    
    init(name: String, age: Int? = nil, occupation: String? = nil, goals: [String] = [], preferences: UserPreferences = UserPreferences()) {
        self.name = name
        self.age = age
        self.occupation = occupation
        self.goals = goals
        self.preferences = preferences
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

struct UserPreferences: Codable {
    var notificationInterval: Int // 分
    var notificationStartTime: Date
    var notificationEndTime: Date
    var isNotificationEnabled: Bool
    var reminderMessages: [String]
    var enableHealthKitSync: Bool
    var enableScreenTimeSync: Bool
    var analysisFrequency: AnalysisFrequency
    
    init() {
        self.notificationInterval = 30
        let calendar = Calendar.current
        self.notificationStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        self.notificationEndTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        self.isNotificationEnabled = true
        self.reminderMessages = [
            "今の気持ちを記録しましょう 🌟",
            "この30分間、どう過ごしましたか？ 📝",
            "感情チェックの時間です ✨",
            "今の状態を記録してみてください 💫"
        ]
        self.enableHealthKitSync = true
        self.enableScreenTimeSync = true
        self.analysisFrequency = .daily
    }
}

enum AnalysisFrequency: String, Codable, CaseIterable {
    case daily = "毎日"
    case weekly = "毎週"
    case monthly = "毎月"
}

// MARK: - Extensions for Data Processing
extension Array where Element == ActivityEntry {
    func averageMoodScore() -> Double {
        guard !isEmpty else { return 0 }
        return Double(map { $0.moodScore }.reduce(0, +)) / Double(count)
    }
    
    func averageEnergyLevel() -> Double {
        guard !isEmpty else { return 0 }
        return Double(map { $0.energyLevel }.reduce(0, +)) / Double(count)
    }
    
    func averageStressLevel() -> Double {
        guard !isEmpty else { return 0 }
        return Double(map { $0.stressLevel }.reduce(0, +)) / Double(count)
    }
    
    func mostFrequentActivities(limit: Int = 5) -> [String] {
        let activityCounts = Dictionary(grouping: self, by: { $0.activity })
            .mapValues { $0.count }
        let sortedActivities = activityCounts.sorted { $0.value > $1.value }
        return sortedActivities.prefix(limit).map { $0.key }
    }
    
    func entriesForToday() -> [ActivityEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return filter { entry in
            entry.timestamp >= today && entry.timestamp < tomorrow
        }
    }
    
    func entriesForWeek(startingFrom date: Date = Date()) -> [ActivityEntry] {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        return filter { entry in
            entry.timestamp >= weekStart && entry.timestamp < weekEnd
        }
    }
}

extension Date {
    func startOfWeek() -> Date {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }
    
    func endOfWeek() -> Date {
        let calendar = Calendar.current
        let startOfWeek = self.startOfWeek()
        return calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }
    
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
