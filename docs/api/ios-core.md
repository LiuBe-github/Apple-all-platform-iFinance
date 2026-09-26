# iOS 核心层接口文档

> 覆盖范围：`iFinance/App`、`iFinance/Persistence.swift`、`iFinance/Manager`、`iFinance/Models`、`iFinance/Protocol`、`iFinance/Helper`。
> 部署目标 iOS 18.0，SDK iOS 27；行号基于 `codex/platform-18-27` 当前提交。
> SwiftData 版同名类型见 [swiftdata.md](swiftdata.md)，两者 API 对齐、实现不同。

## 1. 文件清单

| 文件 | 主要类型 | 职责 |
|------|----------|------|
| `iFinance/App/iFinanceApp.swift` | `iFinanceApp` | 入口：认证路由、生物锁遮罩、主题/语言注入、scenePhase、Watch 激活 |
| `iFinance/Persistence.swift` | `PersistenceController` | Core Data 栈、用户隔离谓词、调试重置钩子 |
| `iFinance/Manager/AuthManager.swift` | `AuthManager` | 注册/登录/密码重置/Apple 登录/资料/预算/删除账号 |
| `iFinance/Manager/BiometricLockManager.swift` | `BiometricLockManager`、`AppLockOverlayView` | Face ID / Touch ID 应用锁状态机与锁屏遮罩 |
| `iFinance/Manager/WatchSessionManager.swift` | `WatchSessionManager` | iPhone 端 WCSession：接收 Watch 账单、回推今日账单 |
| `iFinance/Manager/CloudKitSyncManager.swift` | `CloudKitSyncManager`、`CloudKitSyncState`、`iCloudAccountState` | iCloud 同步**禁用 stub** |
| `iFinance/Manager/NotificationManager.swift` | `NotificationManager`、`NotificationType` | 本地通知**禁用 stub** + 两个 `Notification.Name` 扩展 |
| `iFinance/Models/*.swift` | `ExpenditureCategory`、`IncomeCategory`、`ThemeMode`、`DailySentence` | 分类与主题等模型 |
| `iFinance/Models/CategoryBreakdown.swift` | `CategorySlice`、`CategoryBreakdown` | 分类占比聚合（趋势页饼图的数据源，纯函数） |
| `iFinance/Protocol/TransactionCategory.swift` | `TransactionCategory` | 分类协议（`icon` + `localizedDisplayName`） |
| `iFinance/Helper/LocalizationHelper.swift` | `L10n`、`AppLanguage`、`LanguageSettingView` | 国际化查找与语言设置页 |
| `iFinance/Helper/HapticManager.swift` | `HapticManager` | 9 种触觉反馈单例 |

## 2. App 入口：`iFinanceApp`（`App/iFinanceApp.swift:11`）

| 成员 | 说明 |
|------|------|
| `@AppStorage("selectedTheme") selectedTheme: ThemeMode` | 主题（light/dark/system） |
| `@AppStorage("app_language") appLanguage: String` | 语言（`system`/`zh-Hans`/`zh-Hant`/`en`/`ja`） |
| `@StateObject authManager = AuthManager.shared`、`biometricLock = BiometricLockManager.shared` | 全局单例注入 |
| `persistenceController = PersistenceController.shared` | Core Data 容器 |
| `appLocale` | 依 `appLanguage` 映射 `Locale`，注入 `\.locale` |

行为：`onAppear` 依次执行 `bootstrap()`、`evaluateBiometricCapability()`、`requestLock()`、`WatchSessionManager.shared.activate()`（`:63`-`:68`）；`scenePhase` 变化时刷新会话活跃时间与锁定标记（`:74` 起，`background` 先 `markNeedsRelock()` 再 `fallthrough` 到 `inactive`）。

## 3. 数据栈：`PersistenceController`（`Persistence.swift:11`）

| 成员 | 签名 | 说明 |
|------|------|------|
| `shared` | `static let shared: PersistenceController` | 磁盘容器（`iFinance.sqlite`） |
| `preview` | `@MainActor static let preview` | 内存容器 + 两条示例账单 |
| `init(inMemory:)` | `init(inMemory: Bool = false)` | 启用轻量迁移；`loadPersistentStores` 失败 `fatalError` |
| `scheduleResetAllData()` | `static func scheduleResetAllData()` | 置位 `_DevResetAllData`，下次启动清空数据 |
| `currentUserIdentifier` | `static var currentUserIdentifier: String` | `UserDefaults["AuthUserIdentifier"] ?? "anonymous"`（`:126`） |
| `billUserPredicate` | `static var billUserPredicate: NSPredicate` | `createdBy == currentUserIdentifier`（`:131`） |
| `getOrCreateCurrentUser(identifier:context:)` | `@MainActor func` | 不存在则按默认值创建 |
| `fetchCurrentUser(identifier:context:)` | `@MainActor func ... async -> UserProfile?` | 异步查询 |

