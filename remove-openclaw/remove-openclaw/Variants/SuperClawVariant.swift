import Foundation

struct SuperClawVariant: ClawVariant {
    let id = "superclaw"
    let displayName = "SuperClaw"
    let description = "增强版 OpenClaw，支持插件系统"
    let iconSystemName = "star"

    let stateDirs = [".superclaw", ".config/superclaw"]
}
