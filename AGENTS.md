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
# 真机 Release 运行（编译略慢、运行明显更快；日常调试仍用默认 Debug）
scripts/run-on-device.sh -s iFinance --release
```

测试目标：`iFinanceTests`（XCTest，15 个测试类 / 97 用例）、`iFinanceSwiftDataTests`（Swift Testing，38 用例）、`MaciFinanceTests`（Swift Testing，30 用例）、watch/UI 测试为模板占位。
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
   **待办 / 备忘 / 资产**另有 6 个实体（`TodoItem` / `TodoSubtask` / `TodoTag` / `MemoNote` / `AssetAccount` / `AssetSnapshot`）：两份 Core Data 模型 + SwiftData 的 `Data/TodoEntities.swift`、`Data/AssetEntities.swift`，同样三处同改。
   注意 Core Data 代码生成对整数只给 `Int16/Int32/Int64`（没有 `Int`），非标量属性（String / Date / Decimal / UUID）默认生成**可选**类型——纯逻辑与 SwiftData 实体统一用 `Int16`，Core Data 侧读取判空（详见 [docs/api/todo-asset.md](docs/api/todo-asset.md)）。
3. **三套本地化资源**：iOS / macOS / watchOS 各自拥有 `Resources/Localization/{zh-Hans,zh-Hant,en,ja}.lproj`，key 不共享。新增文案只改对应端。
   SwiftData 版**不复制**这些资源，而是以 target membership 引用 `iFinance/Resources/Localization/*.lproj` 与 `EconomicQuotes.json`——改 iOS 文案会同时影响两版。
4. **新增文案一律用 `L10n.string("...")`**：`String(localized:)` 与 `NSLocalizedString` 已全量统一替换（它们走系统语言、不跟随 App 内语言）。`Text("some.key")`（`LocalizedStringKey`）可以继续用，它随注入的 `\.locale` 正确工作。改文案时按 key 全仓库搜索。
   - 语言切换时会调用 `LocalizationSync.apply(_:)` 写入 `UserDefaults["AppleLanguages"]` 并重启，让系统控件（分享面板、Face ID 提示、系统弹窗）也跟随 App 内语言；App 启动时 `LocalizationSync.syncIfNeeded()` 兜底修正。
   - 提交前建议运行 `python3 scripts/check_localization.py`：扫描代码引用的 key 与四语言包比对（缺失/语言间不一致会返回非零码），「未被引用」仅为提示。
5. **类型字符串**：`Bill.type` 运行时值是 `"expenditure"` / `"income"` / `"transfer"`（不是模型默认值「支出」）。
6. **金额**：Core Data 中是 `Decimal`，代码里用 `NSDecimalNumber` 赋值；Watch 传输用 `Double`。
7. **禁用功能不要"顺手接上"**：`CloudKitSyncManager`、`NotificationManager` 是刻意保留的 stub（需付费开发者账号，所有系统调用已注释）；`iCloudSyncView` 入口仍在。
8. **后台隐私遮罩**：进入后台/非活跃时由 `BiometricLockManager.activatePrivacyShield()` 触发、`.appPrivacyShield(_:)` 对整页做高斯模糊，**仅在用户开启应用锁（`BiometricLockEnabled`）时生效**；改动场景生命周期或锁状态机时不要破坏这条链路，新增页面无需单独处理（入口已统一包裹）。
9. **账单类型与分类必须匹配**：`Bill.category` 存**字符串**，取值规则：
   - 内置分类 = 枚举 rawValue（支出 25 类 / 收入 12 类，转账固定 `"transfer"`）；
   - 自定义分类 = 用户输入的**名称**；二级分类 = `父/子` 复合路径（如 `交通/地铁`），分隔符固定 `"/"` 且名称里禁止出现。
   编辑页的类型切换、旧数据归一化与保存校验统一走 `BillEditRules` → `CategoryResolver.isValid(_:kind:)`（`Views/Common/CategoryResolver.swift`），**不要再用自由文本输入分类**；展示名/图标/配色一律通过 `CategoryResolver` 解析，不要直接 `ExpenditureCategory(rawValue:)` 反查。
10. **标签栏固定 5 项**：首页 / 账本 / **待办** / 趋势 / **我的**（末项标签名为 `tab.setting` = 我的 · Me · マイ，图标是用户头像、无头像时回落 `person.crop.circle.fill`）。待办与备忘在同一个 Tab 内用分段切换（`Views/Todo/TodoTabView.swift`）；**资产不占标签位**，入口是账本页右上角（头像左侧）的按钮（`Views/Asset/AssetView.swift`）。不要把新页面加成第 6 个 Tab。
11. **待办 / 备忘 / 资产的数据隔离**：查询必须叠加 `PersistenceController` 的 `todoUserPredicate` / `todoTagUserPredicate` / `memoUserPredicate` / `assetAccountUserPredicate` / `assetSnapshotUserPredicate`；写入必带 `createdBy`（与 `updatedBy`）。文案命名空间是 `todo.` / `memo.` / `asset.`，Tab 用 `tab.todo`。
12. **SwiftData 删除待办必须走对象图删除**：`TodoItem.tags` 是非可选多对多，`context.delete(model:where:)` 会抛 `mandatory MTM nullify inverse`（`NSCocoaErrorDomain` 134050）且被 `try?` 静默吞掉，数据实际删不掉；只有逐个 `context.delete(_:)` 才会级联子任务并清理关系（见 `AuthManager.deleteTodoAndAssetData`）。
13. **SwiftData 测试夹具必须持有容器**：禁止 `PersistenceController(inMemory: true).container.mainContext` 这种临时实例写法（容器随即销毁，`insert` 直接 SIGTRAP）；用局部 `let controller = ...` 或夹具类持有。

## 代码风格

- 文件头：`// 文件名` + `// 目标名` + `// Created by ...`；正文用 `// MARK: -` 分节。
- 几乎每个 View 文件末尾都有 `#Preview`，预览依赖 `PersistenceController.preview`。
- `internal import CoreData`、`@preconcurrency import WatchConnectivity` 是刻意写法，不要"简化"成普通 import。
- 平台差异用 `#if os(macOS)` / `#if os(watchOS)` 就地分支；项目不做跨端抽象层（存在刻意保留的重复代码）。
- 视觉统一走 `Views/Common/AppVisualStyle.swift` 的 `appGlassCard(cornerRadius:)` 与 `.scalePress`；触觉反馈走 `HapticManager.shared`（9 个方法），不要直接调 `UIImpactFeedbackGenerator`。
- **新写 UI 一律用 token，不要再写魔法数字**：间距/圆角/宽度用 `AppDesignTokens.swift` 的 `AppSpacing` / `AppRadius` / `AppLayout`，字体用 `AppTypography`（语义字体，跟随 Dynamic Type；大号金额用 `.appAmountStyle(size:)`）；动画用 `AppMotion` 的 `quick` / `standard` / `emphasized` / `numeric`，并优先使用 `.appAnimation(_:value:)`、`.appEntrance(index:visible:)` 以自动遵循「减弱动态效果」。iPad 上的主内容用 `.appContentWidth()` 收敛宽度。
- **性能约定**：背景动画只允许用 `AppBackgroundView`（内部走全局共享的 `AppBackgroundClock`，10fps、非活跃自动暂停），不要在新页面里再写 `TimelineView(.animation)`；头像解码统一走 `AvatarImageCache.shared.image(for:)`，不要在 body 里直接 `UIImage(data:)`；`NumberFormatter` / `DateFormatter` 一律声明为 `static let` 复用；百分比展示用 `AppNumberFormat.percent(_:)`（最多两位小数、去尾零）。
  - 趋势页取数固定「最近 24 个月 + 当前账号」窗口（Core Data 谓词 / SwiftData `@Query`），不要改回全量取数；
  - 图表数据点 id 用**日期**（`DailyAmount.id` / `NetTrendPoint.id`），不要用 `UUID()`，否则每次重绘都会全量 diff；
  - 账单列表用 `LazyVStack` 按天懒加载；body 内不要重复调用同一计算属性（先 `let groups = groupedBills`）；
  - 分类选择器的选项数组走 `CategoryResolver` 的版本缓存，数据变更后由 `CategoryStore.revision` 自动失效。
- **趋势页结构**：支出趋势（柱状）→ 支出分类占比（饼图）→ 收入趋势（柱状）→ 收入分类占比（饼图）→ 热力图；**折线图与图表类型切换器已删除**，柱状图是唯一的时间趋势图。分类占比统一走 `CategoryBreakdown`（纯函数，按「最近 N 天」聚合）+ `CategoryPieView`（预算页共用），配色用 `CategoryPalette`。

## 关键数据流

```
Watch 记账 → WatchDataModel.sendBill → transferUserInfo(action: addBill)
           → WatchSessionManager.saveBillFromWatch（兜底 userIdentifier → 按 id 幂等 → Core Data）
Watch 概览 → requestSync → transferUserInfo(action: requestTodayBills)
           → iPhone 查询今日账单 → transferUserInfo(action: todayBills) → Watch todayBills + UserDefaults 缓存
```

协议细节、payload 字段、扩展步骤见 [docs/api/data-and-sync.md](docs/api/data-and-sync.md)。

## 分类体系速查（第四轮建立）

| 想知道 | 看哪里 |
|--------|--------|
| 自定义分类 / 二级分类怎么存、怎么校验 | `Views/Common/CategoryStore.swift`（`CustomCategory`、增删改、`trafficSubcategoryPresets` 播种、上限与重名校验） |
| 某个分类字符串怎么解析成名称 / 图标 / 配色 | `Views/Common/CategoryResolver.swift`（`displayName` / `icon` / `color` / `parentRaw` / `isValid` / `topLevelOptions`） |
| 图标选择器有哪些可选符号 | `Views/Common/CategoryIconLibrary.swift`（9 组 105 枚） |
| 记账页/编辑页的分类网格与「+ 自定义」 | `Views/Transaction/Bills/CategoryGridView.swift`、`CustomCategorySheet.swift` |
| 设置页分类管理（改名/删除/二级分类） | `Views/Setting/CategoryManagementView.swift`（含 `SubcategoryManageView`，两版数据访问不同） |
| 趋势页「总收支」双向柱状图 | `Views/Tendency/NetTrendCard.swift`（`NetTrendBuilder` 纯函数 + 卡片） |

配色规则：**分类身份色**（网格 / 账单行 / 分类管理 / 二级 chips）用 `CategoryKind.accentColor` —— 支出红、收入绿，自定义与二级分类一视同仁；**数据可视化色**（饼图扇区 + 预算页分类明细）用 `CategoryPalette.chartColor(for:kind:)` 的 8 色板，两者不要混用。

## 已确认的坑（改代码前先读）

| 位置 | 问题 |
|------|------|
| Xcode 27 的 UI 测试 | 在克隆模拟器上会触发 XCTest ↔ Swift Testing 互操作递归并崩溃（日志在 `~/Library/Logs/DiagnosticReports/iFinance-*.ips`）；App 正常启动不受影响，验证请用 `-only-testing:` 跳过 UI 测试 |
| iOS 27 / watchOS 27 模拟器运行时 | 本机 Xcode 27 的 `-downloadPlatform` 返回 “not available for download”，上界只能做编译级验证（真机由作者验证） |
| macOS 15 / watchOS 11 下界 | 本机无法运行这两个系统，只能编译 + API 可用性审查 |
| `iFinanceSwiftData` 命名兼容层 | `PersistenceController` / `ModelContainer.viewContext` / `Amount` 计算属性是为了复用 iOS 视图代码而保留的同名 API，改造视图时注意区分两版实现 |
| `MaciFinance/Views/SettingsView.swift:158` | CSV/JSON 导出仍是 TODO |
| `WatchiFinance Watch App/Models/WatchDataModel.swift` | iPhone 不可达时账单只进本地缓存，没有补传队列 |
| iOS 语言切换 | 走 `exit(0)` 重启进程；改语言相关逻辑时不要假设热切换 |
| 工程 scheme | 存在无对应文件的遗留 scheme `Copy of iFinance` |
| 真机部署慢 | 构建本身很快（增量 3～6s、全量约 24s），慢在部署阶段：iOS scheme 依赖 watch target（`Embed Watch Content`），配对手表时每次 Run 都会推送 Watch App，且 Xcode 会附加调试器。改用 `scripts/run-on-device.sh` 可绕过这两步；另注意设备需解锁且已信任电脑 |
| 记账键盘输入 | 数字键盘的表达式逻辑在 `Views/Transaction/Bills/NumberPadLogic.swift`（`NumberPadExpression`，纯函数 + 单测）。**校验只能针对「当前数字段」（最后一个运算符之后的部分）**——曾经用整串 `displayText` 判断小数位，导致「小数点出现后运算符后面再也输不进数字」；`AddBillView.parseExpression` 负责求值 |
| SwiftData 待办/标签删除 | `TodoItem.tags` / `TodoTag.items` 是非可选多对多：`context.delete(model:where:)` 抛 `mandatory MTM nullify inverse`（134050）且被 `try?` 静默吞掉（数据删不掉）。待办与标签必须逐个 `context.delete(_:)`（对象图删除），其余 4 类无关系实体可继续批量删除 |
| SwiftData 测试夹具 | `PersistenceController(inMemory: true).container.mainContext` 这种临时实例写法会让容器随控制器一起释放，`insert`/`save` 直接 SIGTRAP（崩溃点还会飘到别的测试上）。夹具类或局部常量必须持有 `PersistenceController` |
| 标签栏头像（「我的」标签） | `.tabItem` 里放 `.resizable()` 图片会被拉伸铺满整条标签栏；且标签栏会把非符号图片**当模板**渲染成纯色块。必须传固定尺寸位图（`AvatarImageCache.thumbnail(for:diameter:)`），并保证 UIImage 为 `withRenderingMode(.alwaysOriginal)` |
| `UserProfile.avatarData` | 该属性是 Core Data **外部二进制存储**（引用 + `_SUPPORT/_EXTERNAL_DATA` 文件）。**禁止用裸 SQL 往这列写图片字节**：Core Data 会把字节当引用读，轻则读到 nil、重则启动崩（`Missing bytes from file at path .../_EXTERNAL_DATA`）。造测试数据请走 App 流程或 Core Data API |
| 文本解析换行 | Swift 中 `"\r\n"` 是**一个** Character：CSV/文本解析里 `ch == "\n"` 漏掉 CRLF，会把 Windows/Excel 导出的文件当成一整行（`CSVImporter.parseRows` 已修为覆盖 `\n` / `\r\n` / `\r`，新写解析逻辑请照此处理） |
| 视图不要写「比较实体内容」的 Equatable | `BillsCardView` 的 `DayGroupCard` 曾用 `zip(bills, bills).allSatisfy { $0.amount == $1.amount }` 判断内容变化——两侧是同一批 Core Data / SwiftData 实例，比较的是同一个当前值，**恒为 true**，于是编辑金额后视图被判定「没变化」而跳过重绘（症状：改金额后列表当日净额、预算卡都不动）。需要感知实体字段变化时用「内容指纹」（`TransactionView.billRevision`）+ `.onChange`，或直接依赖 SwiftUI 默认重绘 |
| 分类体系（第四轮新增） | 自定义分类与二级分类定义存在**本机 UserDefaults**（`CategoryStore`，按账号隔离，键 `custom_categories_v1_<账号>`），**不改三份数据模型**；账单里只存名字或 `父/子` 路径。改名会同步历史账单、删除不会（历史账单保留原分类名）。macOS / watchOS 不识别自定义分类，显示为灰色纯文本 |
| 分类图标唯一性 | 一级分类图标在同一类型内不得重复、二级分类在同一父级下不得重复；新增/调整分类后必须跑 `iFinanceTests/CategoryIconTests`（同时校验符号在系统中真实存在） |
| 模拟器启动失败 | `xcodebuild test` 偶发 `SBMainWorkspace` 拒绝启动并反复重试（日志刷 `failed to launch cn.liube.iFinance`）：先 `simctl boot` + `bootstatus -b` 手动拉起，仍失败就换一台模拟器设备（本机 iPhone 16 与 iPhone 16 Pro 可互为备份） |
| 键盘浮层定位 | 键盘上方的浮层（如记账页备注条）**只能有一个位移来源**：要么完全交给系统键盘避让，要么容器 `.ignoresSafeArea(.keyboard)` + 用 `keyboardWillChangeFrame` 算出的 `keyboardOverlap` 手动 `padding(.bottom, ...)`。两者叠加会把控件顶到远离键盘的位置（曾踩过：系统避让 + 手动 `offset` = 双重位移） |
| 趋势图 scrub 交互 | 柱状图的按住扫读统一走**原生 `chartXSelection(value:)`**（按下即选 / 拖动吸附 / 松手清空），指示线与浮层由 `chartOverlay` + `ScrubCallout` 绘制、只做透明度变化（`AppMotion.quick` 0.18s 淡出）。**不要再写自研 DragGesture**：会与页面纵向滚动、系统返回手势争抢触摸；贴边自动滚动用「选中项贴边 + Task 200ms 步进窗口」近似（原生选择手势不暴露连续拖动增量）。`TendencyConstants.touchDetectionRadius` 与 `barOpacity` 淡化逻辑已删除，别再引回 |
| 图表规范（第八轮） | 所有图表复用 `Views/Common/` 的五个支撑文件：`ChartAxisSupport`（下界 0 / 上界随数据 / 3–5 条整齐刻度 / 紧凑轴标签）、`ChartSeriesStyle`（语义色，取值为**改版前原色**、深浅共用 + 形状符号通道；R16 明度均衡按用户取舍未采用，**不要顺手改色**）、`ChartSummary`（标题结论副标题）、`ChartAccessibility`（`AXChartDescriptorRepresentable` + 逐点中文标签，轴刻度 `.accessibilityHidden(true)`）、`HeatmapRamp`（热力色阶 + 提高对比度变体）。**不要写死颜色 / 刻度 / 图表文案**；新增图表要补描述符与单测。热力图为自绘网格，整块 `SpatialTapGesture` 吸附最近格（R11 的原生 API 需 Swift Charts 图表，已在代码注释说明）；macOS 统计页尚未接入这些约定（R14/R20 未达成，见 open-items OI-46） |
| 分类数据加载时机 | 分类定义存在 UserDefaults，**不能只在记账页/分类管理页 `reload()`**：账单列表（重启后第一个渲染的页面）也要能解析「父/子」路径。`CategoryStore.currentItems` 会在首次访问时同步从磁盘载入且**不发布变更**（可在渲染期安全调用），`reload()` 只负责补发布给观察 `items` 的视图。曾因此出现「重启后二级分类显示问号」 |

## 文档维护约定

`docs/HANDOFF.md`（交接：接手清单、环境、铁律、验证标准）、`docs/PRD.md`（产品需求：功能清单、业务规则、验收清单）、`docs/PROJECT_MEMORY.md`（架构与坑）、`docs/api/*.md`（接口文档，含 `swiftdata.md`）由代码勘察生成，接口文档带 `路径:行号` 引用。
**每次交接/大改动收尾时更新 `docs/HANDOFF.md` 的 §1 快照表与 §8 风险摘录。**
**修改任何公开类型/方法签名、数据模型、Watch 协议或本地化 key 规则后，请同步更新对应文档与本节中的坑表。**
新增/调整产品功能时，请同步 `docs/PRD.md` 的功能需求表与验收清单（状态列用 ✅ / 🚧 / 💤 标注真实情况）。
每一轮工作结束后，请同步 [memory/](memory/README.md)：`work-history.md` 追加提交记录、`decision-log.md` 记录取舍、`open-items.md` 更新待办状态。
