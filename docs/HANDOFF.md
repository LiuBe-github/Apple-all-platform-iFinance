# 交接文档（HANDOFF）

> 用途：把「iFinance 全平台记账 App」从本轮负责人手里完整交给下一位工程师或 Agent。
> 阅读方式：**先照 §0 跑一遍，再按 §3 的路线读文档**；动手前务必过一遍 §4 的铁律与 §6 的工作流。
> 生成时间：2026-09-26 ｜ 分支 `codex/platform-18-27` ｜ 交接时前一提交 `8acaaed`（第 19 次），本文件为第 20 次

## 0. 一分钟接手

```bash
git switch codex/platform-18-27            # 本轮工作分支，未推送远端
git status --porcelain                     # 期望：无输出（交接时工作区干净）
git log --oneline -20                      # 本轮的 20 次提交
python3 scripts/check_localization.py      # 本地化体检：应四 target 全过
xcodebuild build -project iFinance.xcodeproj -scheme iFinance \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/dd_ios -quiet
```

三条最要紧的信息：**① 四端矩阵**（iOS 18–27 主版本 + SwiftData 版、macOS 15–27、watchOS 11–27）；**② 两条铁律**（账单 `type` 与 `category` 必须匹配；新增文案一律 `L10n.string`）；**③ 最紧的待办**是微信/QQ 登录的真实接入（已先降级为「即将支持」提示，见 §8 的 OI-01）。

## 1. 交接快照

| 项 | 状态 |
|----|------|
| 分支 / 远端 | `codex/platform-18-27`，起点 `main` @ `fd6b1fb`，**未推送远端** |
| 提交数 | 26 次（20 本文件 · 21 `f082fce` reset 脚本 · 22 `262c4d0` 登录降级 + CSV 修复 · 23 `fc87ab3` 修复与图标批次 · 24 `a5d7129` 分类体系与总收支图 · 25 `9d2b147` 性能与构建 · 26 文档同步；台账见 [memory/work-history.md](../memory/work-history.md)） |
| 工作区 | 干净（交接前仅存在本轮已提交的改动） |
| 代码规模 | `iFinance` 12,779 行 · `iFinanceSwiftData` 12,445 行 · `MaciFinance` 3,663 行 · `WatchiFinance Watch App` 723 行 |
| 测试规模 | `iFinanceTests` 15 个 XCTestCase / 97 个用例 · `iFinanceSwiftDataTests` 38 个用例 · `MaciFinanceTests` 30 个用例 |
| 外部依赖 | **无**：无第三方库、无服务端、运行时不发网络请求，数据只存本地 |
| 签名 | `DEVELOPMENT_TEAM = 77MC3D43Z4`、`CODE_SIGN_STYLE = Automatic` —— **接手人必须换成自己的 Team ID**（否则真机与部分构建会失败） |
| 文档存量 | `AGENTS.md`、`README.md`、`docs/`（PRD + 项目记忆 + 7 份接口文档 + 本文件）、`memory/`（7 份会话记忆） |

## 2. 环境准备

| 项 | 要求 / 现状 |
|----|-------------|
| Xcode | 27.0（Build `27A266a`），SDK 为 iOS 27 / macOS 27 / watchOS 27；工程 `SWIFT_VERSION = 5.0` |
| 宿主系统 | macOS 27.0（本轮验证环境） |
| 模拟器运行时 | iOS 18.4、18.6（下界主力）、**iOS 27.0（上界，已安装）**；watchOS 26.2 / 26.4 / 26.5 |
| 上界运行时 | **iOS 27.0 已可运行验证**（设备为 iPhone 17 / 18 系列）；watchOS 27 仍不可下载，只能编译级验证 |
| 已验证设备 | iPhone 16、iPhone SE(3rd)、iPad Pro 11"(M4)、iPhone 17 / 18（iOS 27.0）模拟器；iPhone 16 Pro 真机（UDID `00008140-000C05692013C01C`，需解锁并信任电脑） |
| 真机部署注意 | scheme 依赖 watch target（`Embed Watch Content`）且 Xcode 会附加调试器，因此 Run 会慢；用 `scripts/run-on-device.sh -s iFinance` 跳过这两步 |

