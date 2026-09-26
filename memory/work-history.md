# 工作历史（codex/platform-18-27）

> 分支起点：`main` @ `fd6b1fb` ｜ 当前共 **18 次提交**，`169 files changed, +18581 / −2030`
> 分支未推送远端。每次完成新改动请**在表尾追加一行**；由于提交哈希在写入文件时尚未生成，最新一行用「*(最新一次提交)*」占位，**下次提交时把真实 SHA 回填到上一行**。
> 历史行的 SHA 已核对：1~17 可直接用于 `git show`。

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
| 11 | `bd84c95` | perf | 背景动画共享时钟（30fps→10fps、非活跃暂停、RadialGradient 替代 blur）；头像解码缓存；Formatter 静态化；分类网格 Equatable 拆分；TrendCard 单次遍历；SettingView 拆子视图 | 四端编译；三套测试；冒烟 |
| 12 | `95d2475` | feat | 个性签名：三份模型加 `signature` 字段，`AuthManager.signature/updateSignature/validateSignature`（40 字上限），设置页头部显示 + 点击编辑 + 个人中心入口 | 新增边界单测；三套测试；审计通过 |
| 13 | `5167091` | perf(dev) | 关闭 `SWIFT_EMIT_LOC_STRINGS` / `STRING_CATALOG_GENERATE_SYMBOLS`（全量设备构建 25.1s→23.9s）；新增 `scripts/run-on-device.sh`（跳过 Watch 部署与调试器附加）；修复 macOS 偶发测试失败（`DashboardLogicTests` 加 `.serialized`） | 实测构建耗时；四端编译；三套测试 |
| 14 | `52f6c36` | fix | 记账键盘「运算符后无法继续输入数字」：抽出 `NumberPadExpression`（按当前数字段校验）、修正运算符首按语义 | 新增 9+2 条单测（含复现用例与四则运算）；三套测试 |
| 15 | `1953919` | feat | 趋势页新增支出/收入分类占比饼图（独立跨度、完整列表、点选高亮），删除折线图与图表类型切换器；预算页饼图改用同一组件；新增 `CategoryBreakdown` 纯逻辑 | 新增 4+2 条聚合单测；四端编译；三套测试；审计通过 |
| 16 | `509b9cf` | fix | 编辑页：分类改推入式选择页（只列当前类型分类）、类型切换清空并要求重选、类型补转账、日期精确到时分；新增 `BillEditRules` 归一化旧脏数据 | 新增 3+3 条规则单测；四端编译；三套测试；审计通过 |
| 17 | `db152dd` | docs | 新增 `docs/PRD.md`（11 模块功能需求、10 条业务规则、验收清单、路线图、已知限制）并接入 README / AGENTS / PROJECT_MEMORY 索引 | 11 个 markdown 链接校验 |
| 18 | *(最新一次提交)* | docs | 根据本次协作历史建立 `memory/` 记忆文件夹（7 份：索引 / 速查 / 决策 / 工作历史 / 待办 / 环境 / 协作约定） | 18 个 markdown 链接校验通过（仅文档改动，未跑构建） |

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
