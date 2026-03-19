import Foundation

struct OpenClawTargetsImporter {
    struct ImportResult {
        let targets: [OpenClawCleanupTarget]
        let warnings: [String]
        let duplicatePathCount: Int
        let missingPathCount: Int
    }

    enum ImportError: LocalizedError {
        case unreadableFile(String)
        case unsupportedFormat(String)
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .unreadableFile(let message):
                return "无法读取清单文件: \(message)"
            case .unsupportedFormat(let ext):
                return "不支持的清单格式: .\(ext)。请使用 .txt 或 .json。"
            case .invalidJSON:
                return "JSON 清单格式无效。"
            }
        }
    }

    private struct ExportPayload: Decodable {
        let items: [ExportItem]
    }

    private struct ExportItem: Decodable {
        let path: String
        let sizeBytes: Int64
        let isDirectory: Bool
    }

    private struct RunReportPayload: Decodable {
        let scan: ScanPayload
    }

    private struct ScanPayload: Decodable {
        let targets: [ScanItem]
    }

    private struct ScanItem: Decodable {
        let path: String
        let sizeBytes: Int64
        let isDirectory: Bool
    }

    private struct GenericObjectItem: Decodable {
        let path: String
        let sizeBytes: Int64?
        let size: Int64?
        let isDirectory: Bool?
        let is_dir: Bool?
    }

    static func importTargets(from rawURL: URL) throws -> [OpenClawCleanupTarget] {
        try importTargetsWithReport(from: rawURL).targets
    }

    static func importTargetsWithReport(from rawURL: URL) throws -> ImportResult {
        let fileURL = rawURL.standardizedFileURL
        let data: Data

        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ImportError.unreadableFile(error.localizedDescription)
        }

        let ext = fileURL.pathExtension.lowercased()
        let baseDirectoryURL = fileURL.deletingLastPathComponent()
        let parsedTargets: [OpenClawCleanupTarget]

        switch ext {
        case "json":
            guard let targets = parseJSONTargets(data, baseDirectoryURL: baseDirectoryURL) else {
                throw ImportError.invalidJSON
            }
            parsedTargets = targets
        case "txt":
            parsedTargets = parseTextTargets(data, baseDirectoryURL: baseDirectoryURL)
        case "":
            if let targets = parseJSONTargets(data, baseDirectoryURL: baseDirectoryURL) {
                parsedTargets = targets
            } else {
                parsedTargets = parseTextTargets(data, baseDirectoryURL: baseDirectoryURL)
            }
        default:
            throw ImportError.unsupportedFormat(ext)
        }

        let deduplicated = deduplicateTargets(parsedTargets)
        let missingPaths = collectMissingPaths(in: deduplicated.targets)

        var warnings: [String] = []
        if deduplicated.duplicateCount > 0 {
            warnings.append(
                "清单中发现 \(deduplicated.duplicateCount) 条重复路径，已自动去重。"
            )
        }

        if !missingPaths.isEmpty {
            let preview = missingPaths.prefix(3).joined(separator: "、")
            let suffix = missingPaths.count > 3 ? " 等 \(missingPaths.count) 项。" : "。"
            warnings.append(
                "清单中有 \(missingPaths.count) 条路径当前不存在，卸载时会自动跳过：\(preview)\(suffix)"
            )
        }

        return ImportResult(
            targets: deduplicated.targets,
            warnings: warnings,
            duplicatePathCount: deduplicated.duplicateCount,
            missingPathCount: missingPaths.count
        )
    }

    private static func parseJSONTargets(
        _ data: Data,
        baseDirectoryURL: URL
    ) -> [OpenClawCleanupTarget]? {
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(ExportPayload.self, from: data) {
            return payload.items.compactMap {
                makeCleanupTarget(
                    path: $0.path,
                    size: $0.sizeBytes,
                    isDirectory: $0.isDirectory,
                    baseDirectoryURL: baseDirectoryURL
                )
            }
        }

        if let payload = try? decoder.decode(RunReportPayload.self, from: data) {
            return payload.scan.targets.compactMap {
                makeCleanupTarget(
                    path: $0.path,
                    size: $0.sizeBytes,
                    isDirectory: $0.isDirectory,
                    baseDirectoryURL: baseDirectoryURL
                )
            }
        }

        if let pathArray = try? decoder.decode([String].self, from: data) {
            return pathArray.compactMap {
                makeCleanupTarget(
                    path: $0,
                    size: 0,
                    isDirectory: false,
                    baseDirectoryURL: baseDirectoryURL
                )
            }
        }

        if let objectArray = try? decoder.decode([GenericObjectItem].self, from: data) {
            return objectArray.compactMap {
                makeCleanupTarget(
                    path: $0.path,
                    size: $0.sizeBytes ?? $0.size ?? 0,
                    isDirectory: $0.isDirectory ?? $0.is_dir ?? false,
                    baseDirectoryURL: baseDirectoryURL
                )
            }
        }

        return nil
    }

    private static func parseTextTargets(
        _ data: Data,
        baseDirectoryURL: URL
    ) -> [OpenClawCleanupTarget] {
        let text = String(decoding: data, as: UTF8.self)
        let allLines = text.components(separatedBy: .newlines)
        let headerMarker = "PATH\tSIZE_BYTES\tIS_DIRECTORY"

        var targets: [OpenClawCleanupTarget] = []
        var inTable = false
        let hasStructuredHeader = allLines.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == headerMarker
        }

        for rawLine in allLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !trimmed.hasPrefix("#") else { continue }

            if trimmed == headerMarker {
                inTable = true
                continue
            }

            if hasStructuredHeader && !inTable {
                continue
            }

            if hasStructuredHeader {
                if let tableTarget = parseStructuredTextLine(trimmed, baseDirectoryURL: baseDirectoryURL) {
                    targets.append(tableTarget)
                }
                continue
            }

            if isMetadataLine(trimmed) {
                continue
            }

            if let parsedTarget = parseFlexibleTextLine(trimmed, baseDirectoryURL: baseDirectoryURL) {
                targets.append(parsedTarget)
            }
        }

        return targets
    }

    private static func parseStructuredTextLine(
        _ line: String,
        baseDirectoryURL: URL
    ) -> OpenClawCleanupTarget? {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard let rawPath = columns.first else { return nil }

        let size = columns.count > 1 ? Int64(columns[1]) ?? 0 : 0
        let isDirectory = columns.count > 2 ? parseBool(columns[2]) ?? false : false

        return makeCleanupTarget(
            path: rawPath,
            size: size,
            isDirectory: isDirectory,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    private static func parseFlexibleTextLine(
        _ line: String,
        baseDirectoryURL: URL
    ) -> OpenClawCleanupTarget? {
        if line.contains("\t") {
            return parseStructuredTextLine(line, baseDirectoryURL: baseDirectoryURL)
        }
        return makeCleanupTarget(
            path: line,
            size: 0,
            isDirectory: false,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    private static func makeCleanupTarget(
        path rawPath: String,
        size: Int64,
        isDirectory: Bool,
        baseDirectoryURL: URL
    ) -> OpenClawCleanupTarget? {
        guard let normalizedPath = normalizePath(rawPath, baseDirectoryURL: baseDirectoryURL) else {
            return nil
        }
        return OpenClawCleanupTarget(
            path: normalizedPath,
            size: max(size, 0),
            isDirectory: isDirectory
        )
    }

    private static func normalizePath(_ rawPath: String, baseDirectoryURL: URL) -> String? {
        var value = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("file://"),
           let fileURL = URL(string: value),
           fileURL.isFileURL {
            return fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        }

        if value.hasPrefix("~") {
            value = NSString(string: value).expandingTildeInPath
        }

        let url: URL
        if value.hasPrefix("/") {
            url = URL(fileURLWithPath: value)
        } else {
            url = baseDirectoryURL.appendingPathComponent(value)
        }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func isMetadataLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasPrefix("openclaw cleanup targets") ||
            lower.hasPrefix("generated at:") ||
            lower.hasPrefix("total count:") ||
            lower.hasPrefix("total size bytes:")
    }

    private struct DeduplicationResult {
        let targets: [OpenClawCleanupTarget]
        let duplicateCount: Int
    }

    private static func deduplicateTargets(_ targets: [OpenClawCleanupTarget]) -> DeduplicationResult {
        var deduplicated: [OpenClawCleanupTarget] = []
        var seenPaths: Set<String> = []
        var duplicateCount = 0

        for target in targets {
            let canonicalPath = URL(fileURLWithPath: target.path)
                .standardizedFileURL
                .resolvingSymlinksInPath()
                .path

            guard seenPaths.insert(canonicalPath).inserted else {
                duplicateCount += 1
                continue
            }

            deduplicated.append(
                OpenClawCleanupTarget(
                    path: canonicalPath,
                    size: max(target.size, 0),
                    isDirectory: target.isDirectory
                )
            )
        }

        return DeduplicationResult(
            targets: deduplicated,
            duplicateCount: duplicateCount
        )
    }

    private static func collectMissingPaths(in targets: [OpenClawCleanupTarget]) -> [String] {
        let fileManager = FileManager.default
        return targets
            .map(\.path)
            .filter { !fileManager.fileExists(atPath: $0) }
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes", "y":
            return true
        case "false", "0", "no", "n":
            return false
        default:
            return nil
        }
    }
}
