# iOS 视图层接口文档

> 覆盖范围：`iFinance/Views/**`。部署目标 iOS 18.0，SDK iOS 27。
> SwiftData 版的视图层是同名文件的改造副本，逐行差异见 [swiftdata.md](swiftdata.md) §4。

## 1. 文件清单

| 文件 | 主要类型 | 职责 |
|------|----------|------|
| `Views/ContentView.swift` | `ContentView` | 四个 Tab 容器（home/transaction/tendency/setting） |
| `Views/Home/HomeView.swift` | `HomeView` | 概况页：今日概况（主视觉）+ 周期概况 + 每日一言卡 + 分享 |
| `Views/Home/TodayBalanceCard.swift` | `TodayBalanceCard` | 今日概况大卡（日期 + 大号结余 + 收入/支出/笔数三栏） |
| `Views/Home/PeriodSummaryCard.swift` | `PeriodSummaryCard` | 周期概况卡（本月 / 上月 / 本年 三行明细） |
| `Views/Home/SentenceCardView.swift` | `SentenceCardView` | 每日一言卡（毛玻璃卡 + 右上角「换一句」） |
| `Views/Home/ShareCardView.swift` | `ShareCardView` | 分享用统计卡片（含三个区间摘要，ImageRenderer 渲染） |
| `Views/Home/ShareSheet.swift` | `ShareSheet` | `UIActivityViewController` 包装 |
| `Views/Transaction/TransactionView.swift` | `TransactionView`、`SearchSheet` | 记账 Tab：预算卡片 + 账单卡片 + 搜索页 |
| `Views/Transaction/TransactionRowView.swift` | `TransactionRowView` | 单条账单行 |
| `Views/Transaction/Bills/AddBillView.swift` | `AddBillView` | 新增账单（数字键盘 + 分类） |
| `Views/Transaction/Bills/CategoryGridView.swift` | `CategoryGridView`、`CategoryGridCell` | 分类网格：内置 + 自定义 + 「+ 自定义」入口 + 二级分类 chips（记账页与编辑页共用） |
| `Views/Transaction/Bills/CustomCategorySheet.swift` | `CustomCategorySheet` | 自定义分类 sheet（名称 / 图标 / 主题色 / 二级分类；含图标占用校验） |
| `Views/Setting/CategoryManagementView.swift` | `CategoryManagementView`、`SubcategoryManageView` | 设置页分类管理（改名同步账单、删除保留账单、二级分类增删改；两版数据访问不同） |
| `Views/Tendency/NetTrendCard.swift` | `NetTrendCard`、`NetTrendPoint`、`NetTrendBuilder` | 趋势页「总收支」双向柱状图：以零轴为界，收入柱用正值向上、支出柱用 `expenseBarValue`（负值）向下，Y 轴刻度显示绝对值；跨度月 / 6 个月 / 年 |
| `Views/Transaction/Bills/EditBillView.swift` | `EditBillView` | 编辑 / 删除账单 |
| `Views/Transaction/Bills/CategoryPickerView.swift` | `CategoryPickerView` | 分类选择页（只列当前类型的分类，点选回写并返回） |
| `Views/Transaction/Bills/BillEditRules.swift` | `BillEditRules` | 编辑页类型/分类联动规则（纯函数） |
| `Views/Transaction/Bills/BillsCardView.swift` | `TimeRange`、`BillsCardView` | 账单列表：时间范围 / 分类 / 备注筛选 |
| `Views/Transaction/Bills/NumberPad.swift` | `NumberPad` | 自定义数字键盘主体（含备注、日期） |
| `Views/Transaction/Bills/NumberPadLogic.swift` | `NumberPadExpression` | 键盘表达式纯逻辑（追加数字/小数点、运算符切换、退格、百分比），独立可测 |
| `Views/Transaction/Bills/NumberPadComponents.swift` | `NumberButton`、`OperationButton`、`DatePickerView` | 键盘组件 |
| `Views/Transaction/Bills/{Expenditure,Income}CategoryItemView.swift` | 分类按钮 | 分类选择项 |
| `Views/Transaction/Budget/BudgetView.swift` | `BudgetView`、`CategoryRowView` | 预算页：环形进度 + 分类列表/饼图 |
| `Views/Transaction/Budget/BudgetCardView.swift` | `BudgetCardView` | 预算卡片（本月支出聚合） |
| `Views/Tendency/TendencyView.swift` | `TendencyView` | 趋势页：支出趋势 → 支出分类占比 → 收入趋势 → 收入分类占比 → 热力图 |
| `Views/Tendency/TrendCard.swift` | `TrendCard` | 可复用趋势卡片（5 档跨度 + 柱状图） |
| `Views/Tendency/TendencyChartView.swift` | `TendencyChartView` | 柱状图（Swift Charts；原折线图已移除） |
| `Views/Tendency/CategoryPieCard.swift` | `CategoryPieCard` | 分类占比卡片（标题 + 独立跨度选择器 + 饼图） |
| `Views/Common/CategoryPieView.swift` | `CategoryPieView` | 分类占比环形图（预算页与趋势页共用：点选高亮 + 明细列表 + 合计） |
| `Views/Common/CategoryPalette.swift` | `CategoryPalette` / `CategoryKind` | 分类配色与展示名解析（预算页 / 趋势页共用） |
| `Views/Tendency/TendencyHeatmapView.swift` | `TendencyHeatmapView` | 53 周热力图 |
| `Views/Tendency/TendencyModels.swift` | `DailyAmount`、`SpanOption`、`ChartDisplayType`、`TendencyConstants` | 图表数据模型与常量 |
| `Views/Profile/ProfileView.swift` | `ProfileView` | 个人中心（头像/昵称/邮箱/手机/密码） |
| `Views/Setting/SettingView.swift` | `SettingView`、`SettingsGroup`、`SettingsRow`、`BillCSVDocument` | 设置页：主题/语言/生物锁/数据管理/CSV/关于 |
| `Views/Auth/LoginView.swift` | `LoginView` | 登录/注册/忘记密码/Apple 登录 |
| `Views/iCloudSync/iCloudSyncView.swift` | `iCloudSyncView` | iCloud 同步设置页（对应禁用 stub） |
| `Views/Common/AppVisualStyle.swift` | `AppBackgroundView`、`ScaleButtonStyle`、`ShimmerView` + `View` 扩展 | 全项目视觉统一 |
| `Views/Common/AppDesignTokens.swift` | `AppSpacing`、`AppRadius`、`AppLayout`、`AppTypography` | 布局/间距/圆角/字体 token（HIG 尺度） |
| `Views/Common/AppMotion.swift` | `AppMotion` + `appAnimation` / `appEntrance` / `appPressable` | 动画节奏 token（含 Reduce Motion 降级） |
| `Views/Common/AppPrivacyShield.swift` | `AppPrivacyShield` + `.appPrivacyShield(_:)` | 进入后台时的整页高斯模糊遮罩（仅开启应用锁时启用） |
| `Views/Common/AppBackgroundClock.swift` | `AppBackgroundClock` | 全局共享背景时钟（10fps，非活跃暂停），替代每个页面各自的 30fps TimelineView |
| `Views/Common/AppSplashView.swift` | `AppSplashView` | 冷启动开屏动画（渐变底 + 呼吸光晕 + 标题/副标题 + 加载指示，1.8s） |
| `Views/Common/AvatarImageCache.swift` | `AvatarImageCache` | 头像解码缓存（按数据哈希复用 `UIImage`，避免每次渲染重新解码） |
| `Views/Profile/AvatarCropView.swift` | `AvatarCropView` | 头像裁剪（圆形遮罩 + 拖动/缩放，输出 300×300 JPEG） |
| `Views/Profile/EditSignatureView.swift` | `EditSignatureView` | 个性签名编辑（40 字上限 + 实时计数器） |

