# iFinance —— Agent 项目记忆

SwiftUI 全平台个人记账应用：iOS / macOS / watchOS 三个目标共用一个 Xcode 工程，无任何第三方依赖。

- 仓库：`LiuBe-github/Apple-all-platform-iFinance`
- 工程：`iFinance.xcodeproj`（Xcode 27，`SWIFT_VERSION = 5.0`）
- 详细记忆：[docs/PROJECT_MEMORY.md](docs/PROJECT_MEMORY.md)；接口文档：[docs/api/README.md](docs/api/README.md)
- 文案与注释使用中文；文档也用中文书写。

## 目标与版本

| Scheme | 目录 | 平台 | Bundle ID | 部署目标 |
|--------|------|------|-----------|----------|
| `iFinance` | `iFinance/` | iOS（iPhone + iPad） | `cn.liube.iFinance` | 18.0 |
| `iFinanceSwiftData` | `iFinanceSwiftData/` | iOS（SwiftData 版） | `cn.liube.iFinance.swiftdata` | 18.0 |
| `MaciFinance` | `MaciFinance/` | macOS | `cn.liube.MaciFinance` | 15.0 |
| `WatchiFinance Watch App` | `WatchiFinance Watch App/` | watchOS | `cn.liube.iFinance.watchkitapp` | 11.0 |

> 版本区间：iOS 18.0–27.x / macOS 15.0–27.x / watchOS 11.0–27.x；SDK 为 Xcode 27。iOS 17 已不再支持（2026-09 起）。

## 常用命令

```bash
xcodebuild -list -project iFinance.xcodeproj

xcodebuild build -project iFinance.xcodeproj -scheme iFinance -destination 'generic/platform=iOS Simulator'

xcodebuild test -project iFinance.xcodeproj -scheme iFinance -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project iFinance.xcodeproj -scheme MaciFinance -destination 'platform=macOS'

xcodebuild build -project iFinance.xcodeproj -scheme iFinanceSwiftData -destination 'generic/platform=iOS Simulator'
xcodebuild test -project iFinance.xcodeproj -scheme iFinanceSwiftData -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:iFinanceSwiftDataTests

# 真机快速部署（跳过 Watch 部署与调试器附加，打印各阶段耗时）
scripts/run-on-device.sh -s iFinance
```

测试目标：`iFinanceTests`（XCTest，38 用例）、`MaciFinanceTests`（Swift Testing，`@Test`）、watch/UI 测试为模板占位。
测试统一使用 `PersistenceController(inMemory: true)`，不触碰磁盘数据。

## 目录地图

```
iFinance/                 iOS：App/ Manager/ Models/ Protocol/ Helper/ Views/ Resources/
iFinanceSwiftData/        iOS SwiftData 版：App/ Data(@Model+容器)/ Manager/ Views/ Resources/ Helper/
MaciFinance/              macOS：App/ Manager/ Models/ Helpers/ Views/ Resources/
WatchiFinance Watch App/  watchOS：ContentView.swift（三 Tab）+ Models/WatchDataModel.swift
docs/                     项目记忆与接口文档（改动接口后同步更新）
```

> 工程使用 **Xcode 16+ 的文件系统同步分组**（`PBXFileSystemSynchronizedRootGroup`）：每个 target 对应一个顶层文件夹，文件夹内的源文件/资源自动入组，新增文件无需改 `project.pbxproj`。改动工程结构（增删 target、例外文件）请用 `xcodeproj` gem 脚本或 Xcode，不要手写 pbxproj。

层级约定：`Views/` 按业务分目录（Home / Transaction{Bills,Budget} / Tendency / Profile / Setting / Auth / Common）；Manager 全部是 `@MainActor final class ... ObservableObject` + `static let shared` + `private init`。

## 必须遵守的不变量

