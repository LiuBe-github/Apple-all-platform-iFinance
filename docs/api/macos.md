# macOS 端接口文档（MaciFinance）

> 覆盖范围：`MaciFinance/`（约 2 500 行 Swift）。部署目标 macOS 15.0，构建 SDK macOS 27；Bundle ID `cn.liube.MaciFinance`。
> 行号基于 `codex/platform-18-27` 当前提交。

## 1. 文件清单

| 文件 | 主要类型 | 职责 |
|------|----------|------|
| `MaciFinance/MaciFinanceApp.swift` | `MaciFinanceApp` | 入口：`NavigationSplitView` 侧边栏 + 登录路由 + 主题/语言注入 |
| `MaciFinance/Persistence.swift` | `PersistenceController` | 独立 Core Data 栈（模型名 `MaciFinance`），无调试重置钩子 |
| `MaciFinance/Manager/AuthManager.swift` | `AuthManager` | 注册/登录/Apple 登录/资料/预算/删除账号（约 500 行） |
| `MaciFinance/Manager/CloudKitSyncManager.swift` | `CloudKitSyncManager` 等 | iCloud 同步禁用 stub（与 iOS 版同结构） |
| `MaciFinance/Models/*.swift` | 分类 / 主题 | 支出 25 + 收入 11 + `ThemeMode` + `TransactionCategory` |
| `MaciFinance/Helpers/L10n.swift` | `L10n`、`AppLanguage` | 本地化查找（与 iOS 版同策略） |
| `MaciFinance/Helpers/HapticManager.swift` | `HapticManager` | 桌面端降级实现（无触觉硬件） |
| `MaciFinance/Views/MainContentView.swift` | `MainContentView` | 侧边栏四项导航（仪表盘/账单/统计/设置） |
| `MaciFinance/Views/DashboardView.swift` | `DashboardView` | 今日概览 + 近期趋势图 |
| `MaciFinance/Views/BillListView.swift` | `BillListView` | 账单明细 + 类型/关键词筛选 + 删除 |
| `MaciFinance/Views/AddBillSheet.swift` | `AddBillSheet` | 新增账单弹窗 |
| `MaciFinance/Views/StatisticsView.swift` | `StatisticsView` | 周/月/年统计（折线/柱状切换） |
| `MaciFinance/Views/SettingsView.swift` | `SettingsView` | 主题/语言/数据管理/测试数据；CSV 导出仍为 TODO |
| `MaciFinance/Views/LanguageSettingView.swift` | `LanguageSettingView` | 语言切换页 |
| `MaciFinance/Views/iCloudSyncView.swift` | `iCloudSyncView` | 云同步设置页（对 disabled stub） |
| `MaciFinance/Views/Auth/LoginView.swift` | `LoginView` | 登录/注册/Apple 登录 |
| `MaciFinance/Views/Common/AppVisualStyle.swift` | `AppBackgroundView` 等 | macOS 版视觉样式（`#if os(macOS)` 分支） |
| `MaciFinance/MaciFinance.entitlements` | — | 当前为空字典（App Sandbox 授权未启用） |

## 2. 入口：`MaciFinanceApp`（`MaciFinanceApp.swift`）

- `NavigationSplitView` 提供侧边栏；未登录时展示 `LoginView`。
- 与 iOS 一致地注入 `AuthManager.shared`（`@StateObject`）、`\.locale`（依 `@AppStorage("app_language")`）与 `preferredColorScheme`（依 `@AppStorage("selectedTheme")`）。
- **不包含**：生物识别锁、Watch 联动、`scenePhase` 会话刷新逻辑（iOS 独有）。

## 3. 数据栈：`PersistenceController`（`Persistence.swift:11`）

| 成员 | 说明 |
|------|------|
| `shared` / `preview` | 磁盘容器 / 内存预览容器（含两条示例账单） |
| `container: NSPersistentContainer` | 模型名 `MaciFinance`，开启自动轻量迁移，`automaticallyMergesChangesFromParent = true` |
| `currentUserIdentifier` | `static var`，读 `UserDefaults["AuthUserIdentifier"] ?? "anonymous"`（`:46`） |

