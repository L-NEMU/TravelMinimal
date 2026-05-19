import Foundation

struct Trip: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date?
    var endDate: Date?
    var packingItems: [PackingItem]
    var budget: TripBudget
    var transport: TransportPlan?
    var hotel: HotelPlan?
    var leisurePool: [LeisureItem]
    var dayPlans: [DayPlan]
    var expenseRecords: [ExpenseRecord]

    static let empty = Trip(
        id: UUID(),
        title: "My Trip",
        startDate: nil,
        endDate: nil,
        packingItems: [],
        budget: .empty,
        transport: nil,
        hotel: nil,
        leisurePool: [],
        dayPlans: [],
        expenseRecords: []
    )
}

struct PackingItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var isChecked: Bool
}

struct TripBudget: Codable, Equatable {
    var total: Decimal
    var flightOrRail: Decimal
    var hotel: Decimal
    var leisure: Decimal

    var spent: Decimal {
        flightOrRail + hotel + leisure
    }

    var remaining: Decimal {
        total - spent
    }

    static let empty = TripBudget(total: 0, flightOrRail: 0, hotel: 0, leisure: 0)
}

enum TransportType: String, Codable, CaseIterable {
    case flight
    case rail
}

struct TransportPlan: Codable, Equatable {
    var type: TransportType
    var code: String
    var waitingPoint: String
    var seat: String
    var price: Decimal
}

struct HotelPlan: Codable, Equatable {
    var name: String
    var price: Decimal
    var checkInTime: Date?
    var note: String
}

enum LeisureCategory: String, Codable, CaseIterable {
    case shopping
    case attraction
    case restaurant
}

struct LeisureItem: Codable, Identifiable, Equatable {
    var id: UUID
    var category: LeisureCategory
    var title: String
    var location: String
    var price: Decimal
    var note: String
}

struct DayPlan: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var timelineItems: [TimelineItem]
}

struct TimelineItem: Codable, Identifiable, Equatable {
    var id: UUID
    var sourceLeisureID: UUID?
    var time: Date
    var title: String
    var location: String
    var price: Decimal
    var note: String
    var imageLocalIdentifiers: [String]
}

struct ExpenseRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var category: ExpenseCategory
    var title: String
    var amount: Decimal
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case flightOrRail
    case hotel
    case shopping
    case attraction
    case restaurant
}

struct TripArchive: Codable, Identifiable, Equatable {
    var id: UUID
    var archivedAt: Date
    var trip: Trip
}
