import SwiftUI
import CoreData

// 週の時間グリッド。記録があるマスにブロックを出し、タップで中身を見る。
struct WeekGridView: View {
    let entries: [MindfulnessData]
    let focusedDate: Date
    let intervalMinutes: Int
    let dayStartMinutes: Int
    let dayEndMinutes: Int
    let onSelectEntry: (MindfulnessData) -> Void
    let onSelectEmptySlot: (Date, Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let days = weekDays
        let slots = timeSlots
        let slotHeight = CGFloat(max(intervalMinutes == 30 ? 28 : (intervalMinutes == 60 ? 40 : 56), 24))

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 36)
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 2) {
                        Text(weekdayLabel(day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.caption)
                            .fontWeight(calendar.isDateInToday(day) ? .bold : .regular)
                            .foregroundColor(calendar.isDateInToday(day) ? .white : .primary)
                            .frame(width: 24, height: 24)
                            .background(calendar.isDateInToday(day) ? Color.blue : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(slots, id: \.self) { minutes in
                            Text(timeLabel(minutes))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: slotHeight, alignment: .topTrailing)
                        }
                    }

                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 0) {
                            ForEach(slots, id: \.self) { minutes in
                                let slotStart = date(on: day, minutes: minutes)
                                let slotEnd = date(on: day, minutes: minutes + intervalMinutes)
                                let slotEntries = entries(in: slotStart, end: slotEnd)

                                ZStack(alignment: .topLeading) {
                                    Rectangle()
                                        .fill(Color(UIColor.systemBackground))
                                    Rectangle()
                                        .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)

                                    if let nowLine = nowOffset(in: day, slotStart: slotStart, slotEnd: slotEnd, height: slotHeight) {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 1.5)
                                            .offset(y: nowLine)
                                    }

                                    if let entry = slotEntries.first {
                                        Button(action: { onSelectEntry(entry) }) {
                                            entryBlock(entry)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: slotHeight, maxHeight: slotHeight)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let entry = slotEntries.first {
                                        onSelectEntry(entry)
                                    } else {
                                        onSelectEmptySlot(slotStart, slotEnd)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: focusedDate)?.start ?? focusedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var timeSlots: [Int] {
        stride(from: dayStartMinutes, through: dayEndMinutes, by: intervalMinutes).map { $0 }
    }

    private func entries(in start: Date, end: Date) -> [MindfulnessData] {
        entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return timestamp >= start && timestamp < end
        }
    }

    private func date(on day: Date, minutes: Int) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    private func timeLabel(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private func weekdayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func nowOffset(in day: Date, slotStart: Date, slotEnd: Date, height: CGFloat) -> CGFloat? {
        let now = Date()
        guard calendar.isDateInToday(day), now >= slotStart, now < slotEnd else { return nil }
        let ratio = now.timeIntervalSince(slotStart) / slotEnd.timeIntervalSince(slotStart)
        return height * CGFloat(max(0, min(1, ratio)))
    }

    private func entryBlock(_ entry: MindfulnessData) -> some View {
        let genre = Genre(rawValue: entry.genre ?? "") ?? .other
        let mood = Mood(rawValue: entry.mood ?? "") ?? Mood.fromEmoji(entry.mood ?? "")
        return Text("\(genre.rawValue) \(mood.emoji)")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(3)
            .background(genre.color)
            .cornerRadius(4)
    }
}

// 日の時間グリッド。週グリッドの1列版。
struct DayGridView: View {
    let entries: [MindfulnessData]
    let focusedDate: Date
    let intervalMinutes: Int
    let dayStartMinutes: Int
    let dayEndMinutes: Int
    let onSelectEntry: (MindfulnessData) -> Void
    let onSelectEmptySlot: (Date, Date) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let slots = stride(from: dayStartMinutes, through: dayEndMinutes, by: intervalMinutes).map { $0 }
        let slotHeight = CGFloat(max(intervalMinutes == 30 ? 36 : (intervalMinutes == 60 ? 48 : 64), 32))

        ScrollView {
            VStack(spacing: 0) {
                ForEach(slots, id: \.self) { minutes in
                    let slotStart = date(minutes: minutes)
                    let slotEnd = date(minutes: minutes + intervalMinutes)
                    let slotEntries = entries.filter { entry in
                        guard let timestamp = entry.timestamp else { return false }
                        return timestamp >= slotStart && timestamp < slotEnd
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%d:%02d", minutes / 60, minutes % 60))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .trailing)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(UIColor.systemGray5), lineWidth: 0.5)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.systemBackground)))

                            if let entry = slotEntries.first {
                                Button(action: { onSelectEntry(entry) }) {
                                    let genre = Genre(rawValue: entry.genre ?? "") ?? .other
                                    let mood = Mood(rawValue: entry.mood ?? "") ?? Mood.fromEmoji(entry.mood ?? "")
                                    HStack {
                                        Text(genre.rawValue)
                                            .fontWeight(.semibold)
                                        Text(mood.description)
                                        if let activity = entry.activity, !activity.isEmpty {
                                            Text(activity).lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                    .background(genre.color)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: slotHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let entry = slotEntries.first {
                                onSelectEntry(entry)
                            } else {
                                onSelectEmptySlot(slotStart, slotEnd)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func date(minutes: Int) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: focusedDate) ?? focusedDate
    }
}
