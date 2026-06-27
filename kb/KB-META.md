---
type: Schema
title: ai-rd-system 知识库总览
description: KB-META.md — 知识库"灵魂层",定义知识表示、SKILL 工作规范、评测闭环
tags: [schema, okf, kb-meta, ai-rd-system]
created: 2026-06-26
updated: 2026-06-26
version: 0.1
---

# KB-META.md — ai-rd-system 知识库总览

> **本文件是整个 KB 的"灵魂层"** —— 写给 LLM/agent 的工作规范。
> 不是给人类读的目录(那是 `index.md`),也不是操作日志(那是 `log.md`)。

---

## 0. 我们用什么设计

**ai-rd-system 的 KB 三层架构**(融合阿里 + Karpathy + Google 三家所长):

```
┌─────────────────────────────────────────────┐
│ L3 Schema 灵魂层 (本文件 KB-META.md)        │
│ - 知识表示规范 / SKILL 工作流 / 评测闭环      │
├─────────────────────────────────────────────┤
│ L2 Wiki 数据层                              │
│ - kb-md/ (原始 md) + kb/ (LLM 维护的概念)    │
│ - entities/ concepts/ sources/ code/ queries│
│ - index.md (目录) log.md (变更日志)          │
├─────────────────────────────────────────────┤
│ L1 Raw 原始层 (只读)                         │
│ - kb-source/ (NAS 镜像,只读不可修改)         │
│ - kb-md/ (转换产物,只读)                    │
└─────────────────────────────────────────────┘
```

**三家借鉴表**:

| 层 | 采用 | 来源 |
|----|------|------|
| 格式层 | OKF v0.1(markdown + YAML frontmatter + index/log) | Google Cloud 2026-06-12 |
| 灵魂层 | 阿里 KB-META.md(codeRepo/outputPath/templatePath/relatedKBs) | 阿里团队 2026 |
| 评测层 | 阿里 4 层闭环 + Google Measurable Context Eval | 阿里 + Google |

---

## 1. 知识表示规范(OKF v0.1 兼容)

### 1.1 Frontmatter 字段(必填)

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | string | ✅ | Concept 类型。OKF v0.1 不注册,自由字符串。**Consumer MUST tolerate unknown** |
| `title` | string | ✅ | 人类可读名称 |
| `description` | string | ✅ | 一句话摘要(<= 200 字) |
| `created` | date | ✅ | 创建时间 ISO 8601 |
| `updated` | date | ✅ | 最后更新时间 ISO 8601 |

### 1.2 Frontmatter 字段(推荐)

| 字段 | 类型 | 说明 |
|------|------|------|
| `resource` | string | 外部系统 URI(项目路径、文件路径、API endpoint) |
| `tags` | list[string] | 自由 tag,用于过滤/聚合 |
| `related` | list[string] | 双向链接 `[[path/to/other-concept]]` |
| `source_file` | string | 原始 L1 路径(可追溯) |
| `tier` | enum | `final / draft / archived` |
| `language` | enum | `zh / en / mixed` |
| `version` | string | KB 版本号 |

### 1.3 Frontmatter 字段(ai-rd-system 扩展)

| 字段 | 类型 | 说明 |
|------|------|------|
| `kb` | enum | `kb-md / kb / raw` 标识所在层 |
| `doc_type` | enum | `pdf / docx / xlsx / pptx / doc / ppt / xls / txt / log` |
| `scan_status` | enum | `native / scanned`(是否扫描件 PDF) |
| `year` | int | 文档年份(从 NAS 路径抽出) |
| `project` | string | 项目归属(如"浦东嘉里中心") |
| `cross_refs` | list[string] | 交叉引用(RFI 链等) |
| `entities` | list[string] | 实体识别结果(人名、公司、项目) |
| `quality_score` | float | LLM 评估质量分 0-1 |

### 1.4 type 枚举(ai-rd-system 用,OKF 兼容)

我们用以下 `type` 值,**但不强制,新增自由**:

