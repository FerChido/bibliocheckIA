import SwiftUI
import SwiftData

@main
struct bibliocheckApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .modelContainer(session.container)
        }
    }
}

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if session.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