与 iOS 版差异：无 `billUserPredicate`、无 `getOrCreateCurrentUser`、无 `scheduleResetAllData()`；过滤逻辑在各视图内直接用 `createdBy == ...` 书写。

## 4. 认证：`Manager/AuthManager.swift`

`@MainActor final class AuthManager: ObservableObject`（`static let shared`），API 与 iOS 版对齐（注册/登录/第三方/Apple/改密/重置/资料/预算/删除账号），但：

- 视图直接使用 `createdBy`/`email` 等字段过滤，未抽 `billUserPredicate`；
- 无 `handleAppDidBecomeActive/WillResignActive` 会话刷新（macOS 未接入 `scenePhase`）；
- 删除账号同样使用 `NSBatchDeleteRequest` 清理该用户账单（`AuthManager.swift:301`）。

## 5. 视图层

| 视图 | 关键依赖 | 说明 |
|------|----------|------|
| `MainContentView`（`Views/MainContentView.swift`） | `@State selection` | 侧边栏 + 详情区；选中项高亮、卡片悬停抬升由 `AppVisualStyle` 的 macOS 分支提供 |
| `DashboardView`（`Views/DashboardView.swift:17` 起） | `@FetchRequest allBills` | 今日收入/支出/结余、笔数、近期趋势（`Chart`），空数据占位（`:158`） |
| `BillListView`（`Views/BillListView.swift`） | `@State searchText`、`selectedType` | `filteredBills`（`:38`）按类型 + `category`/`note` 关键词过滤；按日期分组（`:65`）；汇总合计（`:86`） |
| `AddBillSheet`（`Views/AddBillSheet.swift`） | Core Data 上下文 | 弹窗式新增账单（金额/类型/分类/备注/日期） |
| `StatisticsView`（`Views/StatisticsView.swift:15` 起） | `@FetchRequest allBills` | 周/月/年区间（`:70`、`:129`）+ 折线/柱状切换 |
| `SettingsView`（`Views/SettingsView.swift`） | `@State` 若干 | 主题、语言（`LanguageSettingView`）、数据管理（`NSBatchDeleteRequest` 清空，`:176`）、测试数据生成；**CSV/JSON 导出为 TODO（`:158`）** |
| `iCloudSyncView` | `CloudKitSyncManager.shared` | 展示禁用状态 |
| `LoginView`（`Views/Auth/LoginView.swift`） | `AuthManager.shared` | 登录/注册/Apple 登录 |

`Views/Common/AppVisualStyle.swift`（130 行）与 iOS 版同名 API：`AppBackgroundView`、`appGlassCard(cornerRadius:)`、`.scalePress`，但内部用 `#if os(macOS)` 选择桌面端材质与悬停效果。

## 6. 与 iOS 端的关键差异

| 维度 | iOS（iFinance） | macOS（MaciFinance） |
|------|-----------------|----------------------|
| Core Data 模型 | `iFinance.xcdatamodeld` | `MaciFinance.xcdatamodeld`（字段一致，物理独立） |
| 隔离谓词 | `PersistenceController.billUserPredicate` | 视图内手写 `createdBy` 过滤 |
| 生物识别锁 | 有（`BiometricLockManager`） | 无 |
| Watch 联动 | 有（`WatchSessionManager`） | 无 |
| 本地通知 | 有禁用 stub | 无 |
| 会话刷新 | `scenePhase` + 7 天会话 | 无（仅登录态持久化） |
| CSV | 导入 + 导出已实现 | 未实现（TODO） |
| 视觉 | 全屏 TabView + 触觉反馈 | 侧边栏 + 悬停效果，无触觉 |
| 本地化资源 | `iFinance/Resources/Localization` | `MaciFinance/Resources/Localization`（独立副本） |

## 7. 未覆盖 / 存疑

- `AuthManager` 内部实现约 500 行，本文档只列对外语义；逐方法签名请直接查阅源码。
- 测试目标 `MaciFinanceTests`（Swift Testing，20+ 用例）覆盖 Persistence/Bill/Dashboard/Statistics 计算，不含 UI。
