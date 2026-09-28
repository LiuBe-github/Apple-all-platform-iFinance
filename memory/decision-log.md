# 决策记录（本次协作）

> 记录范围：2026-09-23 ~ 2026-09-26 期间与用户逐条确认的产品/技术取舍。
> 阅读方式：改动相关模块前先扫一遍，避免推翻已有共识；每条都写了「为什么」与「影响文件」。

## A. 版本与工程结构

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-01 | 三端统一支持 **2024 代 → 27**：iOS 18.0 / macOS 15.0 / watchOS 11.0 起，上限各 27.x | 用户要「全平台适配 18.0 到 27.0」；原部署目标是 iOS 17.6 / macOS 26.2 / watchOS 26.0 | `project.pbxproj` 全部 target |
| D-02 | iOS 最低版本由 17.6 **提高到 18.0**（放弃 iOS 17） | 与「18.0 起」的诉求一致，且免去为 iOS 17 写降级分支；已与用户二次确认 | iOS 两个 target + 测试 target |
| D-03 | 验收标准定为「**编译 + 可运行验证**」，而非仅编译 | 用户希望确认真的能跑 | 冒烟流程：iOS 18.x / watchOS 26.x 模拟器 + 本机 macOS 27 |
| D-04 | SwiftData 版做成**同工程独立 target**（`iFinanceSwiftData`，Bundle ID `cn.liube.iFinance.swiftdata`，显示名「iFinance SD」） | 可与主版本共存安装、便于对照；避免侵入现有 iOS 代码 | 新增 target + scheme + `iFinanceSwiftDataTests` |
| D-05 | SwiftData 版**复制视图层**而非抽协议共享 | 视图深度依赖 Core Data（`@FetchRequest` / `NSFetchRequest`）；抽协议会大改主版本 | 两版视图为同名副本，改动需同步（见 [working-agreements.md](working-agreements.md)） |
| D-06 | SwiftData 版**不迁移** Core Data 历史数据、不含 Watch / CloudKit / 通知 | 「单独做一版」的定位；数据从空库开始 | `iFinanceSwiftData/Data/` |
| D-07 | 共享 iOS 的四语言 `.lproj` 与 `EconomicQuotes.json`（target membership 引用，不复制） | 避免两份文案漂移；改 iOS 文案同时影响两版 | 工程资源引用 |
| D-08 | 先建 `codex/platform-18-27` 分支并**把用户既有未提交改动提交为基线** | 便于分阶段回滚与 review（用户明确选择） | commit `37b2b39` |
| D-09 | 提交粒度：分阶段提交；本次全部改动**不推送远端** | 用户在 Codex 里自行 review 后决定 | 分支上 20 次提交 |

## B. 视觉、动画与设计系统

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-10 | 动画**统一节奏**而非逐处调参：抽 `AppMotion`（quick/standard/emphasized/numeric），并支持「减弱动态效果」降级 | 原先 30+ 处 spring 参数各写各的 | `Views/Common/AppMotion.swift` |
| D-11 | 布局按 **HIG 重定尺度**（允许可见观感变化），抽 `AppSpacing` / `AppRadius` / `AppLayout` | 用户选择「按 HIG 重定尺度」而非保持现状 | `AppDesignTokens.swift`；padding/spacing/圆角全量收敛 |
| D-12 | 标题/正文改用**语义字体**（跟随 Dynamic Type），大号金额保留字号 + 自适应缩放 | 兼顾可读性与不撑破卡片 | `AppTypography` + `.appAmountStyle` |
| D-13 | iPad 主内容统一用 `.appContentWidth()` 收敛（700 / 表单 640） | 避免大屏被拉满 | 各主滚动页 |

## C. 概况页（首页）重构

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-14 | **彻底移除图片能力**：删 `ImageLoader` / `ImageCache` / `ImageDownsampler`、`DailySentence.picture2`、JSON 中的 100 条图片地址 | 用户要「去掉图片功能，只留下一言」，并选择连数据一起清 | 两版共 6 个文件删除 + JSON 清理 |
| D-15 | 页面标题改为「概况 / 概況 / Overview / 概要」，**底部 Tab 名不变**（首页 / Home / ホーム） | 用户明确只改页面标题 | `home.title` |
| D-16 | 今日概况升级为**主视觉大卡**（日期 + 40pt 大号结余 + 收支笔数三栏），并为它增加**周期概况卡**（本月 / 上月 / 本年三行） | 用户反馈「概况卡内容太少」 | `TodayBalanceCard`、`PeriodSummaryCard`、`PeriodSummary` / `PeriodRanges` |
| D-17 | 每日一言**独立成卡**（毛玻璃 + 右上角「换一句」），页面底部只留分享按钮 | 用户认为纯文字小字「太丑」 | `SentenceCardView`、`HomeView` |
| D-18 | 今日结余**只显示数字**，去掉「结余 / 超支」文字标签 | 用户要求「不需要文字描述」 | `TodayBalanceCard` |
| D-19 | 分享卡片与页面一致：日期 + 今日结余 + 三栏统计 + 本月/上月/本年摘要 + 一言（375×560） | 用户选择「与页面一致」 | `ShareCardView` |
| D-20 | 名言数据保留在本地 JSON（100 条），**不做任何网络请求** | 去图后无网络依赖，离线可用 | `EconomicQuotes.json` |

