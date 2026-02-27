import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var auth: SpotifyAuth?
    var playerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURL(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        auth?.handleCallback(url: url)
    }
}

@main
struct SpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var spotify = SpotifyController()
    @State private var auth = SpotifyAuth()

    init() {}

    var body: some Scene {
        WindowGroup {
            MiniPlayerView(spotify: spotify, auth: auth)
                .onAppear {
                    spotify.auth = auth
                    appDelegate.auth = auth
                    if let window = NSApplication.shared.windows.first {
                        appDelegate.playerWindow = window
                        configurePlayerWindow(window)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 110)

        Window("Preferences", id: "settings") {
            SettingsView(auth: auth)
        }
        .windowResizability(.contentSize)
    }

    private func configurePlayerWindow(_ window: NSWindow) {
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
    }
}
