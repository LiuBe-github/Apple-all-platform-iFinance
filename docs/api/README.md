# 接口文档索引

> 生成依据：`fd6b1fb` 基线 + `codex/platform-18-27` 分支（三端版本适配与 SwiftData 版）。
> 项目背景、架构决策与已知问题见 [PROJECT_MEMORY.md](../PROJECT_MEMORY.md)；Agent 速用记忆见 [AGENTS.md](../../AGENTS.md)。

## 版本矩阵（2026-09 起）

| 目标 | 最低版本 | 上限 | Bundle ID |
|------|----------|------|-----------|
| iFinance（iOS） | iOS 18.0 | iOS 27.x | `cn.liube.iFinance` |
| iFinanceSwiftData（iOS，SwiftData） | iOS 18.0 | iOS 27.x | `cn.liube.iFinance.swiftdata` |
| MaciFinance（macOS） | macOS 15.0 | macOS 27.x | `cn.liube.MaciFinance` |
| WatchiFinance Watch App（watchOS） | watchOS 11.0 | watchOS 27.x | `cn.liube.iFinance.watchkitapp` |

构建 SDK 为 Xcode 27 的 iOS 27 / macOS 27 / watchOS 27。

## 文档地图

| 文档 | 覆盖范围 | 适用场景 |
|------|----------|----------|
| [ios-core.md](ios-core.md) | iOS 核心层：App 入口、Persistence、5 个 Manager、Models、Protocol、Helper | 改认证、数据层、生物锁、本地化、触觉反馈 |
| [ios-ui.md](ios-ui.md) | iOS 视图层：Home / Transaction(Bills, Budget) / Tendency / Profile / Setting / Auth / Common | 改界面、复用样式、调整图表与键盘 |
| [swiftdata.md](swiftdata.md) | iOS SwiftData 版：`@Model` 实体、SwiftData 版 AuthManager、视图改造点、测试 | 维护 / 对照 SwiftData 版 |
| [macos.md](macos.md) | macOS 端全部类型（含与 iOS 的差异对比） | 维护桌面端 |
| [watchos.md](watchos.md) | watchOS 端全部类型（含 Watch 端状态与缓存） | 维护手表端 |
| [data-and-sync.md](data-and-sync.md) | Core Data 模型、多账号隔离、iPhone ↔ Watch 协议、CSV 格式 | 改数据模型或跨端通信 |

## 阅读方式

每份文档的组织方式一致：

1. **文件清单表** —— 文件 / 类型 / 职责，用于快速定位。
2. **按类型分节** —— 职责一句话 → 声明原文 → 属性表 → 方法签名（逐字一致，含默认参数与 `throws`/`async`）→ 副作用与调用方 → 坑。
3. **`路径:行号` 引用** —— 所有事实均可回溯到源码；行号基于生成时的 HEAD，代码改动后可能偏移，此时以符号名搜索（`rg -n "<符号名>"`）为准。

## 全局通用约定

| 主题 | 约定 |
|------|------|
| 线程模型 | 所有 Manager 为 `@MainActor`；Core Data 操作统一在主上下文 `viewContext` 上执行 |
| 单例模式 | `static let shared` + `private init`（`AuthManager`、`BiometricLockManager`、`WatchSessionManager`、`WatchDataModel`、`CloudKitSyncManager`、`NotificationManager`、`HapticManager`） |
| 数据隔离 | `Bill.createdBy == UserDefaults["AuthUserIdentifier"]`，查询用 `PersistenceController.billUserPredicate` |
| 金额 | Core Data `Decimal`（`NSDecimalNumber`）；Watch 传输 `Double` |
| SwiftData 版 | 同名类型 + `@Model` 实现；`ModelContainer.viewContext` 与 `Bill.amountDouble` 为兼容层（详见 [swiftdata.md](swiftdata.md)） |
| 类型值 | `type ∈ {"expenditure", "income", "transfer"}`（注意模型默认值是中文「支出」） |
| 本地化 | `L10n.string(key)` 优先按用户在设置中选择的语言查找；三端各自维护 `.lproj` |
| 触觉反馈 | `HapticManager.shared.{light,medium,heavy,soft,rigid,success,warning,error,selectionChanged}()` |
| 视觉样式 | `appGlassCard(cornerRadius:)`、`.scalePress`、`AppBackgroundView`（各平台各一份实现） |
| 禁用功能 | `CloudKitSyncManager`、`NotificationManager` 为 stub（系统调用已注释），接口返回固定值 |

## 文档维护

- 新增/修改公开类型或方法签名、数据模型字段、Watch 协议 action、本地化 key 规则时，请同步更新对应文档。
- 若发现文档与代码不一致，以代码为准，并顺手修正文档中的 `路径:行号`。
- 建议在文档中保留「未覆盖 / 存疑」小节，标注无法从源码确认的推断。
