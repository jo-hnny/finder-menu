import AppKit
import FinderSync

enum FinderExtensionStatus {
    case enabled
    case running
    case unconfirmed

    static let bundleIdentifier = "dev.jojo.FinderMenu.Extension"

    @MainActor static func read() -> Self {
        if FIFinderSyncController.isExtensionEnabled { return .enabled }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains(where: { !$0.isTerminated }) {
            return .running
        }
        // The API checks the containing app's extension. Another installed copy
        // can be enabled instead, so false alone does not establish that it is off.
        return .unconfirmed
    }
}
