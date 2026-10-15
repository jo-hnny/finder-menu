import AppKit
import FinderMenuCore
import SwiftUI

struct ItemInspector: View {
    let item: MenuItem
    let store: MenuStore
    @Environment(ApplicationCatalog.self) private var catalog
    /// Titles save on Return, focus loss, selection change or quit, not on every keystroke.
    @State private var draftTitle = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("菜单名称", text: $draftTitle)
                    .focused($titleFocused)
                    .onSubmit(commitTitle)
                Picker("显示范围", selection: Binding(get: { item.scope }, set: { value in
                    var copy = item
                    copy.scope = value
                    store.update(copy)
                })) {
                    ForEach(MenuScope.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle("在菜单中显示", isOn: Binding(get: { item.isEnabled }, set: { value in
                    var copy = item
                    copy.isEnabled = value
                    store.update(copy)
                }))
            }

            Section("顺序") {
                HStack {
                    Button("上移", systemImage: "arrow.up") { store.moveSelected(by: -1) }
                        .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                        .disabled(!store.canMoveSelected(by: -1))
                    Button("下移", systemImage: "arrow.down") { store.moveSelected(by: 1) }
                        .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                        .disabled(!store.canMoveSelected(by: 1))
                }
            }

            switch item.action {
            case .copyPaths:
                Section {
                    Text("内置操作，可以禁用但不能移除。").foregroundStyle(.secondary)
                }
            case .open(let application):
                Section("应用") {
                    if let name = catalog.entry(for: application).name {
                        LabeledContent("名称", value: name)
                    } else {
                        Text("找不到这个应用，请重新添加。").foregroundStyle(.orange)
                    }
                    LabeledContent("Bundle ID") { Text(application.bundleIdentifier).textSelection(.enabled) }
                    Button("移除应用", systemImage: "trash", role: .destructive) { store.remove(id: item.id) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { draftTitle = item.title }
        .onChange(of: titleFocused) { _, focused in if !focused { commitTitle() } }
        .onDisappear(perform: commitTitle)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in commitTitle() }
    }

    private func commitTitle() {
        store.rename(id: item.id, to: draftTitle)
        if let saved = store.configuration.item(id: item.id)?.title { draftTitle = saved }
    }
}
