import SwiftUI

@main
struct DeviceScopeApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
        }
    }
}
