# 工作历史（codex/platform-18-27）

> 分支起点：`main` @ `fd6b1fb` ｜ 当前共 **31 次提交**，`217 files changed, +27794 / −2531`（含本文件所在提交，实测值见 `git diff --shortstat main...HEAD`）
> 分支未推送远端。每次完成新改动请**在表尾追加一行**；由于提交哈希在写入文件时尚未生成，最新一行用「*(最新一次提交)*」占位，**下次提交时把真实 SHA 回填到上一行**。
> 历史行的 SHA 已核对：1~30 可直接用于 `git show`（第 31 行是当前提交的占位）。

## 时间线

| # | 提交 | 类型 | 做了什么 | 验证 |
|---|------|------|----------|------|
| 1 | `37b2b39` | chore | 建立基线：把用户既有 39 个未提交改动 + 新建的 `AGENTS.md`/`docs/` 一起提交 | 工作区干净 |
| 2 | `00a565d` | feat | 三端部署目标改为 iOS 18 / macOS 15 / watchOS 11（上限 27）；新增 `iFinanceSwiftData` 应用 target + `iFinanceSwiftDataTests`；修复基线遗留的测试问题（`TrendCard.allBills` 类型、分类数量断言、macOS 搜索用例期望） | 四端编译通过；三套测试全绿；两个 iOS App 在 18.6 模拟器启动 |
| 3 | `d01e957` | docs | 补齐 `docs/api/{ios-core,ios-ui,macos,watchos,swiftdata}.md`，更新 `AGENTS.md`、`PROJECT_MEMORY.md`、`data-and-sync.md`，修正 README（版本表、语言切换说明、目录树） | 链接校验通过 |
| 4 | `bd083b5` | style | 新增 `AppDesignTokens` / `AppMotion`（含 Reduce Motion 降级）；全量收敛 iOS 视图的动画参数与布局数值（padding/spacing 归一到 4pt 网格、圆角 4 档、动画 3 档） | 两版编译通过；三套测试全绿；iPhone SE / 16 / iPad 三尺寸启动冒烟 |
| 5 | `219fdb6` | feat | 开启应用锁时进后台整页高斯模糊（`.appPrivacyShield`），解锁/关闭锁自动清除 | 单测 3 条；模拟器实测：开锁后切后台有遮罩、未开锁无遮罩 |
| 6 | `b10f146` | feat | 首页去图片化（概况大卡为主视觉、一言变纯文字、分享无图、删除图片管线与 `picture2` 数据）+ 修复语言切换「取消」按钮显示 `common.cancel`（macOS 主题 key 同类问题一并修） | 四端编译通过；三套测试全绿；打包产物核对（`home.title=概况`、`common.cancel=取消`） |
| 7 | `d520586` | feat | 概况页新增「周期概况卡」（本月/上月/本年，跨年场景正确）+ 每日一言独立卡片；分享图加入三区间摘要 | 新增聚合单测（跨月跨年、转账口径、窗口覆盖）；三尺寸冒烟 |
| 8 | `104f9f8` | style | 今日结余只显示金额，移除「结余 / 超支」文字 | 两版编译 + 测试；冒烟 |
| 9 | `8b5f152` | assets | 微信二维码替换为 `IMG_5894.jpg`，改为单文件通用资源（445KB→164KB）；移除误收录的空图片集 | 编译 + `assetutil` 核对尺寸 + 冒烟 |
| 10 | `30392f8` | fix | 本地化修复：268 处 `String(localized:)`/`NSLocalizedString` → `L10n.string`；新增 `LocalizationSync`（AppleLanguages 同步 + 启动兜底）；补 15 个 `auth.*` 译文、清理 6 个残留 key；新增审计脚本 | 四端编译；三套测试全绿；审计脚本四 target 通过；两版 App 在 en/ja 下验证同步日志 |
| 11 | `b275f02` | feat | 账单行备注为主/分类为次（同步 macOS）、头像裁剪页（拖动缩放 + 300×300 JPEG）、概况页配色与层级重排、冷启动开屏动画、设置页头像旁显示昵称、已用百分比保留两位小数 | 新增百分比格式单测；四端编译；三套测试；冒烟 |
| 12 | `bd84c95` | perf | 背景动画共享时钟（30fps→10fps、非活跃暂停、RadialGradient 替代 blur）；头像解码缓存；Formatter 静态化；分类网格 Equatable 拆分；TrendCard 单次遍历；SettingView 拆子视图 | 四端编译；三套测试；冒烟 |
| 13 | `95d2475` | feat | 个性签名：三份模型加 `signature` 字段，`AuthManager.signature/updateSignature/validateSignature`（40 字上限），设置页头部显示 + 点击编辑 + 个人中心入口 | 新增边界单测；三套测试；审计通过 |
| 14 | `5167091` | perf(dev) | 关闭 `SWIFT_EMIT_LOC_STRINGS` / `STRING_CATALOG_GENERATE_SYMBOLS`（全量设备构建 25.1s→23.9s）；新增 `scripts/run-on-device.sh`（跳过 Watch 部署与调试器附加）；修复 macOS 偶发测试失败（`DashboardLogicTests` 加 `.serialized`） | 实测构建耗时；四端编译；三套测试 |
| 15 | `52f6c36` | fix | 记账键盘「运算符后无法继续输入数字」：抽出 `NumberPadExpression`（按当前数字段校验）、修正运算符首按语义 | 新增 9+2 条单测（含复现用例与四则运算）；三套测试 |
| 16 | `1953919` | feat | 趋势页新增支出/收入分类占比饼图（独立跨度、完整列表、点选高亮），删除折线图与图表类型切换器；预算页饼图改用同一组件；新增 `CategoryBreakdown` 纯逻辑 | 新增 4+2 条聚合单测；四端编译；三套测试；审计通过 |
| 17 | `509b9cf` | fix | 编辑页：分类改推入式选择页（只列当前类型分类）、类型切换清空并要求重选、类型补转账、日期精确到时分；新增 `BillEditRules` 归一化旧脏数据 | 新增 3+3 条规则单测；四端编译；三套测试；审计通过 |
| 18 | `db152dd` | docs | 新增 `docs/PRD.md`（11 模块功能需求、10 条业务规则、验收清单、路线图、已知限制）并接入 README / AGENTS / PROJECT_MEMORY 索引 | 11 个 markdown 链接校验 |
| 19 | `8acaaed` | docs | 根据本次协作历史建立 `memory/` 记忆文件夹（7 份：索引 / 速查 / 决策 / 工作历史 / 待办 / 环境 / 协作约定） | 18 个 markdown 链接校验通过（仅文档改动，未跑构建） |
| 20 | `74cb9e5` | docs | 新增 `docs/HANDOFF.md` 交接文档（接手清单、环境准备、十条铁律、代码地图、验证四件套、风险摘录）并接入 README / AGENTS / PROJECT_MEMORY / docs/api / memory 索引；修正 `work-history.md` 的提交数与统计偏差（补记第 11 行 `b275f02`） | 19 个 markdown 文件、0 失效链接（仅文档改动，未跑构建） |
| 21 | `f082fce` | fix | 修复 `reset_ifinance_data.sh` 的 Bundle ID（12 处 `com.liube.iFinance` → `cn.liube.iFinance`），模拟器数据清理脚本恢复可用 | 脚本 diff 核对（未跑构建） |
| 22 | `262c4d0` | fix | 接手复核并落地第二轮改动：微信/QQ 登录降级「即将支持」+ `AuthManager.loginWithProvider` 拒绝非 Apple 建号（三端）；CSV 导入抽 `CSVImporter` 并补齐 `createdBy`/审计字段、修正 `en_US_POSIX` 拼写；**修 CRLF 换行解析**（Swift `"\r\n"` 是单个 Character，两版同步）；配套文案/文档/记忆更新 | 四端编译 exit=0；本地化审计四 target 通过；两版 App 在 iPhone 16 / iOS 18.6 与 **iPhone 17 / iOS 27.0（上界）** 安装启动冒烟正常（PID 存活、无崩溃）；**未跑全套单测**（用户指示"基本功能能用就行"），CSV 解析改用本地脚本验证 CRLF/LF/CR 三种换行 |
| 23 | `fc87ab3` | fix | 批次一（修复与体验）：新增账单页分类网格最后一行被键盘遮挡（固定占位 → `safeAreaInset`）；图标体系重排（数码/通讯、交通/汽车等 10 处去重，收入新增「生活费」）；备注键盘不再顶走页面（键盘区折叠、金额+备注条浮到键盘上方）；柱状图手势拆分（按柱子选中 / 空白处横向滚动，日与周保持原行为） | 两版 iOS 编译 exit=0；新增图标单测 4 条通过；本地化审计通过；两版 App 启动冒烟正常；视觉细节待人工确认 |
| 24 | `a5d7129` | feat | 批次二（分类体系）：新增 `CategoryStore`（UserDefaults JSON、按账号隔离、交通二级分类播种）、`CategoryResolver`（内置/自定义/「父/子」统一解析）、`CategoryIconLibrary`（105 枚精选符号 9 组）；记账页与编辑页分类网格改为可自定义 + 二级 chips；新增 `CustomCategorySheet` 与设置页「分类管理」（改名同步历史账单、删除保留账单）；趋势页置顶新增 `NetTrendCard` 总收支双向柱状图（月/6 个月/年） | 两版 iOS 编译 exit=0；新增单测 19 条全绿（图标 4 + 分类存储 11 + 总收支聚合 4）；本地化审计 468 key 通过；两版 App 启动冒烟正常 |
| 25 | `9d2b147` | perf | 批次三（性能与构建）：趋势页取数加「最近 24 个月」窗口（Core Data 谓词 / SwiftData @Query）；`DailyAmount.id` 改为日期避免图表全量 diff；账单列表单次过滤分组 + LazyVStack；分类选项按 revision 缓存；开屏 1.8s→1.2s、Watch 连接延后到首帧后、DEBUG 启动耗时日志；`run-on-device.sh --release` | 四端编译 exit=0；iFinanceTests 关键 58 条全绿（含既有用例）；两版 App 在 iPhone 16 / iOS 18.6 启动冒烟正常 |
| 26 | `b155546` | docs | 同步文档与记忆：AGENTS（分类体系不变量、性能约定、坑表、测试规模）、PRD（分类管理 / 自定义分类 / 二级分类 / 总收支图）、PROJECT_MEMORY、docs/api（分类体系与趋势页）、HANDOFF 快照、memory（台账 / 决策 D-51~D-58 / 待办） | 19 个 markdown 文件 0 失效链接；`check_localization.py` 四 target 通过；另在 iPhone 17 / iOS 27.0（上界）冒烟两版 App 启动正常 |
| 27 | *(最新一次提交)* | fix | 备注输入条定位重做（删除 `NumberPad` 的键盘位移与内嵌输入框，改为 `AddBillView` 根级浮层 + 键盘高度单一来源定位，页面与浮层都忽略键盘安全区）；总收支图支出柱改为零轴向下（`expenseBarValue = -expense`，Y 轴刻度显示绝对值）；分类配色统一（身份色支出红/收入绿，删除主题色选择；饼图与预算明细保留 8 色板）；清理两条无用文案 | 两版 iOS 编译 exit=0；关键单测 58 条全绿（含新增 `expenseBarValue` 断言）；本地化审计四 target 通过；两版 App 在 iPhone 16 Pro / iOS 18.6 与 iPhone 17 / iOS 27.0 启动冒烟正常；备注条间距与图表观感待人工确认 |
| 28 | *(最新一次提交)* | fix | 修复「重启后二级分类在账单页显示问号」：`CategoryStore` 拆分读取路径与发布路径——新增 `currentItems`（首次访问同步从磁盘载入 + 播种、不发布变更，渲染期安全）与 `ensureLoaded(force:)`，`reload()` 只负责补发布；新增 `resetInMemoryCacheForTesting()` 与两版冷启动回归用例 | 两版 iOS 编译 exit=0；CategoryStore/CategoryIcon/NetTrend 共 20 条测试全绿（含冷启动回归）；本地化审计四 target 通过；两版 App 在 iPhone 16 Pro / iOS 18.6 启动冒烟正常 |
| 29 | *(最新一次提交)* | refactor(ios) | 趋势页两个柱状图改造为 Apple Health 式 scrub：原生 `chartXSelection` 负责按下即选/拖动吸附/松手清空，`chartOverlay` + 新增 `ScrubCallout` 自绘指示线与浮层（只做透明度变化，`AppMotion.quick` 0.18s），`ScrubSelection` 门控触觉（跨数据点才 tick）并提供贴边自动滚动（Task 200ms 步进近似）；删除 `DragMode`/`touchDetectionRadius`/`barOpacity` 与全部自研拖动手势；补 8 条中文 a11y 文案与 `.accessibilityLabel/Value/Hint`；`TrendCard` 新增 `scrollBounds` 传参 | 两版 iOS 编译 exit=0；`iFinanceTests` 106 条全绿（含新增 ScrubSelectionTests 5 条 + ScrubRenderSmokeTests 4 条真实渲染，覆盖选中/未选中/双向柱状图/Dynamic Type 最大档）；本地化审计四 target 通过（474 key）；静态检查无 `DragMode/touchDetectionRadius/barOpacity` 残留；两版 App 在 iPhone 16/iOS 18.6 与 iPhone 17/iOS 27.0 启动冒烟正常。**240fps 慢动作、真实触觉计数、VoiceOver 实读、Reduce Motion 观感、页面滚动/返回手势等真机项未在本机验证（见 open-items OI-45）** |
| 30 | *(最新一次提交)* | feat(ios) | 趋势页图表对齐 Apple 图表规范 R1–R22：新增 5 个支撑文件（`ChartAxisSupport` 整齐刻度轴模型、`ChartSeriesStyle` 语义色 + 形状通道、`ChartSummary` 结论副标题、`ChartAccessibility` 图表描述符、`HeatmapRamp` 热力色阶）；两个柱状图改显式 y 域 + 右置轴 + 紧凑标签 + 3–5 条整齐刻度，日粒度按天/周取刻度；去掉图表额外内边距；余下英文 plottable 标签本地化；四图补 `AXChartDescriptor` 且轴刻度 `accessibilityHidden`；配色明度均衡（浅色对比度 ≥3.7:1、深色 ≥7.9:1）并支持「不以颜色区分」形状；热力图改整块网格单击吸附 + 深浅/提高对比度色阶 | 新增 `ChartGuidelineTests` 17 条（轴/刻度/紧凑标签/副标题/形状/对比度/色阶单调）；`iFinanceTests` **123 条全绿**、SwiftData 版 **50 条全绿（16 套件）**；两版 iOS 编译 exit=0；本地化审计四 target 通过（488 key）；`rg` 确认无未本地化 plottable 标签；两版 App 在 iPhone 16/iOS 18.6 启动冒烟正常。**240fps 并排、VoiceOver 实读、触觉计数、四环境观感、FKA 等真机项见 open-items OI-47；macOS R14/R20 未达成见 OI-46** |
| 31 | *(最新一次提交)* | style(ios) | **配色回退**（用户反馈「改暗了不好看，我要原来的颜色」）：`ChartSeriesStyle` 的 8 色系列板与支出红 / 收入绿恢复为改版前原值、深浅模式共用；`HeatmapRamp` 默认色阶恢复原四级蓝色（`dark = light`），仅保留「提高对比度」变体；R16 的明度均衡 / 对比度目标标记未采用（D-70、OI-48）；测试改为「锁定原始颜色取值」防止再次被改暗 | 两版 iOS 编译 exit=0；`ChartGuidelineTests` 17 条全绿（含颜色取值锁定）；本地化审计不受影响；两版 App 启动冒烟正常 |

