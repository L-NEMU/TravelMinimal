import Foundation

@MainActor
final class TripStore: ObservableObject {
    @Published var trip: Trip
    @Published private(set) var history: [TripArchive]

    private let storageURL: URL
    private let historyURL: URL
    private let timelineImagesDirectoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storageURL = directory.appendingPathComponent("trip.json")
        self.historyURL = directory.appendingPathComponent("history.json")
        self.timelineImagesDirectoryURL = directory.appendingPathComponent("timeline-images", isDirectory: true)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? decoder.decode(Trip.self, from: data) {
            self.trip = loaded
        } else {
            self.trip = .empty
        }

        if let historyData = try? Data(contentsOf: historyURL),
           let loadedHistory = try? decoder.decode([TripArchive].self, from: historyData) {
            self.history = loadedHistory
        } else {
            self.history = []
        }

        try? fileManager.createDirectory(at: timelineImagesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func save() {
        guard let data = try? encoder.encode(trip) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func updateTripDates(start: Date?, end: Date?) {
        let normalizedStart = start.map { Calendar.current.startOfDay(for: $0) }
        let normalizedEnd = end.map { Calendar.current.startOfDay(for: $0) }
        trip.startDate = normalizedStart
        trip.endDate = normalizedEnd
        save()
    }

    func addPackingItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        trip.packingItems.append(PackingItem(id: UUID(), name: trimmed, isChecked: false))
        save()
    }

    func togglePackingItem(id: UUID) {
        guard let index = trip.packingItems.firstIndex(where: { $0.id == id }) else { return }
        trip.packingItems[index].isChecked.toggle()
        save()
    }

    func removePackingItem(id: UUID) {
        trip.packingItems.removeAll { $0.id == id }
        save()
    }

    func updateBudgetTotal(_ total: Decimal) {
        trip.budget.total = max(0, total)
        save()
    }

    func upsertTransport(
        type: TransportType,
        code: String,
        waitingPoint: String,
        seat: String,
        price: Decimal
    ) {
        trip.transport = TransportPlan(
            type: type,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            waitingPoint: waitingPoint.trimmingCharacters(in: .whitespacesAndNewlines),
            seat: seat.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, price)
        )
        syncBudgetBreakdown()
    }

    func upsertHotel(
        name: String,
        price: Decimal,
        checkInTime: Date?,
        note: String
    ) {
        trip.hotel = HotelPlan(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, price),
            checkInTime: checkInTime,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        syncBudgetBreakdown()
    }

    func addLeisure(
        category: LeisureCategory,
        title: String,
        location: String,
        price: Decimal,
        note: String
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        trip.leisurePool.append(
            LeisureItem(
                id: UUID(),
                category: category,
                title: trimmedTitle,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                price: max(0, price),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        syncBudgetBreakdown()
    }

    func removeLeisure(id: UUID) {
        trip.leisurePool.removeAll { $0.id == id }
        syncBudgetBreakdown()
    }

    func ensureDayPlansForTripRange() {
        let dates = tripDays
        guard !dates.isEmpty else {
            trip.dayPlans = []
            save()
            return
        }

        var keptPlans: [DayPlan] = []
        for date in dates {
            if let existing = trip.dayPlans.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                keptPlans.append(existing)
            } else {
                keptPlans.append(DayPlan(id: UUID(), date: date, timelineItems: []))
            }
        }
        trip.dayPlans = keptPlans
        save()
    }

    var tripDays: [Date] {
        guard let start = trip.startDate, let end = trip.endDate else { return [] }
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: min(start, end))
        let to = calendar.startOfDay(for: max(start, end))
        let span = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return (0...span).compactMap { calendar.date(byAdding: .day, value: $0, to: from) }
    }

