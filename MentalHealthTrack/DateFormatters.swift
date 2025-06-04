//
//  DateFormatters.swift
//  MentalHealthTrack
//
//  Created by KAZ on 6/3/25.
//

// DateFormatters.swift
import Foundation

struct DateFormatters {
    // 日付時刻フォーマッター
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 時刻のみフォーマッター
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 日付のみフォーマッター
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 月年フォーマッター
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 日のみフォーマッター
    static let dayOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    // 短縮曜日フォーマッター
    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 時間範囲表示用ヘルパー
    static func timeRange(from date: Date) -> String {
        let endTime = date
        let startTime = Calendar.current.date(byAdding: .minute, value: -30, to: endTime) ?? endTime
        
        return "\(timeOnly.string(from: startTime)) - \(timeOnly.string(from: endTime))"
    }
    
    // 通知時間範囲表示用ヘルパー
    static func notificationPeriod(start: Date, end: Date) -> String {
        let startStr = timeOnly.string(from: start)
        let endStr = timeOnly.string(from: end)
        return "\(startStr) 〜 \(endStr)"
    }
    
    // 曜日シンボル取得
    static var shortWeekdaySymbols: [String] {
        return shortWeekday.shortWeekdaySymbols
    }
}
