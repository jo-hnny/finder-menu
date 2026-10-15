import AppKit
import SwiftUI

struct MenuPreview: View {
    let entries: [MenuEntry]
    let highlightedID: UUID?
    @State private var target: MenuEntry.Scope = .folders

    private var visibleEntries: [MenuEntry] {
        entries.filter { $0.enabled && ($0.scope == .both || $0.scope == target) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Finder 预览").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Picker("预览对象", selection: $target) {
                    Text("文件").tag(MenuEntry.Scope.files)
                    Text("文件夹").tag(MenuEntry.Scope.folders)
                }
                .labelsHidden().pickerStyle(.segmented).controlSize(.small).frame(width: 140)
            }
            .padding(.bottom, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: target == .folders ? "folder.fill" : "doc.text")
                            .font(.system(size: 32)).foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.88))
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target == .folders ? "My Project" : "README.md")
                                .font(.system(size: 12, weight: .medium))
                            Text(target == .folders ? "文件夹" : "Markdown 文档")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    VStack(spacing: 2) {
                        systemRow("打开", shortcut: "⌘O")
                        systemRow("显示简介", shortcut: "⌘I")
                        Divider().padding(.horizontal, 8).padding(.vertical, 4)
                        if visibleEntries.isEmpty {
                            Text("此处没有已启用的菜单项")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                        ForEach(visibleEntries) { entry in
                            previewRow(entry)
                        }
                        Divider().padding(.horizontal, 8).padding(.vertical, 4)
                        systemRow("快速操作", shortcut: "›")
                    }
                    .padding(6)
                    .background(Color(red: 0.985, green: 0.989, blue: 1), in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white, lineWidth: 1))
                    .shadow(color: Color(red: 0.2, green: 0.27, blue: 0.4).opacity(0.15), radius: 20, y: 12)
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("右键菜单预览")
                }
                .frame(maxWidth: 340).padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            Text("预览本应用菜单的内容与顺序")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 16)
        }
        .padding(26)
        .background {
            LinearGradient(colors: [Color(red: 0.94, green: 0.95, blue: 0.975), Color(red: 0.91, green: 0.935, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func previewRow(_ entry: MenuEntry) -> some View {
        let highlighted = entry.id == highlightedID
        let unavailable = entry.kind == .application && entry.applicationURL == nil
        return HStack(spacing: 9) {
            Group {
                if entry.kind == .copyPaths {
                    Image(systemName: "doc.on.doc").font(.system(size: 13))
                } else if let url = entry.applicationURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
                } else {
                    Image(systemName: "app.dashed")
                }
            }
            .frame(width: 17, height: 17)
            Text(entry.title).lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .foregroundStyle(highlighted ? Color.white : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(highlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
        .opacity(unavailable ? 0.4 : 1)
        .accessibilityElement(children: .combine)
    }

    private func systemRow(_ title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut).foregroundStyle(.tertiary)
        }
        .font(.system(size: 12)).foregroundStyle(.secondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .accessibilityLabel("系统菜单示意：\(title)")
    }
}
