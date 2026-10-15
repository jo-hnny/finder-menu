import FinderMenuCore
import SwiftUI

struct MenuRow: View {
    let item: MenuItem
    let store: MenuStore
    @Environment(ApplicationCatalog.self) private var catalog

    var body: some View {
        HStack(spacing: 10) {
            ItemIcon(item: item, size: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    .lineLimit(2)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("启用 \(item.title)", isOn: Binding(get: { item.isEnabled }, set: { value in
                var copy = item
                copy.isEnabled = value
                store.update(copy)
            }))
            .labelsHidden().toggleStyle(.switch).controlSize(.mini)
        }
        .padding(.vertical, 6)
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
