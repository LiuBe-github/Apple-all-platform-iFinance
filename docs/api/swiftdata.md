# iFinanceSwiftData 接口文档（iOS SwiftData 版）

> 覆盖范围：`iFinanceSwiftData/`（应用）与 `iFinanceSwiftDataTests/`（测试）。
> 部署目标 iOS 18.0，构建 SDK iOS 27；Bundle ID `cn.liube.iFinance.swiftdata`，显示名「iFinance SD」，可与 Core Data 版共存安装。
> 行号基于 `codex/platform-18-27` 分支当前提交；代码改动后请以符号名搜索为准。

## 1. 文件清单

| 文件 | 职责 |
|------|------|
| `iFinanceSwiftData/App/iFinanceSwiftDataApp.swift` | App 入口：认证路由、生物锁遮罩、主题与语言注入（**不**注册 WCSession） |
| `iFinanceSwiftData/Data/Bill.swift` | `@Model` 账单实体 + `amountDouble` / `amountString` 兼容属性 |
| `iFinanceSwiftData/Data/UserProfile.swift` | `@Model` 用户实体（凭证、资料、预算、头像） |
| `iFinanceSwiftData/Data/PeriodSummary.swift` | 概况页区间统计（`SummaryPeriod` / `PeriodRanges` / `PeriodSummary`，与 iOS 版同名同义） |
| `iFinanceSwiftData/Data/Persistence.swift` | SwiftData 容器 `PersistenceController` + 用户隔离谓词 + `ModelContainer.viewContext` 兼容扩展 |
| `iFinanceSwiftData/Data/{Expenditure,Income}Category.swift` `ThemeMode.swift` `DailySentence.swift` `TransactionCategory.swift` | 与 iOS 版一致的数据模型/协议（复制） |
| `iFinanceSwiftData/Manager/AuthManager.swift` | SwiftData 版认证管理器（API 与 Core Data 版一致） |
| `iFinanceSwiftData/Manager/BiometricLockManager.swift` | 生物识别锁（与 iOS 版一致，复制） |
| `iFinanceSwiftData/Manager/{CloudKitSyncManager,NotificationManager}.swift` | 禁用 stub（与 iOS 版一致，复制） |
| `iFinanceSwiftData/Helper/{LocalizationHelper,HapticManager}.swift` | `L10n` / `AppLanguage` / `LanguageSettingView` / 触觉反馈（复制） |
| `iFinanceSwiftData/Views/**` | 由 iOS 版复制改造的视图层 |
| `iFinanceSwiftData/Views/Common/AppDesignTokens.swift`、`AppMotion.swift`、`AppPrivacyShield.swift` | 布局/字体/动画 token 与后台隐私遮罩（与 iOS 版逐字一致的副本） |
| `iFinanceSwiftData/Resources/Info.plist`、`Assets.xcassets` | 独立 Info.plist 与图标资源 |
| `iFinanceSwiftDataTests/SwiftDataCoreTests.swift` | Swift Testing：CRUD / 账号隔离 / 聚合 / 哈希 |

共享资源（不属于本目录）：`iFinance/Resources/Localization/{zh-Hans,zh-Hant,en,ja}.lproj`、`iFinance/Resources/EconomicQuotes.json` 通过 target membership 引用进本 target。

## 2. 数据层接口

### `Bill`（`Data/Bill.swift:12`）

```swift
@Model
final class Bill {
    var id: UUID?
    var amount: Decimal?
    var type: String?          // "expenditure" / "income" / "transfer"
    var category: String?
    var note: String?
    var date: Date?
    var createdAt: Date?
    var updatedAt: Date?
    var createdBy: String?     // 账号隔离键
    var updatedBy: String?

    init(id: UUID? = UUID(), amount: Decimal? = nil, type: String? = nil,
         category: String? = nil, note: String? = nil, date: Date? = Date(),
         createdAt: Date? = Date(), updatedAt: Date? = Date(),
         createdBy: String? = nil, updatedBy: String? = nil)
}
```

兼容属性（`Data/Bill.swift:69` 起）：

| 属性 | 类型 | 说明 |
|------|------|------|
| `amountDouble` | `Double` | 等价 Core Data 版的 `bill.amount?.doubleValue ?? 0` |
| `amountString` | `String` | 等价 `bill.amount?.stringValue ?? "0"`（CSV 导出） |

