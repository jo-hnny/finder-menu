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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("菜单名称")
                    TextField("菜单名称", text: $draftTitle)
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.accentColor.opacity(titleFocused ? 1 : 0.18),
                                              lineWidth: titleFocused ? 2 : 1)
                        }
                        .focused($titleFocused)
                        .onSubmit(commitTitle)
                }

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("显示范围")
                    Picker("显示范围", selection: Binding(get: { item.scope }, set: { value in
                        var copy = item
                        copy.scope = value
                        store.update(copy)
                    })) {
                        Text("全部").tag(MenuScope.all)
                        Text("仅文件").tag(MenuScope.files)
                        Text("仅文件夹").tag(MenuScope.folders)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    Text(scopeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Toggle(isOn: Binding(get: { item.isEnabled }, set: { value in
                    var copy = item
                    copy.isEnabled = value
                    store.update(copy)
                })) {
                    Text("在菜单中显示").frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                Divider()
                switch item.action {
                case .copyPaths:
                    Label("内置操作，可以禁用但不能移除。", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .open(let application):
                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("应用")
                        if let name = catalog.entry(for: application).name {
                            Text(name).font(.callout.weight(.medium))
                        } else {
                            Label("找不到这个应用，请重新添加。", systemImage: "exclamationmark.triangle")
                                .font(.callout).foregroundStyle(.orange)
                        }
                        Text(verbatim: application.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if item.isRemovable {
                Button(role: .destructive) { store.remove(id: item.id) } label: {
                    Label("移除应用", systemImage: "trash")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(24)
            }
        }
        .background(Color("PanelSurface"))
        .onAppear { draftTitle = item.title }
        .onChange(of: titleFocused) { _, focused in if !focused { commitTitle() } }
        .onDisappear(perform: commitTitle)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in commitTitle() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("编辑菜单项").font(.callout.weight(.semibold))
                Spacer()
                Button {
                    commitTitle()
                    store.selectedID = nil
                } label: {
                    Image(systemName: "xmark").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.accentColor.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭编辑")
                .help("关闭编辑")
            }
            HStack(spacing: 12) {
                ItemIcon(item: item, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline).lineLimit(2)
                    Text(item.isRemovable ? "应用操作" : "内置操作")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
    }

    private var scopeDescription: LocalizedStringKey {
        switch item.scope {
        case .all: "在文件和文件夹的右键菜单中显示。"
        case .files: "仅在选中文件时显示。"
        case .folders: "仅在选中文件夹时显示。"
        }
    }

    private func commitTitle() {
        store.rename(id: item.id, to: draftTitle)
        if let saved = store.configuration.item(id: item.id)?.title { draftTitle = saved }
    }
}