| type | 用途 | 目录 |
|------|------|------|
| `Schema` | 灵魂层 / 规范文档 | `kb/` |
| `Concept` | 业务/技术概念页 | `kb/concepts/` |
| `Entity` | 实体页(模块、类、人物、公司) | `kb/entities/` |
| `Source` | 文档摘要(NAS 原始文档的 LLM 摘要) | `kb/sources/` |
| `Module` | 模块概述 | `kb/code/modules/` |
| `Class` | 核心类详情 | `kb/code/classes/` |
| `Query` | 有价值的问答存档 | `kb/queries/` |
| `Playbook` | 流程性文档(类似 SOP) | `kb/playbooks/` |
| `Plan` | 设计方案 | `kb/plans/` |

### 1.5 链接形式(OKF 推荐)

**优先用 bundle-relative 路径**(以 `/` 开头):

```markdown
参考 [[/concepts/curtain-wall-thermal-insulation]] 和 [[/sources/rfi-185]]。
```

**也接受 Obsidian 风格** `[[双链]]`:

```markdown
参考 [[curtain-wall-thermal-insulation]] 和 [[rfi-185]]。
```

**两者在我们的 KB 里都允许**,但推荐 bundle-relative(OKF 标准)。

**Plan 专属链接约定**(SKILL 2 使用):

```markdown
related_prd: "[[/kb/prds/<slug>]]"              # 双向链接回 PRD
reference_projects:                              # 引用的 baseline KB Source
  - "[[/kb/sources/<year>/<slug>]]"
```

注意:`/kb/` 前缀(因为 PRD / Source 都在 `kb/` 下,而 `kb/concepts/` 不带),bundle-relative 起点是 repo 根。

### 1.6 Plan type 专属 frontmatter 字段(SKILL 2 约束)

`type=Plan` 的页面**必须含下列字段**(在通用 7 字段之上):

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `plan_type` | enum | ✅ | 子类型:`tech-solution` / `architecture-design` / `pricing-update` / 等 |
| `related_prd` | string | ✅ | 双向链接 `[[/kb/prds/<slug>]]`,**SKILL 2 Hard Gate #7 强制** |
| `reference_projects` | list[string] | ✅ | baseline slug 列表(从 KB 反查),**至少 1 个** |
| `total_quote_cny` | float | ⚠️ 按需 | 造价类方案必填(总价),其他类型可省 |
| `confidence_score` | float | ✅ | 0-1,**Phase 1 反查输出**,< 0.7 触发风险标注 |
| `risk_flags` | list[string] | ✅ | 结构化风险标签(对应正文 §5),**与正文风险表行数 = N:1 关系** |
| `summary_table` | string | ✅ | 摘要表(纯文本 markdown 表格),**SKILL 2 phase 2 输出的 summary_table 直接落 frontmatter** |
| `unit_price_analysis` | list[dict] | ⚠️ 按需 | 造价类方案必填,每子系统 5 分项 `{subsystem, labor_pct, material_pct, machine_pct, management_pct, profit_pct, unit_cny_per_m2}`,**每个百分比必须 ≥ 1 个 KB Source 引用**(SKILL 2 字段约束) |
| `breakdown_by_subsystem` | dict | ⚠️ 按需 | 造价类方案必填,`{subsystem_name: pct}`,各 pct 之和应 = 100 |

**Plan 9 段强制结构**(SKILL 2 Phase 3 输出模板):

```
## 1. 方案摘要 (Summary)        — 核心结论 + 适配场景 + 关键风险数
## 2. 计算模型 (Calculation)     — baseline 数据 + 子系统分解 + 敏感性
## 3. 关键技术决策 (Tech Decisions) — 子系统决策 + 设计标准 + 工艺路线
## 4. 实施步骤 (Implementation)  — 阶段划分 + 关键路径
## 5. 风险点与对策 (Risks)       — 表格,行数 = frontmatter risk_flags 数
## 6. 不适用范围 (Out of Scope)  — ≥ 3 行排除条款
## 7. 验收标准 (Acceptance)      — 对应 PRD §6,逐条 [x]
## 8. 维护与版本 (Maintenance)   — 基线年度 + 刷新触发 + 降级路径
## 9. 关联 KB (References)       — PRD + Source + 后续 SKILL
```

