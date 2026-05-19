import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            CalendarPageView()
                .tabItem {
                    Label("日历 / Calendar", systemImage: "calendar")
                }

            PreparationPageView()
                .tabItem {
                    Label("准备 / Prep", systemImage: "list.bullet")
                }

            DuringTripPageView()
                .tabItem {
                    Label("旅行中 / During", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }

            PostTripPageView()
                .tabItem {
                    Label("旅行后 / Post", systemImage: "doc.text")
                }
        }
        .tint(.primary)
    }
}