## D. 隐私与安全

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-21 | 进后台对整页做**高斯模糊**，**仅在用户开启应用锁时生效** | 用户明确的条件；防止多任务快照泄露 | `BiometricLockManager.activatePrivacyShield()` + `.appPrivacyShield(_:)` |
| D-22 | 遮罩：20pt 模糊 + `.regularMaterial` 覆盖，切换不加动画（保证快照立即是模糊态），并对 VoiceOver 隐藏内容 | 隐私优先 | `Views/Common/AppPrivacyShield.swift` |
| D-23 | 隐私遮罩**只作用于 iOS 两版**，macOS 无此概念 | 平台差异 | — |

## E. 国际化

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-24 | 语言切换时同步写入 `UserDefaults["AppleLanguages"]` 并重启；启动时幂等兜底 | 让 `String(localized:)`、`NSLocalizedString` 与**系统控件**（分享面板 / Face ID 提示）也跟随 App 内语言 | `LocalizationSync` |
| D-25 | 把 268 处 `String(localized:)` / `NSLocalizedString` **统一替换为 `L10n.string`** | 前者走系统语言、切换后不跟随，是"切换语言后部分文字没变"的根因 | iOS 两版 + macOS |
| D-26 | 补齐 15 个只有简体中文的 `auth.*` 错误文案（英/日/繁），清理 6 个无引用 key | 非简体语言下会直接显示原始 key | 四语言包 × 2 端 |
| D-27 | 新增 `scripts/check_localization.py` 与「四语言 key 集合一致」单测 | 防止再次漏翻译 | 脚本 + 测试 |

## F. 性能与体验

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-28 | 背景动画抽成**全局共享时钟** `AppBackgroundClock`：10fps、非活跃暂停、Reduce Motion 静态，光斑用 `RadialGradient` 代替 `blur(36)` | 原先 12 处页面各自跑 30fps TimelineView，是「切页面卡顿」的主因 | `Views/Common/AppBackgroundClock.swift`、`AppVisualStyle.swift` |
| D-29 | 头像解码走 `AvatarImageCache`；Formatter 一律 `static let`；`AddBillView` 分类网格拆成 `Equatable` 子视图；`TrendCard` 每帧只算一次序列 | 针对「切页面 / 开键盘卡顿」的定点优化 | 多个视图文件 |
| D-30 | 开屏动画为**品牌版 1.8s**（渐变底 + 呼吸光晕 + 标题 + 加载指示），**仅冷启动**，Reduce Motion 降级 0.8s | 用户选择；开屏期间数据照常加载 | `Views/Common/AppSplashView.swift` |
| D-31 | 头像裁剪：**圆形遮罩 + 拖动/双指缩放**，确认后输出 300×300 JPEG | 用户选择；修复「选完直接存、无法调整取景」 | `Views/Profile/AvatarCropView.swift` |
| D-32 | 百分比统一格式：**最多两位小数、去尾零**（`43%` / `43.2%` / `43.25%`） | 用户明确选择；后续饼图、预算页「已用」都遵循 | `AppNumberFormat.percent(_:)` |
| D-33 | 关闭 `SWIFT_EMIT_LOC_STRINGS` 与 `STRING_CATALOG_GENERATE_SYMBOLS`（项目用手写 .strings） | 白跑一遍编译期字符串提取；全量构建 25.1s→23.9s | `project.pbxproj` |
| D-34 | 新增 `scripts/run-on-device.sh`：构建 → `devicectl` 安装 → 启动，跳过 Watch 部署与调试器附加 | 真机慢在部署阶段（配对手表会推送 Watch App），构建本身仅 3–6s | `scripts/run-on-device.sh` |