首次打开工程后请先做三件事：① 把 4 个 target 的 `DEVELOPMENT_TEAM` 改成自己的；② 确认已安装 iOS 18.6 模拟器运行时；③ 跑一遍 §0 的命令确认基线可构建。

## 3. 上手阅读路线

| 顺序 | 文档 | 读它是为了 |
|------|------|-----------|
| 1 | [AGENTS.md](../AGENTS.md) | Agent/开发速用记忆：版本矩阵、构建命令、9 条不变量、坑表 |
| 2 | [docs/PRD.md](PRD.md) | 产品要做什么、业务规则、验收清单、现实状态（✅ / 🚧 / 💤） |
| 3 | [docs/PROJECT_MEMORY.md](PROJECT_MEMORY.md) | 架构、数据层、认证、国际化、技术债 |
| 4 | [memory/README.md](../memory/README.md) | 本轮协作的决策、历史、待办、环境与协作约定 |
| 5 | [docs/api/README.md](api/README.md) 及其对应模块 | 具体类型的接口签名与 `路径:行号` |

按任务挑接口文档：iOS 核心层 → [ios-core.md](api/ios-core.md)；iOS 界面 → [ios-ui.md](api/ios-ui.md)；SwiftData 版 → [swiftdata.md](api/swiftdata.md)；macOS / watchOS → [macos.md](api/macos.md) / [watchos.md](api/watchos.md)；数据模型与 Watch 协议 → [data-and-sync.md](api/data-and-sync.md)。

## 4. 铁律（改动前必读，违反即引入缺陷）

1. **数据隔离**：账单归属由 `Bill.createdBy == UserDefaults["AuthUserIdentifier"]` 决定。所有查询必须叠加 `PersistenceController.billUserPredicate`，所有写入必须设置 `createdBy`；否则表现为「账单凭空消失」。
2. **三份数据模型同改**：`iFinance/iFinance.xcdatamodeld`、`MaciFinance/MaciFinance.xcdatamodeld`、SwiftData 版（`iFinanceSwiftData/Data/*`）字段契约一致。新增字段可轻量迁移，改类型/删字段需要 Mapping Model。
3. **三套本地化资源互不共享**（iOS / macOS / watchOS 各自的 `.lproj`），但 SwiftData 版**引用** iOS 的语言包与 `EconomicQuotes.json`。**新增文案一律 `L10n.string("key")`**，不要用 `String(localized:)` / `NSLocalizedString`（它们跟随系统语言，会导致切换语言后文字不跟随）。
4. **类型与分类必须匹配**：`type ∈ {expenditure, income, transfer}`；分类只能取对应枚举的 rawValue，转账固定 `"transfer"`。编辑页的类型切换、旧数据归一化、保存校验统一走 `BillEditRules`，**分类不允许自由文本输入**。
5. **禁用功能不要"顺手接上"**：`CloudKitSyncManager`、`NotificationManager` 是刻意保留的 stub（系统调用已注释，需付费开发者账号）。
6. **后台隐私遮罩链路完整**：进入后台/非活跃 → `BiometricLockManager.activatePrivacyShield()` → `.appPrivacyShield(_:)` 整页高斯模糊，**仅在用户开启应用锁时生效**；入口已统一包裹，新增页面无需单独处理，但不要破坏这条链路。
7. **UI 不写魔法数字**：间距/圆角/宽度用 `AppSpacing` / `AppRadius` / `AppLayout`，字体用 `AppTypography`（大额金额用 `.appAmountStyle`），动画用 `AppMotion` 四档（`quick` / `standard` / `emphasized` / `numeric`）并优先 `.appAnimation` / `.appEntrance` 以自动降级 Reduce Motion；iPad 主内容用 `.appContentWidth()`。
8. **性能约定**：背景动画只能用 `AppBackgroundView`（内部共享 10fps 时钟、非活跃暂停），不要再写 `TimelineView(.animation)`；头像解码走 `AvatarImageCache.shared.image(for:)`；`NumberFormatter` / `DateFormatter` 一律 `static let`；百分比用 `AppNumberFormat.percent(_:)`。
9. **两版 iOS 视图是同名副本**（`iFinance/Views` ↔ `iFinanceSwiftData/Views`）：改一处必须手工同步另一处；只有数据访问写法不同。
10. **文档同步**：改公开签名/模型/Watch 协议 → 更新 `docs/api/*`；改功能 → 更新 `docs/PRD.md` 状态列；每轮结束 → 更新 `memory/`（见 §6）。

