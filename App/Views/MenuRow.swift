import AppKit
import FinderMenuCore
import SwiftUI
import UniformTypeIdentifiers

struct MenuRow: View {
    let item: MenuItem
    let store: MenuStore
    @Environment(ApplicationCatalog.self) private var catalog
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var handleHovered = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 10) {
            dragHandle
            Button { store.selectedID = item.id } label: {
                HStack(spacing: 10) {
                    ItemIcon(item: item, size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .fontWeight(.medium)
                            .foregroundStyle(item.isEnabled ? .primary : .secondary)
                            .lineLimit(2)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑 \(item.title)")
            .accessibilityAddTraits(store.selectedID == item.id ? .isSelected : [])
            .accessibilityAction(named: Text("上移")) { move(by: -1) }
            .accessibilityAction(named: Text("下移")) { move(by: 1) }
            Toggle("启用 \(item.title)", isOn: Binding(get: { item.isEnabled }, set: { value in
                var copy = item
                copy.isEnabled = value
                store.update(copy)
            }))
            .labelsHidden().toggleStyle(.switch).controlSize(.mini)
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(isDropTarget ? 0.16 : store.selectedID == item.id ? 0.08 : 0))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(store.selectedID == item.id || isDropTarget ? 0.14 : 0))
                }
        }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .onDrop(of: [UTType.text], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first, provider.canLoadObject(ofClass: NSString.self) else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let value = object as? String, let id = UUID(uuidString: value) else { return }
                Task { @MainActor in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        store.move(id: id, to: item.id)
                    }
                }
            }
            return true
        }
    }

    private var dragHandle: some View {
        HStack(spacing: 3) {
            ForEach(0..<2) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3) { _ in Circle().frame(width: 2.5, height: 2.5) }
                }
            }
        }
        .foregroundStyle(handleHovered ? Color.accentColor : Color.secondary.opacity(0.65))
        .frame(width: 24, height: 32)
        .background(handleHovered ? Color.accentColor.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .background(DragHandleCursor())
        .contentShape(Rectangle())
        .onHover { handleHovered = $0 }
        .help("拖动调整顺序")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("拖动 \(item.title)")
    }

    private func move(by offset: Int) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }),
              store.items.indices.contains(index + offset) else { return }
        store.move(id: item.id, to: store.items[index + offset].id)
    }

    private var subtitle: String {
        switch item.action {
        case .copyPaths:
            return String(localized: "内置操作 · \(item.scope.title)")
        case .open(let application):
            guard let name = catalog.entry(for: application).name else {
                return String(localized: "找不到应用 · \(item.scope.title)")
            }
            return "\(name) · \(item.scope.title)"
        }
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

struct ItemIcon: View {
    let item: MenuItem
    let size: CGFloat
    @Environment(ApplicationCatalog.self) private var catalog

    var body: some View {
        Group {
            switch item.action {
            case .copyPaths:
                Image(systemName: "doc.on.doc")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.tint)
                    .frame(width: size, height: size)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.25))
            case .open(let application):
                if let icon = catalog.entry(for: application).icon {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: size * 0.6))
                        .foregroundStyle(.secondary)
                        .frame(width: size, height: size)
                }
            }
        }
        .opacity(item.isEnabled ? 1 : 0.45)
        .accessibilityHidden(true)
    }
}