## 2. 根容器：`ContentView`（`Views/ContentView.swift:11`）

```swift
enum Tab { case home, transaction, tendency, setting }
```

`TabView(selection:)` + 四个 `tabItem`（`tab.home` / `tab.transaction` / `tab.tendency` / `tab.setting`，SF Symbol 分别 `house` / `long.text.page.and.pencil.fill` / `chart.bar` / `gear`）。切换时调用 `HapticManager.shared.selectionChanged()` 并叠加 `.sensoryFeedback(.selection, trigger:)`。

依赖：`@Environment(\.managedObjectContext) var viewContext`；子视图通过 `@EnvironmentObject AuthManager` 获取登录态。

## 3. 视觉样式 API：`Common/AppVisualStyle.swift`

### 3.1 设计 token（`AppDesignTokens.swift` / `AppMotion.swift`）

新增 UI 必须使用 token，不要写魔法数字：

| Token | 取值 | 用途 |
|-------|------|------|
| `AppSpacing` | `xs=4 / sm=8 / md=12 / lg=16 / xl=20 / xxl=24 / section=32 / screen=20` | 所有 padding 与 `spacing:` |
| `AppRadius` | `control=10 / row=14 / card=16 / sheet=22` | 控件、列表行、卡片、弹层圆角 |
| `AppLayout` | `cardPadding=16`、`cardPaddingCozy=20`、`contentMaxWidth=700`、`formMaxWidth=640`、`listRowMinHeight=44`、`chartHeightCompact/Regular`、`heatmapCell=12`、`privacyBlurRadius=20` | 卡片内边距、iPad 内容宽度、最小行高与图表尺寸 |
| `AppTypography` | `screenTitle` / `sectionTitle` / `body` / `secondary` / `caption` / `tiny` / `amount(_:)` | 语义字体（跟随 Dynamic Type）；金额用 `.appAmountStyle(size:weight:)` |
| `AppMotion` | `quick=0.18s easeOut`、`standard=spring(0.35, 0.85)`、`emphasized=spring(0.5, 0.82)`、`numeric=snappy(0.35)`、`press`、`shimmer`、`ambient` | 全部动画参数 |
| `AppNumberFormat.percent(_:)` | `NumberFormatter`（`.percent`，最多两位小数、去尾零） | 「已用」等百分比展示 |
| 修饰器 | `.appAmountStyle(size:weight:)`、`.appContentWidth(_:)`、`.appCardPadding(cozy:)`、`.appAnimation(_:value:)`、`.appEntrance(index:visible:)`、`.appPressable()` | 统一挂载点 |

