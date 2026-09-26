# iFinance 项目记忆

> 生成依据：`fd6b1fb`（初始勘察基线）→ 适配与 SwiftData 版落地于 `codex/platform-18-27` 分支。所有结论均来自源码实测，关键位置附带路径与行号。
> 配套文档：[AGENTS.md](../AGENTS.md)（Agent 速用记忆）、[docs/api/README.md](api/README.md)（接口文档索引）。

## 1. 项目定位

iFinance 是一套 **Apple 全平台个人记账应用**，同一仓库内包含三个可独立运行的目标：

| 目标 | 目录 | 平台 | Bundle ID | 部署目标（下限） | 版本 |
|------|------|------|-----------|----------|------|
| iFinance | `iFinance/` | iOS / iPadOS | `cn.liube.iFinance` | iOS 18.0 | 1.1 (2) |
| iFinanceSwiftData | `iFinanceSwiftData/` | iOS / iPadOS（SwiftData 版） | `cn.liube.iFinance.swiftdata` | iOS 18.0 | 1.1 (2) |
| MaciFinance | `MaciFinance/` | macOS | `cn.liube.MaciFinance` | macOS 15.0 | 1.1 (2) |
| WatchiFinance Watch App | `WatchiFinance Watch App/` | watchOS | `cn.liube.iFinance.watchkitapp` | watchOS 11.0 | 1.1 (2) |

版本上限：各平台 27.x（构建 SDK 为 Xcode 27 的 iOS 27 / macOS 27 / watchOS 27）。iOS 17 自本轮起不再支持。
开发环境：Xcode 27.0（Swift 6.x 工具链），工程 `SWIFT_VERSION = 5.0`（Swift 5 语言模式）。
外部依赖：**无**（无 SPM / CocoaPods / Carthage 依赖，全部自研）。

### ⚠️ 工程形态要点

- 工程使用 **文件系统同步分组**（`PBXFileSystemSynchronizedRootGroup`）：每个 target 对应一个顶层文件夹，文件夹内的文件自动归属该 target；新增 Swift 文件不需要改 `project.pbxproj`。
- SwiftData 版共享 iOS 版的本地化与名言 JSON（以 target membership 引用 `iFinance/Resources/...`），不复制副本。
- 语言切换仍是「选择后由程序主动退出并重启」（`iFinance/Helper/LocalizationHelper.swift:185`），README 已同步更正。

## 2. 目录与模块地图

```
.
├── iFinance/                     # iOS 主应用（约 9 400 行 Swift）
│   ├── App/iFinanceApp.swift     # 入口：认证路由 + 生物锁遮罩 + 主题/语言注入 + Watch 激活
│   ├── Persistence.swift         # Core Data 栈 + 用户隔离 predicate + 调试重置钩子
│   ├── Manager/                  # AuthManager / BiometricLockManager / WatchSessionManager
│   │                             # + CloudKitSyncManager、NotificationManager（两个 stub）
│   ├── Models/                   # 支出 25 类、收入 11 类、ThemeMode、DailySentence
│   ├── Protocol/TransactionCategory.swift
│   ├── Helper/                   # L10n + AppLanguage + LanguageSettingView + HapticManager
│   ├── Views/                    # Home / Transaction(Bills,Budget) / Tendency / Profile / Setting / Auth
│   └── Resources/                # Localization(4 语言) + EconomicQuotes.json（100 条）
├── iFinanceSwiftData/            # 🧪 iOS SwiftData 版（独立 target，约 1 900 行 Swift）
│   ├── App/iFinanceSwiftDataApp.swift  # 入口：认证路由 + 生物锁遮罩（不激活 Watch）
│   ├── Data/                     # @Model Bill / UserProfile + SwiftData 版 PersistenceController
│   ├── Manager/                  # SwiftData 版 AuthManager + 生物锁 + 两个 stub
│   ├── Views/                    # 由 iOS 版复制改造的视图层（@Query / FetchDescriptor）
│   └── Resources/                # Info.plist + Assets（本地化与名言 JSON 共享 iOS 版）
├── iFinanceSwiftDataTests/       # Swift Testing：CRUD / 账号隔离 / 预算聚合 / 密码哈希
├── MaciFinance/                  # macOS 应用（约 2 500 行 Swift）
│   ├── MaciFinanceApp.swift      # NavigationSplitView 侧边栏入口
│   ├── Persistence.swift         # 独立 Core Data 栈（模型名 MaciFinance）
│   ├── Manager/                  # AuthManager + CloudKitSyncManager（stub）
│   ├── Views/                    # DashboardView / BillListView / AddBillSheet / StatisticsView / SettingsView ...
│   └── Resources/Localization/   # 4 语言
├── WatchiFinance Watch App/      # watchOS 应用（约 800 行 Swift）
│   ├── ContentView.swift         # 三 Tab：概览 / 快速记账 / 当日历史
│   ├── Models/WatchDataModel.swift  # WCSession Delegate + 本地缓存
│   └── Resources/Localization/   # 4 语言（key 前缀独立）
├── iFinanceTests/                # XCTest，38 个用例（632 行）
├── MaciFinanceTests/             # Swift Testing（@Test），579 行
├── WatchiFinance Watch AppTests/ # 仅模板占位用例（17 行）
├── *UITests/                     # 模板 UI 测试，无实际断言
├── reset_ifinance_data.sh        # 清理模拟器账号/账单数据（见 §4 已知缺陷）
└── README.md
```

