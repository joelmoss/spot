import Foundation
import Sparkle

@Observable
final class UpdaterController {
    var canCheckForUpdates = false
    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    private let controller: SPUStandardUpdaterController
    private var updater: SPUUpdater { controller.updater }
    private var observation: NSKeyValueObservation?

    init() {
        let isAppBundle = Bundle.main.bundlePath.hasSuffix(".app")
        controller = SPUStandardUpdaterController(startingUpdater: isAppBundle, updaterDelegate: nil, userDriverDelegate: nil)
        if isAppBundle {
            observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
