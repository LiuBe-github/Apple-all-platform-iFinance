# 数据模型与跨端同步协议

> 生成依据：HEAD `fd6b1fb`。适用于 iOS / macOS / watchOS 三端的数据层与 iPhone ↔ Watch 通信。
> 相关文档：[PROJECT_MEMORY.md](../PROJECT_MEMORY.md)、[ios-core.md](ios-core.md)、[watchos.md](watchos.md)。

---

## 一、Core Data 模型

> 版本矩阵（本轮适配后）：iOS 18.0 – 27.x、macOS 15.0 – 27.x、watchOS 11.0 – 27.x，SDK 为 Xcode 27。
> SwiftData 版（`iFinanceSwiftData`，仅 iOS）以 `@Model` 复刻本文第 1.2/1.3 节的字段契约，但**数据不互通**；差异见 [swiftdata.md](swiftdata.md)。

### 1.1 两套独立模型

| 平台 | 模型文件 | 容器名 / 存储文件 | 栈实现 |
|------|----------|-------------------|--------|
| iOS | `iFinance/iFinance.xcdatamodeld/iFinance.xcdatamodel/contents` | `iFinance` / `iFinance.sqlite` | `iFinance/Persistence.swift:63` |
| macOS | `MaciFinance/MaciFinance.xcdatamodeld/MaciFinance.xcdatamodel/contents` | `MaciFinance` / `MaciFinance.sqlite` | `MaciFinance/Persistence.swift:54` |

两端字段定义一致但**物理上互相独立**（各自 App 容器内的 Application Support 目录），没有 App Group、没有共享容器，也没有跨端数据库同步。同一用户在两台设备上看到的是两份数据。

模型 JSON 中的 `usedWithCloudKit="YES"` 属于编辑器遗留标记（模型由 CloudKit 模板创建），当前容器是普通 `NSPersistentContainer`（`iFinance/Persistence.swift:68`），不启用 CloudKit。

### 1.2 实体 `Bill`

字段定义（两个平台一致，取自 `.xcdatamodel/contents`）：

| 属性 | 模型类型 | 可选 | 默认值 | Swift 侧实际用法 |
|------|----------|------|--------|------------------|
| `id` | UUID | 是 | — | `UUID`，幂等去重键；读取用 `bill.id?.uuidString` |
| `amount` | Decimal | 否 | 0 | 赋值 `NSDecimalNumber(value:)`；读取按可选处理（`bill.amount?.doubleValue` / `?.stringValue`） |
| `type` | String | 否 | `支出` | 运行时取值 `"expenditure"` / `"income"` / `"transfer"` |
| `category` | String | 否 | `餐饮` | 分类枚举 rawValue（中文字符串），可为 `nil` |
| `note` | String | 是 | `无备注` | 备注 |
| `date` | Date | 否 | 时间戳常量 | 分组 / 筛选 / 排序依据 |
| `createdAt` | Date | 否 | — | 审计 |
| `createdBy` | String | 否 | `user` | **账号隔离键** = `UserProfile.userIdentifier` |
| `updatedAt` | Date | 否 | — | 审计 |
| `updatedBy` | String | 否 | `user` | 最后修改人标识 |

⚠️ 两处易踩的坑：

1. 模型默认值（`type = "支出"`）与代码写入值（`"expenditure"`）不一致，**任何写入路径都必须显式赋值** `type`，否则会出现无法被类型筛选命中的脏数据。
2. 生成类（`codeGenerationType="class"`，Class Definition）由 Xcode 在 DerivedData 中生成，`Bill` 的 Swift 属性在实际使用中表现为可选类型（见 `iFinance/Persistence.swift:29`、`iFinance/Views/Setting/SettingView.swift:642`）。

### 1.3 实体 `UserProfile`

| 属性 | 模型类型 | 可选 | 默认值 | 说明 |
|------|----------|------|--------|------|
| `id` | UUID | 是 | — | 主键 |
| `userIdentifier` | String | 否 | `anonymous` | 登录标识：小写邮箱 / 归一化手机号 / Apple user id |
| `email` | String | 是 | — | 邮箱凭证 |
| `phone` | String | 是 | — | 手机号凭证 |
| `passwordHash` | String | 是 | — | `SHA256("salt|password")` 的 hex 串 |
| `passwordSalt` | String | 是 | — | `UUID().uuidString` |
| `provider` | String | 是 | — | `wechat` / `qq` / `apple` |
| `providerID` | String | 是 | — | 第三方账号 id |
| `nickname` | String | 是 | `用户123` | 注册时随机 `用户NNN` |
| `avatarData` | Binary | 是 | — | `allowsExternalBinaryDataStorage="YES"` |
| `monthlyBudget` | Double | 否 | 3000 | 月度预算 |
| `createdAt` / `updatedAt` | Date | 是 | — | 审计 |

