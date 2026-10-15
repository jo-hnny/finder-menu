import AppKit
import FinderMenuCore
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = MenuStore()
    @State private var catalog = ApplicationCatalog()
    @State private var previewTarget: SelectionKind = .folders

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { workspace }
        } else {
            workspace
        }
    }

    private var workspace: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let detailWidth = geometry.size.width - 350 - 16
                let showsPreview = store.selectedItem == nil || detailWidth >= 280 + 16 + 340
                HStack(spacing: 0) {
                    editor
                        .frame(width: 350)
                        .frame(maxHeight: .infinity)
                        .modifier(GlassSurface(cornerRadius: 24))
                        .padding(.trailing, 16)
                    if let item = store.selectedItem {
                        ItemInspector(item: item, store: store, isCompact: !showsPreview)
                            .id(item.id)
                            .frame(width: showsPreview ? 280 : detailWidth)
                            .frame(maxHeight: .infinity)
                            .modifier(GlassSurface(cornerRadius: 24))
                            .padding(.trailing, showsPreview ? 16 : 0)
                            .transition(.opacity)
                    }
                    if showsPreview {
                        MenuPreview(configuration: store.configuration, highlightedID: store.selectedID,
                                    dismissEditor: { store.selectedID = nil }, target: $previewTarget)
                            .frame(width: detailWidth - (store.selectedItem == nil ? 0 : 296))
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            StatusBar(store: store)
        }
        .background { WorkspaceBackdrop() }
        .tint(Color("AccentColor"))
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: store.selectedID != nil)
        .environment(catalog)
        .focusedSceneValue(\.menuStore, store)
        .frame(minWidth: 780, minHeight: 620)
        .onChange(of: store.selectedID) { _, _ in revealSelectedItem() }
        .onChange(of: store.selectedItem?.scope) { _, _ in revealSelectedItem() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            catalog.invalidate()
        }
    }

    private func revealSelectedItem() {
        switch store.selectedItem?.scope {
        case .files: previewTarget = .files
        case .folders: previewTarget = .folders
        case .all, nil: break
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("右键菜单")
                        .font(.system(size: 23, weight: .semibold))
                        .tracking(-0.5)
                        .lineLimit(2)
                    Text("\(store.items.filter(\.isEnabled).count) 项已启用")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.primary.opacity(0.78))
                }
            }
            .padding(24)

            HStack {
                Text("菜单项目")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.78))
                Spacer()
                Button {
                    Task { store.addApplications(at: await ApplicationPicker.choose()) }
                } label: {
                    Label("添加应用", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.primary)
                .foregroundStyle(.primary)
                .controlSize(.regular)
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!store.isLoaded)
            }
            .padding(.horizontal, 24).padding(.bottom, 12)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 6) {
                            ForEach(store.items) { item in
                                MenuRow(item: item, store: store)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { store.selectedID = nil }
                    }
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .disabled(!store.isLoaded)

            Label("拖动左侧手柄排序 · 选中项目编辑", systemImage: "arrow.up.arrow.down")
                .font(.caption).foregroundStyle(.secondary)
                .padding(24)
        }
    }
}