`appAnimation` / `appEntrance` 会自动读取 `\.accessibilityReduceMotion`：开启「减弱动态效果」时，标准/强调档降级为 `easeOut(0.15)`，位移类转场通过 `AppMotion.resolvedTransition(_:reduceMotion:)` 退化为纯淡入淡出。

`.appPrivacyShield(_:)`（`AppPrivacyShield.swift`）用于后台隐私保护：`true` 时对整页内容应用 `AppLayout.privacyBlurRadius`（20pt）高斯模糊并叠加 `.regularMaterial` 覆盖层（「降低透明度」开启时提高不透明度），同时 `accessibilityHidden(true)`；切换不加动画，确保进入后台瞬间的快照即为模糊态。是否启用由 `BiometricLockManager.shouldBlurForPrivacy` 决定——**未开启应用锁时完全不生效**。

| API | 签名 | 说明 |
|-----|------|------|
| `AppBackgroundView` | `struct AppBackgroundView: View`（`:5`） | 渐变底 + 3 个漂移光斑，`TimelineView(.animation(minimumInterval: 1/30))` 驱动，`allowsHitTesting(false)` |
| `appGlassCard` | `func appGlassCard(cornerRadius: CGFloat = 22) -> some View`（`:98`） | 毛玻璃卡片（`.ultraThinMaterial` + 描边 + 阴影） |
| `appSoftShadow` | `func appSoftShadow() -> some View`（`:119`） | 统一柔和阴影 |
| `appNumericTransition` | `func appNumericTransition(value: Double) -> some View`（`:124`） | 金额数字滚动动画 |
| `ScaleButtonStyle` | `struct ScaleButtonStyle: ButtonStyle { var pressedScale: CGFloat = 0.96 }`（`:133`） | 按压缩放 |
| `scalePress` | `extension ButtonStyle where Self == ScaleButtonStyle { static var scalePress }`（`:144`） | 便捷写法 `.buttonStyle(.scalePress)` |
| `ShimmerView` | `struct ShimmerView: View`（`:151`） | 骨架/加载微光 |