## 4. 认证：`AuthManager`（`Manager/AuthManager.swift:16`）

`@MainActor final class AuthManager: ObservableObject`，`static let shared`。

Published：`isAuthenticated`、`hasAccount`、`currentEmail`、`currentPhone`、`currentProvider`、`currentUser: UserProfile?`、`avatarData`；计算属性 `userIdentifier`、`nickname`、`monthlyBudget`。

关键方法：

| 方法 | 返回 | 备注 |
|------|------|------|
| `bootstrap()` | `Void` | 旧版 UserDefaults 凭证迁移 + 7 天会话校验（`sessionLifetime`，`:64`/`:136`） |
| `register(email:phone:password:confirmPassword:fieldType:)` | `String?` | 校验邮箱/手机号正则、密码 ≥ 6；重复返回 `auth.account_exists` |
| `login(email:phone:password:fieldType:)` | `String?` | 先按 identifier 查，再回退按 email/phone 字段查 |
| `loginWithProvider(_:identifier:)` | `String?` | 仅放行 `apple`（不存在则创建）；`wechat`/`qq` 返回 `auth.coming_soon`（未开放，防占位建号） |
| `handleSignInWithApple(result:)` | `String?` | 取消返回 `nil`，其它失败 `auth.apple_failed` |
| `logout()` / `deleteAccount()` / `deleteAllAccounts()` | `Void` | 删除账号用 `NSBatchDeleteRequest` 清账单（`:345`/`:368`） |
| `updateNickname(_:)`、`updateEmail(newEmail:password:)`、`updatePhone(newPhone:password:)`、`updatePassword(...)`、`resetPassword(...)` | `String?` | 返回本地化错误 key |
| `signature` | `String` | 个性签名（未设置时为空串） |
| `updateSignature(_:)` | `String?` | 保存个性签名（空串表示清空；超长返回 `profile.signature_too_long`） |
| `validateSignature(_:)` | `nonisolated static func -> SignatureValidation` | 去首尾空白 + 校验 40 字上限，返回 `.valid(String?)` / `.tooLong`（`signatureMaxLength = 40`） |
| `updateAvatar(_:)` / `updateMonthlyBudget(_:)` | `Void` | 写 Core Data |
| `hashPassword(password:salt:)` | `static func -> String` | `SHA256("salt|password")` hex（`:621`） |

UserDefaults key：`AuthIsLoggedIn`、`AuthLastActiveAt`、`AuthLastLoginIdentifier`、`AuthUserIdentifier` + 迁移用 `AuthEmail`/`AuthPhone`/`AuthPasswordHash`/`AuthPasswordSalt`/`AuthProvider`/`AuthProviderID`/`UserProfileNickname`。

## 5. 生物锁：`BiometricLockManager`（`Manager/BiometricLockManager.swift`）

`@MainActor final class ... ObservableObject`，`static let shared`；持久化开关 `@AppStorage("BiometricLockEnabled")`（`:38`）。

| 成员 | 签名 | 说明 |
|------|------|------|
| `isLocked` / `isAuthenticating` | `@Published private(set)` | UI 状态 |
| `isPrivacyShieldActive` | `@Published private(set)` | 隐私遮罩状态（进入后台/非活跃时为 true） |
| `biometricType` | `private(set) var: LABiometryType` | Face ID / Touch ID / none |
| `isBiometricAvailable` / `biometricDisplayName` / `biometricIconName` | 计算属性 | 供设置页展示 |
| `shouldBlurForPrivacy` | 计算属性 | `isLockEnabled && (isPrivacyShieldActive \|\| isLocked)`，驱动整页高斯模糊 |
| `requestLock()` | `func` | 幂等：未启用/已锁定/解锁冷却 5s 内直接返回 |
| `markNeedsRelock()` / `shouldLockNow` | `func` / `var` | 后台标记与前台消费 |
| `activatePrivacyShield()` / `deactivatePrivacyShield()` | `func` | 后台立即遮挡 / 前台（或解锁后）解除；**仅在 `isLockEnabled` 为 true 时生效** |
| `authenticate()` | `@discardableResult func async -> Bool` | `evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` |
| `enableLock()` / `disableLock()` | `@discardableResult func async -> Bool` | 开关（需先验证身份） |
| `evaluateBiometricCapability()` | `func` | 刷新 `biometricType` |

