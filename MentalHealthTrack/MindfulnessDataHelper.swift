//
//  MindfulnessDataHelper.swift
//  MentalHealthTrack
//
//  Created by KAZ on 6/3/25.
//

// MindfulnessDataHelper.swift
import Foundation
import CoreData

struct MindfulnessDataHelper {
    
    // 今日のエントリ数を取得
    static func todayEntriesCount(from entries: [MindfulnessData]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= today && timestamp < tomorrow
        }.count
    }
    
    // 指定日のエントリを取得
    static func entriesForDate(_ date: Date, from entries: [MindfulnessData]) -> [MindfulnessData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= startOfDay && timestamp < endOfDay
        }
    }
    
    // 指定日にエントリがあるかチェック
    static func hasEntriesForDate(_ date: Date, in entries: [MindfulnessData]) -> Bool {
        return entriesCountForDate(date, in: entries) > 0
    }
    
    // 指定日のエントリ数を取得
    static func entriesCountForDate(_ date: Date, in entries: [MindfulnessData]) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= startOfDay && timestamp < endOfDay
        }.count
    }
    
    // カレンダー用の月の日付配列を生成
    static func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < monthLastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    // エントリを日付順でソート（新しい順）
    static func sortedEntries(_ entries: [MindfulnessData]) -> [MindfulnessData] {
        return entries.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
    }
}NotificationManager
