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
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        observation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            self?.canCheckForUpdates = updater.canCheckForUpdates
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