## G. 功能交互修正

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-35 | 账单行改为**备注为主、分类·时间为次**（无备注回退分类） | 用户要求；iOS 两版 + macOS 同步 | `TransactionRowView`、`MaciFinance/BillListView` |
| D-36 | 设置页头像旁第一行显示**昵称**（替换固定 "iFinance"），副标题保留应用说明 | 用户选择「只换昵称」 | `SettingsProfileHeaderView` |
| D-37 | 新增**个性签名**：`UserProfile.signature`（三份模型同步），设置页头部显示且可点编辑，个人中心也有入口，上限 40 字 | 用户要求把描述换成自定义签名 | `AuthManager.updateSignature`、`EditSignatureView` |
| D-38 | 记账键盘修复：**校验只针对「当前数字段」**；运算符首次点击为主运算符、再点切换备用 | 「运算符后无法继续输入数字」的根因是拿整串表达式判断小数位 | `NumberPadLogic.swift`（`NumberPadExpression`） |
| D-39 | 趋势页新增**支出/收入分类占比饼图**（各自独立跨度、完整分类列表、点选高亮），并**删除折线图** | 用户认为折线与柱状区分度低；饼图看分类占比 | `CategoryBreakdown` / `CategoryPieView` / `CategoryPieCard` |
| D-40 | 预算页饼图改为复用同一 `CategoryPieView`，占比同时统一为最多两位小数 | 消除重复实现、格式一致 | `BudgetView`、`CategoryPalette` |
| D-41 | 编辑账单页：分类改为**推入式选择页**（只列当前类型分类）、类型切换清空分类并要求重选、类型补「转账」、日期精确到**年月日时分** | 修复「收入分类带餐饮图标」的非法组合 | `BillEditRules`、`CategoryPickerView`、`EditBillView` |
| D-42 | 微信二维码替换为 `~/Downloads/IMG_5894.jpg`，并改成单文件通用资源（原为三份重复） | 用户提供新图；顺带把 445KB 降到 164KB | `MyWeChat.imageset` |

## H. 文档与流程

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-43 | 建立「项目记忆 + 接口文档 + PRD」三层文档体系，并在每次改动后同步 | 用户在第一轮就要求生成记忆与接口文档；后续每次功能改动都同步 | `AGENTS.md`、`docs/`、本 `memory/` |
| D-44 | 文档状态必须真实：已实现 ✅ / 部分实现 🚧 / 禁用未实现 💤 | 避免把"占位实现"写成"已支持" | [docs/PRD.md](../docs/PRD.md) |
| D-45 | 本次建立 `memory/` 文件夹，沉淀会话级决策与待办 | 用户要求「根据历史对话生成记忆文件夹」 | 本文件夹 |

## I. 占位登录降级与 CSV 导入修复（2026-09-26 第二轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-46 | 微信/QQ 登录降级为**双层防护**：视图点击仅显示「即将支持」（复用内联 `errorMessage`），`AuthManager.loginWithProvider` 入口 `guard provider == .apple` 拒绝建号 | 占位实现每次点击都新建账号（🔴 隐患）；视图提示保留入口外观，guard 防未来/遗留调用点静默建号 | 三端 `LoginView` + 三份 `AuthManager`；新增 key `auth.coming_soon`（不复用 `auth.apple_frontend_only`／`bill.transfer_todo`，语义与命名空间不符） |
| D-47 | CSV 导入逻辑抽为 `iFinance/Helper/CSVImporter.swift` 纯函数（`parseRows` + `makeBill`），换取单元测试覆盖 | `parseCSVRows` 原是 `SettingView` 私有方法无法触达；「导入数据因缺 `createdBy` 而不可见」是真实回归点，必须钉住 | 新增 `CSVImporterTests`（4 用例）；`SettingView.importCSV` 改为调用；SwiftData 版已修不动 |
| D-48 | **备案（本轮不实施）**：OI-05 Watch 离线补传倾向直接依赖 `transferUserInfo` 系统队列（去掉 `isReachable` guard），放弃自建 pending 队列 | `transferUserInfo` 本身是系统级可靠排队（iPhone 暂不可达也保证送达），现有 guard 属过度保守；iPhone 端已按 id 幂等去重，重发安全 | 实施时改 `WatchDataModel.sendBill` / `requestSync` 并同步 `docs/api/data-and-sync.md` §2.3/§2.6 |

## 被否决或搁置的方案

| 曾被考虑的方案 | 为何没采用 |
|----------------|-----------|
| SwiftData 版抽 Repository 协议、与主版本共享视图 | 会大幅改动现有 iOS 代码（`@FetchRequest` 深度耦合），风险高于收益（D-05） |
| 版本适配只降到 iOS 18、macOS/watchOS 保持现状 | 用户要的是「全平台」下探到 2024 代（D-01） |
| 保留折线图作为可切换图表类型 | 用户判断与柱状图区分度低（D-39） |
| 用系统 `List`/`Form` 重构全站卡片以更贴 HIG | 属"大改"，用户明确只要 token 统一 + 组件校准（D-11） |
| SwiftData 版共享主版本的开机语言同步 | 两版各自独立进程与 Bundle ID，分别调用 `LocalizationSync` 即可 |