| 32 | `f312ca9` | feat(ios) | **M1 待办/备忘/资产数据层**：三份模型同步新增 6 实体（TodoItem / TodoSubtask / TodoTag / MemoNote / AssetAccount / AssetSnapshot）；小整数统一 `Integer 16` ↔ `Int16`（Core Data 代码生成只给 Int16/Int32/Int64，拿不到 `Int`）；新增 5 个账号隔离谓词；账号删除与启动重置钩子联动清理；纯逻辑 `TodoGrouping` / `TodoRepeat` / `AssetBreakdown`（两版逐字节一致） | 四端构建 exit=0；`iFinanceTests` 141 条、`iFinanceSwiftDataTests` 56 条、`MaciFinanceTests` 30 条全绿；本地化审计四 target 通过；**老库升级冒烟**：模拟器原有仅含 Bill/UserProfile 的旧库，装新版后实体变 8 个、首帧 533ms 正常启动 |
| 33 | `c803e02` | feat(ios) | **M2 待办与备忘标签页**：Tab 枚举新增 `todo` 插在「账本」与「趋势」之间（首页/账本/待办/趋势/设置 仍 5 项）；新增 `Views/Todo/` 五个文件（分段切换、六分组列表、勾选完成、滑动删除、清除已完成二次确认、待办/备忘编辑 sheet）；纯逻辑补 `TodoRecurrence.nextDraft` 与 `TodoTagRules`；四语言 80 条文案一次性落地 | 两版 iOS 构建 exit=0；`iFinanceTests` **153 条**、`iFinanceSwiftDataTests` **58 条**全绿；本地化审计四 target 通过（569 key）；iPhone 16 两版启动冒烟正常 |
| 34 | `b0feeff` | feat(ios) | **M3 资产页**（账本页右上角入口，不占标签位）：总资产卡（较上次变化金额/百分比 + 负债合计 + 净资产 + 账户数）→ 按账户类型聚合的环形图（点选高亮 + 中心读数 + 明细列表兼图例）→ 分类型账户列表（组内余额降序、负数红色、点行编辑、滑动删除）；`AssetEditSheet`（类型九宫格 / ± 切换负数余额 / 计入总资产 / 删除二次确认）；账户增删改保存后按当天 upsert 一条 `AssetSnapshot` | 四端构建 exit=0；`iFinanceTests` 153 条（含 AssetBreakdownTests 6 条）、`iFinanceSwiftDataTests` 58 条、`MaciFinanceTests` 30 条全绿；本地化审计四 target 通过；两版 App 在 iPhone 16 / iOS 18.6 启动冒烟无崩溃 |

