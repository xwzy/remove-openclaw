import Foundation

struct MaClawVariant: ClawVariant {
    let id = "maclaw"
    let displayName = "MaClaw"
    let description = "Wails 框架开发的 macOS 原生客户端"
    let iconSystemName = "desktopcomputer"

    let appNames = ["MaClaw"]
    let bundleIdentifiers = ["com.wails.MaClaw"]
    let cliBinaryNames = ["MaClaw"]
    let stateDirs = [".maclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/MaClaw",
            "\(home)/Library/Caches/MaClaw",
        ]
    }
}