## J. 交接后第一轮修复（2026-09-26 第三轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-49 | CSV 解析的换行判断改为同时覆盖 `\n` / `\r\n` / `\r`（两版同步） | 接手复核时跑出 `CSVImporterTests.testParseRowsHandlesQuotesEscapesAndCRLF` 失败：Swift 中 `"\r\n"` 是**一个** Character，原判断 `ch == "\n"` 命中不了，Windows/Excel 导出的 CSV 会被解析成单行、整份导入失败（旧实现同样有坑，抽 `CSVImporter` 时被测试钉出） | `iFinance/Helper/CSVImporter.swift`、`iFinanceSwiftData/Views/Setting/SettingView.swift`；新增 LF-only 回归用例；AGENTS 坑表「文本解析换行」 |
| D-50 | 本轮验证强度按用户指示收窄：**不强制跑全套单测**，"基本功能能用即可" | 用户 2026-09-26 明确指示「这个别测试了吧，基本功能能用就行」；仍有四端编译 + 本地化审计 + 启动冒烟兜底，CSV 解析用本地脚本验证三种换行 | 验证记录口径见 [work-history.md](work-history.md) 第 22 行；后续大改动仍建议跑齐三套测试 |

## K. 分类体系扩展与性能专项（2026-09-26 第四轮，三批次交付）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-51 | 图标体系**只用 SF Symbols 精选**（不引入图片资源）：内置分类重排为互不重复的图标，并用单测钉住「同类型内不重复 + 符号真实存在」 | 原实现数码/通讯共用 `phone`、交通/汽车共用 `car`；用户要求「先看官方图标库能否满足」——逐个核对系统符号库后确认够用 | `ExpenditureCategory` / `IncomeCategory` 图标映射、`iFinanceTests/CategoryIconTests.swift`（两版各一份） |
| D-52 | 自定义分类存**本机 UserDefaults JSON（按账号隔离）**，账单 `category` 继续存字符串；二级分类用「父/子」复合路径 | 三份数据模型（iOS Core Data ×2 + SwiftData）改动成本与迁移风险高；`Bill.category` 已是字符串，复合路径可被现有 CSV、Watch 透传兼容 | `Views/Common/CategoryStore.swift`（两版副本）；不做模型迁移 |
| D-53 | 二级分类**可选**（默认记到父分类），统计与饼图**按一级聚合**；内置「交通」预置 7 个子分类且可编辑 | 用户选择「可选：默认到父分类」「按父分类聚合」「预置 + 可编辑」 | `CategoryResolver`（`parentRaw`）、`CategoryBreakdown`、`BudgetView`、`CategoryGridView` 子分类 chips |
| D-54 | 自定义分类**改名同步历史账单**、**删除保留历史账单**（只从选择器移除；旧名以纯文本 + 灰图标展示） | 用户选择「可改名/删除，历史账单保留」；因账单按名字存储，改名若不回填会出现新旧两个名字 | `CategoryStore.storedPath`、`CategoryManagementView.renameBills`（两版各自实现） |
| D-55 | 入口分工：**记账页 sheet 快速新建**（名称/图标/主题色/二级分类）+ **设置页「分类管理」**（改名/换图标/换色/删除/二级分类增删改） | 用户选择「记账页新建 + 设置页管理」 | `CustomCategorySheet`、`CategoryManagementView`、`SettingView` 入口 |
| D-56 | 趋势页新增「总收支」**双向双柱**（收入向上绿、支出向下红），跨度仅月 / 6 个月 / 年，转账不计入；点选显示收入/支出/净额 | 用户在问答中选择「双向双柱（收入/支出分开）」「月/6 个月/年三档」 | `NetTrendCard`、`NetTrendBuilder`、`TendencyView` 置顶卡片 |
| D-57 | 趋势页取数窗口定为**最近 24 个月**（计划里写的是约 13 个月，实施时放宽） | 13 个月虽覆盖年视图，但会让「总收支」月度序列与横向回看缺数据；24 个月兼顾性能与回看体验 | `TendencyView` 的 Core Data 谓词 / SwiftData `@Query` |
| D-58 | 真机提速提供 **Release 运行通道**（`scripts/run-on-device.sh --release`），Debug 配置保持 `-Onone` 不动 | 用户选择「另加优化运行通道」：调试体验与真机流畅度兼得 | `scripts/run-on-device.sh`；文档见 `AGENTS.md` / `docs/PROJECT_MEMORY.md` |

