import Foundation

struct OpenClawTargetsExporter {
    enum ExportFormat {
        case txt
        case json
    }

    private struct ExportPayload: Codable {
        let generatedAt: String
        let totalCount: Int
        let totalSizeBytes: Int64
        let items: [ExportItem]
    }

    private struct ExportItem: Codable {
        let path: String
        let sizeBytes: Int64
        let isDirectory: Bool
    }

    static func export(
        targets: [OpenClawCleanupTarget],
        to rawURL: URL
    ) throws -> URL {
        let format = exportFormat(for: rawURL)
        let resolvedURL = resolvedExportURL(from: rawURL, format: format)
        let totalTargetSize = targets.reduce(0) { $0 + max($1.size, 0) }
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let data: Data

        switch format {
        case .txt:
            let lines = makeTextExportLines(
                targets: targets,
                generatedAt: generatedAt,
                totalTargetSize: totalTargetSize
            )
            data = Data(lines.joined(separator: "\n").utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let payload = ExportPayload(
                generatedAt: generatedAt,
                totalCount: targets.count,
                totalSizeBytes: totalTargetSize,
                items: targets.map {
                    ExportItem(
                        path: $0.path,
                        sizeBytes: $0.size,
                        isDirectory: $0.isDirectory
                    )
                }
            )
            data = try encoder.encode(payload)
        }

        try data.write(to: resolvedURL, options: .atomic)
        return resolvedURL
    }

    private static func exportFormat(for url: URL) -> ExportFormat {
        let ext = url.pathExtension.lowercased()
        if ext == "json" {
            return .json
        }
        return .txt
    }

    private static func resolvedExportURL(from rawURL: URL, format: ExportFormat) -> URL {
        let ext = rawURL.pathExtension.lowercased()
        if ext == "json" || ext == "txt" {
            return rawURL
        }
        let suffix = format == .json ? "json" : "txt"
        return rawURL.appendingPathExtension(suffix)
    }

    private static func makeTextExportLines(
        targets: [OpenClawCleanupTarget],
        generatedAt: String,
        totalTargetSize: Int64
    ) -> [String] {
        var lines: [String] = []
        lines.append("OpenClaw Cleanup Targets")
        lines.append("Generated At: \(generatedAt)")
        lines.append("Total Count: \(targets.count)")
        lines.append("Total Size Bytes: \(totalTargetSize)")
        lines.append("")
        lines.append("PATH\tSIZE_BYTES\tIS_DIRECTORY")

        for target in targets {
            lines.append("\(target.path)\t\(target.size)\t\(target.isDirectory ? "true" : "false")")
        }
        return lines
    }
}
