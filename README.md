<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue.svg?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Xcode-16+-blue.svg?style=flat-square" alt="Xcode" />
  <img src="https://img.shields.io/badge/min%20iOS-17.6-green.svg?style=flat-square" alt="iOS" />
  <img src="https://img.shields.io/badge/min%20watchOS-10.0-green.svg?style=flat-square" alt="watchOS" />
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
| **每日一句** | 首页展示经济名言（沃伦·巴菲特等），配随机风景图（三级缓存 + 图片降采样），支持一键分享今日统计卡片 |
| **今日结余卡片** | 首页顶部紧凑展示当日收入/支出/结余/笔数 |

### ⌚ Apple Watch 快速记账

- **三 Tab 设计**：今日概览 / 快速记账 / 当日历史
- **精简数字键盘**：3×4 网格键盘，直接腕上输入金额
- **横向分类滚动**：支出 6 项 + 收入 4 项快捷分类
- **实时同步**：通过 `WatchConnectivity` 的 `transferUserInfo` 可靠传输至 iPhone
- **完整本地化**：Watch 端独立 `Localizable.strings`，支持 4 种语言

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

支持 **4 种语言**，应用内实时切换，无需重启，三端（iOS / macOS / watchOS）全覆盖：

| 语言 | 标识 |
|------|------|
| 简体中文 | `zh-Hans` |
| 繁體中文 | `zh-Hant` |
| English | `en` |
| 日本語 | `ja` |

### 🎨 界面设计

- **毛玻璃风格** — 自定义 `appGlassCard` 修饰器，统一三端卡片样式
- **深色模式** — 完整适配 Light / Dark / 跟随系统三档主题
- **触觉反馈** — 9 种精细化 Haptic 反馈（按键/确认/成功/错误等）
- **数字动画** — `contentTransition(.numericText())` 金额变化平滑过渡

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
│   │   └── NetworkMonitor.swift       # 网络状态监控（NWPathMonitor）
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
│   │   │   ├── HomeView.swift         # 今日结余 + 名言卡片 + 分享
│   │   │   ├── TodayBalanceCard.swift # 今日结余卡片
│   │   │   ├── SentenceCardView.swift # 名言卡片（随机风景图）
│   │   │   ├── ShareCardView.swift    # 分享统计卡片
│   │   │   ├── ShareSheet.swift       # 系统分享面板
│   │   │   ├── ImageLoader.swift      # 图片异步加载（Combine）
│   │   │   ├── ImageCache.swift       # 图片三级缓存
│   │   │   └── ImageDownsampler.swift # 图片降采样（内存优化）
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
│   │   │   └── Language/LanguageSettingView.swift  # 语言切换页
│   │   └── Auth/LoginView.swift       # 🔑 登录/注册/Apple 登录
│   ├── Resources/
│   │   ├── Localization/              # 4 语言 .strings 资源
│   │   └── EconomicQuotes.json        # 经济名言数据集
│   └── Persistence.swift              # CoreData 控制器 + 用户标识符
│
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
| **Nuke** (`kean/Nuke v12.8.0`) | 高性能图片加载与三层缓存（SPM 依赖） |
| **UniformTypeIdentifiers** | CSV 导入导出 |
| **CloudKit / UserNotifications** | iCloud 同步与本地通知（预留，暂禁用） |

---

## 📦 Bundle ID 与版本

| Target | Bundle Identifier | 最低系统版本 | 营销版本 |
|--------|------------------|------------|---------|
| iOS | `cn.liube.iFinance` | iOS 17.6 | 1.1 |
| macOS | `cn.liube.MaciFinance` | macOS 15+ | 1.1 |
| watchOS | `cn.liube.iFinance.watchkitapp` | watchOS 10+ | 1.1 |

---

## ⚙️ 构建要求

- **Xcode** 16+
- **Swift** 5.0
- **SPM 依赖**：`https://github.com/kean/Nuke`（v12.8.0）

## 🚀 快速开始

1. Clone 项目到本地
2. 用 Xcode 打开 `iFinance.xcodeproj`
3. 选择目标 Scheme 并编译：
   - `iFinance` → iOS 应用
   - `MaciFinance` → macOS 应用
   - `WatchiFinance Watch App` → watchOS 应用
4. **Cmd + R** 运行

## 🧪 开发辅助脚本

- **`reset_ifinance_data.sh`** — 一键清除 iOS 模拟器中该 App 的所有账号与账单数据（用于开发调试，需先启动模拟器）

---

## 📊 数据模型

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

## 📝 License

MIT License

---

<p align="center">
  Made with ❤️ by <a href="#">刘不易</a>
</p>