## 3. 构建、运行与测试

### 3.1 Scheme

`xcodebuild -list` 输出的 4 个 scheme：

| Scheme | 目标 |
|--------|------|
| `iFinance` | iOS 应用 |
| `MaciFinance` | macOS 应用 |
| `WatchiFinance Watch App` | watchOS 应用 |
| `Copy of iFinance` | 遗留副本 scheme（仓库中无对应 `.xcscheme` 文件，建议清理） |

注意：`iFinance.xcodeproj/xcshareddata/xcschemes/` 下只有两个文件——`iFinance.xcscheme` 与 `WatchiFinance Watch App.xcscheme`；`MaciFinance` scheme 由 Xcode 自动生成。

### 3.2 常用命令

```bash
# 列出可用 scheme / 目标
xcodebuild -list -project iFinance.xcodeproj

# iOS 构建（模拟器）
xcodebuild build -project iFinance.xcodeproj -scheme iFinance \
  -destination 'generic/platform=iOS Simulator'

# iOS 测试
xcodebuild test -project iFinance.xcodeproj -scheme iFinance \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# macOS 测试
xcodebuild test -project iFinance.xcodeproj -scheme MaciFinance -destination 'platform=macOS'
```

模拟器设备名以 `xcrun simctl list devices available` 实际输出为准。

### 3.3 测试现状

| 测试目标 | 框架 | 规模 | 覆盖内容 |
|----------|------|------|----------|
| `iFinanceTests` | XCTest（`@MainActor final class`） | 38 用例 | Core Data 容器、Bill 增删改、密码哈希、分类枚举、时间范围过滤、趋势聚合 |
| `MaciFinanceTests` | Swift Testing（`import Testing` + `@Test`） | 20+ 用例 | Persistence、Bill 模型、Dashboard 计算、Statistics 聚合、筛选与分组 |
| `iFinanceSwiftDataTests` | Swift Testing | 10 用例 | SwiftData CRUD、按 `createdBy` 的账号隔离、按删除谓词批量删除、本月/今日聚合、密码哈希一致性 |
| `WatchiFinance Watch AppTests` | Swift Testing | 1 个占位 `example()` | 无实际断言 |
| `iFinanceUITests` / `MaciFinanceUITests` | XCTest | 模板 | 无实际断言 |

测试均在 `inMemory: true` 的 `PersistenceController` 上运行（`iFinanceTests/iFinanceTests.swift:22`），不触碰磁盘数据。

## 4. 数据层

### 4.1 两个互相独立的 Core Data 栈

| 平台 | 模型文件 | 容器名 | Sqlite |
|------|----------|--------|--------|
| iOS | `iFinance/iFinance.xcdatamodeld` | `iFinance` | `.../Application Support/iFinance.sqlite` |
| macOS | `MaciFinance/MaciFinance.xcdatamodeld` | `MaciFinance` | `.../Application Support/MaciFinance.sqlite` |

两端**各自维护一份模型副本**，字段定义目前一致，但**没有任何代码共享**——改一处必须手动同步另一处，否则数据模型漂移。
两端栈实现见 `iFinance/Persistence.swift:63` 与 `MaciFinance/Persistence.swift:54`。

两端均使用普通 `NSPersistentContainer`（**不是** `NSPersistentCloudKitContainer`），并开启自动轻量迁移：

