import SwiftUI
import VisionKit
import UIKit

struct MainTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("INICIO", systemImage: "house.fill")
                }

            AttendanceHistoryView()
                .tabItem {
                    Label("HISTORIAL", systemImage: "clock")
                }

            ProfileView()
                .tabItem {
                    Label("PERFIL", systemImage: "person")
                }
        }
        .tint(.blue)
    }
}

#if DEBUG
#Preview("Tabs") {
    MainTabView()
        .environment(AppSession())
}
#endif
