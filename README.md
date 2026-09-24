<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue.svg?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Xcode-16+-blue.svg?style=flat-square" alt="Xcode" />
  <img src="https://img.shields.io/badge/min%20iOS-17.6-green.svg?style=flat-square" alt="iOS" />
  <img src="https://img.shields.io/badge/min%20watchOS-11.0-green.svg?style=flat-square" alt="watchOS" />
  <img src="https://img.shields.io/badge/version-1.1-lightgrey.svg?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat-square" alt="License" />
</p>

<h1 align="center">iFinance</h1>

<p align="center">
  <strong>Apple 全平台个人记账应用</strong>
</p>

<p align="center">
  支持 iPhone · iPad · Mac · Apple Watch 的现代化个人财务管理工具<br/>
  简洁优雅的界面设计 · 多维度数据统计 · Watch 快速记账 · 多语言支持
</p>

---

## ✨ 功能特性

### 📱 核心功能

| 功能 | 描述 |
|------|------|
| **快速记账** | 自定义数字键盘，支持收入/支出/转账三种类型，25 种支出分类 + 11 种收入分类 |
| **月度预算** | 可设定月度预算，实时追踪已用额度与剩余比例，环形进度可视化 |
| **账单管理** | 按日期分组展示，支持关键词搜索、分类筛选、时间范围（本日/本周/本月/本年）筛选、编辑与删除 |
| **统计分析** | 周/月/年多维图表（Swift Charts），收支趋势折线图/柱状图切换，分类占比饼图 |
| **活跃度热力图** | GitHub 风格 53 周热力图，5 级深浅着色，月份标签随内容同步滚动 |
| **每日一句** | 首页展示经济名言（沃伦·巴菲特等，纯文字、不联网取图），与「今日概况」主卡片一同呈现，支持一键分享统计卡片 |
| **今日结余卡片** | 首页顶部紧凑展示当日收入/支出/结余/笔数 |

### ⌚ Apple Watch 快速记账

- **三 Tab 设计**：今日概览 / 快速记账 / 当日历史
- **精简数字键盘**：3×4 网格键盘，直接腕上输入金额
- **横向分类滚动**：支出 6 项 + 收入 4 项快捷分类
- **实时同步**：通过 `WatchConnectivity` 的 `transferUserInfo` 可靠传输至 iPhone
- **完整本地化**：Watch 端独立 `Localizable.strings`，支持 4 种语言

### 🧪 SwiftData 版（仅 iOS）

与主 iOS 版并列的独立 App（`iFinanceSwiftData` target，Bundle ID `cn.liube.iFinance.swiftdata`，显示名「iFinance SD」），用于验证 SwiftData 方案：

- **数据层**：`@Model` 的 `Bill` / `UserProfile` + `ModelContainer`，字段与 Core Data 版一一对应（含 `createdBy` 账号隔离键与审计字段）
- **功能对齐**：账号体系（多账号 / 密码 / 生物锁）、首页今日结余与每日一句、记账（数字键盘 + 25/11 分类）、账本（搜索 / 筛选 / 编辑 / 删除）、预算、趋势与热力图、设置（主题 / 语言 / CSV 导入导出）
- **与 Core Data 版的差异**：不注册 WatchConnectivity（不联动 Apple Watch）、不启用 CloudKit / 本地通知，数据从空库开始（不迁移历史数据）
- **资源复用**：共享 iOS 版的 4 语言 `.lproj` 与 `EconomicQuotes.json`（以 target membership 方式引用，非复制）
- **实现方式**：视图层由 iOS 版复制改造（`@FetchRequest` → `@Query`、`NSFetchRequest` → `FetchDescriptor`、`NSBatchDeleteRequest` → `ModelContext.delete(model:where:)`），核心类型沿用同名 API（`PersistenceController` / `AuthManager` / `Bill` / `UserProfile`），便于两版对照

### 💻 macOS 应用

- **登录体系**：邮箱 / 手机号 / Sign in with Apple 三种方式注册登录（与 iOS 一致）
- **仪表盘**：今日概览 + 近期收支趋势图
- **账单与统计**：账单明细 + 分类筛选，周/月/年折线图/柱状图切换
- **设置页**：主题 / 语言 / 数据管理 / 测试数据生成
- **视觉规范**：毛玻璃卡片统一样式（`AppVisualStyle`）

### 🔐 安全与账号

- **多账号支持**：邮箱 / 手机号 / Sign in with Apple 三种方式注册登录
- **密码安全**：CryptoKit SHA256 + 随机 Salt 哈希存储，密码不明文留存
- **生物识别锁**：Face ID / Touch ID 应用锁定，前后台自动锁定，含冷却防竞态
- **数据隔离**：多账号共用一套 Core Data，`createdBy` 字段实现用户级数据隔离

