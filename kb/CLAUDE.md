---
type: Schema
title: SKILL 工作规范(给 Claude / agent 看)
description: ai-rd-system 8 个 SKILL 的统一规范 — 目录布局 / frontmatter / hard gate / phase 流程 / 自查清单 / 评测指标
tags: [schema, skill-spec, claude-md, kb-meta]
created: 2026-06-26
updated: 2026-06-26
version: 0.1
---

# CLAUDE.md — SKILL 工作规范

> **本文件是 ai-rd-system 8 个 SKILL 的统一规范。**
> 任何 SKILL.md 都必须遵循本规范,避免 SKILL 之间格式漂移。
>
> **配套文档**:
> - `kb/KB-META.md` — KB 三层架构 + frontmatter 字段定义(type/title/description/tags/...)+ 目录结构
> - `kb/log.md` — 变更日志(≥10 页变更必更)
> - `kb/index.md` — 概念目录

---

## 1. SKILL 目录布局(强制)

```
skills/
├── kb-doc-summary/         # SKILL 1 — 文档摘要入 KB
│   ├── SKILL.md            # 唯一入口(强制文件名)
│   ├── scripts/            # 可选:辅助脚本
│   ├── templates/          # 可选:输出模板
│   └── references/         # 可选:参考资料
├── kb-tech-solution/       # SKILL 2
│   └── SKILL.md
├── kb-tech-review/         # SKILL 3
│   └── SKILL.md
├── kb-just-coding/         # SKILL 4
│   └── SKILL.md
├── kb-test-pre/            # SKILL 5
│   └── SKILL.md
├── kb-problem-solve/       # SKILL 6
│   └── SKILL.md
├── kb-architecture-design/ # SKILL 7
│   └── SKILL.md
├── kb-just-ask/            # SKILL 8
│   └── SKILL.md
└── ...
```

**强制规则**:
- 每个 SKILL 必须有 `SKILL.md`(大小写敏感,大写 SKILL)
- `SKILL.md` 是唯一入口,其他 agent 不读散落文件
- 子目录命名固定:`scripts/` `templates/` `references/`,小写复数

---

## 2. SKILL.md Frontmatter(强制)

```yaml
---
name: {kebab-case-skill-name}            # 例:kb-doc-summary
description: {1-2 句话,触发场景 + 输入输出}  # agent 用此决定何时加载
version: {semver, 例 0.1}
status: {draft | active | deprecated}
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
maintainer: {name (via Hermes)}           # 例:jack (via Hermes)
---
```

**强制字段**:`name` `description` `version` `status`
**推荐字段**:`created` `updated` `maintainer`

**description 写法禁忌**:
- ❌ "用于文档处理"(太宽,agent 不知道何时该用)
- ✅ "Use when enriching the KB by converting raw markdown files (typically from kb-md/) into OKF-compliant Source concept pages — extracts title, description, tags, entities, cross-references"

---

## 3. SKILL.md 正文结构(强制 9 段)

```markdown
# {skill-name} — {中文一句话角色}

## Overview              — 角色定义 / 输出语言 / 核心流程
## When to Use           — 触发场景
## Do NOT use for        — 反向触发(避免误用)
## Hard Gates            — 禁止跳过的检查项(表格:检查项 + 不通过时的行为)
## Phase 0..N            — 分阶段流程,每阶段有「输入 / 动作 / 输出」
## Output Quality Checklist — 输出前的自查清单(10 条左右)
## Quick Reference       — 一表总结(阶段 × 动作 × 是否自动 × 输入)
## Guard Rails           — 异常情况处理(检测信号 + 正确行为 + 错误行为)
## Downstream Handoff    — 产物被谁消费

---

**maintainer**: jack (via Hermes)
**version**: 0.1
**status**: draft
```

**强制段**:`Overview` `When to Use` `Do NOT use for` `Hard Gates` `Phase 0..N` `Output Quality Checklist` `Guard Rails`
**可选段**:`Quick Reference` `Downstream Handoff`(强烈推荐)

---

## 4. Hard Gate 规范

Hard Gate 是**禁止跳过的检查项**,表格三列:

| # | 检查项 | 不通过时的行为 |
|---|--------|---------------|
| 1 | 输入文件存在且可读 | 报错并跳过,记 log |
| 2 | frontmatter 必填字段齐 | 缺失用 `[待补充]` 占位,不阻塞 |
| 3 | 输出路径符合规范 | 不允许写到别处 |
| 4 | slug 唯一(全局) | 冲突加 `-2`/`-3` 后缀 |
| 5 | 跨引用 `[[/sources/...]]` 格式 | bundle-relative 优先,Obsidian 兼容 |

**最少 3 条**,每条必须有"不通过时的行为"列(明确是 skip / placeholder / 报错)。

---

## 5. Phase 流程规范

**最少 3 个 Phase,推荐 5-7 个**。每个 Phase 必须有:
- **输入**:数据/文件的来源
- **动作**:agent 要做的事
- **输出**:产物(可被下一 Phase 消费)

**标准 Phase 模板**:

```markdown
## Phase {N}: {动词} {名词}

### 输入
{具体文件路径或数据格式}

### 动作
1. 步骤 1
2. 步骤 2
3. ...

### 输出
{具体产物路径 / 数据结构}
```

**推荐 Phase 序列**(SKILL 1 验证有效,其他 SKILL 沿用):

- Phase 0: 文件定位 / 输入准备
- Phase 1: 内容阅读 / 信息提取
- Phase 2: 元数据抽取 / 结构化
- Phase 3: 命名 / 去重(slug)
- Phase 4: 写产物 / 输出
- Phase 5: 跨引用 + 索引更新
- Phase 6: 自查清单