| 35 | *(最新一次提交)* | feat(ios) | 标签栏末项由「设置」更名为「我的」（四语言：我的 / 我的 / Me / マイ），图标从齿轮改为**用户头像缩略图**（`.renderingMode(.original)` + 圆形裁切 + 新增 `AppLayout.tabBarIcon` = 25pt；未设置头像时回落 `person.crop.circle.fill`）；ContentView 注入 `authManager`，预览补 `environmentObject` | 两版 iOS 构建 exit=0；`iFinanceTests` 153 条、`iFinanceSwiftDataTests` 58 条全绿；本地化审计四 target 通过；两版 App 在 iPhone 16 / iOS 18.6 安装启动无崩溃（首帧 1012ms / 585ms）。**标签栏头像观感与「有头像 / 无头像」两种状态待人工确认（见 OI-49）** |

| 36 | `010fc88` | fix(ios) | **修「整个标签栏被头像铺满」**：`.tabItem` 里 `Image(uiImage:).resizable()` 没有固有尺寸，会被 TabView 拉伸；改为 `AvatarImageCache.thumbnail(for:diameter:)` 离屏渲染固定点尺寸的圆形缩略图位图（aspect fill → 居中裁圆 → 像素随 scale、点尺寸固定，按「数据哈希 + 直径」缓存），`ContentView` 不再用 `.resizable()/.frame/.clipShape`；新增两版 `AvatarThumbnailTests` 锁住点尺寸约束 | 两版 iOS 构建 exit=0；`iFinanceTests` **156 条**（含新增 3 条）、`iFinanceSwiftDataTests` 58 条（Swift Testing）+ 3 条（XCTest）全绿；本地化审计四 target 通过；iPhone 16 / iOS 18.6 重新安装启动无崩溃（首帧 899ms）。**带真实头像的观感仍需人工确认（OI-58）** |
| 37 | *(本次提交)* | fix(ios) | **修「我的」标签显示白色圆盘而不是头像**：根因是标签栏会把**非符号图片当模板**渲染（整块纯色填充）。改为在 UIImage 层 `withRenderingMode(.alwaysOriginal)`（SwiftUI 层 `.renderingMode(.original)` 不足以阻止模板化），并补「源图尺寸为 0 时回落默认头像」的防御 | 两版 iOS 构建 exit=0；`iFinanceTests` 156 条、`iFinanceSwiftDataTests` 58 + 3 条全绿（`AvatarThumbnailTests` 新增 alwaysOriginal 断言）；**像素级验证**：临时注入洋红+绿方块头像后，截取第 5 个标签区域统计到洋红 3559px / 绿 576px（修复前同区域 0 个饱和像素，只有一块灰盘） |