> macOS 有独立副本 `MaciFinance/Views/Common/AppVisualStyle.swift`（`#if os(macOS)` 分支），改动需两边同步。

## 4. 记账链路（Transaction）

### `NumberPad`（`Views/Transaction/Bills/NumberPad.swift:10`）

> 第五轮变更：备注输入不再内嵌于键盘。`NumberPad` 的备注行是**按钮**（显示「添加备注」或已填内容），点击回调 `onBeginNoteEditing()`；备注输入条由 `AddBillView` 的根级浮层负责（`isNoteEditing` / `keyboardOverlap` / `@FocusState noteFieldFocused`，浮层 `padding(.bottom, keyboardOverlap + 8)`，容器 `.ignoresSafeArea(.keyboard)`）。备注编辑期间数字键盘隐藏。

输入规则由 `NumberPadExpression`（`NumberPadLogic.swift`）实现：

- 数字与小数点只针对**当前数字段**（最后一个运算符之后的部分）校验：小数最多 2 位、整数最多 9 位、重复小数点忽略；
- 运算符按钮首次点击插入主运算符（如 `+`），再点一次切换为备用运算符（如 `×`）；末尾已有其它运算符时替换之；
- 占位 `0.00` 时输入数字直接开始新数字；运算符后直接按小数点补 `0.`；
- 退格删到空回到 `0.00`；`%` 把纯数字除以 100（表达式含运算符时不处理）。
  求值由 `AddBillView.parseExpression(_:)` 完成（对测试可见），支持 `+ - × ÷` 连续运算。

```swift
struct NumberPad: View {
    @Binding var displayText: String            // 金额字符串
    @Binding var currentOperator: String        // 运算符
    @Binding var transactionType: AddBillView.TransactionType
    @Binding var note: String
    @Binding var selectedDate: Date
}
```

内部状态：`isEditingNote`、`showDatePicker`、`keyboardHeight`、`@FocusState isNoteFocused`。数字/运算符输入由 `handleNumberTap(_:)`（`:249`）等私有方法处理；组件为 `NumberButton` / `OperationButton` / `DatePickerView`（`NumberPadComponents.swift:12`/`:52`/`:80`）。

### 其它

| 视图 | 关键参数/依赖 | 说明 |
|------|---------------|------|
| `AddBillView`（`Bills/AddBillView.swift:12`） | `@Environment(\.modelContext)`（iOS 版为 `managedObjectContext`） | 组装 `Bill` 并 `save()`；成功/失败触发 Haptic |
| `EditBillView`（`Bills/EditBillView.swift:11`） | `init(bill: Bill)` | 表单态在 `init` 中由 bill 初始化，保存时写回属性并 `save()` |

**编辑页规则（2026-09 起）**：