---

## 6. 输出质量自查清单(Output Quality Checklist)

**10 条左右**,每条可独立验证(✅/❌)。格式:

```markdown
## Output Quality Checklist

- [ ] frontmatter 必填字段齐(name/description/version/status)
- [ ] type/title/description/created/updated 全填(不能是 `[待补充]` 除非明确允许)
- [ ] description ≤ 200 字
- [ ] tags 3-7 个
- [ ] slug 唯一,无特殊字符(`()（）` 全部去除)
- [ ] 输出路径符合 KB-META §1.4 type → 目录映射
- [ ] 至少 1 段内容摘要
- [ ] 跨引用格式 `[[/sources/<year>/<slug>]]`
- [ ] index.md 已更新
- [ ] log.md 已更新(若 ≥10 页变更)
```

---

## 7. Guard Rails(异常处理)

**最少 5 条**,每条三列:**检测信号 → 正确行为 → 错误行为**(反向警告)。

| # | 检测信号 | 正确行为 | 错误行为 |
|---|---------|---------|---------|
| 1 | md 文件 < 100 字符 | 跳过,记 log | 写空 concept |
| 2 | frontmatter 已存在 | 保留并增量更新 | 覆盖丢失 |
| 3 | slug 冲突 | 加 `-2` 后缀 | 覆盖 |
| 4 | entities 识别失败 | 留空数组 | 编造人名 |
| 5 | 跨引用目标不存在 | 仍写入,标 `[待创建]` | 假装存在 |

**"错误行为"列是反向警示**,写给 agent 看"绝对不能这样做"。

---

## 8. Quick Reference 表(强烈推荐)

**单表总结 Phase 流水线**:

| Phase | 动作 | 自动 | 输入 |
|-------|------|------|------|
| 0 | 文件定位 + 抽 year | ✅ | md_path |
| 1 | 内容阅读 + 提取 | ✅ | md 文件 |
| 2 | 元数据抽取(LLM) | ✅ | 内容 + 路径 |
| 3 | 生成 slug | ✅ | title |
| 4 | 写 concept 页 | ✅ | 模板 |
| 5 | 跨引用 + 索引 | ✅ | cross_refs |
| 6 | 自查清单 | ✅ | - |

**交互点**:**0 次**(全自动) / **1-3 次**(半自动)/ **≥4 次**(考虑自动化掉)

---

## 9. Downstream Handoff

**明确写出产物被谁消费**(其他 SKILL / 工具 / 人类):

```markdown
## Downstream Handoff

生成的 concept 页可被:
- `kb-just-ask` — 检索(Q&A)
- `kb-tech-solution` — 引用(写方案时找相关 RFI)
- `qmd search` — BM25 + 向量 + 重排
- Obsidian Graph View — 看关联
```

---

## 10. 版本与状态

**status 三态**:

| 状态 | 含义 | 行为 |
|------|------|------|
| `draft` | 初稿,未真实数据验证 | 可改 |
| `active` | 已在真实数据上跑过,稳定 | 改要写 log |
| `deprecated` | 被新 SKILL 取代 | 仍保留,标注替代 |

**version 语义**:
- `0.1` — 初稿(未跑真实数据)
- `0.2-0.9` — 试跑 / 修正
- `1.0` — 稳定(已跑 ≥ 50 个真实 case)
- `1.x` — 小修
- `2.0` — 重大重写

---

## 11. 与 KB-META 的关系

```
KB-META.md (灵魂层) — 整个 KB 的 schema
  └─ CLAUDE.md (本文件) — 所有 SKILL 的统一规范
       └─ skills/{name}/SKILL.md — 单个 SKILL 的工作流
            └─ kb/{type}s/{year}/{slug}.md — SKILL 产物
```

**层级关系**:
- KB-META 定**是什么**(frontmatter 字段、type 枚举)
- CLAUDE.md 定**怎么做**(SKILL 写法的统一规范)
- SKILL.md 定**这个 SKILL 怎么跑**(具体 phase 流程)
- 产物是 KB 的血肉

---

## 12. 评测闭环对 SKILL 的要求

每个 SKILL 写完后必须能通过 `kb/lint/schema_gate.py`:
1. SKILL.md frontmatter 必填字段齐
2. 9 段结构齐全(`Overview` `When to Use` `Do NOT use for` `Hard Gates` `Phase` `Output Quality Checklist` `Guard Rails`)
3. Hard Gates 至少 3 条
4. Guard Rails 至少 5 条
5. Output Quality Checklist 至少 8 条

**不通过 = SKILL 视为 draft,不可标 active**。

---

## 13. SKILL 编写检查清单(写 SKILL 时自检)

- [ ] 目录名 = `kb-{kebab-case}`
- [ ] SKILL.md 在 skills/{name}/SKILL.md
- [ ] Frontmatter 5 字段齐(name/description/version/status/created)
- [ ] description 是 "Use when ..." 触发场景描述(≥ 30 字)
- [ ] 9 段结构齐全
- [ ] Hard Gates ≥ 3 条
- [ ] Guard Rails ≥ 5 条
- [ ] Output Quality Checklist ≥ 8 条
- [ ] Quick Reference 表存在
- [ ] Downstream Handoff 段写明产物消费者
- [ ] 末尾 maintainer/version/status 三行齐

---

## 14. 版本历史

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| 0.1 | 2026-06-26 | 初始版本 — 8 段强制结构 + Hard Gate + Guard Rail 规范 | jack (via Hermes) |

---

**maintainer**: jack
**reviewers**: 待定
**status**: draft