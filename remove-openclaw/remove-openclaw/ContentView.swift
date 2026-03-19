import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = OpenClawUninstallViewModel()
    @State private var showUninstallConfirm = false
    @State private var exportMessage: String?
    @AppStorage("terminateRunningProcessesBeforeUninstall")
    private var terminateRunningProcessesBeforeUninstall = true

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            actionBar
            exportStatusView
            statusView
            resultView
            targetsListView
        }
        .padding(20)
        .frame(minWidth: 840, minHeight: 620)
        .onAppear {
            if !viewModel.hasScanned {
                viewModel.scan()
            }
        }
        .alert("确认卸载 OpenClaw", isPresented: $showUninstallConfirm) {
            Button("取消", role: .cancel) {}
            Button("卸载", role: .destructive) {
                viewModel.uninstall(
                    terminateRunningProcesses: terminateRunningProcessesBeforeUninstall
                )
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OpenClaw 卸载工具")
                .font(.title.bold())
            Text("逻辑参考 free-mac-space 的 OpenClaw 完整清理流程：扫描应用、缓存、配置、日志与容器残留，然后统一移入废纸篓。")
                .foregroundStyle(.secondary)
        }
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    viewModel.scan()
                } label: {
                    Label(viewModel.hasScanned ? "重新扫描" : "开始扫描", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning || viewModel.isUninstalling)

                Button(role: .destructive) {
                    showUninstallConfirm = true
                } label: {
                    Label("卸载 OpenClaw", systemImage: "trash")
                }
                .disabled(
                    viewModel.isScanning ||
                    viewModel.isUninstalling ||
                    viewModel.targets.isEmpty
                )

                Button {
                    exportTargetsList()
                } label: {
                    Label("导出清单", systemImage: "square.and.arrow.up")
                }
                .disabled(
                    viewModel.isScanning ||
                    viewModel.isUninstalling ||
                    viewModel.targets.isEmpty
                )

                Spacer()

                if let lastScannedAt = viewModel.lastScannedAt {
                    Text("上次扫描：\(lastScannedAt.formatted(date: .omitted, time: .standard))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("卸载前自动退出 OpenClaw 进程", isOn: $terminateRunningProcessesBeforeUninstall)
                .toggleStyle(.switch)
                .disabled(viewModel.isUninstalling)
        }
    }

    @ViewBuilder
    private var exportStatusView: some View {
        if let exportMessage {
            Label(exportMessage, systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isScanning {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在扫描 OpenClaw 相关路径...")
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.isUninstalling {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在将 OpenClaw 文件移入废纸篓...")
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        } else if viewModel.targets.isEmpty {
            Label("未发现 OpenClaw 相关文件。", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        } else {
            Label(
                "发现 \(viewModel.targets.count) 个可清理项，总计 \(formattedBytes(viewModel.totalTargetSize))。",
                systemImage: "folder.fill.badge.minus"
            )
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if let result = viewModel.lastResult {
            VStack(alignment: .leading, spacing: 6) {
                Text("本次卸载结果")
                    .font(.headline)
                Text("已退出进程：\(result.terminatedProcessCount) 个")
                if result.forceTerminatedProcessCount > 0 {
                    Text("其中强制退出：\(result.forceTerminatedProcessCount) 个")
                        .foregroundStyle(.secondary)
                }
                Text("已移入废纸篓：\(result.movedToTrashCount) 项（\(formattedBytes(result.movedToTrashSize))）")
                Text("失败：\(result.failedCount) 项")
                    .foregroundStyle(result.failedCount > 0 ? .orange : .secondary)
                if !result.failedProcessNames.isEmpty {
                    Text("进程退出失败（最多显示 5 条）:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(result.failedProcessNames, id: \.self) { name in
                        Text(name)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if !result.failedPaths.isEmpty {
                    Text("失败路径（最多显示 5 条）:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(result.failedPaths, id: \.self) { path in
                        Text(path)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var targetsListView: some View {
        if viewModel.targets.isEmpty {
            ContentUnavailableView(
                "没有待卸载项",
                systemImage: "tray",
                description: Text("点击“开始扫描”检查 OpenClaw 相关残留。")
            )
        } else {
            List(viewModel.targets) { target in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: target.isDirectory ? "folder" : "doc")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.path)
                            .font(.callout.monospaced())
                            .lineLimit(2)
                        Text(formattedBytes(target.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }

    private func formattedBytes(_ size: Int64) -> String {
        byteFormatter.string(fromByteCount: size)
    }

    private var confirmMessage: String {
        var message = "将把 \(viewModel.targets.count) 个 OpenClaw 相关文件或目录移入废纸篓，总计 \(formattedBytes(viewModel.totalTargetSize))。"
        if terminateRunningProcessesBeforeUninstall {
            message += "\n\n卸载前会先尝试退出正在运行的 OpenClaw 进程。"
        } else {
            message += "\n\n已关闭自动退出进程，可能导致部分文件删除失败。"
        }
        return message
    }

    private func exportTargetsList() {
        let panel = NSSavePanel()
        panel.title = "导出 OpenClaw 待清理清单"
        panel.message = "支持导出为 .txt 或 .json"
        panel.nameFieldStringValue = "openclaw-cleanup-targets.txt"
        panel.allowedContentTypes = [.plainText, .json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            let exportedURL = try viewModel.exportTargets(to: selectedURL)
            exportMessage = "已导出清单：\(exportedURL.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
