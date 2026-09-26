# 项目速查

> 详细实现见 [docs/PROJECT_MEMORY.md](../docs/PROJECT_MEMORY.md)；产品需求见 [docs/PRD.md](../docs/PRD.md)。

## 1. 是什么

SwiftUI 写的**全平台个人记账 App**（iOS / macOS / watchOS 三端 + 一个 iOS SwiftData 验证版），**数据只存本地**，无任何第三方依赖、无服务端、运行时不发起网络请求。

仓库：`LiuBe-github/Apple-all-platform-iFinance` ｜ 工程：`iFinance.xcodeproj`（Xcode 27，`SWIFT_VERSION = 5.0`）

## 2. 四端矩阵

| Scheme | 目录 | 平台 | Bundle ID | 部署目标 | 数据层 |
|--------|------|------|-----------|----------|--------|
| `iFinance` | `iFinance/` | iOS / iPadOS | `cn.liube.iFinance` | 18.0 | Core Data |
| `iFinanceSwiftData` | `iFinanceSwiftData/` | iOS / iPadOS | `cn.liube.iFinance.swiftdata` | 18.0 | SwiftData |
| `MaciFinance` | `MaciFinance/` | macOS | `cn.liube.MaciFinance` | 15.0 | Core Data（独立库） |
| `WatchiFinance Watch App` | `WatchiFinance Watch App/` | watchOS | `cn.liube.iFinance.watchkitapp` | 11.0 | 无（内存 + UserDefaults，靠 iPhone 落库） |

上限均为各平台 27.x。iOS 17 自本轮起不再支持。

## 3. 技术栈与关键约定

| 项 | 说明 |
|----|------|
| UI | SwiftUI（三端各自实现，刻意不做跨端抽象层） |
| 持久化 | Core Data（iOS/macOS）与 SwiftData（第三份模型），**三处字段必须同步** |
| 图表 | Swift Charts（柱状趋势、分类占比饼图、热力图） |
| 跨设备 | WatchConnectivity 的 `transferUserInfo`（`action: addBill / requestTodayBills / todayBills`） |
| 认证 | CryptoKit `SHA256("盐|密码")`、`AuthenticationServices`（Apple 登录）、`LocalAuthentication`（应用锁） |
| 国际化 | 四语言（zh-Hans / zh-Hant / en / ja），`L10n.string` + `AppleLanguages` 同步 |
| 设计系统 | `AppSpacing` / `AppRadius` / `AppLayout` / `AppTypography` / `AppMotion`（禁止魔法数字） |

## 4. 目录地图（改代码时常去的地方）

```
iFinance/
├── App/iFinanceApp.swift              入口：认证路由 + 生物锁遮罩 + 隐私遮罩 + 开屏 + 主题/语言
├── Persistence.swift                  Core Data 栈 + 用户隔离 predicate + 调试重置
├── Manager/                           AuthManager / BiometricLockManager / WatchSessionManager
│                                      + CloudKitSyncManager、NotificationManager（禁用 stub）
├── Models/                            分类枚举、ThemeMode、DailySentence、CategoryBreakdown、PeriodSummary
├── Views/Common/                      设计 token、AppMotion、隐私遮罩、开屏、背景时钟、头像缓存、饼图组件
├── Views/Home/                        概况页（今日大卡 / 周期卡 / 每日一言卡 / 分享）
├── Views/Transaction/Bills/           记账与编辑（数字键盘、分类网格、编辑规则）
├── Views/Transaction/Budget/          预算（环形进度 + 分类列表/饼图）
├── Views/Tendency/                    趋势（柱状趋势、分类占比饼图、热力图）
├── Views/Setting/ Views/Profile/      设置与个人中心
└── Helper/                            L10n / LocalizationSync / HapticManager
iFinanceSwiftData/                     同上结构的 SwiftData 版（视图为同名副本，数据层不同）
MaciFinance/                           macOS 端（仪表盘 / 账单 / 统计 / 设置）
WatchiFinance Watch App/               三 Tab：概览 / 快速记账 / 当日历史
docs/                                  PRD、项目记忆、接口文档
memory/                                本文件夹（会话记忆与决策）
scripts/                               本地化审计、真机快速部署
```

## 5. 常用命令

```bash
# 构建 / 测试
xcodebuild build -project iFinance.xcodeproj -scheme iFinance -destination 'generic/platform=iOS Simulator'
xcodebuild test  -project iFinance.xcodeproj -scheme iFinance -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:iFinanceTests
xcodebuild test  -project iFinance.xcodeproj -scheme iFinanceSwiftData -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:iFinanceSwiftDataTests
xcodebuild test  -project iFinance.xcodeproj -scheme MaciFinance -destination 'platform=macOS' -only-testing:MaciFinanceTests

# 本地化体检（四 target；新增/改文案后必跑）
python3 scripts/check_localization.py

# 真机快速部署（跳过 Watch 部署与调试器附加，打印各阶段耗时）
scripts/run-on-device.sh -s iFinance
```

> 测试务必**串行**执行；并行跑多个 `xcodebuild test` 会导致测试宿主互相干扰（详见 [environment.md](environment.md)）。

## 6. 按主题找文件

| 想改… | 先看 |
|-------|------|
| 首页/概况页布局与文案 | `iFinance/Views/Home/`（`TodayBalanceCard` / `PeriodSummaryCard` / `SentenceCardView` / `ShareCardView`） |
| 记账键盘输入与运算 | `iFinance/Views/Transaction/Bills/NumberPadLogic.swift`（`NumberPadExpression`）+ `AddBillView.parseExpression` |
| 编辑账单的类型/分类/日期规则 | `iFinance/Views/Transaction/Bills/BillEditRules.swift` + `EditBillView.swift` + `CategoryPickerView.swift` |
| 账单列表行样式 | `iFinance/Views/Transaction/TransactionRowView.swift`（备注为主、分类·时间为次） |
| 预算与占比 | `Views/Transaction/Budget/` + `Views/Common/CategoryPieView.swift` |
| 趋势页三件套 | `Views/Tendency/`（`TrendCard` 柱状、`CategoryPieCard` 饼图、`TendencyHeatmapView` 热力图） |
| 视觉/动画/间距 | `Views/Common/AppVisualStyle.swift`、`AppDesignTokens.swift`、`AppMotion.swift` |
| 应用锁与后台模糊 | `Manager/BiometricLockManager.swift` + `Views/Common/AppPrivacyShield.swift` |
| 多语言 | `Helper/LocalizationHelper.swift`（`L10n`、`LocalizationSync`）+ 四套 `.lproj` |
| Watch 同步 | `iFinance/Manager/WatchSessionManager.swift` ↔ `WatchiFinance Watch App/Models/WatchDataModel.swift` |

## 7. 数据模型（两句话）

- `Bill`：`id`(UUID 幂等键) / `amount`(Decimal) / `type`(`expenditure`·`income`·`transfer`) / `category`(分类 rawValue) / `note` / `date` / `createdBy`(隔离键) / 审计字段。
- `UserProfile`：`userIdentifier` / 邮箱手机号 / 密码哈希与盐 / `nickname` / `signature`(≤40 字) / `avatarData` / `monthlyBudget`。

完整字段与同步协议见 [docs/api/data-and-sync.md](../docs/api/data-and-sync.md)。
