# remove-openclaw

一个只做一件事的 macOS App: 扫描并卸载 OpenClaw（将相关文件移入废纸篓）。

## 功能

- 扫描 OpenClaw 相关残留（应用、配置、缓存、日志、容器目录等）
- 支持开关“卸载前自动退出 OpenClaw 进程”（默认开启，必要时强制退出）
- 展示待清理路径和体积
- 支持导出待清理清单（`.txt` / `.json`）
- 支持从清单文件恢复目标（`--target-file`），便于审计后再执行卸载
- 支持严格清单模式（`--strict-target-file`），空清单直接失败，适合自动化
- 清单导入会提示告警（重复路径、路径不存在），并写入 JSON 结果
- 支持告警即失败（`--fail-on-warnings`），可阻断不干净的清单输入
- 一键卸载（移入废纸篓，失败项会显示）
- CLI 真实卸载需显式确认（`--confirm` / `--yes`），降低误操作风险

核心路径发现与校验逻辑参考 `../free-mac-space` 中 OpenClaw 完整清理实现。

## 构建

```bash
cd remove-openclaw
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme remove-openclaw \
  -project remove-openclaw.xcodeproj \
  -destination 'platform=macOS' \
  build
```

## 命令行模式

构建后可直接执行 App 二进制进入 CLI 模式：

```bash
APP="$(ls -dt ~/Library/Developer/Xcode/DerivedData/remove-openclaw-*/Build/Products/Debug/remove-openclaw.app | head -n 1)"
"$APP/Contents/MacOS/remove-openclaw" --cli --help
```

常用示例：

```bash
# 仅扫描
"$APP/Contents/MacOS/remove-openclaw" --cli --scan

# 扫描并导出 JSON 清单
"$APP/Contents/MacOS/remove-openclaw" --cli --export ~/Desktop/openclaw-targets.json

# 扫描并输出执行结果 JSON（包含统计与失败详情）
"$APP/Contents/MacOS/remove-openclaw" --cli --scan --json-output ~/Desktop/openclaw-result.json

# 从清单文件打印目标列表（支持 .txt/.json）
"$APP/Contents/MacOS/remove-openclaw" --cli --target-file ~/Desktop/openclaw-targets.json --list

# 从清单文件卸载，且要求清单非空（CI 推荐）
"$APP/Contents/MacOS/remove-openclaw" --cli --target-file ~/Desktop/openclaw-targets.json --strict-target-file --uninstall --confirm

# 导入清单若有告警（重复/不存在路径）则直接失败
"$APP/Contents/MacOS/remove-openclaw" --cli --target-file ~/Desktop/openclaw-targets.json --fail-on-warnings --list

# 扫描后直接卸载
"$APP/Contents/MacOS/remove-openclaw" --cli --uninstall --confirm

# 按清单文件执行卸载（推荐先 --dry-run）
"$APP/Contents/MacOS/remove-openclaw" --cli --target-file ~/Desktop/openclaw-targets.json --uninstall --confirm

# 预演卸载（不实际删除）
"$APP/Contents/MacOS/remove-openclaw" --cli --uninstall --dry-run

# 卸载但不自动退出进程
"$APP/Contents/MacOS/remove-openclaw" --cli --uninstall --confirm --no-terminate-processes
```
