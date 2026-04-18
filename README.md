<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat-square" alt="Swift" />
  <img src="https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS-blue.svg?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Xcode-16+-blue.svg?style=flat-square" alt="Xcode" />
  <img src="https://img.shields.io/badge/min%20iOS-26.2-green.svg?style=flat-square" alt="iOS" />
  <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat-square" alt="License" />
</p>

<h1 align="center">iFinance</h1>

<p align="center">
  <strong>Apple 全平台个人记账应用</strong>
</p>

<p align="center">
  一款支持 iPhone、iPad、Mac、Apple Watch 的现代化个人财务管理工具<br/>
  简洁优雅的界面设计 · 多维度数据统计 · iCloud 全平台同步
</p>

---

## ✨ 功能特性

### 📱 核心功能
| 功能 | 描述 |
|------|------|
| **记账** | 自定义数字键盘，快速记录收入/支出，24 种支出分类 + 11 种收入分类 |
| **预算** | 月度预算管理，实时追踪已用额度与剩余比例 |
| **统计** | 周/月/年趋势图表（Swift Charts），收支双线对比 + 分类占比分析 |
| **账单** | 按日期分组展示账单明细，支持搜索、筛选、编辑、删除 |

### 🔐 安全与隐私
- **生物识别锁** — 支持 Face ID / Touch ID 应用锁定，前后台自动锁定
- **本地认证** — 邮箱/手机号注册登录，CryptoKit SHA256 密码哈希存储
- **社交登录** — 微信 / QQ / Apple 登录支持

### 🌍 国际化
支持 **4 种语言**：简体中文、繁體中文、English、日本語

### 🎨 界面设计
- **毛玻璃风格** — 自定义 `appGlassCard` 视觉组件，统一卡片样式
- **深色模式** — 完整适配 Light / Dark / 跟随系统三种主题
- **触觉反馈** — 9 种精细化 Haptic 反馈（按键/确认/成功/错误等）
- **经济名言** — 首页每日展示一条投资理财名言（沃伦·巴菲特 等）

### ☁️ 数据同步
- **CloudKit** — 基于 `NSPersistentCloudKitContainer` 的 iCloud 自动同步
- **多端共享** — iOS 与 Mac 共享同一套 Core Data 模型

---

## 📸 截图

> （待补充）

---

## 🏗️ 技术架构

```
iFinance/
├── iFinance/                          # 📱 iOS 主应用
│   ├── App/
│   │   └── iFinanceApp.swift          # 入口：认证流程 + 生物锁 + 主题 + 语言
│   ├── Models/                        # 数据模型层
│   │   ├── ExpenditureCategory.swift  # 24 个支出分类枚举 + SF Symbol 图标
│   │   ├── IncomeCategory.swift       # 11 个收入分类枚举
│   │   ├── ThemeMode.swift            # 主题模式（light/dark/system）
│   │   ├── DailySentence.swift        # 每日一句数据结构
│   │   └── NetworkMonitor.swift       # 网络状态监控（NWPathMonitor）
│   ├── Protocol/
│   │   └── TransactionCategory.swift  # 分类协议约束
│   ├── Manager/
│   │   ├── AuthManager.swift          # 认证管理器（注册/登录/密码/CryptoKit）
│   │   └── BiometricLockManager.swift # 生物识别锁屏管理器
│   ├── Helper/
│   │   ├── HapticManager.swift        # 触觉反馈单例（9 种反馈类型）
│   │   └── LocalizationHelper.swift   # L10n 国际化辅助
│   ├── Views/
│   │   ├── Home/HomeView.swift        # 🏠 首页仪表盘（35KB，核心页面）
│   │   ├── Transaction/
│   │   │   ├── TransactionView.swift  # 📝 记账页
│   │   │   ├── Bills/
│   │   │   │   ├── AddBillView.swift      # 新增账单
│   │   │   │   ├── EditBillView.swift     # 编辑账单
│   │   │   │   ├── BillsCardView.swift    # 账单列表卡片
│   │   │   │   ├── NumberPad.swift         # 自定义数字键盘
│   │   │   │   ├── ExpenditureCategoryItemView.swift
│   │   │   │   └── IncomeCategoryItemView.swift
│   │   │   └── Budget/
│   │   │       ├── BudgetView.swift       # 预算管理
│   │   │       ├── BudgetCardView.swift
│   │   │       └── HaveSpentCardView.swift
│   │   ├── Tendency/TendencyView.swift # 📊 统计趋势图（Charts）
│   │   ├── Profile/ProfileView.swift   # 👤 个人中心
│   │   ├── Setting/SettingView.swift   # ⚙️ 设置页
│   │   ├── Auth/LoginView.swift        # 🔑 登录注册
│   │   └── Common/AppVisualStyle.swift  # 全局视觉样式定义
│   ├── Resources/
│   │   ├── Localization/              # 多语言资源（4 语言）
│   │   └── EconomicQuotes.json         # 经济名言数据集
│   └── Persistence.swift              # CoreData 持久化控制器
│
├── MaciFinance/                       # 💻 macOS 应用
│   ├── MaciFinanceApp.swift           # 入口（NavigationSplitView 布局）
│   ├── Models/                        # 共享模型（分类/主题/协议）
│   ├── Helpers/L10n.swift             # Mac 本地化辅助
│   ├── Views/
│   │   ├── MainContentView.swift       # 侧边栏导航
│   │   ├── DashboardView.swift         # 仪表盘
│   │   ├── BillListView.swift          # 账单列表
│   │   ├── AddBillSheet.swift          # 新增账单弹窗
│   │   ├── StatisticsView.swift        # 统计分析
│   │   └── SettingsView.swift          # 设置
│   └── Persistence.swift
│
├── WatchiFinance Watch App/           # ⌚ watchOS 应用（规划中）
│
└── README.md
```

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| **SwiftUI** | 全部 UI 声明式构建 |
| **CoreData** | 本地持久化（NSPersistentCloudKitContainer） |
| **CloudKit** | iCloud 多设备同步 |
| **Swift Charts** | 趋势图 / 柱状图 / 占比图 |
| **Nuke** (`kean/Nuke`) | 高性能图片加载与缓存 |
| **CryptoKit** | 密码 SHA256 哈希 |
| **LocalAuthentication** | Face ID / Touch ID |
| **Network.framework** | 网络状态监控 |
| **Combine** | 响应式数据流 |

## ⚙️ 构建要求

- **Xcode** 16+
- **iOS** 26.2+ / **macOS** 26.2+ / **watchOS** —
- **Swift** 5.0
- **SPM 依赖**：
  ```
  https://github.com/kean/Nuke (v12.8.0)
  ```

## 🚀 快速开始

1. Clone 项目到本地
2. 用 Xcode 打开 `iFinance.xcodeproj`
3. 选择目标 scheme：
   - `iFinance` → 运行 iOS 应用
   - `MaciFinance` → 运行 macOS 应用
4. **Cmd + R** 编译运行

## 📦 Bundle ID & 版本

| Target | Bundle Identifier | 版本 |
|--------|-----------------|------|
| iOS | `cn.liube.iFinance` | 1.1 |
| macOS | `cn.liube.MaciFinance` | 1.1 |
| watchOS | `cn.liube.iFinance.watchkitapp` | 1.1 |

## 📝 License

MIT License

---

<p align="center">
  Made with ❤️ by <a href="#">刘不易</a>
</p>
