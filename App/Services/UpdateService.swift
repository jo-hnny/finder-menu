import Combine
import Foundation
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )

        // Development builds without a signing key must not start an unusable updater.
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