**Plan 与 Source / PRD 的关系**:

```
PRD (kb/prds/<slug>.md)         — 需求输入
  ↓ kb-tech-solution (SKILL 2)
Plan (kb/plans/<slug>-v<N>.md)  — 技术方案
  ↓ kb-tech-review (SKILL 3)    — 评审
Plan.status = active            — 通过评审
  ↓ kb-just-coding (SKILL 4)    — 落地编码
```

---

## 2. 目录结构(OKF 兼容)

```
kb/                              # 知识库 vault (LLM 维护)
├── KB-META.md                   # 本文件:灵魂层 / schema
├── CLAUDE.md                    # SKILL 工作规范(给 Claude/agent 看)
├── index.md                     # 内容目录(给人类浏览)
├── log.md                       # 变更日志(谁/何时/改了什么)
├── README.md                    # 快速开始(团队 onboarding)
│
├── concepts/                    # 业务/技术概念
│   ├── curtain-wall-system.md
│   ├── thermal-insulation-types.md
│   └── ...
│
├── entities/                    # 实体(模块/类/人物/公司)
│   ├── people/
│   │   ├── jack-wu.md
│   │   └── sun-cheng.md
│   ├── companies/
│   │   ├── kpf.md
│   │   └── andes-glass.md
│   └── projects/
│       ├── pudong-kerry-centre.md
│       └── changzhou-hotel.md
│
├── sources/                     # NAS 原始文档的 LLM 摘要
│   ├── 2012/
│   │   ├── rfi-185-pudong-kerry-thermal.md
│   │   ├── shnm-north-glass-review.md
│   │   └── ...
│   └── 2013/
│       └── ...
│
├── code/                        # 代码知识化(暂未启用)
│   ├── modules/
│   └── classes/
│
├── queries/                     # 有价值的问答存档
│   └── ...
│
├── playbooks/                   # 流程性 SOP
│   ├── convert-nas-year.md
│   └── lo-retry-failed.md
│
└── plans/                       # 设计方案
    └── ...
```

**OKF 保留文件名**:
- `index.md` — 目录(§6 OKF spec)
- `log.md` — 变更日志(§7 OKF spec)

**其他都是概念文档**。

---

## 3. KB 内容源映射

| 来源 | 处理 | 落地 |
|------|------|------|
| `kb-source/` (NAS 镜像) | 只读,**不可改** | - |
| `kb-md/` (转换产物) | `scripts/convert_year.sh` 转出来 | - |
| `kb/sources/<year>/` | LLM 读 `kb-md/<year>/<file>.md` 生成摘要 | 写 concept 页 |

**未来 KB 应该是 "从 kb-md 自动 enrich"**,不是手动抄。

---

## 4. 8 个 SKILL 拆法(待写)

**对照阿里 8 个 SKILL**(待 Phase 3 启动后逐个写):

| # | SKILL | 角色 | 输入 | 输出 |
|---|-------|------|------|------|
| 1 | `kb-doc-summary` ⭐ | 文档摘要师 | md 文件 | `kb/sources/<year>/<slug>.md` concept 页 |
| 2 | `kb-tech-solution` | 资深架构师 | PRD | 技术方案 |
| 3 | `kb-tech-review` | 严格评审员 | 技术方案 | 评审意见 + 修改建议 |
| 4 | `kb-just-coding` | 编码工程师 | 技术方案 | 代码 + CR 自查清单 |
| 5 | `kb-test-pre` | 测试工程师 | 技术方案 + PRD | 测试用例 + 回归点 |
| 6 | `kb-problem-solve` | 故障排查员 | SLS/log + 现象 | 根因 + 修复方案 |
| 7 | `kb-architecture-design` | 架构师 | 业务背景 | 架构图 + 模块拆分 |
| 8 | `kb-just-ask` | 答疑助手 | 用户问题 | 引用 KB 的答案 |

**附加 SKILL**(KB 维护):

