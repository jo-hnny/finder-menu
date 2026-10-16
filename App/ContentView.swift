import AppKit
import FinderMenuCore
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = MenuStore()
    @State private var catalog = ApplicationCatalog()
    @State private var previewTarget: SelectionKind = .folders
    @State private var inspectorWindow = InspectorWindowState()

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
                let inspectorWidth = inspectorWindow.revealedWidth
                HStack(spacing: 0) {
                    editor
                        .frame(width: 350)
                        .frame(maxHeight: .infinity)
                        .modifier(GlassSurface(cornerRadius: 24))
                        .padding(.trailing, 16)
                    Group {
                        if let item = inspectorWindow.displayedID.flatMap(store.configuration.item(id:)) {
                            InspectorReveal(item: item, store: store, width: inspectorWidth)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: inspectorWidth)
                    .frame(maxHeight: .infinity)
                    .allowsHitTesting(store.selectedID != nil && inspectorWidth >= 296)
                    .accessibilityHidden(inspectorWidth < 296 || store.selectedID == nil)
                    MenuPreview(configuration: store.configuration, highlightedID: store.selectedID,
                                dismissEditor: { store.selectedID = nil }, target: $previewTarget)
                        .frame(width: max(340, geometry.size.width - 366 - inspectorWidth))
                        .frame(maxHeight: .infinity)
                }
                .frame(minHeight: geometry.size.height)
                .transaction { $0.animation = nil }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            StatusBar(store: store)
        }
        .background { WorkspaceBackdrop(screenWidth: inspectorWindow.window?.screen?.frame.width) }
        .background {
            InspectorWindowResize(state: inspectorWindow)
        }
        .tint(Color("AccentColor"))
        .environment(catalog)
        .focusedSceneValue(\.menuStore, store)
        .frame(minWidth: max(780, 350 + 16 + inspectorWindow.revealedWidth + 340 + 32), minHeight: 620)
        .onChange(of: store.selectedID) { _, id in
            revealSelectedItem()
            inspectorWindow.select(id, reduceMotion: reduceMotion)
        }
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
