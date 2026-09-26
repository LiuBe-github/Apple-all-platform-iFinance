# 待办与风险（open-items）

> 状态：🔴 高优先级/有隐患 ｜ 🟡 待排期 ｜ ⚪ 可选优化 ｜ ✅ 已完成（保留记录）
> 更新规则：做完就改状态并注明提交号；新增待办追加到对应分区。

## A. 产品缺口（需要外部条件）

| 编号 | 事项 | 状态 | 前置条件 | 建议动作 |
|------|------|------|----------|----------|
| OI-01 | **微信 / QQ 登录已降级为「即将支持」**：按钮点击仅提示，`loginWithProvider` 仅放行 Apple；**真实接入仍未实现** | 🟡 | 微信开放平台（企业主体 + 300 元/年认证）、QQ 互联（免费审核）、**服务端**换 token、URL Scheme / Universal Link | 有服务端后按 PRD §7.2 接入，移除视图提示与 AuthManager 的 `.apple` 限制 |
| OI-02 | 邮箱绑定无验证码流程（只验证密码） | 🟡 | 服务端下发/校验 + 发信服务（Resend/SendGrid 免费额度）+ 发信域名 SPF/DKIM | 有服务端后按 PRD §7.3 实现 |
| OI-03 | CloudKit 同步与本地通知被禁用（保留 stub） | 🟡 | 付费开发者账号（CloudKit 容器 + 推送） | 升级账号后恢复被注释的系统调用；同步需切 `NSPersistentCloudKitContainer` 或自建方案 |
| OI-04 | macOS CSV / JSON 导出仍是 TODO | 🟡 | 无 | 参照 iOS 的 `BillCSVDocument` 实现（`MaciFinance/Views/SettingsView.swift:158`） |
| OI-05 | Watch 离线账单**不会补传**（不可达时只写本地缓存） | 🟡 | 无 | 增加发送队列 + `sessionReachabilityDidChange` 时重试 |
| OI-06 | iPad 未做分栏 / 多窗口适配（仅内容宽度居中） | ⚪ | 无 | 需要时再评估 `NavigationSplitView` 方案 |
| OI-07 | 无埋点与崩溃上报 | ⚪ | 需第三方或自建服务 | 当前依赖本地 `Logger` 与系统诊断报告 |

## B. 代码缺陷与不一致（已知、未修）

| 编号 | 事项 | 状态 | 说明 / 位置 |
|------|------|------|-------------|
| OI-10 | 工程存在无对应文件的遗留 scheme `Copy of iFinance` | ⚪ | 可在 Xcode 中删除 |
| OI-11 | 两版 iOS 视图为**同名副本**（`iFinance/Views` 与 `iFinanceSwiftData/Views`），改一处需手工同步另一处 | 🟡 | 已有约定与文档；可考虑写一个「两版视图一致性检查」脚本（类似本地化审计） |
| OI-12 | macOS 端未同步 iOS 的两项新规则：趋势页分类占比饼图、编辑页类型/分类联动（macOS 只有新增账单弹窗） | ⚪ | 若要求三端体验一致再补 |

## C. 验证欠账（环境限制导致）

| 编号 | 事项 | 状态 | 现状 |
|------|------|------|------|
| OI-13 | 上界验证：iOS 27 / watchOS 27 无法本机运行 | 🟡 | 运行时不可下载（见 [environment.md](environment.md)）；目前仅编译级验证，建议真机验证后回填结论 |
| OI-14 | 下界验证：macOS 15 / watchOS 11 无法本机运行 | 🟡 | 仅编译 + API 可用性审查 |
| OI-15 | UI 测试在 Xcode 27 克隆模拟器上崩溃（XCTest ↔ Swift Testing 互操作递归） | 🟡 | 属工具链问题；日常验证用 `-only-testing:` 跳过 UI 测试 |
| OI-16 | 测试必须串行执行（并行会互相干扰） | 🟡 | 已写入 AGENTS 坑表；如接入 CI 需注意 |

## D. 已完成（保留记录，便于回溯）

| 编号 | 事项 | 完成于 |
|------|------|--------|
| ✅ OI-17 | 三端版本适配（iOS 18 / macOS 15 / watchOS 11 → 27） | `00a565d` |
| ✅ OI-18 | SwiftData 版（独立 target、功能对齐、独立测试） | `00a565d` |
| ✅ OI-19 | 动画/布局 token 化 + Reduce Motion 降级 | `bd083b5` |
| ✅ OI-20 | 后台隐私遮罩（仅应用锁开启时） | `219fdb6` |
| ✅ OI-21 | 首页去图片化 + 概况/周期/一言三卡结构 | `b10f146`、`d520586` |
| ✅ OI-22 | 语言切换后部分文字不跟随（根因：两套本地化机制） | `30392f8` |
| ✅ OI-23 | 切页面/开键盘卡顿（背景共享时钟、头像缓存等） | `bd84c95` |
| ✅ OI-24 | 真机构建/部署慢（实为部署阶段 + Watch 推送） | `5167091` |
| ✅ OI-25 | 记账键盘「运算符后无法输入数字」 | `52f6c36` |
| ✅ OI-26 | 趋势页分类占比饼图 + 删除折线图 | `1953919` |
| ✅ OI-27 | 编辑页分类选择页 + 类型联动 + 日期到时分 | `509b9cf` |
| ✅ OI-28 | 个性化：头像裁剪、个性签名、设置页昵称、两位小数百分比 | `b275f02`、`95d2475` |
| ✅ OI-09 | `reset_ifinance_data.sh` Bundle ID 修正为 `cn.liube.iFinance`（12 处） | `f082fce` |
| ✅ OI-08 | iOS 主版本 CSV 导入补齐 `createdBy` 等字段 + `en_US_POSIX` 拼写 + 抽 `CSVImporter` 补测试 | *(第 22 次提交)* |
| ✅ OI-29 | CSV 解析不支持 CRLF（Windows/Excel 导出被当成单行）——修 `parseRows` 换行判断并补 LF 回归用例（两版同步） | *(第 22 次提交)* |

## E. 下一步建议（按性价比排序）

1. **OI-01 剩余部分（半天以内决策）**：占位建号隐患已消除（已降级为提示）；真实接入需等服务端与开放平台资质。
2. **OI-05（1~2 天）**：Watch 离线补传——已定方向为直接依赖 `transferUserInfo` 系统队列（去掉 `isReachable` guard），见 [decision-log.md](decision-log.md) D-48。
3. **OI-13/OI-14**：用真机把上界（iOS 27 / watchOS 27）与下界（macOS 15 / watchOS 11）验证结论回填到 PRD 与 memory。
4. 若启动新一轮 UI 大改，先读 [decision-log.md](decision-log.md) 的 D-10~D-13，避免推翻设计 token 体系。