### `UserProfile`（`Data/UserProfile.swift:12`）

字段：`id`、`userIdentifier`、`email`、`phone`、`passwordHash`、`passwordSalt`、`provider`、`providerID`、`nickname`、`avatarData`（`@Attribute(.externalStorage)`）、`monthlyBudget: Double = 3000`、`createdAt`、`updatedAt`。
未使用 `#Unique` 宏，唯一性由代码保证（新建前先按 `userIdentifier` 查询），与 Core Data 版行为一致。

### `PersistenceController`（`Data/Persistence.swift:15`）

| 成员 | 签名 | 说明 |
|------|------|------|
| `shared` | `static let shared: PersistenceController` | 磁盘容器（`default.store`） |
| `preview` | `@MainActor static let preview: PersistenceController` | 内存容器 + 两条示例账单 |
| `init(inMemory:)` | `init(inMemory: Bool = false)` | `Schema([Bill.self, UserProfile.self])`；失败时 `fatalError` |
| `currentUserIdentifier` | `static var currentUserIdentifier: String` | 读 `UserDefaults["AuthUserIdentifier"]`，缺省 `"anonymous"` |
| `billUserPredicate` | `static var billUserPredicate: Predicate<Bill>` | `#Predicate { $0.createdBy == identifier }` |
| `billPredicate(for:)` | `static func billPredicate(for identifier: String) -> Predicate<Bill>` | 指定用户的谓词（删除账号用） |

兼容扩展（`Data/Persistence.swift:83`）：

```swift
extension ModelContainer {
    @MainActor var viewContext: ModelContext { mainContext }   // 保留 Core Data 版写法
}
```

## 3. 认证层：`AuthManager`（`Manager/AuthManager.swift:16`）

`@MainActor final class AuthManager: ObservableObject`，`static let shared`，对外 API 与 Core Data 版**逐字一致**，视图层因此可零改动复用。

Published 状态：`isAuthenticated`、`hasAccount`、`currentEmail`、`currentPhone`、`currentProvider`、`currentUser: UserProfile?`、`avatarData`。
计算属性：`userIdentifier`、`nickname`、`monthlyBudget`。

方法（含默认语义）：

| 方法 | 返回 | 说明 |
|------|------|------|
| `bootstrap()` | `Void` | 迁移旧版 UserDefaults 凭证 → 校验 7 天会话 → 恢复 `currentUser` |
| `handleAppDidBecomeActive()` / `handleAppWillResignActive()` | `Void` | 刷新 `AuthLastActiveAt` |
| `register(email:phone:password:confirmPassword:fieldType:)` | `String?` | 返回本地化错误 key（如 `auth.account_exists`），成功返回 `nil` |
| `login(email:phone:password:fieldType:)` | `String?` | 同上 |
| `loginWithProvider(_:identifier:)` | `String?` | 第三方登录，不存在则创建账号 |
| `handleSignInWithApple(result:)` | `String?` | 处理 `ASAuthorization` 结果 |
| `logout()` | `Void` | 清 UserDefaults 登录态与内存状态 |
| `deleteAccount()` | `Void` | `delete(model: Bill.self, where:)` + 删除 `UserProfile` + 登出 |
| `deleteAllAccounts()` | `Void` | 清空所有 `Bill` 与 `UserProfile`（调试用） |
| `updateNickname(_:)` / `updateEmail(newEmail:password:)` / `updatePhone(newPhone:password:)` / `updatePassword(currentPassword:newPassword:confirmPassword:)` / `resetPassword(email:phone:fieldType:newPassword:confirmPassword:)` | `String?` | 资料与凭证更新 |
| `updateAvatar(_:)` / `updateMonthlyBudget(_:)` | `Void` | 头像与预算 |
| `nonisolated static hashPassword(password:salt:)` | `String` | `SHA256("salt|password")` 十六进制；与 Core Data 版算法一致，可跨版校验 |

副作用：写入 UserDefaults（`AuthIsLoggedIn`、`AuthLastActiveAt`、`AuthLastLoginIdentifier`、`AuthUserIdentifier`）、写 SwiftData 上下文（`try? context.save()`）。

## 4. 视图层改造点