## L. 备注浮层 / 图表方向 / 配色统一（2026-09-26 第五轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-59 | 备注输入条改为**根级浮层 + 键盘高度单一来源定位**：`AddBillView` 持有 `isNoteEditing` / `keyboardOverlap` / `@FocusState`，浮层 `padding(.bottom, keyboardOverlap + 8)`；页面与浮层都 `.ignoresSafeArea(.keyboard)`；`NumberPad` 不再内嵌输入框与键盘位移 | 上一版同时使用「系统键盘避让」与「手动 `offset(y: -keyboardLift)`」，两次位移叠加把输入条顶到离键盘很远处（用户反馈"间隔很大、看不见"）。单一来源才能可预测 | `AddBillView`（两版）、`NumberPad`（备注行改为按钮 + `onBeginNoteEditing`）、`NetTrendTests` 无关 |
| D-60 | 总收支图**支出柱画负值**（`NetTrendPoint.expenseBarValue = -expense`），Y 轴刻度显示绝对值；`NetTrendBuilder` 的数据语义保持正值不变 | 用户要求「以 0 为界，支出向下、收入向上」；把渲染方向收在模型的一个计算属性里，既能单测又不影响既有聚合测试 | `Views/Tendency/NetTrendCard.swift`（两版）、`NetTrendTests`（两版） |
| D-61 | 分类**身份色**统一：支出红 `(1.0, 0.27, 0.23)`、收入绿 `(0.18, 0.78, 0.44)`（含自定义与二级分类）；**删除主题色选择**；**饼图与预算页明细保留 8 色调色板** | 用户要求「不做复杂颜色系统，支出红、收入绿」；但饼图若同色则无法区分扇区，用户选择保留现有彩色调色板 | `CategoryResolver.color` → `CategoryKind.accentColor`；新增 `CategoryPalette.chartColor`（仅饼图/明细用）；`CustomCategorySheet` 去掉颜色段；`CategoryStore.colorHex` 保留字段但不再读写 |

## M. 分类数据冷启动修复（2026-09-26 第六轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-62 | `CategoryStore` 拆分「读取路径」与「发布路径」：新增 `currentItems`（首次访问同步从磁盘载入 + 播种，**不发布变更**，可在渲染期调用）与 `ensureLoaded(force:)`；`reload()` 只做「载入 + 补发布」；新增 `resetInMemoryCacheForTesting()` 模拟冷启动 | 用户反馈「重启后二级分类在账单页变成问号」：分类定义存 UserDefaults，但只有记账页/分类管理页会 `reload()`，账单列表重启后首个渲染时内存为空 → `CategoryResolver.isValid("交通/地铁")` 失败 → 未知分类兜底为问号。若直接在渲染期 publish `items` 又会触发 SwiftUI 的 "Publishing changes from within view updates" 隐患，因此把读取与发布分离 | `CategoryStore`（两版副本）、`CategoryStoreTests` 新增冷启动回归用例（两版） |

## N. 趋势图 scrub 改造（2026-09-27 第七轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-63 | 单系列柱状图与双向柱状图统一改为 **Apple Health 式 scrub**：选择用原生 `chartXSelection(value:)`；指示线与浮层由 `chartOverlay` + `ScrubCallout` 绘制（只做透明度变化，`AppMotion.quick` = 0.18s 淡出）；触觉由 `ScrubSelection.shouldTick` 门控（跨数据点才 tick）；删除 `DragMode` 状态机、`touchDetectionRadius` 与柱状图淡化逻辑 | 用户给出 Health 实测契约（≤100ms 出现、吸附、跨点 tick、松手淡出、不打断页面滚动/返回手势）。原生选择手势本身就是为可滚动容器设计；自研手势会与页面 ScrollView / 返回手势争抢触摸 | `TendencyChartView`、`NetTrendCard`、新增 `ScrubSupport.swift`（两版逐字节相同副本）；`TrendCard` 传入完整数据范围 `scrollBounds`；新增 a11y 文案 8 条 |
| D-64 | 契约 4（贴边继续拖动自动滚动）用「**选中项贴住窗口边缘 + Task 每 200ms 步进一档窗口**」近似，不支持 `chartScrollableAxes`/`chartScrollPosition` 原生滚动 | 原生 `chartXSelection` 只回传吸附后的 x 值，不暴露连续拖动增量；若为取增量再叠一个自研 `DragGesture`，会破坏契约 5（不打断页面滚动与返回手势）。因此保留当前「窗口由 `scrollPosition` 驱动 + 固定 domain」的模型，用贴边判定 + 定时步进逼近 Health 的贴边滚动 | 同上；已在 PRD TDY-07 与 open-items OI-45 标注为「近似实现，待真机手感确认」 |

