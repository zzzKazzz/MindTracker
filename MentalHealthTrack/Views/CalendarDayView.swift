import SwiftUI

struct CalendarDayView: View {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let entryCount: Int
    let onTapped: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTapped) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                // 記録インジケーター
                if entryCount > 0 {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 40, height: 40)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary
        } else if isToday {
            return .white
        } else if isSelected {
            return .white
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isToday {
            return .blue
        } else if isSelected {
            return .blue.opacity(0.8)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected && !isToday {
            return .blue
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected && !isToday {
            return 1
        } else {
            return 0
        }
    }
    
    private var indicatorColor: Color {
        switch entryCount {
        case 0:
            return .clear
        case 1...2:
            return .blue
        case 3...4:
            return .green
        default:
            return .orange
        }
    }
}

// MARK: - Preview
struct CalendarDayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                CalendarDayView(
                    date: Date(),
                    isCurrentMonth: true,
                    isSelected: false,
                    entryCount: 0,
                    onTapped: {}
                )
                
                CalendarDayView(
                    date: Date(),
                    isCurrentMonth: true,
                    isSelected: false,
                    entryCount: 2,
                    onTapped: {}
                )
                
                CalendarDayView(
                    date: Date(),
                    isCurrentMonth: true,
                    isSelected: true,
                    entryCount: 4,
                    onTapped: {}
                )
            }
            
            HStack(spacing: 20) {
                CalendarDayView(
                    date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    isCurrentMonth: false,
                    isSelected: false,
                    entryCount: 1,
                    onTapped: {}
                )
                
                CalendarDayView(
                    date: Date(),
                    isCurrentMonth: true,
                    isSelected: false,
                    entryCount: 6,
                    onTapped: {}
                )
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}