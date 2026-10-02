import SwiftUI

@main
struct CMemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppViewModel())
        }
        .windowResizability(.contentMinSize)
    }
}
