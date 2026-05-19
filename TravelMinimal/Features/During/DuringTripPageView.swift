import SwiftUI
import MapKit

struct DuringTripPageView: View {
    @EnvironmentObject private var tripStore: TripStore

    @State private var selectedDayIndex = 0
    @State private var showPool = false

    @State private var showDayMap = false
    @State private var showDaySpending = false
    @State private var showRemainingBudget = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                content
                floatingAddButton
            }
            .navigationTitle("旅行中 / During")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("一日地图 / Day Map") { showDayMap = true }
                        Button("一日花销 / Daily Spending") { showDaySpending = true }
                        Button("剩余预算 / Remaining") { showRemainingBudget = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .regular))
                    }
                }
            }
            .sheet(isPresented: $showPool) { poolSheet }
            .sheet(isPresented: $showDayMap) {
                if let day = currentDay {
                    DayMapView(day: day, items: tripStore.timelineItems(for: day))
                }
            }
            .sheet(isPresented: $showDaySpending) {
                if let day = currentDay {
                    DaySpendingView(day: day, items: tripStore.timelineItems(for: day))
                }
            }
            .sheet(isPresented: $showRemainingBudget) {
                RemainingBudgetView(totalBudget: tripStore.trip.budget.total, spent: tripStore.grandTotalExpense)
            }
            .onAppear {
                tripStore.ensureDayPlansForTripRange()
                clampDayIndex()
            }
            .onChange(of: tripStore.trip.startDate) { _, _ in
                tripStore.ensureDayPlansForTripRange()
                clampDayIndex()
            }
            .onChange(of: tripStore.trip.endDate) { _, _ in
                tripStore.ensureDayPlansForTripRange()
                clampDayIndex()
            }
            .background(Color(.systemBackground))
        }
    }

    private var currentDay: Date? {
        let days = tripStore.tripDays
        guard days.indices.contains(selectedDayIndex) else { return nil }
        return days[selectedDayIndex]
    }

    private var content: some View {
        let days = tripStore.tripDays

        return Group {
            if days.isEmpty {
                VStack(spacing: 10) {
                    Text("请先设置日期 / Set dates first")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("设定起止日期后，会自动生成每日页。 / Daily pages appear after date range.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                TabView(selection: $selectedDayIndex) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, date in
                        dayTimelinePage(date: date, dayIndex: index)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 72)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
    }

    private func dayTimelinePage(date: Date, dayIndex: Int) -> some View {
        let items = tripStore.timelineItems(for: date)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                dayHeader(date: date, dayIndex: dayIndex, itemCount: items.count)
                dropArea(date: date)

                if items.isEmpty {
                    emptyTimeline
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            timelineCard(item: item, dayDate: date)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func dayHeader(date: Date, dayIndex: Int, itemCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("第 \(dayIndex + 1) 天 / Day \(dayIndex + 1)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text(dayDateText(date))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Text("\(itemCount) 项 · \(currency(tripStore.dayExpense(for: date)))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func dropArea(date: Date) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .foregroundStyle(.secondary)
            .frame(height: 56)
            .overlay {
                Text("拖拽备选到此 / Drag from pool and drop")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .dropDestination(for: String.self) { items, _ in
                guard let first = items.first,
                      let id = UUID(uuidString: first) else { return false }
                tripStore.addLeisureToTimeline(leisureID: id, date: date)
                return true
            }
    }

    private var emptyTimeline: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.tertiarySystemBackground))
            .frame(height: 180)
            .overlay(alignment: .center) {
                Text("暂无安排 / No activities yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
    }

    private func timelineCard(item: TimelineItem, dayDate: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { item.time },
                            set: { newValue in
                                tripStore.updateTimelineTime(dayDate: dayDate, itemID: item.id, newTime: newValue)
                            }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Spacer()

                    Text(currency(item.price))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Button(role: .destructive) {
                        tripStore.removeTimelineItem(dayDate: dayDate, itemID: item.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                if !item.location.isEmpty {
                    Text(item.location)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                TextField(
                    "备注 / Note",
                    text: Binding(
                        get: { item.note },
                        set: { newValue in
                            tripStore.updateTimelineNote(dayDate: dayDate, itemID: item.id, note: newValue)
                        }
                    ),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var floatingAddButton: some View {
        Button {
            showPool = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 52, height: 52)
                .background(Color.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 18)
        .padding(.bottom, 18)
    }

    private var poolSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    poolGroup(title: "购物 / Shopping", category: .shopping)
                    poolGroup(title: "景点 / Attraction", category: .attraction)
                    poolGroup(title: "餐厅 / Restaurant", category: .restaurant)
                }
                .padding(16)
            }
            .navigationTitle("备选池 / Leisure Pool")
            .toolbarTitleDisplayMode(.inline)
            .presentationDetents([.fraction(0.33)])
            .presentationDragIndicator(.visible)
            .background(Color(.systemBackground))
        }
    }

    private func poolGroup(title: String, category: LeisureCategory) -> some View {
        let items = tripStore.trip.leisurePool.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            if items.isEmpty {
                Text("无条目 / No items")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            if !item.location.isEmpty {
                                Text(item.location)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(currency(item.price))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .draggable(item.id.uuidString)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func clampDayIndex() {
        let count = tripStore.tripDays.count
        if count == 0 {
            selectedDayIndex = 0
        } else {
            selectedDayIndex = min(selectedDayIndex, count - 1)
        }
    }

    private func dayDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd EEE"
        return formatter.string(from: date)
    }

    private func currency(_ value: Decimal) -> String {
        let decimal = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: decimal) ?? "¥0"
    }
}

private struct DayMapView: View {
    let day: Date
    let items: [TimelineItem]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map {
                ForEach(locatedItems) { item in
                    Marker(item.title, systemImage: "mappin", coordinate: item.coordinate)
                }
            }
            .mapStyle(.standard)
            .navigationTitle("一日地图 / Day Map")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成 / Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(dayText(day))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color(.systemBackground).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(12)
            }
        }
    }

    private var locatedItems: [LocatedTimelineItem] {
        let base = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        return items.enumerated().map { index, item in
            let offset = Double(index) * 0.003
            return LocatedTimelineItem(
                id: item.id,
                title: item.title,
                coordinate: CLLocationCoordinate2D(latitude: base.latitude + offset, longitude: base.longitude + offset)
            )
        }
    }

    private func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

private struct LocatedTimelineItem: Identifiable {
    let id: UUID
    let title: String
    let coordinate: CLLocationCoordinate2D
}

private struct DaySpendingView: View {
    let day: Date
    let items: [TimelineItem]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("花销明细 / Spending Detail") {
                    ForEach(sortedItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(timeText(item.time))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currency(item.price))
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }

                Section("合计 / Total") {
                    HStack {
                        Text(dayText(day))
                        Spacer()
                        Text(currency(total))
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("一日花销 / Daily")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成 / Done") { dismiss() }
                }
            }
        }
    }

    private var sortedItems: [TimelineItem] { items.sorted { $0.time < $1.time } }
    private var total: Decimal { sortedItems.reduce(Decimal(0)) { $0 + $1.price } }

    private func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func currency(_ value: Decimal) -> String {
        let decimal = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: decimal) ?? "¥0"
    }
}

private struct RemainingBudgetView: View {
    let totalBudget: Decimal
    let spent: Decimal

    @Environment(\.dismiss) private var dismiss

    private var remaining: Decimal { totalBudget - spent }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                metric("总预算 / Total", totalBudget)
                metric("已花费 / Spent", spent)
                Divider().overlay(Color(.separator))
                metric("剩余 / Remaining", remaining)
                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("剩余预算 / Budget")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成 / Done") { dismiss() }
                }
            }
            .background(Color(.systemBackground))
        }
    }

    private func metric(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Text(currency(value))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func currency(_ value: Decimal) -> String {
        let decimal = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: decimal) ?? "¥0"
    }
}