## O. 图表对齐 Apple 规范 R1–R22（2026-09-27 第八轮）

| 编号 | 决策 | 理由 / 约束 | 影响 |
|------|------|-------------|------|
| D-65 | 轴与刻度统一走新 `ChartAxisSupport`：柱状图下界 0、上界随数据、目标 4 条整齐步长（1/2/2.5/5×10ⁿ）、≥1 万时中文/日文用「万」英文用「k」；双向图两侧共用步长且 0 必为刻度 | R2/R3/R4/R6。原先依赖 Swift Charts 自动刻度，可能出现 1/6/11 这类不整齐序列；把规则固化成纯函数才能单测 | 新增 `Views/Common/ChartAxisSupport.swift`；`TendencyChartView` / `NetTrendCard` 改用 `yAxisModel` + `chartYScale(domain:)` + 显式 `AxisMarks(values:)` |
| D-66 | 配色重排为 `ChartSeriesStyle`：保留原 8 色色相、把明度收进同一带（浅色 L≈0.20、深色 L≈0.44），语义命名（支出红 / 收入绿 / series1…8 / unknown），深浅各一套；热力图另做 `HeatmapRamp` 四套（深浅 × 普通 / 提高对比度） | R16：原调色板明度差大（`#FFCC19` vs `#5666FF`）、深色模式沿用浅色色阶导致高等级对比度不足。用 RGB 元组定义才能直接单测对比度与亮度单调 | 新增 `ChartSeriesStyle.swift` / `HeatmapRamp.swift`；`CategoryPalette` 增加 `scheme` 参数（签名保持向后兼容）；饼图 / 预算明细 / 账单行 / 键盘 / 管理页统一取语义色 |
| D-67 | 「不以颜色为唯一区分手段」只跟随系统 `accessibilityDifferentiateWithoutColor`：开启时总收支柱顶叠加圆 / 方符号、饼图明细色点按索引循环形状；颜色语义需文字说明（本 App 红＝支出、绿＝收入，与「红涨绿跌」相反） | R14/R17。用户明确选择「跟随系统设置」而非 App 内开关；图例本来就有文字（收入 / 支出），形状是第二通道 | `ChartLegendShape` / `ChartSeriesStyle.markerSymbolName`；`NetTrendCard` 柱顶 `PointMark` 符号；`CategoryPieView.legendMark`；PRD TDY-08 写明文化前提 |
| D-68 | 标题下新增结论副标题（`ChartSummary`），只用**现有区间数值**（合计 / 日均 / 净额）；图表 `AXChartDescriptor` 走 `ChartDescriptorRepresentable` 包装，轴刻度一律 `.accessibilityHidden(true)`，逐点标签统一「上下文在前、数值在后」 | R7/R18/R19 + 用户确认「副标题只用现有数值，不新增统计口径」；`AXChartDescriptor` 本身不符合 `AXChartDescriptorRepresentable`，必须包装；不隐藏轴刻度会被 VoiceOver 重复朗读 | 新增 `ChartSummary.swift` / `ChartAccessibility.swift`；两个柱状图 + 饼图 + 热力图各加描述符；新增 14 条四语言文案 |
| D-69 | 热力图维持自绘 53×7 网格与横向滚动，把「12pt 单格点选」改为整块网格 `SpatialTapGesture` 吸附最近格（选中态改描边 + 圆点，去掉 `scaleEffect`）；macOS 统计页本轮不动（R14/R20 记未达成） | 用户选择方案 A；拖动被横向滚动占用，按住扫读会与滚动争抢；macOS 不在本轮范围（用户明确「不动 macOS」） | `TendencyHeatmapView` 整格命中 + `HeatmapRamp` + 描述符；重复的 `heatmapCellSize` token 合并到 `AppLayout.heatmapCell`；open-items 新增 OI-46 / OI-47 |

| D-70 | **配色回退**：撤掉 D-66 的明度均衡，`ChartSeriesStyle` 与 `HeatmapRamp` 的默认取值恢复为改版前的原始配色（8 色原值、支出红 / 收入绿原值、热力四级蓝色原值），深浅模式共用同一组原色；热力图仅保留「提高对比度」变体（只在系统开关开启时生效）；R16 的「明度均衡 / 对比度 ≥3:1」目标标记为**未采用（用户取舍）** | 用户反馈「更改后颜色变暗了不好看，我要原来的颜色」。原方案虽满足对比度阈值，但整体观感偏暗；本项目以用户观感优先，可辨识性由形状 / 符号 + 文字图例承担（R14） | `ChartSeriesStyle`（`seriesLight == seriesDark`、`expenseLight/incomeLight` 回原值）、`HeatmapRamp`（`dark = light`）；测试由「对比度阈值」改为「锁定原始颜色取值」，避免后续再被顺手改暗；open-items 新增 OI-48 |