```swift
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

`model.contents` 中仍保留 `usedWithCloudKit="YES"` 字段，属于历史遗留，不影响运行。

### 4.2 实体：`Bill`

| 字段 | 模型类型 | 源码中的用法 | 说明 |
|------|----------|--------------|------|
| `id` | UUID（optional） | `bill.id?.uuidString` | 幂等键；Watch 端写入时按 `id` 去重 |
| `amount` | Decimal（默认 0） | `NSDecimalNumber` 赋值，读取时按可选使用（`bill.amount?.doubleValue`） | 金额 |
| `type` | String（默认「支出」） | 运行时实际值：`"expenditure"` / `"income"` / `"transfer"` | 类型 |
| `category` | String（默认「餐饮」） | 存**枚举 rawValue**（中文），可为 nil | 分类 |
| `note` | String?（默认「无备注」） | 可为 nil | 备注 |
| `date` | Date? | 影响分组/筛选 | 记账日期 |
| `createdAt` / `updatedAt` | Date | — | 审计字段 |
| `createdBy` / `updatedBy` | String（默认 `user`） | **数据隔离键**，等于 `UserProfile.userIdentifier` | 账号归属 |

模型定义：`iFinance/iFinance.xcdatamodeld/iFinance.xcdatamodel/contents`。
⚠️ 模型默认值（如 `type = "支出"`）与代码实际写入值（`"expenditure"`）**不一致**，只靠代码保证正确性；新增数据路径时务必显式赋值。

### 4.3 实体：`UserProfile`

| 字段 | 模型类型 | 说明 |
|------|----------|------|
| `id` | UUID? | 主键 |
| `userIdentifier` | String（默认 `anonymous`） | 登录标识：邮箱 / 手机号 / Apple user id |
| `email` / `phone` | String? | 账号凭证 |
| `passwordHash` / `passwordSalt` | String? | SHA256 哈希与盐（第三方登录账号为空） |
| `provider` / `providerID` | String? | `wechat` / `qq` / `apple` |
| `nickname` | String? | 默认 `用户123`，注册时随机 `用户NNN` |
| `avatarData` | Binary?（`allowsExternalBinaryDataStorage`） | 头像 |
| `monthlyBudget` | Double（默认 3000） | 月度预算 |
| `createdAt` / `updatedAt` | Date? | 审计字段 |

### 4.4 多账号数据隔离

- 隔离键：`PersistenceController.currentUserIdentifier`，读取 `UserDefaults["AuthUserIdentifier"]`，缺省 `"anonymous"`（`iFinance/Persistence.swift:126`）。
- 查询助手：`PersistenceController.billUserPredicate`（`iFinance/Persistence.swift:131`）。
- 约定：**所有账单查询都必须带 `createdBy == currentUserIdentifier` 过滤**，否则会串号；iOS 的 `AuthManager` 在登录/登出时同步该 key（`syncUserIdentifierToDefaults()`，`iFinance/Manager/AuthManager.swift:549`）。
- 删除账号：`AuthManager.deleteAccount()` 批量删除该用户账单后删除 `UserProfile`（`iFinance/Manager/AuthManager.swift:345`）。

### 4.5 调试辅助

- `PersistenceController.scheduleResetAllData()`：打标 `UserDefaults["_DevResetAllData"]`，下次启动时批量清空 `Bill` + `UserProfile` 并打印日志（`iFinance/Persistence.swift:100`、`:104`）。
- `AuthManager.deleteAllAccounts()`：立即清空所有账号与账单（`iFinance/Manager/AuthManager.swift:368`）。
- `PersistenceController.preview`：内存容器 + 预置样例账单，供 `#Preview` 使用。

### 4.6 CSV 导入导出（仅 iOS）

- 实现位置：`iFinance/Views/Setting/SettingView.swift:595`（导出）、`:613`（导入）、`:658`/`:662`（转义与解析）。
- 表头：`date,type,category,amount,note`；日期为 ISO8601，导入时回退解析 `yyyy-MM-dd HH:mm:ss`（`en_US_POSIX`）。
- 导入仅接受 `type ∈ {income, expenditure, transfer}`；导入的账单**不写 `createdAt/createdBy/updatedAt/updatedBy`**，因此这些记录不会出现在按 `createdBy` 过滤的列表中（已知缺陷，见 §10）。
- macOS 端 SettingsView 中标注 `// TODO: implement CSV/JSON export`（`MaciFinance/Views/SettingsView.swift:158`），功能未实现。

### 4.7 SwiftData 版数据层（`iFinanceSwiftData/`）

同一工程内的独立 iOS target（Bundle ID `cn.liube.iFinance.swiftdata`，显示名「iFinance SD」），与 Core Data 版**并存安装、数据互不影响**。