### ☁️ 云同步与通知（预留功能）

> ⚠️ 以下两项功能因需要付费开发者账号才能启用，当前**暂时禁用**，类结构已保留以保证编译通过（所有相关系统框架调用已注释）：

- **iCloud 同步**（`CloudKitSyncManager`，iOS + macOS）：基于 CloudKit 的跨设备数据同步，支持同步状态机（同步中/空闲/无账号/网络不可用/错误）与手动同步入口
- **本地通知**（`NotificationManager`）：预算超支提醒 / 记账提醒 / 每日账单汇总三类本地通知

### 🌍 国际化

支持 **4 种语言**，应用内切换（选择后重启 App 生效；iOS/watchOS 端由程序主动退出后重新拉起），三端全覆盖：

| 语言 | 标识 |
|------|------|
| 简体中文 | `zh-Hans` |
| 繁體中文 | `zh-Hant` |
| English | `en` |
| 日本語 | `ja` |

### 🎨 界面设计

- **毛玻璃风格** — 自定义 `appGlassCard` 修饰器，统一三端卡片样式；背景为渐变 + 缓慢漂移的呼吸光斑
- **深色模式** — 完整适配 Light / Dark / 跟随系统三档主题
- **触觉反馈** — 9 种精细化 Haptic 反馈（按键/确认/成功/错误等），Tab 切换与图表选中带系统触感（`sensoryFeedback`）
- **数字动画** — `contentTransition(.numericText())` 金额变化平滑滚动
- **符号动效** — `symbolEffect`（iOS 17+）旋转/弹跳/脉冲图标动效，覆盖刷新、分享、分类选中、超支警示等场景
- **按压缩放** — 统一 `ScaleButtonStyle`，所有可点击元素按下即缩放的即时反馈（HIG）
- **入场动画** — 首页卡片/账单分组/热力图/设置页采用弹簧淡入 + 错峰入场
- **热力图交互** — 点击任意格子高亮并显示当日笔数气泡，附"少→多"图例
- **饼图交互** — 预算页饼图支持点选扇区/列表联动高亮（`chartAngleSelection`）
- **macOS 专属** — 侧边栏选中高亮、卡片悬停抬升与描边、行悬停变色等桌面端交互

---

## 🏗️ 技术架构

