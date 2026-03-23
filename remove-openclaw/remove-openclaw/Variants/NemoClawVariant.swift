import Foundation

struct NemoClawVariant: ClawVariant {
    let id = "nemoclaw"
    let displayName = "NemoClaw"
    let description = "支持语音输入的 OpenClaw 变体"
    let iconSystemName = "waveform"

    let cliBinaryNames = ["nemoclaw", "openshell"]
    let stateDirs = [
        ".nemoclaw", ".config/nemoclaw", ".config/openshell",
    ]
}
