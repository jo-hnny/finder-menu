import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OSLog

struct MenuRow: View {
    let entry: MenuEntry
    let store: MenuStore
    @Binding var expandedID: UUID?
    @State private var draftTitle = ""
    @State private var handleHovered = false

    private var expanded: Bool { expandedID == entry.id }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(0..<2) { _ in
                        VStack(spacing: 3) {
                            ForEach(0..<3) { _ in Circle().frame(width: 2.5, height: 2.5) }
                        }
                    }
                }
                    .foregroundStyle(handleHovered ? Color.accentColor : Color.secondary.opacity(0.65))
                    .frame(width: 26, height: 32)
                    .background(handleHovered ? Color.accentColor.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    .background(DragHandleCursor())
                    .contentShape(Rectangle())
                    .onHover { handleHovered = $0 }
                    .help("拖动调整顺序")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("拖动 \(entry.title)")
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        expandedID = expanded ? nil : entry.id
                        draftTitle = entry.title
                    }
                } label: {
                    HStack(spacing: 10) {
                        icon.frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(displayName).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(entry.enabled ? .primary : .secondary)
                                .lineLimit(2).multilineTextAlignment(.leading)
                            Text(entry.kind == .copyPaths ? "内置操作 · \(entry.scope.title)" : entry.scope.title)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary).rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(expanded ? "收起" : "编辑") \(entry.title)")
                .help(expanded ? "收起设置" : "编辑菜单名称和显示范围")
                Toggle("启用 \(entry.title)", isOn: Binding(get: { entry.enabled }, set: { value in
                    var copy = entry; copy.enabled = value; store.update(copy)
                }))
                .labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            .padding(.horizontal, 10).frame(minHeight: 74)
            .contentShape(Rectangle())
            .onDrag {
                Logger(subsystem: "dev.jojo.FinderMenu", category: "Configuration").notice("Menu drag began")
                return NSItemProvider(object: entry.id.uuidString as NSString)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider().opacity(0.55)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
                        GridRow {
                            Text("菜单名称").foregroundStyle(.secondary)
                            TextField("菜单名称", text: $draftTitle)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: draftTitle) { _, _ in saveTitle() }
                                .onSubmit { saveTitle() }
                        }
                        GridRow {
                            Text("显示范围").foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Picker("显示范围", selection: Binding(get: { entry.scope }, set: { value in
                                    var copy = entry; copy.scope = value; store.update(copy)
                                })) {
                                    Text("全部").tag(MenuEntry.Scope.both).help("文件与文件夹")
                                    Text("仅文件").tag(MenuEntry.Scope.files)
                                    Text("仅文件夹").tag(MenuEntry.Scope.folders)
                                }
                                .labelsHidden().pickerStyle(.segmented).controlSize(.small)
                                Spacer(minLength: 0)
                                if entry.kind == .application {
                                    Button(role: .destructive) { store.remove(entry.id) } label: {
                                        Label("移除应用", systemImage: "trash")
                                    }
                                    .buttonStyle(.plain).foregroundStyle(.red).fixedSize()
                                }
                            }
                        }
                    }
                    .font(.system(size: 11))
                    if entry.kind == .application && entry.applicationURL == nil {
                        Text("找不到这个应用，请重新添加。").font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.leading, 46).padding(.trailing, 14).padding(.bottom, 18)
                .onAppear { draftTitle = entry.title }
            }
        }
        .background(expanded ? Color.black.opacity(0.035) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
            guard let provider = providers.first, provider.canLoadObject(ofClass: NSString.self) else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let value = object as? String, let id = UUID(uuidString: value) else { return }
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.18)) { store.move(id, to: entry.id) }
                }
            }
            return true
        }
    }

    private var displayName: String {
        guard entry.kind == .application, let url = entry.applicationURL else { return entry.title }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    @ViewBuilder private var icon: some View {
        if entry.kind == .copyPaths {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 16)).foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
        } else if let url = entry.applicationURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
                .opacity(entry.enabled ? 1 : 0.45)
        } else {
            Image(systemName: "app.dashed").foregroundStyle(.secondary)
        }
    }

    private func saveTitle() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != entry.title,
              var current = store.entries.first(where: { $0.id == entry.id }) else { return }
        current.title = title
        store.update(current)
    }
}

// Cursor rectangles restore the surrounding control's cursor automatically on exit.
private struct DragHandleCursor: NSViewRepresentable {
    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ nsView: CursorView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }

    final class CursorView: NSView {
        override func resetCursorRects() { addCursorRect(visibleRect, cursor: .openHand) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