```
iFinance/
├── iFinance/                          # 📱 iOS 主应用
│   ├── App/iFinanceApp.swift          # 入口：认证路由 + 生物锁 + 主题 + 语言 + Watch激活
│   ├── Models/                        # 数据模型
│   │   ├── ExpenditureCategory.swift  # 25 个支出分类枚举 + SF Symbol 图标
│   │   ├── IncomeCategory.swift       # 11 个收入分类枚举
│   │   ├── ThemeMode.swift            # 主题模式（light/dark/system）
│   │   ├── DailySentence.swift        # 每日一句数据结构
│   │   └── DailySentence.swift        # 每日一句数据结构
│   ├── Protocol/
│   │   └── TransactionCategory.swift  # 分类协议（icon + localizedDisplayName）
│   ├── Manager/
│   │   ├── AuthManager.swift          # 注册/登录/密码重置/Apple ID/头像/预算
│   │   ├── BiometricLockManager.swift # 生物识别状态机 + 冷却防竞态
│   │   ├── WatchSessionManager.swift  # iPhone 端 WCSession Delegate，写入 CoreData
│   │   ├── CloudKitSyncManager.swift  # iCloud 同步管理器（预留，暂禁用）
│   │   └── NotificationManager.swift  # 本地通知管理器（预留，暂禁用）
│   ├── Helper/
│   │   ├── HapticManager.swift        # 触觉反馈单例（9 种反馈）
│   │   └── LocalizationHelper.swift   # L10n 静态国际化辅助
│   ├── Views/
│   │   ├── Home/                      # 🏠 首页
│   │   │   ├── HomeView.swift         # 概况页：今日概况 + 每日一言 + 换一句/分享
│   │   │   ├── TodayBalanceCard.swift # 今日概况大卡（主视觉）
│   │   │   ├── SentenceCardView.swift # 每日一言（纯文字）
│   │   │   ├── ShareCardView.swift    # 分享统计卡片
│   │   │   ├── ShareSheet.swift       # 系统分享面板
│   │   ├── Transaction/               # 📝 记账
│   │   │   ├── Bills/                 # 新增/编辑/浏览账单，自定义数字键盘
│   │   │   │   ├── NumberPad.swift            # 数字键盘主体
│   │   │   │   └── NumberPadComponents.swift  # 键盘组件
│   │   │   └── Budget/                # 月度预算环形图 + 分类用量
│   │   ├── Tendency/                  # 📊 趋势
│   │   │   ├── TendencyModels.swift        # 数据点/时间跨度模型
│   │   │   ├── TrendCard.swift             # 可复用趋势卡片（5 档跨度 + 图表切换）
│   │   │   ├── TendencyChartView.swift     # 折线/柱状图
│   │   │   └── TendencyHeatmapView.swift   # 53 周热力图（月份标签随内容滚动）
│   │   ├── iCloudSync/iCloudSyncView.swift # ☁️ 云同步设置页（预留）
│   │   ├── Profile/ProfileView.swift  # 👤 个人中心（头像/昵称/密码）
│   │   ├── Setting/
│   │   │   ├── SettingView.swift      # ⚙️ 设置（主题/语言/生物锁/CSV 导入导出）
│   │   │   └── LanguageSettingView.swift  # 语言切换页（定义在 Helper/LocalizationHelper.swift）
│   │   └── Auth/LoginView.swift       # 🔑 登录/注册/Apple 登录
│   ├── Resources/
│   │   ├── Localization/              # 4 语言 .strings 资源
│   │   └── EconomicQuotes.json        # 经济名言数据集
│   └── Persistence.swift              # CoreData 控制器 + 用户标识符
│
├── iFinanceSwiftData/                 # 🧪 iOS SwiftData 版（独立 target）
│   ├── App/iFinanceSwiftDataApp.swift # 入口：认证路由 + 生物锁 + 主题/语言注入（不激活 Watch）
│   ├── Data/                          # @Model Bill / UserProfile + SwiftData 版 PersistenceController
│   ├── Manager/AuthManager.swift      # SwiftData 版认证管理器（API 与 Core Data 版一致）
│   ├── Views/                         # 由 iOS 版复制改造的视图层
│   └── Resources/                     # Info.plist + Assets（本地化与名言 JSON 共享 iOS 版）
├── iFinanceSwiftDataTests/            # Swift Testing：增删改查 / 账号隔离 / 预算聚合 / 密码哈希
├── MaciFinance/                       # 💻 macOS 应用
│   ├── MaciFinanceApp.swift           # 入口（NavigationSplitView 侧边栏）
│   ├── MaciFinance.entitlements       # App Sandbox 授权
│   ├── Manager/
│   │   ├── AuthManager.swift          # 登录/注册/Apple ID
│   │   └── CloudKitSyncManager.swift  # iCloud 同步管理器（预留，暂禁用）
│   ├── Models/                        # 分类枚举（支出 25 + 收入 11）
│   ├── Views/
│   │   ├── MainContentView.swift      # 侧边栏四项导航
│   │   ├── DashboardView.swift        # 仪表盘（今日概览 + 近期趋势图）
│   │   ├── BillListView.swift         # 账单明细 + 分类筛选
│   │   ├── AddBillSheet.swift         # 新增账单弹窗
│   │   ├── StatisticsView.swift       # 统计（周/月/年 · 折线图/柱状图切换）
│   │   ├── SettingsView.swift         # 设置（主题/语言/数据管理/测试数据生成）
│   │   ├── Auth/LoginView.swift       # 登录/注册/Apple 登录
│   │   ├── LanguageSettingView.swift  # 语言切换页
│   │   ├── iCloudSyncView.swift       # 云同步设置页（预留）
│   │   └── Common/AppVisualStyle.swift# 毛玻璃卡片统一视觉样式
│   ├── Helpers/L10n.swift             # Mac 端本地化辅助
│   ├── Resources/Localization/        # 4 语言 .strings 资源
│   └── Persistence.swift
│
└── WatchiFinance Watch App/           # ⌚ watchOS 应用
    ├── WatchiFinanceApp.swift         # 入口（自动激活 WCSession）
    ├── ContentView.swift              # 三 Tab：概览 / 快速记账 / 历史
    ├── L10n.swift                     # Watch 端本地化辅助
    ├── Models/WatchDataModel.swift    # WCSession Delegate + transferUserInfo 发送
    └── Resources/Localization/        # 4 语言 .strings 资源
```

