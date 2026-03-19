import Testing
@testable import remove_openclaw
import Foundation

struct remove_openclawTests {
    @Test("Import exporter JSON and deduplicate paths")
    func importExporterJSON() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("targets.json")
        let content = """
        {
          "items": [
            { "path": "/Applications/OpenClaw.app", "sizeBytes": 1024, "isDirectory": true },
            { "path": "/Applications/OpenClaw.app", "sizeBytes": 2048, "isDirectory": false }
          ]
        }
        """
        try Data(content.utf8).write(to: inputURL)

        let targets = try OpenClawTargetsImporter.importTargets(from: inputURL)
        #expect(targets.count == 1)
        #expect(targets[0].path == "/Applications/OpenClaw.app")
        #expect(targets[0].size == 1024)
        #expect(targets[0].isDirectory)
    }

    @Test("Import scan report JSON with relative path")
    func importScanReportJSON() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("scan-report.json")
        let content = """
        {
          "scan": {
            "targets": [
              { "path": "relative/OpenClaw", "sizeBytes": 88, "isDirectory": true }
            ]
          }
        }
        """
        try Data(content.utf8).write(to: inputURL)

        let targets = try OpenClawTargetsImporter.importTargets(from: inputURL)
        let expectedPath = tempDirectory
            .appendingPathComponent("relative/OpenClaw")
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        #expect(targets.count == 1)
        #expect(targets[0].path == expectedPath)
        #expect(targets[0].size == 88)
        #expect(targets[0].isDirectory)
    }

    @Test("Import structured text file and expand tilde")
    func importStructuredText() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("targets.txt")
        let content = """
        OpenClaw Cleanup Targets
        Generated At: 2026-03-19T14:00:00Z
        Total Count: 2
        Total Size Bytes: 1234

        PATH\tSIZE_BYTES\tIS_DIRECTORY
        /Applications/OpenClaw.app\t1024\ttrue
        ~/Library/Caches/OpenClaw\t210\ttrue
        """
        try Data(content.utf8).write(to: inputURL)

        let targets = try OpenClawTargetsImporter.importTargets(from: inputURL)
        let expectedHomePath = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Caches/OpenClaw"

        #expect(targets.count == 2)
        #expect(targets.contains(where: { $0.path == "/Applications/OpenClaw.app" && $0.size == 1024 && $0.isDirectory }))
        #expect(targets.contains(where: { $0.path == expectedHomePath && $0.size == 210 && $0.isDirectory }))
    }

    @Test("Import no-extension file and auto-detect JSON")
    func importNoExtensionFile() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("targets")
        let content = """
        {
          "items": [
            { "path": "/tmp/openclaw-demo", "sizeBytes": 1, "isDirectory": false }
          ]
        }
        """
        try Data(content.utf8).write(to: inputURL)

        let targets = try OpenClawTargetsImporter.importTargets(from: inputURL)
        #expect(targets.count == 1)
        #expect(targets[0].path == "/tmp/openclaw-demo")
        #expect(targets[0].size == 1)
        #expect(targets[0].isDirectory == false)
    }

    @Test("Reject unsupported extension")
    func importUnsupportedExtension() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("targets.md")
        try Data("demo".utf8).write(to: inputURL)

        do {
            _ = try OpenClawTargetsImporter.importTargets(from: inputURL)
            #expect(false)
        } catch let error as OpenClawTargetsImporter.ImportError {
            switch error {
            case .unsupportedFormat(let ext):
                #expect(ext == "md")
            default:
                #expect(false)
            }
        } catch {
            #expect(false)
        }
    }

    @Test("Report warnings for duplicate and missing paths")
    func importWarningsReport() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let guaranteedMissing = tempDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
            .path
        let inputURL = tempDirectory.appendingPathComponent("targets.json")
        let content = """
        {
          "items": [
            { "path": "\(guaranteedMissing)", "sizeBytes": 1, "isDirectory": false },
            { "path": "\(guaranteedMissing)", "sizeBytes": 2, "isDirectory": false }
          ]
        }
        """
        try Data(content.utf8).write(to: inputURL)

        let result = try OpenClawTargetsImporter.importTargetsWithReport(from: inputURL)
        #expect(result.targets.count == 1)
        #expect(result.duplicatePathCount == 1)
        #expect(result.missingPathCount == 1)
        #expect(result.warnings.contains(where: { $0.contains("重复路径") }))
        #expect(result.warnings.contains(where: { $0.contains("当前不存在") }))
    }

    private func makeTempDirectory() throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("remove-openclaw-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        return tempDirectory
    }
}