## 5. 代码地图：想改什么，先看哪里

| 想改… | 先看 |
|-------|------|
| App 入口 / 认证路由 / 遮罩 / 开屏 | `iFinance/App/iFinanceApp.swift` |
| 数据栈、用户隔离、调试重置 | `iFinance/Persistence.swift` |
| 认证、应用锁、Watch 同步 | `iFinance/Manager/`（`AuthManager` / `BiometricLockManager` / `WatchSessionManager`） |
| 概况页（今日大卡 / 周期卡 / 每日一言 / 分享） | `iFinance/Views/Home/` |
| 记账与编辑（数字键盘、分类网格、编辑规则） | `iFinance/Views/Transaction/Bills/`（`NumberPadLogic.swift`、`BillEditRules.swift`、`CategoryPickerView.swift`） |
| 账单列表行样式 | `iFinance/Views/Transaction/TransactionRowView.swift`（备注为主、分类·时间为次） |
| 预算与分类占比 | `Views/Transaction/Budget/` + `Views/Common/CategoryPieView.swift` + `CategoryPalette.swift` |
| 趋势页三件套 | `Views/Tendency/`（柱状 `TrendCard` → 分类饼图 `CategoryPieCard` → `TendencyHeatmapView`）；**折线图与图表类型切换器已删除** |
| 视觉 / 动画 / 间距 token | `Views/Common/AppDesignTokens.swift`、`AppMotion.swift`、`AppVisualStyle.swift` |
| 分类体系（自定义 / 二级 / 图标） | `Views/Common/CategoryStore.swift`、`CategoryResolver.swift`、`CategoryIconLibrary.swift` + `Views/Transaction/Bills/CategoryGridView.swift`、`CustomCategorySheet.swift`、`Views/Setting/CategoryManagementView.swift` |
| 趋势页总收支双向柱状图 | `Views/Tendency/NetTrendCard.swift`（`NetTrendBuilder` 纯函数聚合） |
| 多语言 | `Helper/LocalizationHelper.swift`（`L10n`、`LocalizationSync`）+ 各端 `.lproj` |
| Watch 端 | `WatchiFinance Watch App/ContentView.swift` + `Models/WatchDataModel.swift` |
| macOS 端 | `MaciFinance/`（独立 Core Data 库与视图实现） |

## 6. 标准工作流（本轮固定下来，建议沿用）

1. **开工前**：`git status --porcelain` 核对工作区；确认分支为 `codex/*`（默认不推送远端）。
2. **改动**：分阶段小步提交（功能与视觉 / 性能 / 文档各自独立），提交信息用中文写清「做了什么 + 怎么验证的」；**不要用 `git add -A`**（曾把用户正在编辑的空图片集误提交），只添加本次相关路径。
3. **验证四件套**：
   - 四端编译：`iFinance`、`iFinanceSwiftData`、`MaciFinance`、`WatchiFinance Watch App`（后两端确认未被牵连）；
   - 三套测试**串行**全绿：`iFinanceTests`（iOS 18.6 模拟器）、`iFinanceSwiftDataTests`（同）、`MaciFinanceTests`（本机 macOS）；用户 2026-09-26 指示「基本功能能用即可」时，可只保留编译 + 审计 + 冒烟（见 [memory/working-agreements.md](../memory/working-agreements.md)）；
   - `python3 scripts/check_localization.py`（四 target 通过）；
   - 模拟器安装 + 启动冒烟（必要时三尺寸：iPhone SE / iPhone 16 / iPad）。
