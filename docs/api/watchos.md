# watchOS 端接口文档（WatchiFinance Watch App）

> 覆盖范围：`WatchiFinance Watch App/`（约 800 行 Swift）。部署目标 watchOS 11.0，构建 SDK watchOS 27；Bundle ID `cn.liube.iFinance.watchkitapp`。
> 与 iPhone 的通信协议见 [data-and-sync.md](data-and-sync.md) §2。

## 1. 文件清单

| 文件 | 主要类型 | 职责 |
|------|----------|------|
| `WatchiFinance Watch App/WatchiFinanceApp.swift` | `WatchiFinanceApp` | 入口（16 行），仅声明 `WindowGroup { ContentView() }` |
| `WatchiFinance Watch App/ContentView.swift` | `ContentView` 及子视图 | 三 Tab：今日概览 / 快速记账 / 当日历史（426 行） |
| `WatchiFinance Watch App/Models/WatchDataModel.swift` | `WatchBill`、`WatchDataModel` | `WCSessionDelegate` + 本地缓存 + 发送/请求 |
| `WatchiFinance Watch App/L10n.swift` | `L10n` | Watch 端本地化查找（与 iOS 同策略，独立实现） |
| `WatchiFinance Watch App/Resources/Localization/{zh-Hans,zh-Hant,en,ja}.lproj` | — | 45 行 key（`add.*`、`category.*`、`summary.*`、`history.*`、`tab.*`、`status.*`） |

## 2. 传输模型：`WatchBill`（`Models/WatchDataModel.swift:17`）

```swift
struct WatchBill: Identifiable, Codable {
    var id: String
    let amount: Double
    let type: String
    let category: String
    let note: String?
    let date: Date

    init(id: String = UUID().uuidString, amount: Double, type: String,
         category: String, note: String? = nil, date: Date = Date())

    func toPayload() -> [String: Any]        // :35  字典（含 userIdentifier）
    static func from(_ payload: [String: Any]) -> WatchBill?   // :49
}
```

`toPayload()` 字段：`id`(String) / `amount`(Double) / `type` / `category` / `note`(可选) / `date`(ISO8601 String) / `userIdentifier`（`UserDefaults["AuthUserIdentifier"] ?? "anonymous"`，`:43`）。
`from(_:)` 要求 `id`/`amount`/`type`/`category` 齐备，`date` 缺失时回退当前时间；**不读取** `userIdentifier`。

## 3. 数据模型：`WatchDataModel`（`Models/WatchDataModel.swift:64`）

`@MainActor final class WatchDataModel: NSObject, ObservableObject, WCSessionDelegate`，`static let shared`（`:66`）。

| 成员 | 类型 | 说明 |
|------|------|------|
| `todayBills` | `@Published private(set) [WatchBill]` | 今日账单（概览/历史数据源，`:71`） |
| `isReachable` | `@Published private(set) Bool` | iPhone 可达性（`:72`） |
| `syncMessage` | `@Published private(set) String?` | 提示文案（预留，`:73`） |
| `todayExpense` / `todayIncome` / `todayBalance` / `todayCount` | 计算属性 | 由 `todayBills` 派生 |
| `cachedBills` | `private [WatchBill]` | 全量本地缓存（`:76`） |

公开方法：

| 方法 | 签名 | 行为 |
|------|------|------|
| `sendBill(_:)` | `func sendBill(_ bill: WatchBill) async -> Bool`（`:109`） | 可达时 `transferUserInfo(["action": "addBill", "bill": payload])`、本地追加并返回 `true`；**不可达时仅写缓存与本地列表并返回 `false`（无补发队列）** |
| `requestSync()` | `func requestSync()`（`:127`） | 可达时发送 `["action": "requestTodayBills"]`；不可达直接返回（使用缓存） |

初始化（`:95`）：`WCSession.isSupported()` 时设置 delegate 并 `activate()`，随后 `loadCachedBills()` + `refreshTodayBills()`。

## 4. Delegate 实现

| 方法 | 行 | 说明 |
|------|----|------|
| `session(_:activationDidCompleteWith:error:)` | `:139` | 激活成功且 `state == .activated` 时刷新 `isReachable` 并 `requestSync()` |
| `session(_:didReceiveUserInfo:)` | `:163` | 处理 `action == "todayBills"`：解析 `bills` → 覆盖 `todayBills` → `saveCache` |
| `sessionReachabilityDidChange(_:)` | `:182` | 刷新可达性，变为可达时自动 `requestSync()` |

⚠️ **watchOS 限制**：`sessionDidBecomeInactive` / `sessionDidDeactivate` 在 watchOS 上不可用（源码注释 `:134`），本端不实现；iOS 端需要实现。
所有回调均声明 `nonisolated` 并通过 `DispatchQueue.main.async` 回到主线程更新 `@Published` 状态。

## 5. 本地缓存

| 项 | 值 |
|----|-----|
| UserDefaults key | `WatchBillsCache`（`:193`） |
| 编码 | `JSONEncoder().encode([WatchBill])`（`saveCache`，`:195`） |
| 读取 | `loadCachedBills()`（`:204`）→ `filterToday(from:)`（`:229`）按 `Calendar.isDate(_:inSameDayAs:)` 过滤出今日 |
| 更新时机 | 收到 iPhone 回推、发送新账单（`addLocalBill`，`:218`）、离线缓存（`cacheBill`，`:213`） |

## 6. 界面：`ContentView`（426 行）

三 Tab 结构（`tab.*` 本地化 key）：

1. **概览**：`todayIncome` / `todayExpense` / `todayBalance` / `todayCount` 卡片；
2. **快速记账**：3×4 数字键盘 + 横向分类滚动（支出 6 项 / 收入 4 项）+ 发送；
3. **当日历史**：`todayBills` 列表。

交互均通过 `WatchDataModel.shared` 的 `@Published` 状态驱动；发送成功后调用 `HapticManager` 等效的 `WKInterfaceDevice` 触觉（Watch 端为独立实现）。

## 7. 与 iOS 端的协作要点

- Watch 不写本地数据库，只有内存列表 + UserDefaults 缓存；真正的落库发生在 iPhone（`WatchSessionManager`）。
- `userIdentifier` 在 Watch 端常为 `"anonymous"`（两设备不共享 UserDefaults），由 iPhone 端兜底为当前登录用户。
- 账单去重依赖 `WatchBill.id`（UUID 字符串）在 iPhone 端按 `id` 查询。

## 8. 未覆盖 / 存疑

- 未在 watchOS 11 设备上验证（本机仅有 watchOS 26.x 运行时），下界为编译级验证。
- Watch 与 iPhone 的真实配对同步需要在同一 Apple ID 的配对设备上验证；模拟器只能验证编译与单端逻辑。