1. **数据隔离**：账单归属由 `Bill.createdBy == UserDefaults["AuthUserIdentifier"]` 决定。所有账单查询都必须叠加 `PersistenceController.billUserPredicate`；所有写入都必须设置 `createdBy`。
2. **两份 Core Data 模型**：`iFinance/iFinance.xcdatamodeld` 与 `MaciFinance/MaciFinance.xcdatamodeld` 是手动维护的副本，改一处必须同步另一处（新增字段可自动轻量迁移；改类型/删字段需 Mapping Model）。
   SwiftData 版是**第三份模型**（`iFinanceSwiftData/Data/Bill.swift`、`UserProfile.swift`），字段契约必须与 Core Data 版保持一致；三处同改。
3. **三套本地化资源**：iOS / macOS / watchOS 各自拥有 `Resources/Localization/{zh-Hans,zh-Hant,en,ja}.lproj`，key 不共享。新增文案只改对应端。
   SwiftData 版**不复制**这些资源，而是以 target membership 引用 `iFinance/Resources/Localization/*.lproj` 与 `EconomicQuotes.json`——改 iOS 文案会同时影响两版。
4. **新增文案一律用 `L10n.string("...")`**：`String(localized:)` 与 `NSLocalizedString` 已全量统一替换（它们走系统语言、不跟随 App 内语言）。`Text("some.key")`（`LocalizedStringKey`）可以继续用，它随注入的 `\.locale` 正确工作。改文案时按 key 全仓库搜索。
   - 语言切换时会调用 `LocalizationSync.apply(_:)` 写入 `UserDefaults["AppleLanguages"]` 并重启，让系统控件（分享面板、Face ID 提示、系统弹窗）也跟随 App 内语言；App 启动时 `LocalizationSync.syncIfNeeded()` 兜底修正。
   - 提交前建议运行 `python3 scripts/check_localization.py`：扫描代码引用的 key 与四语言包比对（缺失/语言间不一致会返回非零码），「未被引用」仅为提示。
5. **类型字符串**：`Bill.type` 运行时值是 `"expenditure"` / `"income"` / `"transfer"`（不是模型默认值「支出」）。
6. **金额**：Core Data 中是 `Decimal`，代码里用 `NSDecimalNumber` 赋值；Watch 传输用 `Double`。
7. **禁用功能不要"顺手接上"**：`CloudKitSyncManager`、`NotificationManager` 是刻意保留的 stub（需付费开发者账号，所有系统调用已注释）；`iCloudSyncView` 入口仍在。
8. **后台隐私遮罩**：进入后台/非活跃时由 `BiometricLockManager.activatePrivacyShield()` 触发、`.appPrivacyShield(_:)` 对整页做高斯模糊，**仅在用户开启应用锁（`BiometricLockEnabled`）时生效**；改动场景生命周期或锁状态机时不要破坏这条链路，新增页面无需单独处理（入口已统一包裹）。

## 代码风格

- 文件头：`// 文件名` + `// 目标名` + `// Created by ...`；正文用 `// MARK: -` 分节。
- 几乎每个 View 文件末尾都有 `#Preview`，预览依赖 `PersistenceController.preview`。
- `internal import CoreData`、`@preconcurrency import WatchConnectivity` 是刻意写法，不要"简化"成普通 import。
- 平台差异用 `#if os(macOS)` / `#if os(watchOS)` 就地分支；项目不做跨端抽象层（存在刻意保留的重复代码）。
- 视觉统一走 `Views/Common/AppVisualStyle.swift` 的 `appGlassCard(cornerRadius:)` 与 `.scalePress`；触觉反馈走 `HapticManager.shared`（9 个方法），不要直接调 `UIImpactFeedbackGenerator`。
- **新写 UI 一律用 token，不要再写魔法数字**：间距/圆角/宽度用 `AppDesignTokens.swift` 的 `AppSpacing` / `AppRadius` / `AppLayout`，字体用 `AppTypography`（语义字体，跟随 Dynamic Type；大号金额用 `.appAmountStyle(size:)`）；动画用 `AppMotion` 的 `quick` / `standard` / `emphasized` / `numeric`，并优先使用 `.appAnimation(_:value:)`、`.appEntrance(index:visible:)` 以自动遵循「减弱动态效果」。iPad 上的主内容用 `.appContentWidth()` 收敛宽度。
- **性能约定**：背景动画只允许用 `AppBackgroundView`（内部走全局共享的 `AppBackgroundClock`，10fps、非活跃自动暂停），不要在新页面里再写 `TimelineView(.animation)`；头像解码统一走 `AvatarImageCache.shared.image(for:)`，不要在 body 里直接 `UIImage(data:)`；`NumberFormatter` / `DateFormatter` 一律声明为 `static let` 复用；百分比展示用 `AppNumberFormat.percent(_:)`（最多两位小数、去尾零）。

