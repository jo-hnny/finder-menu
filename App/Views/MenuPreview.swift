import FinderMenuCore
import SwiftUI

struct MenuPreview: View {
    let configuration: MenuConfiguration
    let highlightedID: UUID?
    let dismissEditor: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var target: SelectionKind

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finder 预览").font(.title3.weight(.semibold))
                    Text("更改会实时显示在预览中。")
                        .font(.callout).foregroundStyle(Color.primary.opacity(0.78))
                }
                Spacer(minLength: 12)
                Picker("预览对象", selection: $target) {
                    Text("文件").tag(SelectionKind.files)
                    Text("文件夹").tag(SelectionKind.folders)
                }
                .labelsHidden().pickerStyle(.segmented).controlSize(.small).fixedSize()
            }
            .padding(28)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        previewContent
                        Color.clear
                            .frame(minHeight: 0, idealHeight: 0, maxHeight: .infinity)
                    }
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                    .background {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture(perform: dismissEditor)
                    }
                }
                .frame(height: geometry.size.height)
                .clipped()
            }

            Label("预览本应用菜单的内容与顺序；灰色系统项仅为示意", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: target)
    }

    @ViewBuilder
    private var previewContent: some View {
        if #available(macOS 26.0, *) {
            // Keep glass rendering inside the preview's scroll viewport.
            GlassEffectContainer { previewGroup }
        } else {
            previewGroup
        }
    }

    private var previewGroup: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Image(systemName: target == .folders ? "folder.fill" : "doc.text.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.blue.gradient)
                    .shadow(color: .blue.opacity(0.16), radius: 14, y: 8)
                    .frame(height: 76)
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text(verbatim: target == .folders ? "My Project" : "README.md")
                        .font(.callout.weight(.semibold))
                    Text(target == .folders ? "文件夹" : "Markdown 文档")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            menu
        }
        .frame(maxWidth: 320)
        .contentShape(Rectangle())
        // Only the surrounding blank space dismisses the editor.
        .onTapGesture { }
        .padding(.horizontal, 28)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity)
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
        .padding(8)
        .modifier(GlassSurface(cornerRadius: 18))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.09), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("右键菜单预览")
    }

    private func previewRow(_ item: MenuItem) -> some View {
        let highlighted = item.id == highlightedID
        return HStack(spacing: 9) {
            ItemIcon(item: item, size: 17, isHighlighted: highlighted)
            Text(item.title).lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .foregroundStyle(highlighted ? Color.white : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(highlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
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
