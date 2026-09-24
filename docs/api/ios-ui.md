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
| `Views/Transaction/Bills/EditBillView.swift` | `EditBillView` | 编辑 / 删除账单 |
| `Views/Transaction/Bills/BillsCardView.swift` | `TimeRange`、`BillsCardView` | 账单列表：时间范围 / 分类 / 备注筛选 |
| `Views/Transaction/Bills/NumberPad.swift` | `NumberPad` | 自定义数字键盘主体（含备注、日期） |
| `Views/Transaction/Bills/NumberPadComponents.swift` | `NumberButton`、`OperationButton`、`DatePickerView` | 键盘组件 |
| `Views/Transaction/Bills/{Expenditure,Income}CategoryItemView.swift` | 分类按钮 | 分类选择项 |
| `Views/Transaction/Budget/BudgetView.swift` | `BudgetView`、`CategoryRowView` | 预算页：环形进度 + 分类列表/饼图 |
| `Views/Transaction/Budget/BudgetCardView.swift` | `BudgetCardView` | 预算卡片（本月支出聚合） |
| `Views/Tendency/TendencyView.swift` | `TendencyView` | 趋势页：支出/收入卡片 + 热力图 |
| `Views/Tendency/TrendCard.swift` | `TrendCard` | 可复用趋势卡片（5 档跨度 + 图表切换） |
| `Views/Tendency/TendencyChartView.swift` | `TendencyChartView` | 折线/柱状图（Swift Charts） |
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
| `ChartDisplayType` | `:35` | `.line` / `.bar` 等图表类型 |
| `TendencyConstants` | `:49` | 图表配色与尺寸常量 |

`TrendCard`（`TrendCard.swift:10`）参数：`titleKey: LocalizedStringKey`、`accent: Color`、`billType: String`（`"expenditure"`/`"income"`）、`allSeries: [DailyAmount]`、`allBills: [Bill]`、`span`、`chartType`、`selectedDate`、`scrollPosition`（后四者为 `Binding`）。聚合逻辑在卡片内部：`displaySeries`（单日按小时、>31 天按月聚合）、`metricsSeries`、`hourlyTotal(hourStart:for:)`（`:166`）、`windowedSeries`、`aggregateByMonth`。

`TendencyView`（`TendencyView.swift:10`）持有 `@FetchRequest` 的 `allBills` 并把 `Array(allBills)` 传给两张 `TrendCard`；`TendencyHeatmapView`（`:11`）渲染 53 周热力图与月份标签。

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
