import SwiftUI
import DesignSystem

public struct WeekStripView: View {
    let filledDates: Set<DateComponents>  // year/month/day-resolution components
    let today: Date
    let calendar: Calendar

    public init(filledDates: Set<DateComponents>,
                today: Date = Date(),
                calendar: Calendar = Calendar(identifier: .iso8601)) {
        self.filledDates = filledDates
        self.today = today
        self.calendar = calendar
    }

    private var weekDays: [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func isFilled(_ d: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: d)
        return filledDates.contains(comps)
    }

    public var body: some View {
        HStack(spacing: PulseSpacing.sm) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let filled = isFilled(day)
                VStack(spacing: 4) {
                    Text(weekdayLabel(day))
                        .pulseFont(.small)
                        .foregroundStyle(isToday ? PulseColors.ink0.color : PulseColors.ink2.color)
                    Circle()
                        .fill(filled ? PulseColors.ink0.color : PulseColors.bg2.color)
                        .frame(width: 8, height: 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PulseSpacing.sm)
                .background(isToday ? PulseColors.bg2.color : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: PulseRadius.sm))
            }
        }
    }

    private func weekdayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }
}
