import AppKit
import FinderMenuCore
import FinderSync
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = MenuStore()
    @State private var catalog = ApplicationCatalog()
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    var body: some View {
        HStack(spacing: 0) {
            editor.frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            MenuPreview(configuration: store.configuration, highlightedID: store.selectedID)
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .inspector(isPresented: inspectorPresented) {
            Group {
                if let item = store.selectedItem {
                    ItemInspector(item: item, store: store).id(item.id)
                }
            }
            .inspectorColumnWidth(min: 260, ideal: 290, max: 360)
        }
        .environment(catalog)
        .frame(minWidth: 760, minHeight: 560)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
            catalog.invalidate()
        }
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { store.selectedID != nil }, set: { if !$0 { store.selectedID = nil } })
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("右键菜单").font(.title.weight(.semibold))
                    Text("让顺手的操作，触手可及。").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    Task { store.addApplications(at: await ApplicationPicker.choose()) }
                } label: {
                    Label("添加应用", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!store.isLoaded)
            }
            .padding([.horizontal, .top], 24)
            .padding(.bottom, 12)

            List(selection: $store.selectedID) {
                Section {
                    ForEach(store.items) { item in
                        MenuRow(item: item, store: store).tag(item.id)
                    }
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack {
                        Text("菜单项目")
                        Spacer()
                        Text("\(store.items.filter(\.isEnabled).count) 项已启用")
                    }
                }
            }
            .listStyle(.inset)
            .disabled(!store.isLoaded)

            Text("拖动排序 · 选中项目编辑名称和显示范围")
                .font(.caption).foregroundStyle(.tertiary)
                .padding(.horizontal, 24).padding(.vertical, 12)
        }
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
        .background(.bar)
    }
}