哈希实现：`AuthManager.hashPassword(password:salt:)`（`iFinance/Manager/AuthManager.swift:621`）——`payload = "\(salt)|\(password)"`，单轮 SHA256，十六进制小写输出。

### 1.4 迁移策略

```swift
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

（`iFinance/Persistence.swift:76`、`MaciFinance/Persistence.swift:64`）

| 变更类型 | 是否支持自动迁移 | 建议 |
|----------|------------------|------|
| 新增属性（可选或带默认值） | ✅ | 直接改两个 `.xcdatamodeld` |
| 新增实体 | ✅ | 同上 |
| 删除属性 / 实体 | ❌（需手工迁移或清库） | 开发期卸载 App 重装 |
| 修改已有属性类型 | ❌ | 需 Mapping Model |
| 重命名属性 | ❌（会被视为删+增） | 需要版本化模型 + Mapping Model |

迁移失败时 `loadPersistentStores` 的闭包会 `fatalError` 崩溃（`iFinance/Persistence.swift:79`），属于刻意设计（尽早暴露模型问题）。

### 1.5 用户数据隔离

```swift
static var currentUserIdentifier: String {
    UserDefaults.standard.string(forKey: "AuthUserIdentifier") ?? "anonymous"
}

static var billUserPredicate: NSPredicate {
    NSPredicate(format: "createdBy == %@", currentUserIdentifier)
}
```

（`iFinance/Persistence.swift:126`、`:131`）

多账号共用同一份 Core Data，通过 `Bill.createdBy == UserProfile.userIdentifier` 做逻辑隔离。因此：

- 任何新增的账单查询 / 统计 / 聚合都必须叠加该 predicate；
- 写入时必须设置 `createdBy`（`AuthManager.signIn` 会同步 `AuthUserIdentifier`，见 `AuthManager.swift:549`）；
- 登录状态切换后需要让 `@FetchRequest` 重新求值（视图通常会重建）。

### 1.6 调试辅助接口

| 接口 | 位置 | 行为 |
|------|------|------|
| `PersistenceController.scheduleResetAllData()` | `iFinance/Persistence.swift:100` | 置位 `_DevResetAllData`，下次启动清空所有 `Bill` 与 `UserProfile` |
| `runStartupHooksIfNeeded()`（私有） | `iFinance/Persistence.swift:104` | 消费该标记，`NSBatchDeleteRequest` 清库 |
| `AuthManager.deleteAllAccounts()` | `AuthManager.swift:368` | 立即清空全部账号与账单并登出 |
| `AuthManager.deleteAccount()` | `AuthManager.swift:345` | 删除当前账号的账单与资料后登出 |
| `PersistenceController.getOrCreateCurrentUser(identifier:context:)` | `iFinance/Persistence.swift:134` | 找不到资料时按默认值创建 |
| `PersistenceController.fetchCurrentUser(identifier:context:) async` | `iFinance/Persistence.swift:154` | 异步查询资料 |

### 1.7 预览容器

`PersistenceController.preview` 使用内存存储（`/dev/null`）并预置样例账单（`iFinance/Persistence.swift:12`、`MaciFinance/Persistence.swift:12`），供 `#Preview` 使用；测试也统一用 `inMemory: true`（`iFinanceTests/iFinanceTests.swift:22`）。

---

## 二、iPhone ↔ Apple Watch 同步协议

### 2.1 通道与角色

| 项 | 值 |
|----|-----|
| 框架 | `WatchConnectivity`（`WCSession.default`） |
| 传输 API | `transferUserInfo(_:)`（可靠、有序、后台排队，不覆盖） |
| 兼容接收 | iPhone 端**同时**实现了 `didReceiveUserInfo` 与 `didReceiveApplicationContext` 两个入口（旧版本 Watch 用 `updateApplicationContext` 发送） |
| 数据落点 | iPhone 写入 Core Data（`Bill`）；Watch 端只维护内存 + UserDefaults 缓存 |
| 激活时机 | iPhone：`iFinanceApp.onAppear`（`iFinance/App/iFinanceApp.swift:68`）；Watch：`WatchDataModel.init`（`WatchDataModel.swift:95`） |

