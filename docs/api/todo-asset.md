# 待办 / 备忘 / 资产 接口文档

> 覆盖范围：iOS 两版（`iFinance` 主版本 + `iFinanceSwiftData`）的「待办与备忘」标签页与「资产」页；
> macOS / watchOS 只在 `.xcdatamodeld` 层面同步数据模型，没有对应界面。
> 行号会随提交漂移，定位请以符号名搜索（`rg -n "<符号名>"`）为准。

## 1. 文件清单

| 文件 | 类型 | 职责 |
|------|------|------|
| `iFinance/Models/TodoModels.swift` ↔ `iFinanceSwiftData/Data/TodoModels.swift` | 纯逻辑（两版逐字节一致） | `TodoSnapshot` / `TodoPriority` / `TodoGroup` / `TodoGrouping` / `TodoRepeat` / `TodoRecurrence` / `TodoTagRules` / `MemoSorting` |
| `iFinance/Models/AssetBreakdown.swift` ↔ `iFinanceSwiftData/Data/AssetBreakdown.swift` | 纯逻辑（两版逐字节一致） | `AssetType` / `AssetAccountSnapshot` / `AssetSnapshotValue` / `AssetBreakdown` |
| `iFinanceSwiftData/Data/TodoEntities.swift` | SwiftData `@Model` | `TodoItem` / `TodoSubtask` / `TodoTag` / `MemoNote` |
| `iFinanceSwiftData/Data/AssetEntities.swift` | SwiftData `@Model` | `AssetAccount` / `AssetSnapshot` |
| `iFinance/iFinance.xcdatamodeld`、`MaciFinance/MaciFinance.xcdatamodeld` | Core Data 模型 | 上述 6 个实体（`codeGenerationType="class"`，属性由 Xcode 生成） |
| `iFinance/Views/Todo/`、`iFinanceSwiftData/Views/Todo/` | 视图 | `TodoTabView` / `TodoListView` / `TodoEditSheet` / `MemoListView` / `MemoEditSheet` |
| `iFinance/Views/Asset/`、`iFinanceSwiftData/Views/Asset/` | 视图 | `AssetView` / `AssetEditSheet` / `AssetDonutChart` / `AssetTypeBreakdown` / `AssetChartStyle` / `AssetAmount` |

> 两版同名视图只允许「数据栈差异」：`@FetchRequest` ↔ `@Query`、`@Environment(\.managedObjectContext)` ↔ `@Environment(\.modelContext)`、
> `AssetAccount(context:)` + `NSDecimalNumber` ↔ `AssetAccount(init:)` + `Decimal`、`NSFetchRequest` ↔ `FetchDescriptor`、preview 的 environment key。

## 2. 实体字段

### TodoItem / TodoSubtask / TodoTag

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID? | 业务主键（幂等/展示用，Core Data 侧可选） |
| `title` | String | 待办标题（保存时校验非空） |
| `note` | String? | 备注 |
| `dueDate` | Date? | 截止日（分组依据） |
| `priority` | Int16 | 0 无 / 1 低 / 2 中 / 3 高 |
| `isDone` / `completedAt` | Bool / Date? | 完成状态与完成时间 |
| `repeatRule` | String | `none` / `daily` / `weekly` / `monthly` / `yearly` |
| `createdAt` / `updatedAt` / `createdBy` / `updatedBy` | Date / String | 审计字段，写入必带 |
| `subtasks` | to-many | `TodoSubtask`，删除规则 **Cascade**（SwiftData：`.cascade` + `inverse: \TodoSubtask.owner`） |
| `tags` | to-many | `TodoTag`，**多对多 Nullify**（SwiftData 用 `@Relationship(inverse: \TodoTag.items)`） |

`TodoSubtask`：`id` / `title` / `isDone` / `createdAt` / `owner`（仅一层，不支持嵌套）。
`TodoTag`：`id` / `name`（1–8 字，同账号去重）/ `colorIndex`(Int16，8 色板下标) / `createdBy`（可选）/ `items`（多对多反向）。

### MemoNote

`id` / `title?` / `content` / `isPinned` / `createdAt` / `updatedAt` / `createdBy` / `updatedBy`。
标题缺省时列表显示正文首行。

### AssetAccount / AssetSnapshot

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID? | 业务主键 |
| `name` | String | 账户名 |
| `type` | String | `cash` / `debitCard` / `creditCard` / `payment` / `investment` / `other`（`AssetType.rawValue`） |
| `balance` | Decimal | 余额；负债填负数 |
| `note` | String? | 备注 |
| `includeInTotal` | Bool | 是否计入总资产（默认 true） |
| `sortOrder` | Int16 | 预留排序位（当前 UI 未使用，列表按类型分组 + 余额降序展示） |
| `createdAt` / `updatedAt` / `createdBy` / `updatedBy` | Date / String | 审计字段，写入必带 |