- 类型为「支出 / 收入 / 转账」三段；**切换类型会清空分类**（转账固定为 `"transfer"`），未选择分类前保存按钮置灰；
- 分类行是推入式选择页 `CategoryPickerView`（只列当前类型的分类网格，点选后写回 rawValue 并自动返回）；转账账单的分类行只读显示「转账」；
- 打开旧账单时用 `BillEditRules.normalizedCategory(_:for:)` 归一化：跨类型脏数据（如「收入 + 餐饮」）按未选择处理；
- 日期为 `[.date, .hourAndMinute]` 紧凑式选择器（可精确到年月日时分），标签用 `bill.select_datetime`。
| `BillsCardView`（`Bills/BillsCardView.swift:48`） | `@FetchRequest(...billUserPredicate)`、`selectedCategory: Binding<String?>?`、`selectedNote: Binding<String?>?` | `TimeRange`（`:12`）提供本日/本周/本月/本年；筛选在内存完成 |
| `TransactionView`（`TransactionView.swift:11`） | `@State`：`showingAddBillView`、`showProfile`、`showingSearch`、`selectedCategory`、`selectedNote` | 组合预算卡与账单卡；`SearchSheet`（`:145`）维护历史关键词 |
| `BudgetView`（`Budget/BudgetView.swift:13`） | `@FetchRequest` 本月支出、`authManager.monthlyBudget`、`chartAngleSelection` 选中态 | 列表/饼图切换、预算编辑 |
| `BudgetCardView`（`Budget/BudgetCardView.swift:34`） | `@FetchRequest` 本月支出 | 环形进度 + 剩余金额 |

## 5. 趋势链路（Tendency）

`TendencyModels.swift`：

| 类型 | 行 | 说明 |
|------|----|------|
| `DailyAmount` | `:11` | `Identifiable` 数据点（`date` + `value`） |
| `SpanOption` | `:19` | 跨度选项（`Identifiable & Hashable`，含 `days`） |
| `TendencyConstants` | `:35` | 图表配色与尺寸常量（`chartTypePickerWidth` 已随折线图移除） |

`TrendCard`（`TrendCard.swift:10`）参数：`titleKey: LocalizedStringKey`、`accent: Color`、`billType: String`（`"expenditure"`/`"income"`）、`allSeries: [DailyAmount]`、`allBills: [Bill]`、`span`、`selectedDate`、`scrollPosition`（后三者为 `Binding`）。聚合逻辑在卡片内部：`displaySeries`（单日按小时、>31 天按月聚合）、`metricsSeries`、`hourlyTotal(hourStart:for:)`、`windowedSeries`、`aggregateByMonth`。**图表类型切换器已移除，只保留柱状图。**

`CategoryPieCard`（`CategoryPieCard.swift:10`）参数：`titleKey`、`accent`、`kind: CategoryKind`、`billType`、`allBills`、`span`（`Binding`）；内部用 `CategoryBreakdown.slices(bills:type:days:)` 聚合后交给 `CategoryPieView`，切换跨度时通过 `.id(span.days)` 重置扇区选中态。

`CategoryPieView`（`CategoryPieView.swift`）：

| 成员 | 说明 |
|------|------|
| 参数 | `slices: [CategorySlice]`、`accent: Color`、`kind: CategoryKind`、`emptyKey: String` |
| 环形图 | `SectorMark`（innerRadius 0.5、angularInset 1.5、cornerRadius 4）+ `chartAngleSelection` 点选高亮（未选中降为 0.4 透明度）+ 中心显示选中分类与金额 |
| 明细列表 | 颜色点 / 分类名 / 金额 / 占比（`AppNumberFormat.percent`，最多两位小数）+ 底部合计行；无数据时显示 `emptyKey` 文案 |

`TendencyView`（`TendencyView.swift:10`）持有 `@FetchRequest` 的 `allBills`，依次渲染支出趋势卡、支出分类占比卡、收入趋势卡、收入分类占比卡与 `TendencyHeatmapView`（53 周热力图）；两张饼图各自持有独立的 `SpanOption`。

> 分类占比聚合逻辑 `CategoryBreakdown`（`iFinance/Models/CategoryBreakdown.swift`）是纯函数：窗口 = 最近 N 天（含今天），只统计指定 `type`、`category` 非空的账单，按金额降序（同额按 rawValue 升序），转账不计入；单测见 `iFinanceTests/CategoryBreakdownTests`。

## 6. 概况页（Home）