## P. 待办与备忘 + 资产（2026-09-26 第九轮）

| 编号 | 决策 | 理由 | 落地 |
|------|------|------|------|
| D-71 | **标签栏仍是 5 项**：新增「待办」为第 3 个 Tab（首页 / 账本 / 待办 / 趋势 / 设置）；**资产不占 Tab 位**，改为账本页右上角（头像左侧）推入的二级页面 | HIG 建议底部标签不超过 5 项；资产是「偶尔查看」的页面，而待办是需要频繁勾选的日常动作，所以把有限的标签位给待办 | `ContentView` 的 `Tab` 枚举 + `TodoTabView`；`TransactionView.topBarTrailing` 新增资产按钮 + `navigationDestination` |
| D-72 | 新增 6 个持久化实体，**三份模型契约同步**（iOS / macOS 两份 `.xcdatamodeld` + SwiftData 三处）；小整数一律 `Integer 16` ↔ `Int16` | Core Data 代码生成对整数只产出 `Int16/Int32/Int64`，永远拿不到 Swift 惯用的 `Int`；若纯逻辑用 `Int`，两版视图与单测会处处要转换。统一成 `Int16` 后「实体 / 纯逻辑 / SwiftData 实体」三方类型完全一致 | `iFinance/Models/TodoModels.swift`、`AssetBreakdown.swift`（两版副本逐字节一致）；`.xcdatamodeld` 新增实体；SwiftData `TodoEntities.swift` / `AssetEntities.swift` |
| D-73 | SwiftData 版删除待办/标签走**对象图删除**（`fetch` + 逐个 `context.delete`），不用 `delete(model:where:)` 批量删除；其余 4 类无关系实体仍用批量删除 | `TodoItem.tags` / `TodoTag.items` 是非可选多对多，批量删除会抛 `Constraint trigger violation: Batch delete failed due to mandatory MTM nullify inverse`（`NSCocoaErrorDomain` 134050）；若用 `try?` 包裹会被静默吞掉、数据删不掉（已由单测抓出）。对象图删除才能触发级联（子任务）与关系清理 | `iFinanceSwiftData/Manager/AuthManager.swift:deleteTodoAndAssetData`；回归用例 `TodoAssetIsolationTests.deleteTodoAndAssetDataClearsOnlyTargetAccount` |
| D-74 | 资产快照口径：**每个自然日一条，同日覆盖写**；账户新增 / 编辑 / 删除保存后按当天 upsert（`date` 取当天 00:00，`createdBy` 必填） | 快照用于「较上次变化」，粒度太细（每次改动一条）会让差值失去意义；只有一条记录时显示「首次记录」而不是假的变化值 | `AssetBreakdown.upsertIndex(for:in:calendar:)`；`AssetView.persistSnapshot()`；单测 `AssetBreakdownTests.testUpsertIndexMatchesSameDay` |
| D-75 | 重复待办**必须先设截止日**才会在完成时生成下一期（`TodoRecurrence.nextDraft` 在无 `dueDate` 时返回 nil） | 重复规则本质是「按截止日推进一档」；没有锚点日期时生成的新条目仍然没有日期，只会产生无意义的副本链 | `TodoRecurrence`（两版副本）；PRD TODO-04 写明该前提 |
| D-76 | 测试夹具必须用**局部常量持有 `PersistenceController`**，禁止写成 `PersistenceController(inMemory: true).container.mainContext` 这种临时实例链 | 临时实例被释放后容器随之销毁，随后的 `insert`/`save` 会直接触发 SwiftData 内部断言（SIGTRAP，崩溃点还会飘到别的测试上，极难定位）。已用对照用例（持有 = 通过 / 不持有 = 崩溃）确认 | `iFinanceSwiftDataTests/TodoAssetTests.swift` 的 `TodoAssetTestHarness`；同类写法在 `SwiftDataCoreTests.SwiftDataTestContext` 早已正确 |

## Q. 待办/备忘体验与账单刷新（2026-09-28 第十轮）

