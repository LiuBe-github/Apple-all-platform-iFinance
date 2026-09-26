# 记忆文件夹（memory/）

> 用途：把「这次协作里发生了什么、为什么这么做、还剩什么没做」沉淀下来，供**下一位 agent 或下一次会话**直接接手。
> 创建时间：2026-09-26 ｜ 覆盖范围：`codex/platform-18-27` 分支全部 22 次提交

## 与其它文档的分工

| 想知道什么 | 看哪里 |
|------------|--------|
| **刚接手这个项目** | [docs/HANDOFF.md](../docs/HANDOFF.md)（交接清单、环境准备、验证标准） |
| 产品要做什么、怎么验收 | [docs/PRD.md](../docs/PRD.md) |
| 代码怎么组织、有哪些坑 | [docs/PROJECT_MEMORY.md](../docs/PROJECT_MEMORY.md)、[AGENTS.md](../AGENTS.md) |
| 某个类型的接口/签名 | [docs/api/](../docs/api/README.md) |
| **这次为什么这么改、还剩什么** | **本文件夹** |

## 文件索引

| 文件 | 内容 | 什么时候读 |
|------|------|-----------|
| [project-context.md](project-context.md) | 项目速查：四端矩阵、技术栈、目录、常用命令、关键文件导航 | 刚接手项目时先读这份 |
| [decision-log.md](decision-log.md) | 决策记录：本次协作中每个关键选择及其理由（含被否决的方案） | 想改动某块设计前先看这里，避免推翻既有共识 |
| [work-history.md](work-history.md) | 工作历史：22 次提交分别做了什么、验证到什么程度 | 想了解「某个功能是怎么来的」 |
| [open-items.md](open-items.md) | 未完成事项、风险与验证欠账（按优先级） | 规划下一步时 |
| [environment.md](environment.md) | 本机环境与验证能力边界（Xcode/模拟器/真机/脚本） | 准备跑构建、测试、真机部署前 |
| [working-agreements.md](working-agreements.md) | 与用户的协作偏好与踩过的协作坑 | 开始新一轮对话前 |

## 维护约定

1. **每次改动完成后更新 `work-history.md`**（追加一行：提交 + 内容 + 验证）。
2. **做出产品/技术取舍时更新 `decision-log.md`**（写明决策、理由、影响范围）。
3. **新增待办或修完待办时更新 `open-items.md`**（保持状态真实：未做就是未做）。
4. 环境变化（Xcode 升级、运行时安装、设备更换）更新 `environment.md`。
5. 本文件夹是**会话记忆**，不重复 [docs/PRD.md](../docs/PRD.md) 的功能清单，也不重复 [docs/api/](../docs/api/README.md) 的接口签名。

## 一分钟接手清单

```bash
git switch codex/platform-18-27        # 当前工作分支（未推送远端）
git log --oneline -22                  # 看这次协作的提交
python3 scripts/check_localization.py  # 本地化体检（应四 target 全过）
xcodebuild build -project iFinance.xcodeproj -scheme iFinance -destination 'generic/platform=iOS Simulator'
```

读完后，如果只记三件事：

1. **四端矩阵**：iOS 18–27（主版本 + SwiftData 版）、macOS 15–27、watchOS 11–27；
2. **两条铁律**：账单 `type` 与 `category` 必须匹配（`BillEditRules`）；新增文案必须用 `L10n.string`；
3. **最紧的待办**：微信/QQ 登录目前是「点击即新建账号」的占位实现（见 [open-items.md](open-items.md) 的 OI-01）。
