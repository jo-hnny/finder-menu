import AppKit
import Combine
import FinderSync
import SwiftUI

struct StatusBar: View {
    let store: MenuStore
    @State private var extensionStatus = FinderExtensionStatus.read()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: extensionStatus == .unconfirmed ? "questionmark.circle" : "checkmark.circle.fill")
                        .foregroundStyle(extensionStatus == .unconfirmed ? Color.secondary : Color.green)
                    Text(extensionTitle)
                        .foregroundStyle(.primary)
                }
                .help(extensionHelp)

                Button("扩展设置…") { FIFinderSyncController.showExtensionManagementInterface() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                Spacer(minLength: 24)

                if let message = store.message {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .help(message)
                        .textSelection(.enabled)
                } else if store.isLoaded {
                    Label("自动保存", systemImage: "checkmark")
                        .help("菜单名称在回车或离开编辑时保存，其他更改即时保存。")
                }

                Button("退出应用") { NSApp.terminate(nil) }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .foregroundStyle(.primary)
                    .controlSize(.small)
                    .help("退出配置应用后，Finder 菜单仍然可用。")
            }
            .font(.caption)
            .foregroundStyle(Color.primary.opacity(0.78))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .modifier(GlassSurface(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 6)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionStatus = FinderExtensionStatus.read()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .receive(on: RunLoop.main)) { _ in
            extensionStatus = FinderExtensionStatus.read()
        }
    }

    private var extensionTitle: LocalizedStringKey {
        switch extensionStatus {
        case .enabled: "Finder 扩展已启用"
        case .running: "Finder 扩展运行中"
        case .unconfirmed: "扩展状态待确认"
        }
    }

    private var extensionHelp: LocalizedStringKey {
        switch extensionStatus {
        case .enabled: "已在系统设置中启用 Finder 扩展。"
        case .running: "已检测到正在运行的 Finder 扩展，可能来自另一个已安装的应用副本。"
        case .unconfirmed: "暂时无法确认扩展状态，可在系统设置中检查。"
        }
    }
}
