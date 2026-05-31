import SwiftUI
import UIKit

struct PreparationPageView: View {
    @EnvironmentObject private var tripStore: TripStore

    @State private var packingInput = ""

    @State private var budgetInput = ""

    @State private var selectedTransportType: TransportType = .flight
    @State private var transportCodeInput = ""
    @State private var waitingPointInput = ""
    @State private var seatInput = ""
    @State private var transportPriceInput = ""

    @State private var hotelNameInput = ""
    @State private var hotelPriceInput = ""
    @State private var hotelCheckInTime = Date()
    @State private var includeCheckInTime = false
    @State private var hotelNoteInput = ""

    @State private var selectedLeisureCategory: LeisureCategory = .shopping
    @State private var leisureTitleInput = ""
    @State private var leisureLocationInput = ""
    @State private var leisurePriceInput = ""
    @State private var leisureNoteInput = ""

    @FocusState private var focusedField: Field?

    private let sectionSpacing: CGFloat = 14

    private enum Field: Hashable {
        case packing
        case budget
        case transportCode
        case waitingPoint
        case seat
        case transportPrice
        case hotelName
        case hotelPrice
        case hotelNote
        case leisureTitle
        case leisureLocation
        case leisurePrice
        case leisureNote
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    packingSection
                    budgetSection
                    transportSection
                    hotelSection
                    leisureInputSection
                    leisurePoolSection
                }
                .padding(20)
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
            .navigationTitle("Preparation")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .onAppear(perform: syncInputsFromStore)
            .onChange(of: tripStore.trip.id) { _, _ in
                syncInputsFromStore()
            }
            .background(Color(.systemBackground))
        }
    }

    private var packingSection: some View {
        sectionContainer(title: "Packing List") {
            HStack(spacing: 10) {
                TextField("Add item", text: $packingInput)
                    .focused($focusedField, equals: .packing)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Add") {
                    dismissKeyboard()
                    tripStore.addPackingItem(name: packingInput)
                    packingInput = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 56, height: 40)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if tripStore.trip.packingItems.isEmpty {
                emptyText("No items yet")
            } else {
                VStack(spacing: 8) {
                    ForEach(tripStore.trip.packingItems) { item in
                        HStack(spacing: 10) {
                            Button {
                                tripStore.togglePackingItem(id: item.id)
                            } label: {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(item.isChecked ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(item.name)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.primary)
                                .strikethrough(item.isChecked, color: .secondary)

                            Spacer()

                            Button(role: .destructive) {
                                tripStore.removePackingItem(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        sectionContainer(title: "Budget") {
            HStack(spacing: 10) {
                TextField("Total budget", text: $budgetInput)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .budget)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button("Save") {
                    dismissKeyboard()
                    tripStore.updateBudgetTotal(parseDecimal(budgetInput))
                    budgetInput = decimalString(tripStore.trip.budget.total)
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 56, height: 40)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                budgetRow(label: "Total", value: tripStore.trip.budget.total)
                budgetRow(label: "Transport", value: tripStore.trip.budget.flightOrRail)
                budgetRow(label: "Hotel", value: tripStore.trip.budget.hotel)
                budgetRow(label: "Leisure", value: tripStore.trip.budget.leisure)
                Divider()
                    .overlay(Color(.separator))
                budgetRow(label: "Spent", value: tripStore.trip.budget.spent)
                budgetRow(label: "Remaining", value: tripStore.trip.budget.remaining)
            }
        }
    }

    private var transportSection: some View {
        sectionContainer(title: "Transport") {
            Picker("Type", selection: $selectedTransportType) {
                Text("Flight").tag(TransportType.flight)
                Text("Rail").tag(TransportType.rail)
            }
            .pickerStyle(.segmented)
            .tint(.primary)

            inputRow("Code", text: $transportCodeInput, field: .transportCode)
            inputRow("Waiting Point", text: $waitingPointInput, field: .waitingPoint)
            inputRow("Seat", text: $seatInput, field: .seat)
            inputRow("Price", text: $transportPriceInput, field: .transportPrice, decimal: true)

            Button("Save Transport") {
                dismissKeyboard()
                tripStore.upsertTransport(
                    type: selectedTransportType,
                    code: transportCodeInput,
                    waitingPoint: waitingPointInput,
                    seat: seatInput,
                    price: parseDecimal(transportPriceInput)
                )
                syncInputsFromStore()
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

    private var hotelSection: some View {
        sectionContainer(title: "Hotel") {
            inputRow("Name", text: $hotelNameInput, field: .hotelName)
            inputRow("Price", text: $hotelPriceInput, field: .hotelPrice, decimal: true)

            Toggle("Include Check-in Time", isOn: $includeCheckInTime)
                .tint(.primary)
                .font(.system(size: 14, weight: .regular))

            if includeCheckInTime {
                DatePicker(
                    "Check-in Time",
                    selection: $hotelCheckInTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .font(.system(size: 14, weight: .regular))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Optional", text: $hotelNoteInput, axis: .vertical)
                    .focused($focusedField, equals: .hotelNote)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button("Save Hotel") {
                dismissKeyboard()
                tripStore.upsertHotel(
                    name: hotelNameInput,
                    price: parseDecimal(hotelPriceInput),
                    checkInTime: includeCheckInTime ? hotelCheckInTime : nil,
                    note: hotelNoteInput
                )
                syncInputsFromStore()
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

    private var leisureInputSection: some View {
        sectionContainer(title: "Leisure Entry") {
            Picker("Category", selection: $selectedLeisureCategory) {
                Text("Shopping").tag(LeisureCategory.shopping)
                Text("Attraction").tag(LeisureCategory.attraction)
                Text("Restaurant").tag(LeisureCategory.restaurant)
            }
            .pickerStyle(.segmented)
            .tint(.primary)

            inputRow("Title", text: $leisureTitleInput, field: .leisureTitle)
            inputRow("Location", text: $leisureLocationInput, field: .leisureLocation)
            inputRow("Price", text: $leisurePriceInput, field: .leisurePrice, decimal: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Optional", text: $leisureNoteInput, axis: .vertical)
                    .focused($focusedField, equals: .leisureNote)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button("Add To Pool") {
                dismissKeyboard()
                tripStore.addLeisure(
                    category: selectedLeisureCategory,
                    title: leisureTitleInput,
                    location: leisureLocationInput,
                    price: parseDecimal(leisurePriceInput),
                    note: leisureNoteInput
                )
                leisureTitleInput = ""
                leisureLocationInput = ""
                leisurePriceInput = ""
                leisureNoteInput = ""
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

    private var leisurePoolSection: some View {
        sectionContainer(title: "Leisure Pool") {
            if tripStore.trip.leisurePool.isEmpty {
                emptyText("No leisure entries yet")
            } else {
                VStack(spacing: 8) {
                    ForEach(tripStore.trip.leisurePool) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(leisureLabel(item.category))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .frame(height: 22)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(currency(item.price))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                Button(role: .destructive) {
                                    tripStore.removeLeisure(id: item.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            if !item.location.isEmpty {
                                Text(item.location)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            if !item.note.isEmpty {
                                Text(item.note)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
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

    private func inputRow(_ label: String, text: Binding<String>, field: Field, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .focused($focusedField, equals: field)
                .keyboardType(decimal ? .decimalPad : .default)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func budgetRow(label: String, value: Decimal) -> some View {
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

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    private func leisureLabel(_ category: LeisureCategory) -> String {
        switch category {
        case .shopping: return "SHOPPING"
        case .attraction: return "ATTRACTION"
        case .restaurant: return "RESTAURANT"
        }
    }

    private func syncInputsFromStore() {
        budgetInput = decimalString(tripStore.trip.budget.total)

        if let transport = tripStore.trip.transport {
            selectedTransportType = transport.type
            transportCodeInput = transport.code
            waitingPointInput = transport.waitingPoint
            seatInput = transport.seat
            transportPriceInput = decimalString(transport.price)
        } else {
            selectedTransportType = .flight
            transportCodeInput = ""
            waitingPointInput = ""
            seatInput = ""
            transportPriceInput = ""
        }

        if let hotel = tripStore.trip.hotel {
            hotelNameInput = hotel.name
            hotelPriceInput = decimalString(hotel.price)
            hotelNoteInput = hotel.note
            if let checkIn = hotel.checkInTime {
                includeCheckInTime = true
                hotelCheckInTime = checkIn
            } else {
                includeCheckInTime = false
                hotelCheckInTime = Date()
            }
        } else {
            hotelNameInput = ""
            hotelPriceInput = ""
            hotelNoteInput = ""
            includeCheckInTime = false
            hotelCheckInTime = Date()
        }
    }

    private func parseDecimal(_ input: String) -> Decimal {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned) ?? 0
    }

    private func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private func currency(_ value: Decimal) -> String {
        let decimal = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: decimal) ?? "¥0"
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