| 类型 | 接口要点 |
|------|----------|
| `HomeView`（`HomeView.swift:20`） | `@FetchRequest` 今日账单（`date` 区间 + `createdBy`）；从 `Bundle` 读取 `EconomicQuotes.json` 解析 `[DailySentence]`；`@State` 维护当前名言与 `quoteOpacity`；「换一句」只更换名言（不再加载图片） |
| `TodayBalanceCard`（`TodayBalanceCard.swift:11`） | 输入今日收入/支出/结余/笔数；主视觉为 40pt 大号结余（`.appAmountStyle` + `.appNumericTransition`），下方三栏统计 |
| `PeriodSummaryCard`（`PeriodSummaryCard.swift:10`） | 参数：`periods: [PeriodSummary]`；每行 = 区间名 + 笔数 / 收入 + 支出 / 结余（盈绿亏损红） |
| `SentenceCardView`（`SentenceCardView.swift:11`） | 参数：`sentence: DailySentence` + 可选回调 `onChangeQuote`（显示右上角「换一句」按钮）；毛玻璃卡样式 |
| `ShareCardView`（`ShareCardView.swift:11`） | 参数：`sentence` + `periods` + 统计值 + `dateText`（**无 backgroundImage**）；`ImageRenderer` 以 375×560 输出分享图 |

**区间数据**（`iFinance/Models/PeriodSummary.swift`）：

| 类型 | 说明 |
|------|------|
| `SummaryPeriod` | `.thisMonth` / `.lastMonth` / `.thisYear`，提供本地化 `titleKey` |
| `PeriodRanges` | 由 `make(calendar:now:)` 生成今日 / 本月 / 上月 / 本年的 `Range<Date>`；`fetchWindow` 覆盖「本年 + 上月」（1 月时含去年 12 月） |
| `PeriodSummary` | 单区间 `income`/`expense`/`count`/`balance` |
| `PeriodSummary.make(bills:ranges:periods:)` | 聚合纯函数；`transfer` 计入笔数但不计入收支 |

`HomeView` 的取数：Core Data 版用「今日 + 窗口」两次 `@FetchRequest`（自定义 `init()` 构造窗口谓词）；SwiftData 版在已按用户过滤的 `@Query` 结果上做内存窗口过滤，两版聚合共用同一套纯函数。
| `ShareSheet`（`ShareSheet.swift:12`） | `UIViewControllerRepresentable` 包装 `UIActivityViewController` |

> 首页原「名言随机风景图 + 三级图片缓存」能力已移除（2026-09）：`ImageLoader` / `ImageCache` / `ImageDownsampler` 三个文件与 `DailySentence.picture2` 字段均已删除，运行时不再发起网络图片请求。

## 7. 设置与个人中心

`SettingView`（`Setting/SettingView.swift:238`）依赖：`@EnvironmentObject AuthManager`、`@Environment(\.managedObjectContext)`、`@AppStorage("selectedTheme")`、`@StateObject BiometricLockManager.shared`。功能入口：主题选择、语言（`navigateToLanguage`）、生物锁开关（`lockToggleValue` + `isTogglingLock`）、个人资料、iCloud（注释保留）、帮助（`HelpFeedbackView:142`）、关于（`AboutAppView:189`）、删除账号确认、CSV 导出/导入（`fileExporter`/`fileImporter`，文档类型 `BillCSVDocument:15`）。

CSV 导出表头 `date,type,category,amount,note`；导入解析见 `parseCSVRows`（`:662`），已知缺陷与 SwiftData 版差异见 [data-and-sync.md](data-and-sync.md) §3。

设置页头部 `SettingsProfileHeaderView`（`Setting/SettingView.swift`）显示「头像 + 昵称 + 个性签名」：未设置签名时显示占位提示「点击设置个性签名」，点击整块头部弹出 `EditSignatureView`；个人中心也提供「个性签名」入口。

`ProfileView`（`Profile/ProfileView.swift:4`）与 `LoginView`（`Auth/LoginView.swift:4`）通过 `AuthManager` 完成注册/登录/改密/头像/个性签名等操作，错误以本地化 key 返回后由视图映射为文案。

## 8. 未覆盖 / 存疑

- 各视图的手势/动画细节未逐条展开；改动画请直接阅读对应文件的 `body`。
- `ShareCardView` 的导出分辨率与不同机型缩放未做像素级核对。