| 组成 | 实现 | 位置 |
|------|------|------|
| 模型 | `@Model final class Bill` / `UserProfile`，字段与 Core Data 版一一对应（`id`/`amount`/`type`/`category`/`note`/`date`/`createdAt`/`updatedAt`/`createdBy`/`updatedBy`） | `iFinanceSwiftData/Data/Bill.swift`、`UserProfile.swift` |
| 容器 | `PersistenceController` + `ModelContainer(for: [Bill.self, UserProfile.self])`，内存容器用于预览/测试 | `iFinanceSwiftData/Data/Persistence.swift` |
| 隔离 | `PersistenceController.billUserPredicate`（`#Predicate` 版本）与 `billPredicate(for:)` | 同上 |
| 认证 | SwiftData 版 `AuthManager`（API 与 Core Data 版完全一致） | `iFinanceSwiftData/Manager/AuthManager.swift` |
| 视图 | 由 iOS 版复制改造：`@FetchRequest`→`@Query`、`NSFetchRequest`→`FetchDescriptor`、`NSBatchDeleteRequest`→`delete(model:where:)` | `iFinanceSwiftData/Views/**` |
| 资源 | 以 target membership 引用 `iFinance/Resources/Localization/*.lproj` 与 `EconomicQuotes.json` | 工程配置 |
| 测试 | `iFinanceSwiftDataTests`（Swift Testing，内存容器） | `iFinanceSwiftDataTests/SwiftDataCoreTests.swift` |

**同名 API 兼容层**（关键设计，改代码前必读）：

- 视图层沿用 Core Data 版的写法，靠三个兼容点保持零改动复制：`PersistenceController.currentUserIdentifier` / `billUserPredicate`、`ModelContainer.viewContext` 扩展（内部即 `mainContext`）、`Bill.amountDouble` / `amountString` 计算属性（替代 `amount?.doubleValue` / `amount?.stringValue`）。
- 因此**两版视图代码是两份文件**，改一处不会自动同步另一处；共同的字符串资源是唯一真正共享的部分。
- SwiftData 版不注册 `WCSession`（不联动 Watch）、不启用 CloudKit 与本地通知，数据从空库开始（不迁移 Core Data 历史数据）。
- SwiftData 版的 CSV 导入会写入 `createdBy`/`updatedBy` 与审计字段，并修正了 Core Data 版的 `en_US_POSX` locale 拼写问题（Core Data 版保持原样）。

## 5. 认证与账号体系（iOS）

核心类：`AuthManager`（`@MainActor final class ... ObservableObject`，单例 `shared`，`iFinance/Manager/AuthManager.swift:16`）。

### 5.1 状态机

```
未登录(LoginView) --register/login/loginWithProvider/handleSignInWithApple--> isAuthenticated = true --> ContentView
ContentView --logout/deleteAccount/会话过期(7 天)--> isAuthenticated = false --> LoginView
```

- 会话有效期：`sessionLifetime = 7 * 24 * 60 * 60`，`bootstrap()` 中比较 `AuthLastActiveAt`（`AuthManager.swift:64`、`:136`）。
- 启动流程：`iFinanceApp.onAppear` → `authManager.bootstrap()`（`iFinance/App/iFinanceApp.swift:63`）。
- 前后台：`scenePhase` 变化时调用 `handleAppWillResignActive()` / `handleAppDidBecomeActive()` 刷新活跃时间（`iFinance/App/iFinanceApp.swift:74`）。

### 5.2 密码存储

```swift
static func hashPassword(password: String, salt: String) -> String {
    let payload = "\(salt)|\(password)"
    let digest = SHA256.hash(data: Data(payload.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}
```

（`iFinance/Manager/AuthManager.swift:621`）盐值 = `UUID().uuidString`；密码强度仅要求长度 ≥ 6；手机号规则 `^1[3-9]\d{9}$`，邮箱为常规正则（`AuthManager.swift:605`、`:610`）。
⚠️ 未加迭代次数（非 PBKDF2/Argon2），仅适合演示用途。

### 5.3 UserDefaults key 全表（iOS）

| Key | 写入方 | 含义 |
|-----|--------|------|
| `AuthLastLoginIdentifier` | AuthManager | 上次登录的 `userIdentifier` |
| `AuthIsLoggedIn` | AuthManager | 登录标记（Bool） |
| `AuthLastActiveAt` | AuthManager | 最近活跃时间（Date，用于 7 天会话） |
| `AuthUserIdentifier` | AuthManager / PersistenceController | **数据隔离正在使用的用户标识** |
| `AuthEmail` `AuthPhone` `AuthPasswordHash` `AuthPasswordSalt` `AuthProvider` `AuthProviderID` `UserProfileNickname` | 旧版本迁移 | 仅用于迁移到 Core Data 后即删除哈希/盐（`AuthManager.swift:559`） |
| `selectedTheme` | `@AppStorage` | 主题（`light` / `dark` / `system`） |
| `app_language` | `@AppStorage` | 语言（`system` / `zh-Hans` / `zh-Hant` / `en` / `ja`） |
| `BiometricLockEnabled` | `@AppStorage` | 生物识别锁开关 |
| `iCloudSyncEnabled` | CloudKitSyncManager | iCloud 同步开关（当前恒为 false） |
| `WatchBillsCache` | watchOS WatchDataModel | Watch 侧今日账单 JSON 缓存（**仅 Watch 端**） |
| `_DevResetAllData` | PersistenceController | 一次性重置数据标记 |

