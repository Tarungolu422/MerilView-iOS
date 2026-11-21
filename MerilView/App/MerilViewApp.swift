import SwiftUI

@main
public struct MerilViewApp: App {
    @StateObject private var appState = AppState()
    
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
