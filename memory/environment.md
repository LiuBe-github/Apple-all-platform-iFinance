# 本机环境与验证能力

> 记录时间：2026-09-26（第二轮更新：iOS 27.0 模拟器运行时已安装）｜ 更换 Xcode / 安装运行时 / 换设备后请更新本节。

## 1. 工具链

| 项 | 值 |
|----|-----|
| Xcode | 27.0（Build `27A266a`） |
| SDK | iOS 27.0 / macOS 27.0 / watchOS 27.0 |
| 工程语言模式 | `SWIFT_VERSION = 5.0` |
| 宿主系统 | macOS 27.0（Build `26A428`） |

## 2. 模拟器运行时

| 平台 | 已安装 | 说明 |
|------|--------|------|
| iOS | 18.4、18.6、**27.0** | 18.x 用于下界验证（iPhone 16 / iPhone SE(3rd) / iPad Pro 11"(M4)）；**27.0 现已安装**，设备为 iPhone 17 / 18 系列，上界可运行验证 |
| watchOS | 26.2、26.4、26.5 | 用于 watch 端运行验证 |
| watchOS 27 | ❌ 不可用 | `xcodebuild -downloadPlatform watchOS` 仍返回 “not available for download”，只能编译级验证 |

结论：**iOS 上界（27.0）已可在模拟器运行验证**（2026-09-26 复查发现运行时已装好，型号为 iPhone 17 / 18 系列）；watchOS 27 仍只能编译级验证；下界（macOS 15 / watchOS 11）本机无法运行，属编译 + API 审查级验证。

## 3. 真机

| 设备 | 标识 | 状态 |
|------|------|------|
| iPhone 16 Pro（真机） | UDID `00008140-000C05692013C01C` | 需**解锁并信任此电脑**，否则 `devicectl` 显示 unavailable |
| 配对的 Apple Watch | Watch7,11 | 配对状态会导致每次 Run 额外推送 Watch App |

**真机部署慢的历史原因与当前配置**（已实测）：

1. 原 iOS scheme 通过 `Embed Watch Content` + target dependency 依赖 watch target → 每次 Run 都会构建并推送 Watch App。现已把普通 Run/Test/Profile/Analyze 与 Watch 分离，仅 Archive 构建并嵌入 Watch；
2. Xcode 会附加调试器（lldb attach）；
3. 设备锁定/休眠时 Xcode 反复重试，等待时间显著变长。

构建本身很快：**增量 3～6s，全量冷构建约 24～25s**。

## 4. 可用脚本

| 脚本 | 用途 | 备注 |
|------|------|------|
| `scripts/check_localization.py` | 本地化审计：代码引用的 key ↔ 四语言包比对（缺失/语言间不一致返回非零码，「未被引用」仅提示） | 提交前必跑；支持指定 target：`python3 scripts/check_localization.py iOS macOS` |
| `scripts/run-on-device.sh` | 真机快速部署：`xcodebuild` 增量构建 → `devicectl` 安装 → 启动，并打印各阶段耗时；跳过 Watch 部署与调试器附加 | 参数：`-s <scheme>`、`-d <UDID>`、`--console`、`--no-build` |
| `reset_ifinance_data.sh` | 清模拟器账号与账单 | ⚠️ 当前有 Bundle ID 错误（见 [open-items.md](open-items.md) OI-09） |

## 5. 验证能力矩阵（重要）

| 平台/版本 | 编译 | 运行 | 说明 |
|-----------|------|------|------|
| iOS 18.4 / 18.6 | ✅ | ✅ 模拟器 | 主力验证环境（`-only-testing:` 跑单测） |
| iOS 27.0 | ✅ | ✅ 模拟器 | 运行时已安装（iPhone 17 / 18 系列）；2026-09-26 实测两版 App 在 iPhone 17 上安装启动正常 |
| macOS 27 | ✅ | ✅ 本机 | `xcodebuild test -scheme MaciFinance -destination 'platform=macOS'` |
| macOS 15 | ✅ | ❌ | 无法本机运行 |
| watchOS 26.x | ✅ | ✅ 模拟器 | watch 端冒烟 |
| watchOS 11 / 27 | ✅ | ❌ | 11 无法运行；27 运行时不可下载 |

## 6. 已知的环境级坑

1. **测试必须串行**：并行执行多个 `xcodebuild test`（尤其含 UI 测试）会出现测试宿主互相干扰，表现为 `Early unexpected exit`、UI 测试超时或随机失败（例：`MaciFinanceTests/DashboardLogicTests.testDailyDataPointsGeneration`，已加 `.serialized` 缓解）。
2. **UI 测试在克隆模拟器上崩溃**：Xcode 27 会触发 XCTest ↔ Swift Testing 互操作递归（栈深 900+）后 SIGSEGV；崩溃日志全部来自 `XCTestDevices`，**普通启动不受影响**。验证请加 `-only-testing:` 跳过 UI 测试。
3. **并行构建会争抢同一个 DerivedData**：`error: unable to attach DB ... database is locked`。并行验证时给每个 scheme 指定独立 `-derivedDataPath`。
4. **`simctl spawn defaults write` 的可见域**：写入 App 的偏好（如 `app_language`）后，App 能读到；但 App 自己写入的 `AppleLanguages` 不会出现在 `defaults read` 里（写在 App 自身域），验证机制时应依赖 `Logger` 日志（subsystem `com.liube.ifinance`，category `Localization`）。
5. **日志级别**：`Logger.info/debug` 不落盘，`log show` 查不到；状态类日志请用 `notice`（项目里隐私遮罩、AppleLanguages 同步都是 `notice`）。
6. **模拟器可能卡在 Shutdown**：`xcodebuild test` 自动启动模拟器失败时会反复重试并调用 `simctl diagnose`（最长 600s，看起来像"卡住"）。处理：先 `xcrun simctl boot <UDID>` + `xcrun simctl bootstatus <UDID> -b` 手动拉起，再跑测试，并用 `-destination 'id=<UDID>'` 显式指定设备。

## 7. 常用验证命令

```bash
# 四端编译（并行时给独立 DerivedData，避免锁冲突）
xcodebuild build -project iFinance.xcodeproj -scheme iFinance -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/dd_ios -quiet
xcodebuild build -project iFinance.xcodeproj -scheme iFinanceSwiftData -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/dd_sd -quiet
xcodebuild build -project iFinance.xcodeproj -scheme MaciFinance -destination 'platform=macOS' -derivedDataPath /tmp/dd_mac -quiet
xcodebuild build -project iFinance.xcodeproj -scheme 'WatchiFinance Watch App' -destination 'generic/platform=watchOS Simulator' -derivedDataPath /tmp/dd_watch -quiet

# 测试（务必串行）
xcodebuild test -project iFinance.xcodeproj -scheme iFinance -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -derivedDataPath /tmp/dd_ios -only-testing:iFinanceTests -quiet

# 模拟器冒烟
xcrun simctl bootstatus 7A81F674-CF28-475C-A74E-DCAABE006F08 -b
xcrun simctl install <UDID> <path>/iFinance.app && xcrun simctl launch <UDID> cn.liube.iFinance

# 查看应用内状态日志
xcrun simctl spawn <UDID> log show --last 2m --predicate 'category == "Localization" OR category == "BiometricLock"' --style compact
```
