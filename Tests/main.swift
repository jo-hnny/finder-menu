import AppKit

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let file = temporary.appendingPathComponent("中文 空格 #?.txt")
try Data("fixture".utf8).write(to: file)
let folder = temporary.appendingPathComponent("目录 空格", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var entry = MenuEntry.defaults[0]
expect(entry.applies(to: [file, folder]), "Both scope must allow mixed selection")
entry.scope = .files
expect(entry.applies(to: [file]), "File scope must allow files")
expect(!entry.applies(to: [file, folder]), "File scope must reject mixed selection")
entry.scope = .folders
expect(entry.applies(to: [folder]), "Folder scope must allow folders")
entry.enabled = false
expect(!entry.applies(to: [folder]), "Disabled items must not appear")
expect(!entry.applies(to: []), "No menu without a target")
var reordered = Array(MenuEntry.defaults.reversed())
reordered[0].enabled = false
let config = MenuConfiguration(entries: reordered)
let decoded = try JSONDecoder().decode(MenuConfiguration.self, from: JSONEncoder().encode(config))
expect(config == decoded, "Persistence must preserve order, IDs and disabled state")
try decoded.validate()
try MenuConfiguration(entries: []).validate()
do {
    try MenuConfiguration(version: 999, entries: []).validate()
    fatalError("Unknown versions must not silently overwrite configuration")
} catch ConfigurationError.invalid {}
do {
    try MenuConfiguration(entries: [entry, entry]).validate()
    fatalError("Duplicate IDs must be rejected")
} catch ConfigurationError.invalid {}
print("PASS: selection scope, disabled state, order persistence, empty configuration and validation")
