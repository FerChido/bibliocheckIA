import SwiftUI
import VisionKit
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession

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
        .environmentObject(AppSession())
}
#endif
