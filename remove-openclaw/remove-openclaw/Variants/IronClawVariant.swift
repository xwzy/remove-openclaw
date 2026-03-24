import Foundation

struct IronClawVariant: ClawVariant {
    let id = "ironclaw"
    let displayName = "IronClaw"
    let description = "Go 实现的 OpenClaw 守护进程"
    let iconSystemName = "hammer"

    let bundleIdentifiers = ["com.ironclaw.daemon"]
    let launchAgentLabels = ["com.ironclaw.daemon"]
    let cliBinaryNames = ["ironclaw"]
    let stateDirs = [".ironclaw"]

    nonisolated var extraExplicitPaths: [String] {
        return [
            "/opt/homebrew/Cellar/ironclaw",
            "/opt/homebrew/opt/ironclaw",
            "/opt/homebrew/var/ironclaw",
            "/usr/local/Cellar/ironclaw",
            "/usr/local/opt/ironclaw",
            "/usr/local/var/ironclaw",
        ]
    }
}
