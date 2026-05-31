import SwiftUI

@main
struct TravelMinimalApp: App {
    @StateObject private var tripStore = TripStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(tripStore)
                .preferredColorScheme(nil)
        }
    }
}
