import FinderMenuCore
import SwiftUI

struct MenuPreview: View {
    let configuration: MenuConfiguration
    let highlightedID: UUID?
    let dismissEditor: () -> Void
    @State private var target: SelectionKind = .folders

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Finder 预览").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Picker("预览对象", selection: $target) {
                    Text("文件").tag(SelectionKind.files)
                    Text("文件夹").tag(SelectionKind.folders)
                }
                .labelsHidden().pickerStyle(.segmented).controlSize(.small).fixedSize()
            }
            .padding(.bottom, 24)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        previewContent
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture(perform: dismissEditor)
                    }
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }

            Text("预览本应用菜单的内容与顺序；灰色系统项仅为示意")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 12)
        }
        .padding(24)
        .background(Color("CanvasSurface"))
        .onChange(of: highlightedID, initial: true) { _, _ in revealHighlightedItem() }
        .onChange(of: highlightedScope) { _, _ in revealHighlightedItem() }
    }

    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: target == .folders ? "folder.fill" : "doc.text")
                    .font(.system(size: 32)).foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: target == .folders ? "My Project" : "README.md").font(.callout.weight(.medium))
                    Text(target == .folders ? "文件夹" : "Markdown 文档").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            menu
        }
        .frame(maxWidth: 340).padding(4).padding(.bottom, 28)
        .frame(maxWidth: .infinity)
    }

    private var highlightedScope: MenuScope? {
        highlightedID.flatMap { configuration.item(id: $0)?.scope }
    }

    private func revealHighlightedItem() {
        switch highlightedScope {
        case .files: target = .files
        case .folders: target = .folders
        case .all, nil: break
        }
    }

    private var menu: some View {
        let visible = configuration.visibleItems(for: target)
        return VStack(spacing: 2) {
            systemRow("打开", shortcut: "⌘O")
            systemRow("显示简介", shortcut: "⌘I")
            Divider().padding(.horizontal, 8).padding(.vertical, 4)
            if visible.isEmpty {
                Text("此处没有已启用的菜单项")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            ForEach(visible) { previewRow($0) }
            Divider().padding(.horizontal, 8).padding(.vertical, 4)
            systemRow("快速操作", shortcut: "›")
        }
        .padding(6)
        .background(Color("FieldSurface"), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.12)))
        .shadow(color: Color.accentColor.opacity(0.08), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("右键菜单预览")
    }

    private func previewRow(_ item: MenuItem) -> some View {
        let highlighted = item.id == highlightedID
        return HStack(spacing: 9) {
            ItemIcon(item: item, size: 17)
                .tint(highlighted ? Color.white : Color.accentColor)
            Text(item.title).lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .foregroundStyle(highlighted ? Color.white : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(highlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
    }

    private func systemRow(_ title: LocalizedStringKey, shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: shortcut).foregroundStyle(.tertiary)
        }
        .font(.callout).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}