## 验证方式说明（沿用本轮约定）

1. **四端编译**：`iFinance`、`iFinanceSwiftData`、`MaciFinance`、`WatchiFinance Watch App`（后两端只确认未被牵连）。
2. **测试串行**：`iFinanceTests`（iOS 18.6 模拟器）、`iFinanceSwiftDataTests`（同）、`MaciFinanceTests`（本机 macOS 27）。
3. **本地化审计**：`python3 scripts/check_localization.py`（四 target 必须全过）。
4. **运行冒烟**：iPhone 16 / iPhone SE / iPad Pro 11"（M4）安装启动，确认进程存活；必要时补充真实交互验证。

## 未记录在提交里的过程信息

- 运行时补齐尝试：本机 `xcodebuild -downloadPlatform iOS|watchOS` 返回 “not available for download”，故 iOS 27 / watchOS 27 只做了编译级验证（详见 [environment.md](environment.md)）。
- 构建耗时实测：增量 3～6s；全量冷构建约 24～25s（SwiftCompile 占大头）。
- 产物体积：iOS app 15MB（含 12MB debug dylib）+ watch app 2.5MB。
- 崩溃日志核对：`~/Library/Logs/DiagnosticReports/iFinance-*.ips` 全部来自 **XCTest 测试宿主**（Xcode 27 已知问题），普通启动无崩溃。