### 2.2 消息定义

所有消息都是 `[String: Any]`，用 `action` 字段区分。

#### (1) `addBill` — Watch → iPhone

```jsonc
{
  "action": "addBill",
  "bill": {
    "id": "8F2E...-UUID 字符串",
    "amount": 23.5,                 // Double
    "type": "expenditure",          // expenditure | income | transfer
    "category": "餐饮",              // 分类 rawValue
    "note": "午饭",                  // 可选
    "date": "2026-09-23T04:12:00Z", // ISO8601
    "userIdentifier": "user@example.com" // 可能为 "anonymous"
  }
}
```

发送方：`WatchDataModel.sendBill(_:) async -> Bool`（`WatchDataModel.swift:109`），payload 由 `WatchBill.toPayload()` 构造（`:35`）。
接收方：`WatchSessionManager.saveBillFromWatch(_:)`（`WatchSessionManager.swift:39`）。

接收侧处理规则：

1. 字段校验：`id`/`amount`/`type`/`category`/`date` 缺一不可，`date` 必须是 ISO8601（否则 `logger.error` 后丢弃）。
2. 归属兜底：`userIdentifier` 为 `nil` 或 `"anonymous"` 时替换为 `PersistenceController.currentUserIdentifier`（`:60`）。
3. 幂等：以 `id` 查询，已存在则直接跳过（`:68`）。
4. 写入：`amount` 转 `NSDecimalNumber`，`createdAt/updatedAt` 用当前时间，`createdBy/updatedBy` 用最终 `userIdentifier`，随后 `context.save()`。

#### (2) `requestTodayBills` — Watch → iPhone

```jsonc
{ "action": "requestTodayBills" }
```

发送方：`WatchDataModel.requestSync()`（`WatchDataModel.swift:127`，要求 `isReachable`）。
接收方：`WatchSessionManager` → `sendTodayBillsToWatch(session:)`（`WatchSessionManager.swift:97`）。

#### (3) `todayBills` — iPhone → Watch

```jsonc
{
  "action": "todayBills",
  "bills": [ { "id": "...", "amount": 23.5, "type": "expenditure",
               "category": "餐饮", "note": "午饭", "date": "2026-09-23T04:12:00Z" } ]
}
```

查询口径：`createdBy == 当前用户` 且 `date ∈ [今日 00:00, 明日 00:00)`（`WatchSessionManager.swift:99`）。
注意：回推的 payload **不含** `userIdentifier`（Watch 端 `WatchBill.from` 也不需要该字段，见 `WatchDataModel.swift:49`）。
接收方：`WatchDataModel.session(_:didReceiveUserInfo:)`（`:163`）→ 覆盖 `todayBills`、写入缓存。

### 2.3 时序

```
Watch 记账                iPhone
  │  sendBill(bill)
  │  ├─ isReachable == false → 仅本地缓存 + todayBills 追加，返回 false（不重试）
  │  └─ isReachable == true
  │        transferUserInfo(addBill) ──────────▶ saveBillFromWatch
  │                                              ├─ 兜底 userIdentifier
  │                                              ├─ 按 id 去重
  │                                              └─ Bill(context:).save()
  │        （本地立即追加到 todayBills 并缓存）
  │
  │  requestSync()  →  transferUserInfo(requestTodayBills) ──▶ 查询今日账单
  │  ◀──────────────── transferUserInfo(todayBills) ──────────┘
  │  覆盖 todayBills + saveCache()
```

### 2.4 Watch 端状态与缓存

| 成员 | 类型 | 说明 |
|------|------|------|
| `todayBills` | `@Published private(set) [WatchBill]` | UI 数据源（`WatchDataModel.swift:71`） |
| `isReachable` | `@Published private(set) Bool` | 可达性，由 `sessionReachabilityDidChange` 刷新（`:182`） |
| `syncMessage` | `@Published private(set) String?` | 状态提示文案（预留） |
| `cachedBills` | `private [WatchBill]` | 全量本地缓存（`:76`） |
| `WATCHOS` 计算属性 | `todayExpense` / `todayIncome` / `todayBalance` / `todayCount` | 由 `todayBills` 派生（`:78-92`） |
| UserDefaults key | `WatchBillsCache`（JSONEncoder 编码的 `[WatchBill]`） | `saveCache`/`loadCachedBills`（`:193`、`:195`、`:204`） |

