import Foundation

struct ZeroClawVariant: ClawVariant {
    let id = "zeroclaw"
    let displayName = "ZeroClaw"
    let description = "Rust 实现的高性能 OpenClaw 守护进程"
    let iconSystemName = "bolt"

    let bundleIdentifiers = ["com.zeroclaw.daemon"]
    let launchAgentLabels = ["com.zeroclaw.daemon"]
    let cliBinaryNames = ["zeroclaw"]
    let stateDirs = [".zeroclaw"]

    var extraExplicitPaths: [String] {
        return [
            "/opt/homebrew/Cellar/zeroclaw",
            "/opt/homebrew/opt/zeroclaw",
            "/opt/homebrew/var/zeroclaw",
            "/usr/local/Cellar/zeroclaw",
            "/usr/local/opt/zeroclaw",
            "/usr/local/var/zeroclaw",
        ]
    }
}