`AppLockOverlayView`（`:251`）为锁屏遮罩视图，`VisualEffectBlur`（`:304`）提供毛玻璃。

## 6. Watch 端接收：`WatchSessionManager`（`Manager/WatchSessionManager.swift`）

详细协议见 [data-and-sync.md](data-and-sync.md)。公开接口：

| 成员 | 签名 | 说明 |
|------|------|------|
| `shared` | `static let shared` | 单例 |
| `activate()` | `func` | `WCSession.isSupported()` 后设置 delegate 并 `activate()`（`:26`） |

私有实现：`saveBillFromWatch(_:)`（`:39`，字段校验 → 用户兜底 → `id` 幂等 → 写 Core Data）、`sendTodayBillsToWatch(session:)`（`:97`）。Delegate 方法：`activationDidCompleteWith`、`sessionDidBecomeInactive`、`sessionDidDeactivate`、`didReceiveApplicationContext`、`didReceiveUserInfo`（均在 `DispatchQueue.main.async` 回到主线程处理）。

## 7. 禁用 stub

| 类型 | 现状 |
|------|------|
| `CloudKitSyncManager`（`Manager/CloudKitSyncManager.swift:63`） | `@MainActor` 单例；`syncState` 恒为 `.disabled`，`forceSync()` / `checkAccountStatus()` 为空实现；`isSyncEnabled` 写 `UserDefaults["iCloudSyncEnabled"]`；`CloudKit` 调用与 import 全部注释 |
| `NotificationManager`（`Manager/NotificationManager.swift:44`） | `@MainActor` 单例；`requestAuthorization()` 返回 `false`，其余调度方法为空实现；`UserNotifications` import 注释 |
| `NotificationType`（`:14`） | `budgetExceeded` / `reminder` / `dailySummary`，提供 `titleKey` / `bodyKey` |
| `Notification.Name` 扩展（`:97`） | `didRequestAddBill` / `didRequestBudgetView`（当前**无发送方与订阅方**，遗留扩展点） |

## 8. 模型与协议

### `TransactionCategory`（`Protocol/TransactionCategory.swift:7`）

```swift
protocol TransactionCategory: Equatable, Hashable, RawRepresentable where RawValue == String {
    var icon: String { get }                  // SF Symbol
    var localizedDisplayName: String { get }  // 经 L10n
}
```

### `ExpenditureCategory`（25 项，`Models/ExpenditureCategory.swift:11`）

rawValue 为中文：`餐饮`、`购物`、`服饰`、`日用`、`数码`、`美妆`、`护肤`、`应用软件`、`住房`、`交通`、`娱乐`、`医疗`、`通讯`、`汽车`、`学习`、`办公`、`运动`、`社交`、`人情`、`育儿`、`宠物`、`旅行`、`度假`、`烟酒`、`彩票`；`icon` 返回 SF Symbol（如 `fork.knife`、`cart`、`phone`、`heart`、`airplane.departure`）。

### `IncomeCategory`（11 项，`Models/IncomeCategory.swift:11`）

`工资`、`奖金`、`加班`、`福利`、`公积金`、`红包`、`兼职`、`副业`、`退税`、`意外收入`、`其他`；`icon` 如 `wallet.bifold`、`dollarsign.circle`、`exclamationmark.bubble`。

### 其它

| 类型 | 文件:行 | 说明 |
|------|---------|------|
| `ThemeMode` | `Models/ThemeMode.swift:10` | `light` / `dark` / `system` |
| `DailySentence` | `Models/DailySentence.swift:10` | `Codable` + `Identifiable`，字段 `content` / `note` / `picture2`，自定义 `init(from:)` 容忍缺字段 |

## 9. 国际化与触觉反馈

`L10n.string(_:)`（`Helper/LocalizationHelper.swift:15`）：固定语言 → 对应 `.lproj`；`system` → 依次尝试 `lang_region`、`lang`、`en`，命中即返回；全部失败返回 key 本身。`normalizeLanguageIdentifier`（`:52`）处理 `zh`/`zh-CN`/`zh-TW`/`zh-HK` 等别名。`AppLanguage`（`:77`）提供 `displayName` / `nativeName`；`LanguageSettingView`（`:106`）切换语言后调用 `exit(0)` 重启进程（`:185`）。