---

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **SwiftUI** | 全部 UI 声明式构建，三端统一范式 |
| **CoreData** | 本地持久化，自动轻量迁移，多账号数据隔离 |
| **Swift Charts** | 折线图 / 柱状图 / 热力图 / 饼图 |
| **WatchConnectivity** | iPhone ↔ Watch 双向数据同步（`transferUserInfo` 可靠排队） |
| **CryptoKit** | 密码 SHA256 + Salt 哈希 |
| **LocalAuthentication** | Face ID / Touch ID 生物识别锁 |
| **AuthenticationServices** | Sign in with Apple |
| **Network.framework** | 网络状态实时监控 |
| **Combine** | `ObservableObject` + `@Published` 响应式数据流 |
| **UniformTypeIdentifiers** | CSV 导入导出 |
| **CloudKit / UserNotifications** | iCloud 同步与本地通知（预留，暂禁用） |

---

## 📦 Bundle ID 与版本

| Target | Bundle Identifier | 最低系统版本 | 营销版本 |
|--------|------------------|------------|---------|
| iOS | `cn.liube.iFinance` | iOS 18.0 – 27.x | 1.1 |
| iOS（SwiftData 版） | `cn.liube.iFinance.swiftdata` | iOS 18.0 – 27.x | 1.1 |
| macOS | `cn.liube.MaciFinance` | macOS 15.0 – 27.x | 1.1 |
| watchOS | `cn.liube.iFinance.watchkitapp` | watchOS 11.0 – 27.x | 1.1 |

---

## ⚙️ 构建要求

- **Xcode** 27（SDK：iOS 27 / macOS 27 / watchOS 27）
- **Swift** 5.0
- **最低系统版本**：iOS 18.0 / macOS 15.0 / watchOS 11.0（上限为各自 27.x）
- **外部依赖**：无（名言为本地 JSON，运行时不再发起网络图片请求）

## 🚀 快速开始

1. Clone 项目到本地
2. 用 Xcode 打开 `iFinance.xcodeproj`
3. 选择目标 Scheme 并编译：
   - `iFinance` → iOS 应用
   - `iFinanceSwiftData` → iOS SwiftData 版
   - `MaciFinance` → macOS 应用
   - `WatchiFinance Watch App` → watchOS 应用
4. **Cmd + R** 运行

> 两个 iOS 应用 Bundle ID 不同，可同时安装在同一台设备 / 模拟器上对比。

## 🧪 开发辅助脚本

- **`reset_ifinance_data.sh`** — 一键清除 iOS 模拟器中该 App 的所有账号与账单数据（用于开发调试，需先启动模拟器）

---

## 📊 数据模型

> 下表为 Core Data 版（iOS + macOS）与 SwiftData 版共用的字段契约；SwiftData 版以 `@Model` 类实现同名实体，并额外提供 `amountDouble` / `amountString` 计算属性以兼容 Core Data 版的读取写法。

**`Bill` 实体：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 唯一标识（幂等防重） |
| `amount` | Decimal | 金额 |
| `type` | String | `expenditure` / `income` / `transfer` |
| `category` | String? | 分类原始值 |
| `note` | String? | 备注 |
| `date` | Date? | 记账日期 |
| `createdBy` | String? | 账号标识（用户数据隔离键） |

**`UserProfile` 实体：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `userIdentifier` | String | 登录唯一标识 |
| `email` / `phone` | String? | 账号凭证 |
| `passwordHash` / `passwordSalt` | String? | SHA256 哈希密码 |
| `provider` / `providerID` | String? | 第三方登录（Apple） |
| `nickname` / `avatarData` | String? / Data? | 个人资料 |
| `monthlyBudget` | Double | 月度预算 |

---

## 📚 开发文档

| 文档 | 内容 |
|------|------|
| [AGENTS.md](AGENTS.md) | Agent 速用记忆：版本矩阵、构建命令、不可违反的约定、已知坑 |
| [docs/PROJECT_MEMORY.md](docs/PROJECT_MEMORY.md) | 深度项目记忆：架构、数据层、认证、跨端协议、国际化、技术债 |
| [docs/api/README.md](docs/api/README.md) | 接口文档索引与全局约定 |
| [docs/api/ios-core.md](docs/api/ios-core.md) · [ios-ui.md](docs/api/ios-ui.md) | iOS 核心层与视图层接口 |
| [docs/api/macos.md](docs/api/macos.md) · [watchos.md](docs/api/watchos.md) | macOS / watchOS 接口 |
| [docs/api/swiftdata.md](docs/api/swiftdata.md) | SwiftData 版数据层与视图层接口 |
| [docs/api/data-and-sync.md](docs/api/data-and-sync.md) | Core Data 模型、Watch 同步协议、CSV 格式 |

---

## 📝 License

MIT License

---

<p align="center">
  Made with ❤️ by <a href="#">刘不易</a>
</p>