| # | SKILL | 用途 |
|---|-------|------|
| +1 | `kb-test-fix` | 测试修复(失败用例 → 修代码或修用例) |
| +1 | `kb-sync` | KB 同步(原始 md 变更 → 更新 concept 页) |

每个 SKILL 都要:
- 有 frontmatter 触发条件(`description` + `when to use` + `do NOT use for`)
- 有 hard gate(三要素齐全才能继续)
- 有 phase 流程(Phase 0/1/2/...)
- 有输出前自查清单
- 有评测指标

**当前 SKILL 编写进度**:

- [x] `kb-doc-summary` v0.1(8.3K)—— Phase 3 commit `e903fb5` 后写
- [ ] `kb-tech-solution` v0.1
- [ ] `kb-tech-review` v0.1
- [ ] `kb-just-coding` v0.1
- [ ] `kb-test-pre` v0.1
- [ ] `kb-problem-solve` v0.1
- [ ] `kb-architecture-design` v0.1
- [ ] `kb-just-ask` v0.1
- [ ] `kb-test-fix` v0.1
- [ ] `kb-sync` v0.1

---

## 5. 评测闭环(阿里 4 层 + Google Measurable)

**4 层 evaluation-driven 闭环**:

```
L1 结构层  ──→  L2 实用层  ──→  L3 信号层  ──→  L4 治理层
lint + schema_gate      15 task gold 集     3σ₀ 提升阈值       ≥10 页变更必更 log.md
(每次 KB 变更)          (r-N evaluation)    (真改进才信)       (PR 写动机)
```

### L1 结构层(每次 KB 变更跑)

- `schema_gate.py`:所有 concept 页 frontmatter 必填字段齐
- `lint.py`:矛盾 / 孤页 / 缺失 / 过时检测
- **不通过直接红灯,PR 阻塞门**

### L2 实用层(15 task gold 集)

- 15 个固定 task(每个对应一类问题)
- 每次 KB 变更跑 r-N evaluation(rank-N 命中率)
- **基线对比**,看是否退化

### L3 信号层(3σ₀ 阈值)

- 任务提分需过 3σ₀ 才算"真改进"
- 避免小幅波动被误判为"改进"

### L4 治理层(变更驱动)

- ≥10 页变更必更新 `log.md` + PR 写动机
- 防止"KB 静默增长"

**Google Measurable Context Evaluation**:
- 检索延迟 < 1s
- 检索精度 NDCG@10 评分
- access control-aware search(权限)

---

## 6. 现状与下一步

### 当前状态(2026-06-26)

- ✅ **格式层 (L2 数据层)**:696 个 md 已转换,目录结构定
- ⏳ **灵魂层 (L3 Schema)**:本文件 v0.1,**待补 CLAUDE.md / 8 个 SKILL**
- ❌ **评测闭环**:未启动
- ❌ **8 个 SKILL**:未写

### Phase 3 任务清单

- [ ] 写 `kb/CLAUDE.md`(SKILL 工作规范,给 Claude/agent 看的)
- [ ] 写 OKF frontmatter schema spec(完整字段定义文档)
- [ ] 设计 8 个 SKILL(SKILL.md 模板)
- [ ] 写 SKILL 1: `kb-doc-summary`(从 md 自动生成 concept)
- [ ] 写评测框架 `kb/lint/` + `kb/eval/`
- [ ] 用 `kb-doc-summary` 给 2012/ 头 50 个 md 生成 concept 页(干跑)

---

## 7. 相关参考

- [Google OKF v0.1 spec](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md) — 我们采用的格式标准
- [Karpathy LLM-Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — LLM wiki 模式源头
- 阿里团队《AI 研发自动化系统》 — 8 个 SKILL + 4 层评测思路
- 阿里那篇 `~/桌面/AI研发自动化系统：阿里Wiki知识库+技能包.html`(完整版见 `kb-md/ali-wiki-overview.md`)
- Google Cloud Knowledge Catalog — 企业级元数据管理

---

## 8. 版本历史

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| 0.1 | 2026-06-26 | 初始版本,融合阿里 + OKF + Karpathy | jack (via Hermes) |

---

**maintainer**: jack
**reviewers**: 待定
**status**: draft