| AssetSnapshot 字段 | 类型 | 说明 |
|--------------------|------|------|
| `date` | Date | **当天 00:00**（同一自然日只有一条） |
| `totalAssets` / `totalLiabilities` | Decimal | 写入时刻的合计（负债为绝对值） |
| `createdAt` / `createdBy` | Date / String | 审计字段 |

## 3. 纯逻辑接口

```swift
struct TodoSnapshot: Equatable, Identifiable {
    let id: UUID; let title: String; let note: String?; let dueDate: Date?
    let priority: Int16; let isDone: Bool; let repeatRule: String; let createdAt: Date
}

enum TodoPriority { static let none/low/medium/high: Int16; static let all: [Int16]
    static func sortWeight(_ priority: Int16) -> Int
    static func localizedKey(_ priority: Int16) -> String }   // todo.priority.*

enum TodoGroup: String, CaseIterable { case overdue, today, nextSevenDays, later, noDate, completed
    var localizedKey: String { "todo.group.\(rawValue)" } }

enum TodoGrouping {
    static let upcomingWindowDays = 7
    static func group(of item: TodoSnapshot, now: Date = Date(), calendar: Calendar = .current) -> TodoGroup
    static func grouped(_ items: [TodoSnapshot], now: Date = Date(), calendar: Calendar = .current) -> [(group: TodoGroup, items: [TodoSnapshot])]
    static func sorted(_ items: [TodoSnapshot], in group: TodoGroup, calendar: Calendar = .current) -> [TodoSnapshot]
}

enum TodoRepeat {
    static let noneRule = "none"; static let daily/weekly/monthly/yearly: String
    static let all: [String]
    static func localizedKey(_ rule: String) -> String          // todo.repeat.*
    static func nextDueDate(after date: Date, rule: String, calendar: Calendar = .current) -> Date?
}

enum TodoRecurrence {
    /// 完成时生成下一期草稿；规则为 none / 无截止日 / 规则非法时返回 nil（见决策 D-75）
    static func nextDraft(after snapshot: TodoSnapshot, now: Date = Date(), calendar: Calendar = .current) -> TodoSnapshot?
}

enum TodoTagRules {
    static let maxCount = 12; static let maxNameLength = 8
    enum Validation: Equatable { case valid, empty, tooLong, duplicate, limit }
    static func validate(_ rawName: String, existingNames: [String]) -> Validation
    static func canAdd(existingCount: Int) -> Bool
}

enum MemoSorting { static func sorted(_ notes: [(id: UUID, isPinned: Bool, updatedAt: Date)]) -> [UUID] }

enum AssetType: String, CaseIterable { case cash, debitCard, creditCard, payment, investment, other
    var localizedKey: String { "asset.type.\(rawValue)" }
    var icon: String
    static var displayOrder: [AssetType] { allCases } }

struct AssetAccountSnapshot: Equatable, Identifiable {
    let id: UUID; let name: String; let type: AssetType; let balance: Double
    let note: String?; let includeInTotal: Bool; let sortOrder: Int16
}
struct AssetSnapshotValue: Equatable { let date: Date; let totalAssets: Double; let totalLiabilities: Double
    var net: Double { totalAssets - totalLiabilities } }

enum AssetBreakdown {
    static func included(_ accounts: [AssetAccountSnapshot]) -> [AssetAccountSnapshot]
    static func totalAssets(_ accounts: [AssetAccountSnapshot]) -> Double        // 仅计入且 balance > 0
    static func totalLiabilities(_ accounts: [AssetAccountSnapshot]) -> Double   // 仅计入且 balance < 0，取绝对值
    static func netTotal(_ accounts: [AssetAccountSnapshot]) -> Double
    static func breakdown(_ accounts: [AssetAccountSnapshot]) -> [(type: AssetType, amount: Double, share: Double)]
    static func change(current: AssetSnapshotValue, previous: AssetSnapshotValue?) -> (amount: Double, ratio: Double?)?
    static func upsertIndex(for date: Date, in snapshots: [AssetSnapshotValue], calendar: Calendar = .current) -> Int?
}
```

## 4. 视图入口与交互