4. **文档同步**：`docs/PRD.md` 状态列 → `docs/api/*`（接口变化）→ `AGENTS.md` 坑表 → `memory/`（`work-history.md` 追加一行、`decision-log.md` 记取舍、`open-items.md` 改状态）。
5. **收尾**：更新 `docs/HANDOFF.md` §1 快照表中的提交号与状态；向用户汇报时**结论先行 + 证据**（命令输出/日志/耗时数据）。

```bash
# 四端编译（并行时给每个 scheme 独立 DerivedData，避免数据库锁冲突）
xcodebuild build -project iFinance.xcodeproj -scheme iFinance             -destination 'generic/platform=iOS Simulator'     -derivedDataPath /tmp/dd_ios   -quiet
xcodebuild build -project iFinance.xcodeproj -scheme iFinanceSwiftData    -destination 'generic/platform=iOS Simulator'     -derivedDataPath /tmp/dd_sd    -quiet
xcodebuild build -project iFinance.xcodeproj -scheme MaciFinance          -destination 'platform=macOS'                     -derivedDataPath /tmp/dd_mac   -quiet
xcodebuild build -project iFinance.xcodeproj -scheme 'WatchiFinance Watch App' -destination 'generic/platform=watchOS Simulator' -derivedDataPath /tmp/dd_watch -quiet

# 三套测试：务必串行（并行会互相干扰）
xcodebuild test -project iFinance.xcodeproj -scheme iFinance          -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:iFinanceTests          -quiet
xcodebuild test -project iFinance.xcodeproj -scheme iFinanceSwiftData -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:iFinanceSwiftDataTests -quiet
xcodebuild test -project iFinance.xcodeproj -scheme MaciFinance       -destination 'platform=macOS'                               -only-testing:MaciFinanceTests       -quiet

# 真机：快速部署（默认 Debug）/ Release 优化运行
scripts/run-on-device.sh -s iFinance
scripts/run-on-device.sh -s iFinance --release
```

## 7. 验证能力边界与已知工具链坑

| 平台 / 版本 | 编译 | 运行 | 说明 |
|-------------|------|------|------|
| iOS 18.4 / 18.6 | ✅ | ✅ 模拟器 | 主力验证环境 |
| iOS 27.0 | ✅ | ✅ 模拟器 | 运行时已安装（iPhone 17 / 18 系列）；2026-09-26 实测两版 App 可安装启动 |
| macOS 27 | ✅ | ✅ 本机 | 可直接跑 MaciFinanceTests |
| macOS 15 | ✅ | ❌ | 仅编译 + API 审查 |
| watchOS 26.x | ✅ | ✅ 模拟器 | watch 端冒烟 |
| watchOS 11 / 27 | ✅ | ❌ | 11 无法运行；watchOS 27 运行时不可下载 |

1. **测试必须串行**：并行跑多个 `xcodebuild test` 会出现测试宿主互相干扰（`Early unexpected exit`、随机失败）。
2. **UI 测试在 Xcode 27 克隆模拟器上会崩溃**（XCTest ↔ Swift Testing 互操作递归）：属于工具链问题，App 正常启动不受影响；日常验证请用 `-only-testing:` 跳过 UI 测试。`~/Library/Logs/DiagnosticReports/iFinance-*.ips` 里的崩溃全部来自测试宿主。
3. **并行构建会争抢 DerivedData**（`database is locked`）：并行时各给独立 `-derivedDataPath`。
4. **日志级别**：`Logger.info/debug` 不落盘，`log show` 查不到；状态类日志请用 `notice`（隐私遮罩、AppleLanguages 同步都是 `notice`）。
5. **语言切换需重启进程**（`exit(0)` / `NSApplication.terminate`），不要假设热切换。