## 6. 跨端数据流：iPhone ↔ Apple Watch

两端唯一通道是 `WatchConnectivity`，**不使用** CloudKit 或 App Group。

### 6.1 消息协议（字典 payload）

| 方向 | action | 附带字段 | 发送方式 |
|------|--------|----------|----------|
| Watch → iPhone | `addBill` | `bill: [String: Any]` | `transferUserInfo`（可靠排队） |
| Watch → iPhone | `requestTodayBills` | — | `transferUserInfo` |
| iPhone → Watch | `todayBills` | `bills: [[String: Any]]` | `transferUserInfo` |

`bill` / `bills[]` 字段：`id`(String, UUID 字符串) / `amount`(Double) / `type`(String) / `category`(String) / `note`(String?) / `date`(ISO8601 String) / `userIdentifier`(String，仅 Watch→iPhone 时携带)。

两端实现：
- iPhone 端：`iFinance/Manager/WatchSessionManager.swift`（接收 → 写 Core Data，`saveBillFromWatch` 在 `:39`；回推今日账单 `sendTodayBillsToWatch` 在 `:97`）。
- Watch 端：`WatchiFinance Watch App/Models/WatchDataModel.swift`（`sendBill` 在 `:109`、`requestSync` 在 `:127`、`didReceiveUserInfo` 在 `:163`）。

### 6.2 关键行为

1. **幂等写入**：iPhone 端按 `id` 查询，已存在则跳过（`WatchSessionManager.swift:68`）。
2. **用户归属兜底**：若 Watch 传来的 `userIdentifier` 为 nil 或 `"anonymous"`，改用当前登录用户 `PersistenceController.currentUserIdentifier`（`WatchSessionManager.swift:60`）。Watch 端的默认值是 `UserDefaults["AuthUserIdentifier"] ?? "anonymous"`（`WatchDataModel.swift:43`）——Watch 与 iPhone 不共享 UserDefaults，因此该兜底是常态路径。
3. **离线降级**：Watch 侧 `isReachable == false` 时 `sendBill` 只写本地缓存并返回 `false`（`WatchDataModel.swift:110`），**没有补发队列**，账单不会自动重传，需要用户重试。
4. **今日账单口径**：iPhone 端按 `createdBy == 当前用户` 且 `date ∈ [今日0点, 明日0点)` 查询（`WatchSessionManager.swift:99`）。
5. **Watch 端 delegate 限制**：watchOS 不允许实现 `sessionDidBecomeInactive` / `sessionDidDeactivate`（源码注释：`WatchDataModel.swift:134`）。

### 6.3 激活时机

- iPhone：`iFinanceApp.onAppear` → `WatchSessionManager.shared.activate()`（`iFinance/App/iFinanceApp.swift:68`）。
- Watch：`WatchDataModel.shared` 在 `init` 中激活 `WCSession`（`WatchDataModel.swift:95`），App 入口文件 `WatchiFinance Watch App/WatchiFinanceApp.swift` 仅 16 行。

## 7. 国际化

三端各自持有一套 `.lproj`（互不共享）：`iFinance/Resources/Localization/`、`MaciFinance/Resources/Localization/`、`WatchiFinance Watch App/Resources/Localization/`，各含 `zh-Hans` / `zh-Hant` / `en` / `ja`。

规模（zh-Hans）：iOS 446 行、macOS 418 行、Watch 45 行。iOS 端 key 前缀分布：`mac.*` 87、`settings.*` 57、`bill.*` 42、`cat.*` 36、`auth.*` 36、`icloud.*` 23、`budget.*` 23、`tendency.*` 17、`home.*` 16、`notification.*` 13、`profile.*` 11、`lock.*` 10、`search.*` 9、`common.*` 8、`tab.*` 4。
Watch 端前缀独立：`add.*`、`category.*`、`summary.*`、`history.*`、`tab.*`、`status.*`。

查找机制（iOS/macOS/Watch 三份 `L10n` 实现思路一致）：

1. 用户在设置中选择固定语言 → 从对应 `.lproj` bundle 读取；
2. 选择「跟随系统」→ 依次尝试 `lang_region`、`lang`、`en`，跳过与 key 相同的返回值；
3. 全部失败 → 返回 key 本身。

实现见 `iFinance/Helper/LocalizationHelper.swift:15`；Apple 语言标识归一化函数 `normalizeLanguageIdentifier` 在 `:52`（`zh`→`zh-Hans`、`zh-HK`→`zh-Hant` 等）。

**调用方式（2026-09 起已统一）**：

