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
