import Foundation

struct PicoClawVariant: ClawVariant {
    let id = "picoclaw"
    let displayName = "PicoClaw"
    let description = "极简 TUI 启动器，Rust 编写"
    let iconSystemName = "terminal"

    let appNames = ["PicoClaw Launcher"]
    let bundleIdentifiers = ["com.picoclaw.launcher", "io.picoclaw.launcher"]
    let launchAgentLabels = ["io.picoclaw.launcher"]
    let cliBinaryNames = ["picoclaw", "picoclaw-launcher", "picoclaw-launcher-tui"]
    let stateDirs = [".picoclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/PicoClaw",
        ]
    }
}
