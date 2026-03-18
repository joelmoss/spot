import SwiftUI
import AppKit
import ObjectiveC

class LyricsWindow: NSWindow {
    var onKeyDown: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            onKeyDown?()
            return
        }
        super.sendEvent(event)
    }
}

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
    var lyricsWindow: LyricsWindow?
    var lyricsLocalMonitor: Any?
    weak var spotify: SpotifyController?

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

    func showLyricsOverlay(spotify: SpotifyController) {
        guard lyricsWindow == nil else { return }
        let screen = playerWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let window = LyricsWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.onKeyDown = { [weak self] in
            self?.dismissLyricsOverlay()
        }

        let overlayView = LyricsOverlayView(spotify: spotify) { [weak self] in
            self?.dismissLyricsOverlay()
        }
        window.contentView = NSHostingView(rootView: overlayView)

        // LSUIElement apps (.prohibited policy) can't become active or own key windows.
        // Temporarily switch to .regular so the window can receive key events.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        lyricsWindow = window

        // Local monitor catches key events while the app is active
        lyricsLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.dismissLyricsOverlay()
            return nil
        }
    }

    func dismissLyricsOverlay() {
        if let monitor = lyricsLocalMonitor {
            NSEvent.removeMonitor(monitor)
            lyricsLocalMonitor = nil
        }
        lyricsWindow?.orderOut(nil)
        lyricsWindow = nil
        spotify?.showLyricsOverlay = false

        // Restore LSUIElement behavior — .accessory keeps windows visible but hides dock icon
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct SpotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var spotify = SpotifyController()
    @State private var auth = SpotifyAuth()
    @State private var updater = UpdaterController()
    @AppStorage("hideWhenNotPlaying") private var hideWhenNotPlaying = false
    @Environment(\.openWindow) private var openWindow

    init() {}

    var body: some Scene {
        WindowGroup {
            MiniPlayerView(spotify: spotify, auth: auth)
                .onAppear {
                    spotify.auth = auth
                    appDelegate.auth = auth
                    appDelegate.spotify = spotify
                    if let window = NSApplication.shared.windows.first {
                        appDelegate.playerWindow = window
                        configurePlayerWindow(window)
                        if !auth.hasClientID {
                            makeWindowKeyable(window)
                            NSApp.activate(ignoringOtherApps: true)
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
                .onChange(of: auth.hasClientID) { _, hasID in
                    if !hasID, let window = appDelegate.playerWindow {
                        NSApp.activate(ignoringOtherApps: true)
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .onChange(of: spotify.hasCheckedPlayback) { _, checked in
                    guard hideWhenNotPlaying, checked, !spotify.isSpotifyRunning,
                          auth.hasClientID, auth.isAuthenticated,
                          let window = appDelegate.playerWindow else { return }
                    window.orderOut(nil)
                }
                .onChange(of: spotify.isSpotifyRunning) { _, isRunning in
                    guard hideWhenNotPlaying, auth.hasClientID, auth.isAuthenticated,
                          let window = appDelegate.playerWindow else { return }
                    if isRunning {
                        window.orderFront(nil)
                    } else {
                        window.orderOut(nil)
                    }
                }
                .onChange(of: spotify.showLyricsOverlay) { _, show in
                    if show {
                        appDelegate.showLyricsOverlay(spotify: spotify)
                    } else {
                        appDelegate.dismissLyricsOverlay()
                    }
                }
                .onChange(of: hideWhenNotPlaying) { _, hide in
                    guard auth.hasClientID, auth.isAuthenticated,
                          let window = appDelegate.playerWindow else { return }
                    if !hide && !window.isVisible {
                        window.orderFront(nil)
                    } else if hide && !spotify.isSpotifyRunning {
                        window.orderOut(nil)
                    }
                }
        }
        .windowResizability(.contentSize)

        Window("Preferences", id: "settings") {
            SettingsView(auth: auth, updater: updater)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            Button("Preferences...") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("Quit Spot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(nsImage: menuBarIcon())
        }
    }

    private func menuBarIcon() -> NSImage {
        let icon: NSImage
        // In .app bundle, resources are in Contents/Resources/
        // During swift run, fall back to the source tree path (relative to cwd)
        let bundleURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
        let devURL = URL(fileURLWithPath: "Sources/Spot/Resources/MenuBarIcon@2x.png").standardized
        if let url = bundleURL ?? (FileManager.default.fileExists(atPath: devURL.path) ? devURL : nil),
           let img = NSImage(contentsOf: url)
        {
            icon = img
        } else {
            icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spot") ?? NSImage()
        }
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = true
        return icon
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }

    private func configurePlayerWindow(_ window: NSWindow) {
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
    }
}