- 新增文案一律 `L10n.string("...")`；`String(localized:)` 与 `NSLocalizedString` 已全量替换（各端共 268 处），它们原先走系统语言、切换后不跟随。
- `Text("key")`（`LocalizedStringKey`）可继续使用，随注入的 `\.locale` 正确工作。
- 语言切换时 `LocalizationSync.apply(_:)` 会写入 `UserDefaults["AppleLanguages"]`（跟随系统则移除），重启后让**系统控件**（分享面板、Face ID 提示、系统弹窗）也跟随 App 内语言；三端 App 入口另有 `LocalizationSync.syncIfNeeded()` 幂等兜底。
- 防回归：`scripts/check_localization.py`（代码 key ↔ 四语言包审计）+ `iFinanceTests` / `MaciFinanceTests` 中的「四语言 key 集合一致」用例。
⚠️ 语言切换后走 `exit(0)` / `NSApplication.terminate` 主动退出进程（`LocalizationHelper.swift:185`），是刻意行为：`AppleLanguages` 需重启才生效。

## 8. 视觉与交互规范

| 能力 | 实现 | 位置 |
|------|------|------|
| 渐变背景 + 呼吸光斑 | `AppBackgroundView`（`TimelineView(.animation(minimumInterval: 1/30))` + 3 个漂移球体） | `iFinance/Views/Common/AppVisualStyle.swift:5` |
| 毛玻璃卡片 | `appGlassCard` 系列 modifier | 同上（iOS 与 macOS 各一份 #if 分支实现） |
| 按压缩放 | `ScaleButtonStyle` | 同上 |
| 触觉反馈 | `HapticManager.shared`：`light/medium/heavy/soft/rigid/success/warning/error/selectionChanged` 共 9 个方法 | `iFinance/Helper/HapticManager.swift:16-110` |
| 数字动画 | `.contentTransition(.numericText())` | 卡片金额展示处 |
| 图标动效 | `.symbolEffect(...)` | 刷新/分享/选中/超支等场景 |
| 设计/动画 token | `Views/Common/AppDesignTokens.swift`（`AppSpacing`/`AppRadius`/`AppLayout`/`AppTypography`）与 `AppMotion.swift`（`quick`/`standard`/`emphasized`/`numeric` + Reduce Motion 降级） | 2026-09 起新增 UI 一律用 token，禁止再写魔法数字 |
| 后台隐私保护 | 进入 `.inactive`/`.background` 时 `BiometricLockManager.activatePrivacyShield()`（仅 `isLockEnabled` 时生效）→ `.appPrivacyShield(true)` 对整页做 20pt 高斯模糊 + 材质覆盖；回到前台且无需锁定时解除，解锁成功后也会清除 | `iFinance/Views/Common/AppPrivacyShield.swift`、`BiometricLockManager.swift` |
| 概况页构成 | 三层结构：今日概况大卡（主视觉）→ 周期概况卡（本月 / 上月 / 本年 三行明细）→ 每日一言卡（毛玻璃卡 + 右上角「换一句」）；底部仅保留分享按钮。图片能力已整体移除（`ImageLoader`/`ImageCache`/`ImageDownsampler` 与 `DailySentence.picture2` 均已删除，运行时不再联网取图） | `iFinance/Views/Home/`、`iFinance/Models/PeriodSummary.swift` |
| 开屏与头像 | 冷启动开屏 `AppSplashView`（1.8s，Reduce Motion 降级 0.8s，仅 iOS）；头像选择后经 `AvatarCropView` 圆形遮罩裁剪（拖动/缩放）再写入 300×300 JPEG | `iFinance/Views/Common/AppSplashView.swift`、`iFinance/Views/Profile/AvatarCropView.swift` |
| 个性签名 | `UserProfile.signature`（三份模型同步：iOS/macOS Core Data + SwiftData）；设置页头部用户名下方显示签名（为空时显示「点击设置个性签名」占位），点击头部或个人中心的「个性签名」入口打开 `EditSignatureView`（40 字上限） | `AuthManager.validateSignature/updateSignature`、`Views/Profile/EditSignatureView.swift` |
| 性能约定 | 背景动画统一走 `AppBackgroundView` + 全局 `AppBackgroundClock`（10fps、非活跃暂停、Reduce Motion 静态、RadialGradient 代替 blur）；头像解码走 `AvatarImageCache`；Formatter 全部 `static let`；`AddBillView` 的分类网格拆成 Equatable 子视图避免输入时重建 | `iFinance/Views/Common/`、`AddBillView.swift` |
| 记账键盘 | 表达式编辑逻辑抽为纯函数 `NumberPadExpression`（`NumberPadLogic.swift`）：按「当前数字段」校验位数、运算符首按为主运算符/再按切换、`%` 与退格边界；`AddBillView.parseExpression` 负责四则运算求值，两者都有单测 | `iFinance/Views/Transaction/Bills/NumberPadLogic.swift` |
| 趋势页结构 | 支出趋势（柱状）→ 支出分类占比（饼图）→ 收入趋势（柱状）→ 收入分类占比（饼图）→ 活跃度热力图；折线图与图表类型切换器已移除。饼图数据来自纯函数 `CategoryBreakdown`（最近 N 天、按分类汇总降序），环形图组件 `CategoryPieView` 与配色 `CategoryPalette` 与预算页共用 | `iFinance/Views/Tendency/`、`Views/Common/CategoryPie*.swift`、`Models/CategoryBreakdown.swift` |
| 编辑账单规则 | 类型/分类必须匹配（支出 25 / 收入 11 / 转账固定 `transfer`）：切换类型清空分类并要求重选、分类走推入式 `CategoryPickerView`、旧数据用 `BillEditRules.normalizedCategory` 归一化、日期可选到年月日时分 | `iFinance/Views/Transaction/Bills/EditBillView.swift`、`CategoryPickerView.swift`、`BillEditRules.swift` |
| 本地化自查 | `*LocalizationRegressionTests` 会校验四种语言的关键 key 都能解析出译文（`common.cancel` 曾缺失导致对话框直接显示原始 key） | `iFinanceTests`、`MaciFinanceTests` |