| 编号 | 决策 | 理由 | 落地 |
|------|------|------|------|
| D-77 | 子任务改为**列表内原地展开勾选**（父行显示 `chevron + checklist 2/5`，展开区单独热区），勾选子任务**不联动**父待办完成状态 | 用户反馈「子任务要点进编辑页才能完成」太低效。不联动是为了避免「误勾一个子任务就整条待办被判定完成」——父待办仍由左侧圆圈显式控制 | `TodoListView`（两版）新增 `expandedIDs`、`subtaskList`、`toggleSubtask` |
| D-78 | 标签支持**重命名 / 删除**（新增 `TodoTagManageSheet`，入口在编辑页标签区「管理标签」）：重命名沿用 `TodoTagRules`（1–8 字、忽略大小写与音标去重）；删除**只解除关联**（待办保留）并二次确认，行内显示被引用条数 | 用户反馈「标签不能删也不能改」。标签是轻量分类，删除时连带删待办风险太大；改名不需要迁移历史数据（待办持有的是关系而不是名称副本） | `Views/Todo/TodoTagManageSheet.swift`（两版同名副本，仅数据栈差异） |
| D-79 | 备忘正文支持 **Markdown 子集**：渲染（标题/列表/勾选/引用/粗体/斜体/删除线/行内代码/链接）+ 8 条快捷语法；编辑器用 `UITextView` 包装以拿到选区（SwiftUI `TextEditor` 不暴露选区，无法把语法作用在选中文字上）；打开已有备忘默认进「预览」 | 用户要求「正文增加 MD 语法渲染和快捷语法输入」。要精确包住选中文字必须有选区，`UIViewRepresentable` 是最小代价方案；默认预览符合「打开是想看内容」的直觉，新建时留在编辑 | `MemoMarkdown.swift`（纯逻辑，两版逐字节一致）、`MarkdownTextEditor.swift`、`MemoEditSheet`（编辑/预览分段 + 工具栏）、`MemoListView` 摘要去标记；`MemoMarkdownTests` 11 条 |
| D-80 | 修「只改账单金额不生效」：**删除 `DayGroupCard` 的自定义 `Equatable`**（两侧持同一批实体，比较恒等 → 触发「没变化」跳过重绘），并给 `TransactionView` 加**账单内容指纹**（id + 金额 + 类型 + 分类 + 日期）在变化时重建预算卡 | 用户反馈「修改账单的金额之后，不会有影响」。根因是自定义 `==` 读的是同一批对象的当前值，永远相等；只比数量（`bills.count`）同样漏掉「编辑金额」这类改动 | `BillsCardView`（两版）、`TransactionView.billRevision` + `.onChange` |

## R. 构建提速 / 输入法卡顿 / 金额改不动（2026-09-28 第十一轮）

| 编号 | 决策 | 理由 | 落地 |
|------|------|------|------|
| D-81 | Markdown 渲染**不在纯逻辑层设置 SwiftUI 属性**：`MemoMarkdownRenderer` 只产出「行级样式 + 行内 AttributedString」，字号 / 颜色 / 删除线由视图层修饰器设置 | `rendered.font = ...` / `.foregroundColor = ...` 走 SwiftUI 属性作用域，单文件 `swiftc -typecheck` 要 8.47 秒；增量构建每次重建模块接口，直接拖慢所有构建。分离后 1.76 秒 | `MemoMarkdown.swift`（新增 `MemoMarkdownBlock`）、`MemoEditSheet.markdownPreview` 逐块渲染；`MemoMarkdownTests` 改用 `blocks(from:)` |
| D-82 | `MarkdownTextEditor` **编辑中不回灌文本**：`updateUIView` 在 `uiView.isFirstResponder` 时直接返回，只有非编辑态（打开 sheet 载入内容）才同步；同时移除「每次按键都上报选区」的回调 | 输入法组合（marked text）期间 binding 常落后一两个字，`uiView.text = text` 会打断组合、清掉候选，表现为「打字非常卡」；选区回调每次按键都改父状态，额外触发整页重绘 | `MarkdownTextEditor.swift`（两版逐字节一致） |
| D-83 | 账单编辑页**不再用 `.disabled` 静默禁用保存**，改为点击后按具体原因弹提示；并在打开时归一化类型（`BillEditRules.normalizedType`）、金额输入归一化（`BillAmountInput`） | 用户报「改金额没影响、再打开又是旧值」：旧数据的 `Bill.type` 是模型默认值「支出」等中文 → 分段控件无匹配项、分类校验永远失败 → 保存按钮永久禁用，点按毫无反应（改动根本没写库）。静默禁用是根因放大器 | `BillEditRules.swift`（两版逐字节一致）、`EditBillView`（两版）、新增 `BillInputTests` 7 条 |