启动顺序：激活 session → `loadCachedBills()` → `filterToday(from:)`，随后在激活回调里 `requestSync()` 拉取最新数据（`:95`、`:139`）。

### 2.5 线程与 Actor 约束

- `WatchDataModel` 标注 `@MainActor`，所有 `WCSessionDelegate` 方法声明为 `nonisolated`，内部用 `DispatchQueue.main.async` 回到主线程再改状态（`WatchDataModel.swift:139`、`:163`、`:182`）。
- `WatchSessionManager`（iPhone 端）不是 `@MainActor`，但 Core Data 写入与查询都切到主队列执行（`WatchSessionManager.swift:154`、`:173`）。
- 两端都使用 `os.log` 的 `Logger`，subsystem 分别为 `com.liube.ifinance` 与 `com.liube.ifinance.watch`。

### 2.6 已知限制

1. 离线时 Watch 端不会自动补传（无重试队列，`sendBill` 返回 `false`）。
2. Watch 端 `userIdentifier` 依赖 Watch 自己的 UserDefaults（与 iPhone 不共享），常态是 `"anonymous"`，靠 iPhone 兜底。
3. `transferUserInfo` 是可靠队列，但**没有回执机制**：iPhone 端写入失败（例如 Core Data 保存异常）Watch 不会感知。
4. Watch 端金额统一使用 `Double`（`WatchBill.amount`），跨端存在 Decimal ↔ Double 的精度转换。
5. 不支持账单编辑 / 删除的跨端同步——只有新增与今日视图查询。

### 2.7 扩展指引（新增字段 / 新增 action）

新增一个跨端字段时至少要改 4 处：

1. `WatchBill.toPayload()`（`WatchDataModel.swift:35`）
2. `WatchBill.from(_:)`（`WatchDataModel.swift:49`）
3. `WatchSessionManager.saveBillFromWatch` 的解析与写入（`WatchSessionManager.swift:39`）
4. `WatchSessionManager.sendTodayBillsToWatch` 的回推字典（`WatchSessionManager.swift:107`）

新增 action 时：在两端各自的 `switch action` 分支中添加（iPhone：`WatchSessionManager.swift:154`、`:173`；Watch：`WatchDataModel.swift:163`），并保持**未知 action 静默忽略**的约定。

---

## 三、CSV 交换格式（仅 iOS 实现）

| 项 | 值 |
|----|-----|
| 入口 | 设置页「导出 CSV / 导入 CSV」（`iFinance/Views/Setting/SettingView.swift:325`、`:329`） |
| 文档类型 | `BillCSVDocument: FileDocument`，`UTType.commaSeparatedText`（`SettingView.swift:15`） |
| 表头 | `date,type,category,amount,note` |
| 日期 | ISO8601 导出；导入时回退解析 `yyyy-MM-dd HH:mm:ss`（`en_US_POSIX`） |
| 导出范围 | **全部用户的账单**（未按 `createdBy` 过滤，`SettingView.swift:597`），按 `date` 升序 |
| 导入校验 | `type ∈ {income, expenditure, transfer}`，行字段数 ≥ 5，金额用 `Decimal(string:)`（`en_US_POSIX`）；解析与映射逻辑在 `iFinance/Helper/CSVImporter.swift`（`parseRows` / `makeBill`），导入写入 `id/createdAt/createdBy/updatedAt/updatedBy`，记录归属当前账号 |
| 换行兼容 | CRLF / LF / CR 均可解析（Swift 中 `"\r\n"` 是单个 Character，不能用 `ch == "\n"` 判断） |
| SwiftData 版 | 同等修复：导入写入 `createdBy/updatedBy` 与审计字段，locale 为 `en_US_POSIX`（`iFinanceSwiftData/Views/Setting/SettingView.swift`） |
| macOS | 未实现（`MaciFinance/Views/SettingsView.swift:158` 为 TODO） |

---

_修改数据模型或同步协议后，请同步更新本文件、[PROJECT_MEMORY.md](../PROJECT_MEMORY.md) 与对应平台接口文档。_