视图层由 `iFinance/Views/**` 复制而来，主要机械替换：

| Core Data 写法 | SwiftData 写法 | 位置示例 |
|----------------|----------------|----------|
| `@FetchRequest(sortDescriptors:predicate:animation:)` | `@Query(filter:sort:order:animation:)` | `Views/Transaction/Bills/BillsCardView.swift:48`、`Views/Tendency/TendencyView.swift:14` |
| `FetchedResults<Bill>` | `[Bill]` | 同上 |
| `@Environment(\.managedObjectContext)` | `@Environment(\.modelContext)` | 多处（`rg -n 'modelContext'`） |
| `Bill(context: viewContext)` | `Bill(...)` + `viewContext.insert(_:)` | `Views/Transaction/Bills/AddBillView.swift:198`、`Views/Setting/SettingView.swift:641` |
| `NSFetchRequest` + `NSSortDescriptor` | `FetchDescriptor<Bill>(sortBy:)` | `Views/Setting/SettingView.swift:596` |
| `NSBatchDeleteRequest` | `try context.delete(model: Bill.self, where:)` | `Manager/AuthManager.swift`（deleteAccount/deleteAllAccounts） |
| `bill.amount?.doubleValue ?? 0` | `bill.amountDouble` | 全仓库机械替换 |
| `@ObservedObject var bill: Bill` | `let bill: Bill` | `Views/Transaction/TransactionRowView.swift:11`、`Views/Transaction/Bills/EditBillView.swift:12` |

按日期/类型/分类的过滤在**内存中完成**（先 `@Query` 取当前用户账单，再用 Swift 过滤），对应 Core Data 版里由 `NSPredicate` 完成的部分：

- `Views/Home/HomeView.swift:25` — `todayBills` 计算属性按 `Calendar.isDate(_:inSameDayAs:)` 过滤；
- `Views/Transaction/Budget/BudgetView.swift:19`、`BudgetCardView.swift:47` — `currentMonthBills` / `currentMonthExpenditures` 按 `type` + 月份区间过滤；
- CSV 导入（`Views/Setting/SettingView.swift:613`）写入 `createdBy/updatedBy` 与审计字段。

## 5. 测试

`iFinanceSwiftDataTests/SwiftDataCoreTests.swift`（Swift Testing，全部使用 `PersistenceController(inMemory: true)`）：

| 套件 | 用例 |
|------|------|
| `BillCRUDTests` | 插入查询、更新金额、单条删除、按谓词批量删除 |
| `UserIsolationTests` | 按 `createdBy` 只取当前用户账单、用户资料插入查询 |
| `BudgetAggregationTests` | 本月支出聚合（排除收入与上月）、今日账单聚合 |
| `PasswordHashingTests` | 哈希确定性、不同盐值差异、与 Core Data 版算法一致 |

运行：

```bash
xcodebuild test -project iFinance.xcodeproj -scheme iFinanceSwiftData \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
  -only-testing:iFinanceSwiftDataTests
```

## 6. 与 Core Data 版的差异（速查）

| 维度 | Core Data 版（iFinance） | SwiftData 版（iFinanceSwiftData） |
|------|--------------------------|-----------------------------------|
| 持久化 | `NSPersistentContainer` + `iFinance.xcdatamodeld` | `ModelContainer` + `@Model` 类 |
| 查询 | `@FetchRequest` + `NSPredicate` | `@Query` + Swift 内存过滤 |
| Watch 联动 | 有（`WatchSessionManager`） | 无 |
| iCloud / 通知 | 禁用 stub | 禁用 stub（复制） |
| 数据 | 既有用户数据 | 空库起步，不迁移 |
| 本地化资源 | 自有 `Resources/Localization` | 共享 iOS 版资源 |

## 7. 未覆盖 / 存疑

- 未在 iOS 27 模拟器实机验证（本机无法下载 iOS 27 运行时），仅保证 Xcode 27 SDK 下编译与 iOS 18.6 模拟器运行。
- SwiftData 的 `@Query` + 内存过滤在数据量大（数万条）时的性能未做压测；Core Data 版由谓语下推到 SQLite。
- 未覆盖 ImageRenderer 分享、生物锁在真机 Face ID 下的行为（仅模拟器验证构建与启动）。
