import Foundation

struct MiniClawVariant: ClawVariant {
    let id = "miniclaw"
    let displayName = "MiniClaw"
    let description = "精简版 OpenClaw，适合低配设备"
    let iconSystemName = "rectangle.compress.vertical"

    let bundleIdentifiers = ["com.miniclaw.heartbeat"]
    let launchAgentLabels = ["com.miniclaw.heartbeat"]
    let cliBinaryNames = ["miniclaw"]
    let stateDirs = [".miniclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/MiniClaw",
            "\(home)/Library/Caches/MiniClaw",
        ]
    }
}
