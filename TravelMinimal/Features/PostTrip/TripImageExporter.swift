import SwiftUI
import Photos
import UIKit

@MainActor
final class TripImageExporter: ObservableObject {
    @Published var isExporting = false
    @Published var lastMessage: String?

    func exportDayPlan(day: DayPlan) async {
        isExporting = true
        defer { isExporting = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            lastMessage = "相册权限被拒绝 / Photo permission denied"
            return
        }

        let renderer = ImageRenderer(content: DayPlanLongImageView(day: day))
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            lastMessage = "长图渲染失败 / Render failed"
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            lastMessage = "已保存到相册 / Saved to Photos"
        } catch {
            lastMessage = "保存失败 / Save failed"
        }
    }
}

struct DayPlanLongImageView: View {
    let day: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(dayTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            ForEach(sortedItems) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(timeText(item.time))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(currency(item.price))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    if !item.location.isEmpty {
                        Text(item.location)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 1080)
        .background(Color(.systemBackground))
    }

    private var sortedItems: [TimelineItem] {
        day.timelineItems.sorted { $0.time < $1.time }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: day.date)
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
