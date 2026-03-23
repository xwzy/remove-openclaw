import Foundation

struct OpenClawXVariant: ClawVariant {
    let id = "openclawx"
    let displayName = "OpenClawX"
    let description = "增强版 OpenClaw，集成更多国内模型"

    let cliBinaryNames = ["openbot"]
    let stateDirs = [".openbot"]
}
