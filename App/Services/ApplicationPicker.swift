import AppKit
import UniformTypeIdentifiers

@MainActor
enum ApplicationPicker {
    static func choose(completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "添加应用"
        panel.message = "选择要加入右键菜单的应用。文件夹支持取决于所选应用。"
        panel.prompt = "添加"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            if response == .OK { completion(panel.urls) }
        }
    }
}
