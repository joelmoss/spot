import SwiftUI
import AppKit
import ObjectiveC

private func makeWindowKeyable(_ window: NSWindow) {
    let actualClass: AnyClass = type(of: window)
    let name = "KeyableWindow_\(NSStringFromClass(actualClass))"
    let subclass: AnyClass
    if let existing = NSClassFromString(name) {
        subclass = existing
    } else if let created = objc_allocateClassPair(actualClass, name, 0) {
        let block: @convention(block) (AnyObject) -> Bool = { _ in true }
        class_addMethod(
            created,
            NSSelectorFromString("canBecomeKeyWindow"),
            imp_implementationWithBlock(block),
            "B@:"
        )
        objc_registerClassPair(created)
        subclass = created
    } else {
        return
    }
    object_setClass(window, subclass)
}

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
    @State private var updater = UpdaterController()

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
                        if !auth.hasClientID {
                            makeWindowKeyable(window)
                            NSApp.setActivationPolicy(.regular)
                            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources") ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources") {
                                NSApp.applicationIconImage = NSImage(contentsOf: iconURL)
                            }
                            NSApp.activate(ignoringOtherApps: true)
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
                .onChange(of: auth.hasClientID) { _, hasID in
                    if hasID {
                        NSApp.setActivationPolicy(.accessory)
                    } else if let window = appDelegate.playerWindow {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        window.makeKeyAndOrderFront(nil)
                    }
                }
        }
        .windowResizability(.contentSize)

        Window("Preferences", id: "settings") {
            SettingsView(auth: auth, updater: updater)
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
