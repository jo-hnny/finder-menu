import AppKit
import FinderSync
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MenuStore()
    @State private var expandedID: UUID?
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                editor.frame(minWidth: 410, maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                MenuPreview(entries: store.entries, highlightedID: expandedID)
                    .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().opacity(0.55)
            HStack(spacing: 6) {
                Circle().fill(extensionEnabled ? Color.green : Color.orange).frame(width: 5, height: 5)
                Text(extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展尚未启用")
                Button("管理…") { FIFinderSyncController.showExtensionManagementInterface() }.buttonStyle(.link)
                Spacer()
                Button("退出应用") { NSApp.terminate(nil) }.buttonStyle(.link)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.horizontal, 22).padding(.vertical, 12)
        }
        .background(Color(red: 0.99, green: 0.99, blue: 0.995))
        .frame(minWidth: 860, minHeight: 580)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { extensionEnabled = FIFinderSyncController.isExtensionEnabled }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("右键菜单").font(.system(size: 24, weight: .semibold))
                    Text("让顺手的操作，触手可及。").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { ApplicationPicker.choose { store.add($0) } } label: {
                    Label("添加应用", systemImage: "plus").padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent).tint(Color(red: 0.15, green: 0.16, blue: 0.18))
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!store.loaded)
            }
            .padding(.bottom, 30)
            HStack {
                Text("菜单项目")
                Spacer()
                Text("\(store.entries.filter(\.enabled).count) 项已启用")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(.bottom, 10)
            Divider().opacity(0.55)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.entries) { entry in
                        MenuRow(entry: entry, store: store, expandedID: $expandedID)
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, -10)
            Text("拖动左侧手柄排序 · 点击项目编辑")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
                .padding(.top, 12)
            Divider().opacity(0.55).padding(.vertical, 18)
            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red).textSelection(.enabled)
            } else if store.loaded {
                Label("已保存 · 退出应用后仍然生效", systemImage: "checkmark")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(28)
    }
}
