import AppKit
import UniformTypeIdentifiers

@MainActor
enum ApplicationPicker {
    static func choose() async -> [URL] {
        let panel = NSOpenPanel()
        panel.title = String(localized: "添加应用")
        panel.message = String(localized: "选择要加入右键菜单的应用。文件夹支持取决于所选应用。")
        panel.prompt = String(localized: "添加")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return panel.runModal() == .OK ? panel.urls : []
        }
        return await panel.beginSheetModal(for: window) == .OK ? panel.urls : []
    }
}