macOS 端有独立副本：`MaciFinance/Views/Common/AppVisualStyle.swift`（130 行）与 `MaciFinance/Helpers/HapticManager.swift`（46 行，桌面端为空实现/降级）。

## 9. 代码约定（从现有代码归纳）

1. **文件头注释**：`// 文件名` + `// 目标名` + `// Created by 刘不易 on 日期`（部分新文件用 `WorkBuddy`）。
2. **MARK 分节**：`// MARK: - 分类名` 贯穿全部文件，节顺序大致为「Published 状态 → 私有属性 → 初始化 → Public API → 私有辅助」。
3. **单例 + ObservableObject**：所有 Manager 使用 `static let shared` + `private init`，`@MainActor` 修饰类。
4. **import 写法**：`internal import CoreData`（项目显式关闭 CoreData 的跨模块导出）、`@preconcurrency import WatchConnectivity`、框架调用被禁用时保留注释行（`// import CloudKit`）。
5. **`#Preview`**：几乎每个 View 文件末尾都有；预览依赖 `PersistenceController.preview`。
6. **视图访问 Core Data**：通过 `@Environment(\.managedObjectContext)` 或 `PersistenceController.shared.container.viewContext` 直接取用；`@FetchRequest` 与手动 `NSFetchRequest` 混用。
7. **分类枚举**：`ExpenditureCategory`（25）/`IncomeCategory`（11）遵循 `TransactionCategory` 协议，提供 `icon`（SF Symbol）与 `localizedDisplayName`（走 `L10n`）。
8. **平台分支**：`#if os(macOS)` / `#if os(watchOS)` 用于差异 UI，公共层不做跨端抽象（存在重复代码，是当前架构的既定取舍）。

## 10. 已知问题与技术债

1. **`reset_ifinance_data.sh` 的 Bundle ID 前缀错误**：脚本使用 `com.liube.iFinance`（`reset_ifinance_data.sh:20`、`:41`），工程实际为 `cn.liube.iFinance`（`project.pbxproj:732`）。`xcrun simctl get_app_container` 会取不到容器，`defaults delete` 也全部命中不存在的域（脚本以 `|| true` 静默跳过），实际清理效果不可靠。
2. **CSV 导入缺少账号字段**：导入的 `Bill` 未写 `createdBy`，会被 `billUserPredicate` 过滤掉（`iFinance/Views/Setting/SettingView.swift:641`）。
3. **CSV 解析的小数 locale 拼写错误**：`Locale(identifier: "en_US_POSX")`（`SettingView.swift:637`），应为 `en_US_POSIX`。
4. **CloudKit 同步与本地通知为禁用 stub**：`CloudKitSyncManager` / `NotificationManager` 所有系统调用被注释，接口返回固定值或空实现（需付费开发者账号）；UI 入口仍存在（`iCloudSyncView`）。
5. **Watch 端离线账单不会补传**：`sendBill` 在不可达时仅本地缓存（`WatchDataModel.swift:100`），无重试队列。
6. **`Notification.Name.didRequestAddBill` / `didRequestBudgetView` 无任何发送方或订阅方**（`iFinance/Manager/NotificationManager.swift:97`），属于遗留扩展点。
7. **macOS 端功能缺口**：CSV/JSON 导出为 TODO（`MaciFinance/Views/SettingsView.swift:158`）；无生物锁、无 Watch 联动、无本地通知。
8. **两份 Core Data 模型与两份 AuthManager 手动同步**：iOS 与 macOS 各自实现，字段演进而未同步时会出现平台间行为不一致（模型当前字段一致，实现细节不同）。
9. **遗留 scheme `Copy of iFinance`** 无对应 `.xcscheme` 文件，建议从工程中清理。
10. **测试覆盖偏工具层**：UI 层与 Watch 端几乎无自动化测试（`WatchiFinance Watch AppTests` 仅模板用例）。
11. **UI 测试在 Xcode 27 下崩溃**：`iFinanceUITestsLaunchTests` 在克隆模拟器上会触发 XCTest ↔ Swift Testing 互操作递归（栈深 900+）后 SIGSEGV，崩溃日志为 `~/Library/Logs/DiagnosticReports/iFinance-*.ips`；普通启动不受影响，日常验证请用 `-only-testing:iFinanceTests` 之类参数跳过 UI 测试。
12. **上界运行时不可用**：本机 Xcode 27 的 `xcodebuild -downloadPlatform iOS|watchOS` 返回 “not available for download”，iOS 27 / watchOS 27 无法在本机模拟器验证，只能编译级验证（需真机确认）。
13. **下界不可运行**：macOS 15 / watchOS 11 无法在本机运行，采用「编译 + API 可用性审查」验证；若需真机结论需自行安装对应系统。
14. **SwiftData 版与 Core Data 版视图代码双份维护**：同名 API 兼容层让复制成本很低，但视图改动需要同步两处（见 §4.7）。
15. **测试必须串行执行**：同时运行多个 `xcodebuild test`（尤其含 UI 测试的 scheme）会出现测试宿主互相干扰，表现为 `Early unexpected exit` 与 UI 测试超时；验证时请一次只跑一个 scheme，并用 `-only-testing:` 限定单元测试。

