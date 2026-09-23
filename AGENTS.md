# iFinance —— Agent 项目记忆

SwiftUI 全平台个人记账应用：iOS / macOS / watchOS 三个目标共用一个 Xcode 工程，无任何第三方依赖。

- 仓库：`LiuBe-github/Apple-all-platform-iFinance`
- 工程：`iFinance.xcodeproj`（Xcode 27，`SWIFT_VERSION = 5.0`）
- 详细记忆：[docs/PROJECT_MEMORY.md](docs/PROJECT_MEMORY.md)；接口文档：[docs/api/README.md](docs/api/README.md)
- 文案与注释使用中文；文档也用中文书写。

## 目标与版本

| Scheme | 目录 | 平台 | Bundle ID | 部署目标 |
|--------|------|------|-----------|----------|
| `iFinance` | `iFinance/` | iOS 17.6（iPhone + iPad） | `cn.liube.iFinance` | 17.6 |
| `MaciFinance` | `MaciFinance/` | macOS | `cn.liube.MaciFinance` | 26.2 |
| `WatchiFinance Watch App` | `WatchiFinance Watch App/` | watchOS | `cn.liube.iFinance.watchkitapp` | 26.0 |

> README 中的 watchOS 10 / macOS 15 已过期，以 `project.pbxproj` 为准。

## 常用命令

```bash
xcodebuild -list -project iFinance.xcodeproj

xcodebuild build -project iFinance.xcodeproj -scheme iFinance -destination 'generic/platform=iOS Simulator'

xcodebuild test -project iFinance.xcodeproj -scheme iFinance -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project iFinance.xcodeproj -scheme MaciFinance -destination 'platform=macOS'
```

测试目标：`iFinanceTests`（XCTest，38 用例）、`MaciFinanceTests`（Swift Testing，`@Test`）、watch/UI 测试为模板占位。
测试统一使用 `PersistenceController(inMemory: true)`，不触碰磁盘数据。

## 目录地图

```
iFinance/                 iOS：App/ Manager/ Models/ Protocol/ Helper/ Views/ Resources/
MaciFinance/              macOS：App/ Manager/ Models/ Helpers/ Views/ Resources/
WatchiFinance Watch App/  watchOS：ContentView.swift（三 Tab）+ Models/WatchDataModel.swift
docs/                     项目记忆与接口文档（改动接口后同步更新）
```

层级约定：`Views/` 按业务分目录（Home / Transaction{Bills,Budget} / Tendency / Profile / Setting / Auth / Common）；Manager 全部是 `@MainActor final class ... ObservableObject` + `static let shared` + `private init`。

## 必须遵守的不变量

1. **数据隔离**：账单归属由 `Bill.createdBy == UserDefaults["AuthUserIdentifier"]` 决定。所有账单查询都必须叠加 `PersistenceController.billUserPredicate`；所有写入都必须设置 `createdBy`。
2. **两份 Core Data 模型**：`iFinance/iFinance.xcdatamodeld` 与 `MaciFinance/MaciFinance.xcdatamodeld` 是手动维护的副本，改一处必须同步另一处（新增字段可自动轻量迁移；改类型/删字段需 Mapping Model）。
3. **三套本地化资源**：iOS / macOS / watchOS 各自拥有 `Resources/Localization/{zh-Hans,zh-Hant,en,ja}.lproj`，key 不共享。新增文案只改对应端。
4. **三种本地化调用方式并存**：`L10n.string("...")`、`String(localized: "...")`、`Text("some.key")`（LocalizedStringKey），还有少量 `NSLocalizedString`。改文案时按 key 全仓库搜索。
5. **类型字符串**：`Bill.type` 运行时值是 `"expenditure"` / `"income"` / `"transfer"`（不是模型默认值「支出」）。
6. **金额**：Core Data 中是 `Decimal`，代码里用 `NSDecimalNumber` 赋值；Watch 传输用 `Double`。
7. **禁用功能不要"顺手接上"**：`CloudKitSyncManager`、`NotificationManager` 是刻意保留的 stub（需付费开发者账号，所有系统调用已注释）；`iCloudSyncView` 入口仍在。

## 代码风格

- 文件头：`// 文件名` + `// 目标名` + `// Created by ...`；正文用 `// MARK: -` 分节。
- 几乎每个 View 文件末尾都有 `#Preview`，预览依赖 `PersistenceController.preview`。
- `internal import CoreData`、`@preconcurrency import WatchConnectivity` 是刻意写法，不要"简化"成普通 import。
- 平台差异用 `#if os(macOS)` / `#if os(watchOS)` 就地分支；项目不做跨端抽象层（存在刻意保留的重复代码）。
- 视觉统一走 `Views/Common/AppVisualStyle.swift` 的 `appGlassCard(cornerRadius:)` 与 `.scalePress`；触觉反馈走 `HapticManager.shared`（9 个方法），不要直接调 `UIImpactFeedbackGenerator`。

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
| `reset_ifinance_data.sh` | 使用 `com.liube.iFinance`，实际 Bundle ID 是 `cn.liube.iFinance`，清理无效 |
| `iFinance/Views/Setting/SettingView.swift` | CSV 导入未写 `createdBy` 等字段（导入数据查不到）；`Locale(identifier: "en_US_POSX")` 拼写错误 |
| `MaciFinance/Views/SettingsView.swift:158` | CSV/JSON 导出仍是 TODO |
| `WatchiFinance Watch App/Models/WatchDataModel.swift` | iPhone 不可达时账单只进本地缓存，没有补传队列 |
| iOS 语言切换 | 走 `exit(0)` 重启进程；改语言相关逻辑时不要假设热切换 |
| 工程 scheme | 存在无对应文件的遗留 scheme `Copy of iFinance` |

## 文档维护约定

`docs/PROJECT_MEMORY.md`（架构与坑）、`docs/api/*.md`（接口文档）由代码勘察生成，带 `路径:行号` 引用。
**修改任何公开类型/方法签名、数据模型、Watch 协议或本地化 key 规则后，请同步更新对应文档与本节中的坑表。**
