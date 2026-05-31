import SwiftUI

struct PostTripPageView: View {
    @EnvironmentObject private var tripStore: TripStore
    @StateObject private var exporter = TripImageExporter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    billSection
                    exportSection
                    historySection
                }
                .padding(20)
            }
            .navigationTitle("旅行后 / Post Trip")
            .toolbarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .alert("导出 / Export", isPresented: Binding(
                get: { exporter.lastMessage != nil },
                set: { if !$0 { exporter.lastMessage = nil } }
            )) {
                Button("确定 / OK", role: .cancel) { exporter.lastMessage = nil }
            } message: {
                Text(exporter.lastMessage ?? "")
            }
        }
    }

    private var billSection: some View {
        sectionContainer(title: "总账单 / Total Bill") {
            VStack(alignment: .leading, spacing: 8) {
                row("交通 / Transport", tripStore.trip.budget.flightOrRail)
                row("酒店 / Hotel", tripStore.trip.budget.hotel)
                row("行程 / Timeline", tripStore.totalTimelineExpense)
                Divider().overlay(Color(.separator))
                row("总计 / Grand Total", tripStore.grandTotalExpense)
                row("预算结余 / Remaining", tripStore.trip.budget.total - tripStore.grandTotalExpense)
            }

            Button("保存到历史 / Save To History") {
                tripStore.archiveCurrentTrip()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var exportSection: some View {
        sectionContainer(title: "每日长图导出 / Daily Long Image") {
            if tripStore.trip.dayPlans.isEmpty {
                Text("暂无每日行程 / No day plan yet")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tripStore.trip.dayPlans.sorted(by: { $0.date < $1.date })) { day in
                        HStack {
                            Text(dayText(day.date))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button(exporter.isExporting ? "导出中 / Exporting" : "导出 / Export") {
                                Task {
                                    await exporter.exportDayPlan(day: day)
                                }
                            }
                            .disabled(exporter.isExporting)
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.systemBackground))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var historySection: some View {
        sectionContainer(title: "本地历史 / Local History") {
            if tripStore.history.isEmpty {
                Text("暂无历史 / No history yet")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tripStore.history) { archive in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(archive.trip.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Button(role: .destructive) {
                                    tripStore.removeHistory(id: archive.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("归档时间 / Archived: \(timestampText(archive.archivedAt))")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)

                            Text("旅行总额 / Trip total: \(currency(archive.trip.budget.flightOrRail + archive.trip.budget.hotel + archive.trip.dayPlans.flatMap(\.timelineItems).reduce(Decimal(0)) { $0 + $1.price }))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Text(currency(value))
                .font(.system(size: 14, weight: .semibold))
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

    private func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func timestampText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
}