## 关键数据流

```
Watch 记账 → WatchDataModel.sendBill → transferUserInfo(action: addBill)
           → WatchSessionManager.saveBillFromWatch（兜底 userIdentifier → 按 id 幂等 → Core Data）
Watch 概览 → requestSync → transferUserInfo(action: requestTodayBills)
           → iPhone 查询今日账单 → transferUserInfo(action: todayBills) → Watch todayBills + UserDefaults 缓存
```

协议细节、payload 字段、扩展步骤见 [docs/api/data-and-sync.md](docs/api/data-and-sync.md)。

## 已确认的坑（改代码前先读）

| 位置 | 问题 |
|------|------|
| Xcode 27 的 UI 测试 | 在克隆模拟器上会触发 XCTest ↔ Swift Testing 互操作递归并崩溃（日志在 `~/Library/Logs/DiagnosticReports/iFinance-*.ips`）；App 正常启动不受影响，验证请用 `-only-testing:` 跳过 UI 测试 |
| iOS 27 / watchOS 27 模拟器运行时 | 本机 Xcode 27 的 `-downloadPlatform` 返回 “not available for download”，上界只能做编译级验证（真机由作者验证） |
| macOS 15 / watchOS 11 下界 | 本机无法运行这两个系统，只能编译 + API 可用性审查 |
| `iFinanceSwiftData` 命名兼容层 | `PersistenceController` / `ModelContainer.viewContext` / `Amount` 计算属性是为了复用 iOS 视图代码而保留的同名 API，改造视图时注意区分两版实现 |
| `reset_ifinance_data.sh` | 使用 `com.liube.iFinance`，实际 Bundle ID 是 `cn.liube.iFinance`，清理无效 |
| `iFinance/Views/Setting/SettingView.swift` | CSV 导入未写 `createdBy` 等字段（导入数据查不到）；`Locale(identifier: "en_US_POSX")` 拼写错误 |
| `MaciFinance/Views/SettingsView.swift:158` | CSV/JSON 导出仍是 TODO |
| `WatchiFinance Watch App/Models/WatchDataModel.swift` | iPhone 不可达时账单只进本地缓存，没有补传队列 |
| iOS 语言切换 | 走 `exit(0)` 重启进程；改语言相关逻辑时不要假设热切换 |
| 工程 scheme | 存在无对应文件的遗留 scheme `Copy of iFinance` |
| 真机部署慢 | 构建本身很快（增量 3～6s、全量约 24s），慢在部署阶段：iOS scheme 依赖 watch target（`Embed Watch Content`），配对手表时每次 Run 都会推送 Watch App，且 Xcode 会附加调试器。改用 `scripts/run-on-device.sh` 可绕过这两步；另注意设备需解锁且已信任电脑 |

## 文档维护约定

`docs/PROJECT_MEMORY.md`（架构与坑）、`docs/api/*.md`（接口文档，含 `swiftdata.md`）由代码勘察生成，带 `路径:行号` 引用。
**修改任何公开类型/方法签名、数据模型、Watch 协议或本地化 key 规则后，请同步更新对应文档与本节中的坑表。**