`HapticManager.shared`（`Helper/HapticManager.swift:16`）：`light()`、`medium()`、`heavy()`、`soft()`、`rigid()`、`success()`、`warning()`、`error()`、`selectionChanged()`。

### AppleLanguages 同步（`LocalizationSync`，`Helper/LocalizationHelper.swift:115`）

| 成员 | 签名 | 说明 |
|------|------|------|
| `apply(_:)` | `@discardableResult static func apply(_ language: AppLanguage) -> Bool` | 固定语言 → 写 `UserDefaults["AppleLanguages"] = [lang]`；`.system` → 移除该键；返回是否有改动，并 `synchronize()` 后由调用方重启进程 |
| `syncIfNeeded()` | `static func syncIfNeeded()` | 读取 `app_language` 幂等修正（App 入口 `onAppear` 调用，兜底修正老版本安装） |

作用：让 `String(localized:)`、`NSLocalizedString` 以及系统控件文案（分享面板、Face ID 提示、系统弹窗）跟随 App 内选择的语言。新增文案不要再用 `String(localized:)`，统一走 `L10n.string`。

## 10. CSV 导入：`CSVImporter`（`Helper/CSVImporter.swift`）

| 成员 | 签名 | 说明 |
|------|------|------|
| `parseRows(_:)` | `static func parseRows(_ input: String) -> [[String]]` | 解析 CSV 文本：支持引号包裹、`""` 转义、CRLF / LF / CR 换行、跳过空行 |
| `makeBill(row:context:identifier:)` | `static func makeBill(row: [String], context: NSManagedObjectContext, identifier: String) -> Bill?` | 列数 ≥ 5、`type ∈ {income, expenditure, transfer}`、金额按 `en_US_POSIX` 解析；合法则建 `Bill` 并写入 `id/createdAt/createdBy/updatedAt/updatedBy`，非法返回 `nil`（调用方计入 skipped） |

调用方：`SettingView.importCSV(from:)`（导入按当前账号归属）。格式化器为 `static let`（`ISO8601DateFormatter` + `yyyy-MM-dd HH:mm:ss` 回退）。

> 坑：Swift 里 `"\r\n"` 是**一个** Character，换行判断必须同时覆盖 `\n` / `\r\n` / `\r`，否则 Windows / Excel 导出的 CSV 会被当成一整行。

## 11. 分类体系：`CategoryStore` / `CategoryResolver` / `CategoryIconLibrary`（`Views/Common/`）

| 类型 | 关键接口 | 说明 |
|------|----------|------|
| `CustomCategory` | `id / kind / parentKey / name / icon / colorHex / builtInKey / order / createdAt`、`key` | 自定义分类条目；`parentKey` 非空即二级分类（内置父级用 rawValue，自定义父级用 UUID 字符串） |
| `CategoryStore` | `shared`、`reload(force:)`、`topLevel(_:)`、`subcategories(parentKey:kind:)`、`add(kind:name:icon:colorHex:parentKey:)`、`update(id:name:icon:colorHex:)`、`delete(id:)`、`storedPath(of:)`、`takenIcons(kind:parentKey:)`、`revision` | 本机 UserDefaults JSON（按账号隔离）；名称校验（1–8 字、禁 `/`、同层级去重、一级 20 / 每父 20 上限）；首次使用播种「交通」7 个二级分类 |
| `CategoryResolver` | `split(_:)`、`parentRaw(_:)`、`displayName(for:kind:)`、`icon(for:kind:)`、`color(for:kind:)`、`isValid(_:kind:)`、`topLevelOptions(kind:)`、`subOptions(forParent:kind:)`、`parentKey(forStoredParent:kind:)` | `@MainActor`；一级选项带 revision 缓存；全 App 唯一分类解析入口 |
| `CategoryIconLibrary` | `groups`（9 组）、`allIcons`、`filtered(keyword:)` | 105 枚精选 SF Symbols，供图标选择器与自动分配使用 |

> 规则：一级分类图标在同一类型内不得重复、二级分类在同一父级下不得重复；新增/调整分类后请运行 `iFinanceTests/CategoryIconTests`（同时校验符号真实存在）。

## 12. 未覆盖 / 存疑

- `AuthManager` 的 Apple 登录需真机与已登录 Apple ID 才能完整验证；本仓库仅在编译与模拟器层面验证。
- 生物锁在真实 Face ID 设备上的行为（失败次数、系统弹窗）未验证。
- `CloudKitSyncManager` / `NotificationManager` 的具体历史实现已从源码移除，仅保留 stub 与本地化 key。
