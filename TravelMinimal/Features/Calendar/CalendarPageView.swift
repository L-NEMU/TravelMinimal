import SwiftUI

struct CalendarPageView: View {
    @EnvironmentObject private var tripStore: TripStore
    @State private var displayedMonth: Date
    @State private var selectedStart: Date?
    @State private var selectedEnd: Date?

    private let calendar = Calendar.current
    private let weekSymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let cellSpacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 20

    init() {
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: Foundation.Date()))
        _selectedStart = State(initialValue: nil)
        _selectedEnd = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                monthHeader
                weekdayHeader
                monthGrid
                selectionSummary
                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .navigationTitle("旅行日历 / Calendar")
            .toolbarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .onAppear {
                selectedStart = tripStore.trip.startDate
                selectedEnd = tripStore.trip.endDate
                if let start = selectedStart {
                    displayedMonth = calendar.startOfMonth(for: start)
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Text(monthTitle(displayedMonth))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weekSymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = monthGridDays(for: displayedMonth)

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: 7), spacing: cellSpacing) {
            ForEach(days) { day in
                dayCell(day: day)
            }
        }
    }

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("出行区间 / Range")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text(summaryText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Button("清除 / Clear") {
                selectedStart = nil
                selectedEnd = nil
                tripStore.updateTripDates(start: nil, end: nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var summaryText: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"

        switch (selectedStart, selectedEnd) {
        case let (start?, end?):
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case let (start?, nil):
            return "\(formatter.string(from: start)) - 待选返程 / End pending"
        default:
            return "请选择出发和返程日期 / Pick departure and return"
        }
    }

    private func dayCell(day: MonthDay) -> some View {
        let isCurrentMonth = day.isInDisplayedMonth
        let isStart = selectedStart.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let isEnd = selectedEnd.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let isRange = isDateInSelectedRange(day.date)
        let rangeFill = Color.primary.opacity(0.22)

        return Button {
            selectDate(day.date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isRange ? rangeFill : Color.clear)

                if isStart || isEnd {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary)
                }

                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 15, weight: isStart || isEnd ? .semibold : .regular))
                    .foregroundStyle(isStart || isEnd ? Color(.systemBackground) : (isCurrentMonth ? .primary : .secondary))
            }
            .frame(height: 42)
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth)
    }

    private func selectDate(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)

        if selectedStart == nil || (selectedStart != nil && selectedEnd != nil) {
            selectedStart = normalized
            selectedEnd = nil
            tripStore.updateTripDates(start: selectedStart, end: selectedEnd)
            return
        }

        guard let start = selectedStart else { return }
        if normalized < start {
            selectedStart = normalized
            selectedEnd = start
        } else {
            selectedEnd = normalized
        }
        tripStore.updateTripDates(start: selectedStart, end: selectedEnd)
    }

    private func isDateInSelectedRange(_ date: Date) -> Bool {
        guard let start = selectedStart else { return false }
        let normalizedDate = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: start)

        if let end = selectedEnd {
            let endDay = calendar.startOfDay(for: end)
            return normalizedDate >= min(startDay, endDay) && normalizedDate <= max(startDay, endDay)
        }
        return calendar.isDate(normalizedDate, inSameDayAs: startDay)
    }

    private func monthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private func monthGridDays(for month: Date) -> [MonthDay] {
        let monthStart = calendar.startOfMonth(for: month)
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart),
              let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }

        let daysInMonth = monthRange.count
        let firstWeekdayRaw = calendar.component(.weekday, from: monthStart)
        let mondayBased = (firstWeekdayRaw + 5) % 7

        var items: [MonthDay] = []

        if mondayBased > 0 {
            for offset in stride(from: mondayBased, to: 0, by: -1) {
                if let date = calendar.date(byAdding: .day, value: -offset, to: monthStart) {
                    items.append(MonthDay(date: date, isInDisplayedMonth: false))
                }
            }
        }

        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthStart) {
                items.append(MonthDay(date: date, isInDisplayedMonth: true))
            }
        }

        while items.count % 7 != 0 {
            if let last = items.last,
               let next = calendar.date(byAdding: .day, value: 1, to: last.date) {
                items.append(MonthDay(date: next, isInDisplayedMonth: monthInterval.contains(next)))
            } else {
                break
            }
        }

        return items
    }
}

private struct MonthDay: Identifiable {
    let id = UUID()
    let date: Date
    let isInDisplayedMonth: Bool
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}