| 入口 | 位置 | 说明 |
|------|------|------|
| 待办 Tab | `ContentView` 的 `Tab.todo`，位于「账本」与「趋势」之间 | `TodoTabView`：分段「待办 / 备忘」+ 右上角新建 |
| 资产按钮 | `TransactionView` 的 `topBarTrailing`，**头像左侧** | `Image(systemName: "banknote")`，`accessibilityLabel("asset.title")`，`navigationDestination(isPresented:)` 推入 `AssetView` |

待办列表：`List(.insetGrouped)` + `TodoGrouping.grouped` 分组；勾选圆圈切换完成（`HapticManager.shared.light()`）；
把带 `repeatRule` 的条目勾选完成时，用 `TodoRecurrence.nextDraft` 生成下一期（复制标签与子任务、子任务重置未完成）；
「已完成」分组头提供「清除已完成」（二次确认 alert）。备忘列表用 `MemoSorting.sorted` 置顶优先。

资产页：总资产卡（`AssetAmount` + `.appAmountStyle` / `.appNumericTransition`）→ `AssetDonutChart`（`SectorMark` + `chartAngleSelection` + 中心读数 + 明细列表兼图例）
→ 分类型账户列表（组头小计、组内余额降序、负数红色、点行编辑、`swipeActions` 删除）。编辑 sheet 用 `AssetEditSheet`
（类型九宫格、± 切换负数余额、计入总资产开关、删除二次确认），表单宽度 `AppLayout.formMaxWidth`。

## 5. 数据隔离与快照口径

- 查询一律叠加当前账号谓词：Core Data `PersistenceController.todoUserPredicate` / `todoTagUserPredicate` / `memoUserPredicate` /
  `assetAccountUserPredicate` / `assetSnapshotUserPredicate`；SwiftData 同名静态属性（`#Predicate`）。
- 写入必设 `createdBy`（与 `updatedBy`），值取 `PersistenceController.currentUserIdentifier`。
- 账号删除联动：`AuthManager.deleteTodoAndAssetData(identifier:context:)`（两版语义一致），
  另接入 `deleteAccount()` / `deleteAllAccounts()` 与 Core Data 启动重置钩子。
- 快照：账户增删改保存后调用 `AssetView.persistSnapshot()` —— 用 `AssetBreakdown.upsertIndex` 判断当天是否已有快照，
  有则覆盖 `totalAssets` / `totalLiabilities` 并刷新 `createdAt`，无则插入（`date` = 当天 00:00，`createdBy` = 当前账号）。

## 6. 已知坑

| 位置 | 问题与处理 |
|------|-----------|
| `iFinanceSwiftData/Manager/AuthManager.swift` | `TodoItem.tags` 非可选多对多 → `context.delete(model:where:)` 抛 `mandatory MTM nullify inverse`（134050）且被 `try?` 静默吞掉。**待办与标签必须走对象图删除**；其余 4 类无关系实体可继续批量删除 |
| `iFinanceSwiftDataTests/TodoAssetTests.swift` | 测试夹具必须用局部常量持有 `PersistenceController`；写成 `PersistenceController(inMemory: true).container.mainContext` 会让容器随临时实例释放，随后 `insert` 直接 SIGTRAP |
| `.xcdatamodeld` | Core Data 代码生成对整数只给 `Int16/Int32/Int64`（无 `Int`）、对非标量属性（String / Date / Decimal）默认生成**可选**类型；纯逻辑与 SwiftData 实体因此统一为 `Int16` + 只读快照的 `Double` |
| 两版视图 | 同名副本必须手工同步；新增/修改后按本文件 §1 的「允许差异」清单核对 `diff` |

## 7. 测试覆盖

| 测试 | 覆盖 |
|------|------|
| `iFinanceTests/TodoLogicTests`（两版同名） | 分组（逾期 / 今天 / 未来 7 天 / 以后 / 无日期 / 已完成）、排序（优先级 → 截止日 → 创建时间）、重复规则推进（月末 / 闰年）、标签校验、备忘置顶排序 |
| `iFinanceTests/TodoEditRulesTests` | 编辑待办时的字段校验与重复规则联动 |
| `iFinanceTests/TodoRenderSmokeTests` / `iFinanceSwiftDataTests/TodoRenderSmokeTests` | 待办与备忘视图真实渲染冒烟（不崩溃） |
| `iFinanceTests/AssetBreakdownTests`（两版同名） | 总额 / 负债 / 净资产、类型占比与固定顺序、快照差值（含上一条净额为 0 时比率为 nil）、同日 upsert 下标 |
| `iFinanceTests/TodoAssetIsolationTests` / `iFinanceSwiftDataTests/TodoAssetTests` | 账号隔离（换 `createdBy` 查不到他人数据）、删除联动（6 类数据清空且保留其它账号） |
