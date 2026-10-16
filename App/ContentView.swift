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
                let columns = InspectorWindowLayout.columns(contentWidth: geometry.size.width, reveal: 0)
                HStack(spacing: 0) {
                    MenuEditor(store: store)
                        .frame(width: columns.sidebar)
                        .frame(maxHeight: .infinity)
                        .modifier(GlassSurface(cornerRadius: 24))
                        .padding(.trailing, 16)
                    InspectorPreview(store: store, state: inspectorWindow,
                                     target: $previewTarget, availableWidth: columns.preview)
                        .frame(width: columns.preview)
                        .frame(maxHeight: .infinity)
                }
                .frame(minHeight: geometry.size.height)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            StatusBar(store: store)
        }
        .background { WindowBackdrop(state: inspectorWindow) }
        .background {
            InspectorWindowResize(state: inspectorWindow)
        }
        .tint(Color("AccentColor"))
        .environment(catalog)
        .focusedSceneValue(\.menuStore, store)
        .modifier(InspectorWindowMinimum(state: inspectorWindow))
        .onChange(of: store.selectedItem) { _, item in
            revealSelectedItem()
            inspectorWindow.select(item, reduceMotion: reduceMotion)
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { inspectorWindow.finish() }
        }
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
}

private struct WindowBackdrop: View {
    let state: InspectorWindowState

    var body: some View {
        WorkspaceBackdrop(canvasWidth: state.canvasWidth)
    }
}
