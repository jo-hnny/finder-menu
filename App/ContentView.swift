import AppKit
import FinderMenuCore
import FinderSync
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = MenuStore()
    @State private var catalog = ApplicationCatalog()
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    var body: some View {
        HStack(spacing: 0) {
            editor.frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            if let item = store.selectedItem {
                ItemInspector(item: item, store: store)
                    .id(item.id)
                    .frame(width: 320)
                Divider()
            }
            MenuPreview(configuration: store.configuration, highlightedID: store.selectedID,
                        dismissEditor: { store.selectedID = nil })
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background(Color("PanelSurface"))
        .tint(Color("AccentColor"))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: store.selectedID != nil)
        .environment(catalog)
        .focusedSceneValue(\.menuStore, store)
        .frame(minWidth: store.selectedItem == nil ? 760 : 1022, minHeight: 560)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
            catalog.invalidate()
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().scaledToFit().frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                    Text("右键菜单").font(.title2.weight(.semibold))
                    Spacer(minLength: 8)
                    Button {
                        Task { store.addApplications(at: await ApplicationPicker.choose()) }
                    } label: {
                        Label("添加应用", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(!store.isLoaded)
                }
                Text("让顺手的操作，触手可及。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            HStack {
                Text("菜单项目")
                Spacer()
                Text("\(store.items.filter(\.isEnabled).count) 项已启用")
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 24).padding(.vertical, 12)

            Divider().padding(.horizontal, 24)
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 2) {
                            ForEach(store.items) { item in
                                MenuRow(item: item, store: store)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { store.selectedID = nil }
                    }
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .disabled(!store.isLoaded)

            Text("拖动左侧手柄排序 · 选中项目编辑")
                .font(.caption).foregroundStyle(.tertiary)
                .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .background(Color("PanelSurface"))
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Circle().fill(extensionEnabled ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展尚未启用")
                Button("管理…") { FIFinderSyncController.showExtensionManagementInterface() }.buttonStyle(.link)
                Spacer(minLength: 16)
                if let message = store.message {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).lineLimit(2).textSelection(.enabled)
                } else if store.isLoaded {
                    Label("已保存 · 退出应用后仍然生效", systemImage: "checkmark")
                }
                Button("退出应用") { NSApp.terminate(nil) }.buttonStyle(.link)
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 10)
        }
        .background(Color("PanelSurface"))
    }
}
