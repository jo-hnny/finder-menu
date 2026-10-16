import AppKit
import FinderMenuCore
import SwiftUI

struct MenuEditor: View {
    let store: MenuStore

    var body: some View {
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