    func timelineItems(for date: Date) -> [TimelineItem] {
        guard let dayPlan = trip.dayPlans.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return []
        }
        return dayPlan.timelineItems.sorted { $0.time < $1.time }
    }

    func addLeisureToTimeline(leisureID: UUID, date: Date) {
        guard let leisure = trip.leisurePool.first(where: { $0.id == leisureID }) else { return }
        ensureDayPlansForTripRange()
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }

        let existingCount = trip.dayPlans[dayIndex].timelineItems.count
        let time = timelineDefaultTime(for: date, offset: existingCount)
        let timelineItem = TimelineItem(
            id: UUID(),
            sourceLeisureID: leisure.id,
            time: time,
            title: leisure.title,
            location: leisure.location,
            price: leisure.price,
            note: leisure.note,
            imageLocalIdentifiers: []
        )
        trip.dayPlans[dayIndex].timelineItems.append(timelineItem)
        save()
    }

    func updateTimelineTime(dayDate: Date, itemID: UUID, newTime: Date) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        trip.dayPlans[dayIndex].timelineItems[itemIndex].time = combining(day: dayDate, timeSource: newTime)
        save()
    }

    func updateTimelineNote(dayDate: Date, itemID: UUID, note: String) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        trip.dayPlans[dayIndex].timelineItems[itemIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func updateTimelineTitle(dayDate: Date, itemID: UUID, title: String) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        trip.dayPlans[dayIndex].timelineItems[itemIndex].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func updateTimelineLocation(dayDate: Date, itemID: UUID, location: String) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        trip.dayPlans[dayIndex].timelineItems[itemIndex].location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func addTimelineImage(dayDate: Date, itemID: UUID, imageData: Data, fileExtension: String = "jpg") {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        let safeExt = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().isEmpty ? "jpg" : fileExtension
        let identifier = "\(UUID().uuidString).\(safeExt)"
        let fileURL = timelineImagesDirectoryURL.appendingPathComponent(identifier)
        do {
            try imageData.write(to: fileURL, options: .atomic)
            trip.dayPlans[dayIndex].timelineItems[itemIndex].imageLocalIdentifiers.append(identifier)
            save()
        } catch {
            return
        }
    }

    func removeTimelineImage(dayDate: Date, itemID: UUID, imageIdentifier: String) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }),
              let itemIndex = trip.dayPlans[dayIndex].timelineItems.firstIndex(where: { $0.id == itemID }) else { return }
        trip.dayPlans[dayIndex].timelineItems[itemIndex].imageLocalIdentifiers.removeAll { $0 == imageIdentifier }
        let fileURL = timelineImagesDirectoryURL.appendingPathComponent(imageIdentifier)
        try? FileManager.default.removeItem(at: fileURL)
        save()
    }

    func timelineImageURL(for imageIdentifier: String) -> URL {
        timelineImagesDirectoryURL.appendingPathComponent(imageIdentifier)
    }

    func removeTimelineItem(dayDate: Date, itemID: UUID) {
        guard let dayIndex = trip.dayPlans.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDate) }) else { return }
        trip.dayPlans[dayIndex].timelineItems.removeAll { $0.id == itemID }
        save()
    }

    func dayExpense(for date: Date) -> Decimal {
        timelineItems(for: date).reduce(Decimal(0)) { $0 + $1.price }
    }

    var totalTimelineExpense: Decimal {
        trip.dayPlans
            .flatMap(\.timelineItems)
            .reduce(Decimal(0)) { $0 + $1.price }
    }

    var grandTotalExpense: Decimal {
        trip.budget.flightOrRail + trip.budget.hotel + totalTimelineExpense
    }

    func archiveCurrentTrip() {
        ensureDayPlansForTripRange()
        let archive = TripArchive(id: UUID(), archivedAt: Date(), trip: trip)
        history.insert(archive, at: 0)
        saveHistory()
    }

    func removeHistory(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    private func syncBudgetBreakdown() {
        trip.budget.flightOrRail = trip.transport?.price ?? 0
        trip.budget.hotel = trip.hotel?.price ?? 0
        trip.budget.leisure = trip.leisurePool.reduce(Decimal(0)) { $0 + $1.price }
        save()
    }

    private func timelineDefaultTime(for dayDate: Date, offset: Int) -> Date {
        let baseHour = min(9 + offset, 22)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: dayDate)
        components.hour = baseHour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? dayDate
    }

    private func combining(day: Date, timeSource: Date) -> Date {
        let calendar = Calendar.current
        var dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        dayParts.hour = timeParts.hour
        dayParts.minute = timeParts.minute
        dayParts.second = timeParts.second
        return calendar.date(from: dayParts) ?? day
    }

    private func saveHistory() {
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}
