import SwiftUI
import AppKit

@main
struct SpotApp: App {
    @State private var spotify = SpotifyController()

    init() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            window.level = .floating
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }

    var body: some Scene {
        WindowGroup {
            MiniPlayerView(spotify: spotify)
                .onAppear {
                    configureWindows()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 110)

        Window("Preferences", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }

    private func configureWindows() {
        for window in NSApplication.shared.windows {
            window.styleMask = [.borderless, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.level = .floating
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
        }
    }
}
