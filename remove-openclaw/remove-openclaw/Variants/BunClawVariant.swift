import Foundation

struct BunClawVariant: ClawVariant {
    let id = "bunclaw"
    let displayName = "BunClaw"
    let description = "基于 Bun 运行时的高性能 OpenClaw 分支"
    let iconSystemName = "hare"

    let bundleIdentifiers = ["com.bunclaw"]
    let launchAgentLabels = ["com.bunclaw"]
    let cliBinaryNames = ["bunclaw"]
}