## 11. 高频任务操作指引

| 任务 | 需要改动的文件 |
|------|----------------|
| 新增一个支出分类 | `iFinance/Models/ExpenditureCategory.swift`（+ `MaciFinance/Models/ExpenditureCategory.swift`）；补 4 语言 `cat.*` key；确认 `ExpenditureCategoryItemView`/饼图/筛选列表自动生效 |
| 新增一条界面文案 | 三端各自的 `Resources/Localization/*.lproj/Localizable.strings`（若该文案属于对应端） |
| 修改 `Bill` 字段 | 两个 `.xcdatamodeld/contents` 都要改；只能做「新增字段/新增实体」这类轻量迁移；改类型或删字段需要 Mapping Model（`iFinance/Persistence.swift:76` 注释） |
| 新增一个 iOS 页面 | 放到 `iFinance/Views/<模块>/`，末尾加 `#Preview`；如需参与 Tab，改 `iFinance/Views/ContentView.swift` 的 `Tab` 枚举 |
| 修改 Watch 传输字段 | 同步改 `WatchDataModel.toPayload()`/`from()`、`WatchSessionManager.saveBillFromWatch()`，并注意 `id` 幂等与 `userIdentifier` 兜底 |
| 排查「账单不显示」 | 先查 `createdBy` 是否等于 `UserDefaults["AuthUserIdentifier"]`（`billUserPredicate`），再查 `date` 是否落在筛选区间 |
| 重置本地数据 | 优先用 `AuthManager.deleteAllAccounts()`（App 内）或 `PersistenceController.scheduleResetAllData()`；`reset_ifinance_data.sh` 存在 Bundle ID 缺陷（§10.1） |

## 12. 文档地图

| 文档 | 内容 |
|------|------|
| [docs/HANDOFF.md](HANDOFF.md) | 交接文档：接手清单、环境准备、铁律、代码地图、验证标准、未完成事项 |
| [memory/README.md](../memory/README.md) | 会话记忆：决策记录、工作历史（20 次提交）、待办与风险、环境与协作约定 |
| [docs/PRD.md](PRD.md) | 产品需求文档：功能需求与优先级、业务规则、非功能要求、验收清单、路线图 |
| [docs/api/README.md](api/README.md) | 接口文档索引与通用约定 |
| [docs/api/ios-core.md](api/ios-core.md) | iOS 核心层：入口、Persistence、Manager、Model、Helper |
| [docs/api/ios-ui.md](api/ios-ui.md) | iOS 视图层：Home / Transaction / Tendency / Profile / Setting / Auth / Common |
| [docs/api/macos.md](api/macos.md) | macOS 端全部接口 |
| [docs/api/watchos.md](api/watchos.md) | watchOS 端全部接口 |
| [docs/api/data-and-sync.md](api/data-and-sync.md) | 数据模型与 WatchConnectivity 协议细则 |

---

_本文件由代码勘察生成（HEAD `fd6b1fb`）。修改代码后请同步更新对应章节；新增公开接口时请同步接口文档。_
