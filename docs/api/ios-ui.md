# iOS 视图层接口文档

> 覆盖范围：`iFinance/Views/**`。部署目标 iOS 18.0，SDK iOS 27。
> SwiftData 版的视图层是同名文件的改造副本，逐行差异见 [swiftdata.md](swiftdata.md) §4。

## 1. 文件清单

| 文件 | 主要类型 | 职责 |
|------|----------|------|
| `Views/ContentView.swift` | `ContentView` | 四个 Tab 容器（home/transaction/tendency/setting） |
| `Views/Home/HomeView.swift` | `HomeView` | 首页：今日结余 + 每日一句 + 分享 |
| `Views/Home/TodayBalanceCard.swift` | `TodayBalanceCard` | 今日收入/支出/结余/笔数卡片 |
| `Views/Home/SentenceCardView.swift` | `SentenceCardView` | 每日一句卡片（随机风景图） |
| `Views/Home/ShareCardView.swift` | `ShareCardView` | 分享用统计卡片（ImageRenderer 渲染） |
| `Views/Home/ShareSheet.swift` | `ShareSheet` | `UIActivityViewController` 包装 |
| `Views/Home/ImageLoader.swift` | `ImageLoader` | 异步图片加载（Combine，可取消） |
| `Views/Home/ImageCache.swift` | `ImageCache` | 内存 + 磁盘双层缓存 + 请求去重 |
| `Views/Home/ImageDownsampler.swift` | `ImageDownsampler` | 图片降采样 |
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
| `AppLayout` | `cardPadding=16`、`cardPaddingCozy=20`、`contentMaxWidth=700`、`formMaxWidth=640`、`listRowMinHeight=44`、`heroImageMaxHeight=520`、`chartHeightCompact/Regular`、`heatmapCell=12` | 卡片内边距、iPad 内容宽度、最小行高、图片与图表尺寸 |
| `AppTypography` | `screenTitle` / `sectionTitle` / `body` / `secondary` / `caption` / `tiny` / `amount(_:)` | 语义字体（跟随 Dynamic Type）；金额用 `.appAmountStyle(size:weight:)` |
| `AppMotion` | `quick=0.18s easeOut`、`standard=spring(0.35, 0.85)`、`emphasized=spring(0.5, 0.82)`、`numeric=snappy(0.35)`、`press`、`shimmer`、`ambient` | 全部动画参数 |
| 修饰器 | `.appAmountStyle(size:weight:)`、`.appContentWidth(_:)`、`.appCardPadding(cozy:)`、`.appAnimation(_:value:)`、`.appEntrance(index:visible:)`、`.appPressable()` | 统一挂载点 |

`appAnimation` / `appEntrance` 会自动读取 `\.accessibilityReduceMotion`：开启「减弱动态效果」时，标准/强调档降级为 `easeOut(0.15)`，位移类转场通过 `AppMotion.resolvedTransition(_:reduceMotion:)` 退化为纯淡入淡出。

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

## 6. 首页与图片管线（Home）

| 类型 | 接口要点 |
|------|----------|
| `HomeView`（`HomeView.swift:20`） | `@FetchRequest` 今日账单（`date` 区间 + `createdBy`）；从 `Bundle` 读取 `EconomicQuotes.json` 解析 `[DailySentence]`；`@State` 维护当前/预加载下一条名言；渲染并分享统计卡片 |
| `TodayBalanceCard`（`TodayBalanceCard.swift:11`） | 输入今日收入/支出/结余/笔数；金额用 `.contentTransition(.numericText())` |
| `SentenceCardView`（`SentenceCardView.swift:11`） | 参数：`sentence: DailySentence`；图片经 `ImageLoader` 加载 |
| `ShareCardView`（`ShareCardView.swift:11`） | 参数：`sentence: DailySentence` + 统计值；`ImageRenderer` 输出分享图 |
| `ShareSheet`（`ShareSheet.swift:12`） | `UIViewControllerRepresentable` 包装 `UIActivityViewController` |

图片三级管线：

| 组件 | 接口 | 说明 |
|------|------|------|
| `ImageCache`（`ImageCache.swift:11`） | `get(_:)` / `set(_:for:)` / `getFromDisk(_:)` / `saveToDisk(_:for:)` / `setInflightTask(_:forKey:)` / `getInflightTask(forKey:)` / `removeInflightTask(forKey:)` | 内存 `NSCache` + 磁盘目录（`diskURL(for:)`），过期清理 `cleanupExpiredDiskCache()`；`inflightTasks` 做请求去重 |
| `ImageLoader`（`ImageLoader.swift:13`） | `@Published image: UIImage?` / `isLoaded`；`load(url:targetSize:)`（默认 400×560）、`preload(url:) async`、`performDownload(url:key:)` | Combine 驱动，支持取消与降采样 |
| `ImageDownsampler`（`ImageDownsampler.swift:11`） | `static func downsample(_ imageData: Data, to maxSize: CGSize) -> UIImage?` | 降低内存占用 |

## 7. 设置与个人中心

`SettingView`（`Setting/SettingView.swift:238`）依赖：`@EnvironmentObject AuthManager`、`@Environment(\.managedObjectContext)`、`@AppStorage("selectedTheme")`、`@StateObject BiometricLockManager.shared`。功能入口：主题选择、语言（`navigateToLanguage`）、生物锁开关（`lockToggleValue` + `isTogglingLock`）、个人资料、iCloud（注释保留）、帮助（`HelpFeedbackView:142`）、关于（`AboutAppView:189`）、删除账号确认、CSV 导出/导入（`fileExporter`/`fileImporter`，文档类型 `BillCSVDocument:15`）。

CSV 导出表头 `date,type,category,amount,note`；导入解析见 `parseCSVRows`（`:662`），已知缺陷与 SwiftData 版差异见 [data-and-sync.md](data-and-sync.md) §3。

`ProfileView`（`Profile/ProfileView.swift:4`）与 `LoginView`（`Auth/LoginView.swift:4`）通过 `AuthManager` 完成注册/登录/改密/头像等操作，错误以本地化 key 返回后由视图映射为文案。

## 8. 未覆盖 / 存疑

- 各视图的手势/动画细节未逐条展开；改动画请直接阅读对应文件的 `body`。
- `ShareCardView` 的导出分辨率与不同机型缩放未做像素级核对。
- 首页名言图片来自 `picsum.photos`，离线环境下会走缓存或降级占位图。
