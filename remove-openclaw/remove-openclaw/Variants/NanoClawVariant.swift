import Foundation

struct NanoClawVariant: ClawVariant {
    let id = "nanoclaw"
    let displayName = "NanoClaw"
    let description = "超轻量 OpenClaw 分支"
    let iconSystemName = "cpu"

    let bundleIdentifiers = ["com.nanoclaw"]
    let launchAgentLabels = ["com.nanoclaw"]
    let stateDirs = [".config/nanoclaw"]
}
