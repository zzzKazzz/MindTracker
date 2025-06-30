import SwiftUI

// 気分を表すenum
enum Mood: String, CaseIterable {
    case veryHappy = "とても良い"
    case happy = "良い"
    case neutral = "普通"
    case sad = "悪い"
    case verySad = "とても悪い"

    var description: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .veryHappy: return "face.smiling.fill"
        case .happy: return "face.smiling"
        case .neutral: return "minus.circle.fill"
        case .sad: return "face.dashed"
        case .verySad: return "face.dashed.fill"
        }
    }

    var color: Color {
        switch self {
        case .veryHappy: return .green
        case .happy: return .blue
        case .neutral: return .gray
        case .sad: return .orange
        case .verySad: return .red
        }
    }

    // 既存のデータとの互換性のための絵文字変換
    var emoji: String {
        switch self {
        case .veryHappy: return "😊"
        case .happy: return "🙂"
        case .neutral: return "😐"
        case .sad: return "😔"
        case .verySad: return "😢"
        }
    }

    // 絵文字からMoodを取得するヘルパー
    static func fromEmoji(_ emoji: String) -> Mood {
        switch emoji {
        case "😊": return .veryHappy
        case "🙂": return .happy
        case "😐": return .neutral
        case "😔": return .sad
        case "😢": return .verySad
        default: return .neutral
        }
    }
}

// 活動ジャンルを表すenum
enum Genre: String, CaseIterable {
    case work = "仕事"
    case entertainment = "エンタメ"
    case exercise = "エクササイズ"
    case nap = "仮眠"
    case commute = "移動"
    case meal = "食事"
    case study = "勉強"
    case reading = "読書"
    case creative = "創作"
    case housework = "家事"
    case socializing = "ソーシャライズ"
    case relaxation = "リラックス"
    case other = "その他"

    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .entertainment: return "tv.fill"
        case .exercise: return "figure.run"
        case .nap: return "bed.double.fill"
        case .commute: return "car.fill"
        case .meal: return "fork.knife"
        case .study: return "book.fill"
        case .reading: return "book.closed.fill"
        case .creative: return "paintbrush.fill"
        case .housework: return "house.fill"
        case .socializing: return "person.2.fill"
        case .relaxation: return "leaf.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .work: return .blue
        case .entertainment: return .purple
        case .exercise: return .green
        case .nap: return .indigo
        case .commute: return .orange
        case .meal: return .red
        case .study: return .cyan
        case .reading: return .teal
        case .creative: return .yellow
        case .housework: return .brown
        case .socializing: return .pink
        case .relaxation: return .mint
        case .other: return .gray
        }
    }
}

// データモデル
struct MindfulnessEntry {
    let id = UUID()
    let timestamp: Date
    let activity: String
    let mood: Mood
    let genre: Genre
    let feelings: String
}