## 8. 未完成事项与风险（高优先级摘录）

完整清单见 [memory/open-items.md](../memory/open-items.md)，这里只列接手后最该先看的几条：

| 编号 | 事项 | 级别 | 建议 |
|------|------|------|------|
| OI-01 | **微信 / QQ 登录未真实接入**（已降级为「即将支持」提示 + AuthManager 拒绝建号，占位隐患已消除） | 🟡 | 真接入需要企业主体 + 服务端换 token，见 PRD §7.2 |
| OI-05 | Watch 离线账单不会补传（不可达时只写本地缓存） | 🟡 | 已定方案：去掉 `isReachable` guard 直接走 `transferUserInfo` 系统队列（decision-log D-48） |
| OI-02/03/04 | 邮箱验证码绑定、CloudKit 同步与本地通知（stub）、macOS CSV/JSON 导出 TODO | 🟡 | 前两项需付费账号/服务端，见 open-items 的 A 区 |
| OI-30 | 自定义分类 / 二级分类仅 iOS 支持；定义不入 CSV，macOS 与其它设备显示为灰色纯文本 | 🟡 | 需要跨端一致时再评估（要动三份模型与 macOS 界面） |
| OI-33 | 第四轮的键盘浮层、网格滚到底、图表手势、总收支图**观感未经人工确认** | 🟡 | 在 Xcode / 真机上按验收清单逐条过一遍 |
| OI-13/14 | iOS 上界已可运行（27.0 模拟器）；**watchOS 27** 与下界（macOS 15 / watchOS 11）仍仅编译级验证 | 🟡 | watchOS 27 / 下界需真机或对应系统验证后回填 PRD 与 memory |

## 9. 接手人自检清单

- [ ] 切到 `codex/platform-18-27`，`git status --porcelain` 无输出；
- [ ] 把 4 个 target 的 `DEVELOPMENT_TEAM` 换成自己的，签名成功；
- [ ] 四端编译通过；
- [ ] 三套测试串行全绿（含 iOS 18.6 模拟器运行时已安装；用户明确"基本功能能用即可"时可跳过，见 §6）；
- [ ] `python3 scripts/check_localization.py` 四 target 通过；
- [ ] 模拟器安装并启动 `iFinance` 与 `iFinanceSwiftData`，概况页正常、无崩溃日志；
- [ ] 在 iOS 27.0 模拟器上跑一次两版 App 的启动冒烟（上界验证）；
- [ ] 读完 `AGENTS.md` / `docs/PRD.md` / `memory/README.md`，理解 §4 十条铁律；
- [ ] 就 OI-01（微信/QQ 真实接入）做出排期决定；
- [ ] 明确本轮改动是否推送远端（当前约定：由用户决定，默认不推送）。

## 10. 归属与联系

- 仓库：`LiuBe-github/Apple-all-platform-iFinance`（本机工作副本即本目录）；工程 `iFinance.xcodeproj`。
- 提交归属：本分支 22 次提交由本轮协作产出，尚未推送；如需对外发布，先与作者确认签名与版本号策略。
- 文档维护：本文件是**入口级**交接文档，每轮工作结束时更新 §1 快照表（提交数 / HEAD / 状态）与 §8 的风险摘录；细节变化写进 `memory/`。

---

_生成于 `codex/platform-18-27` 第 20 次提交；事实来源：代码勘察 + [memory/](../memory/README.md) + [docs/PROJECT_MEMORY.md](PROJECT_MEMORY.md)。_
