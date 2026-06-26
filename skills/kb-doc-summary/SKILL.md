---
name: kb-doc-summary
description: Use when enriching the KB by converting raw markdown files (typically from kb-md/) into OKF-compliant Source concept pages — extracts title, description, tags, entities, cross-references, and writes kb/sources/<year>/<slug>.md
version: 0.1
status: draft
created: 2026-06-26
updated: 2026-06-26
maintainer: jack (via Hermes)
---

# kb-doc-summary — 文档摘要入 KB

## Overview

**角色定义**: 你是一名资深幕墙/工程行业知识管理员,擅长将技术文档转化为结构化知识条目。你需要阅读 `kb-md/` 下的原始 md 文件,生成 OKF v0.1 兼容的 Source concept 页,写入 `kb/sources/<year>/<slug>.md`。

**输出语言**: 中文为主,专有名词保持英文。

**核心流程**: 文件定位 → 内容阅读 → 抽取元数据 → 生成 slug → 写 frontmatter + 摘要正文 → 跨引用 → 索引更新。

**配套文档**:
- `kb/KB-META.md` — frontmatter 字段定义、目录结构、type 枚举
- `kb/log.md` — 变更日志(每次 ≥10 页变更必更)

## When to Use

- `kb-md/` 下有新的原始 md 文件,需要入库
- 批量 enrich 一个年份(如 `kb-md/2012/`)的所有文件
- 修补漏掉的 concept 页

**Do NOT use for**:
- 直接读 md 文件(Q&A 用 `kb-just-ask`)
- 写代码(`kb-just-coding`)
- 写技术方案(`kb-tech-solution`)

## Hard Gates(禁止跳过)

| # | 检查项 | 不通过时的行为 |
|---|--------|---------------|
| 1 | md 文件存在且可读 | 报错并跳过 |
| 2 | frontmatter 必填字段齐(type/title/description/created/updated) | 强制生成,缺失用 `[待补充]` |
| 3 | 输出路径符合 OKF:`kb/sources/<year>/<slug>.md` | 不允许写到别处 |
| 4 | slug 唯一(全局不重名) | 冲突加 `-2` / `-3` 后缀 |
| 5 | 跨引用 `[[/sources/<year>/<other-slug>]]` 格式正确 | OKF bundle-relative 优先 |

## Phase 0: 文件定位

### 输入

```python
md_path = "kb-md/2012/浦东嘉里中心保温计算/1-石材/RFI-WH-CW-185.pdf.pdf.md"
# 或批量:
year_dir = "kb-md/2012/"
```

### 抽取 year

从 md_path 路径抽 year:
- `kb-md/2012/...` → year=2012
- 没有年份路径 → `frontmatter.year: [待补充]`

### 抽源文件路径

从 md_path 推出原始 NAS 路径:
- `kb-md/2012/X/Y.pdf.md` → `kb-source/2012/X/Y.pdf`(实际是 `/mnt/nfs/项目存档/2012/...`)

## Phase 1: 内容阅读

读 md 文件,**截取关键信息**:
- 标题(首行 `# xxx`)
- 前 500 字符(摘要候选)
- 章节结构(2-5 个 `##` 标题)
- 表格(参数表、清单表)
- 实体识别(人名、公司、项目、日期)

**不要全文复制**,只摘关键信息 + 重要原文片段(50-200 字引用)。

## Phase 2: 抽取元数据

按 KB-META §1.2/1.3 字段:

| 字段 | 抽取方法 | 例子 |
|------|----------|------|
| `type` | 固定 `Source` | - |
| `title` | 文件首行 `#` 标题,去扩展名 | "RFI-WH-CW-185 浦东嘉里中心保温" |
| `description` | LLM 从正文生成 ≤ 200 字摘要 | "关于上海嘉里中心裙房石材幕墙保温方案的 RFI 咨询,建议硬发泡聚氨酯替代挤塑板" |
| `tags` | 从正文 + 文件路径抽 3-7 个 | `[幕墙, 保温, RFI, 浦东嘉里中心, 聚氨酯]` |
| `project` | 文件路径中的项目名 | "浦东嘉里中心" |
| `entities` | 人名/公司识别 | `[孙诚, KPF, MCL, 同济大学设计院]` |
| `cross_refs` | 文档自身引用的其他文档 | `[RFI-184, RFI-186]` |
| `year` | 路径抽 | 2012 |
| `doc_type` | 源文件扩展名小写 | `pdf` |
| `scan_status` | `native` 或 `scanned` | `scanned`(扫描件) |
| `tier` | 默认 `final` | - |
| `language` | `zh / en / mixed` | `mixed`(中英混排) |
| `source_file` | NAS 原始路径 | `/mnt/nfs/项目存档/2012/...` |
| `quality_score` | LLM 自评 0-1 | 0.85 |
| `created` / `updated` | 当前日期 | 2026-06-26 |

## Phase 3: 生成 slug

**slug 规则**:
- 全小写,英文 + 数字 + 中文(pinyin)
- 中文文件名 → 整段保留中文(OKF 兼容)
- 空格 → `-`
- 去除特殊字符 `()（）` 等

**例子**:
- `RFI-WH-CW-185.pdf.pdf.md` → `rfi-185-pudong-kerry-thermal`
- `浦东嘉里中心裙房幕墙分类.doc.doc.md` → `浦东嘉里中心裙房幕墙分类`
- `SHNM-North-Glass-REVIEW-2012-02-26.pdf.pdf.md` → `shnm-north-glass-review-2012-02-26`

**唯一性**:
```bash
# 检查 slug 是否已存在
[ -f "kb/sources/$year/$slug.md" ] && slug="${slug}-2"
```

## Phase 4: 写 Concept 页

**输出路径**: `kb/sources/<year>/<slug>.md`

**frontmatter 模板**(OKF v0.1 必填 + ai-rd-system 扩展):

```yaml
---
type: Source
title: {title}
description: {description}
tags: [{tags}]
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
year: {year}
project: {project}
entities: [{entities}]
cross_refs: [{cross_refs}]
doc_type: {doc_type}
scan_status: {scan_status}
tier: final
language: {lang}
source_file: {nas_path}
quality_score: {0.0-1.0}
related: []
resource: file://{nas_path}
---

# {title}

## 概述
{description 详细版,200-500 字}

## 关键信息
- 项目: {project}
- 日期: {从正文抽}
- 类型: {RFI / 招标文件 / 计算书 / 报价 / 效果图 / ...}
- 关键决策: {3-5 条,从正文抽}

## 内容摘要
{分章节,2-5 段,每段 100-200 字}

## 表格数据
{如有表格,保留 markdown 表格 + 简述}

## 引用片段
> {原文 50-200 字直接引用}

## 跨引用
- {cross_refs 列表,每条带 [[/sources/<year>/<other-slug>]]}
- ...

## 元数据
- 源文件: `{nas_path}`
- md 文件: `kb-md/{path}`
- slug: `{slug}`
- 入库时间: {created}
- 维护者: jack (via Hermes kb-doc-summary)
```

## Phase 5: 跨引用与索引更新

### 跨引用

如果正文提到其他文件(如 "参考 RFI-184"),在 `cross_refs` 列表加 slug,并在正文末"跨引用"段写 `[[/sources/<year>/<other-slug>]]` 链接。

### 索引更新

在 `kb/index.md` 的 `sources/<year>/` 段加一行:

```markdown
- [[/sources/2012/rfi-185-pudong-kerry-thermal]] — RFI-WH-CW-185 浦东嘉里中心保温方案
```

### log.md 更新

如果 ≥10 页变更,追加到 `kb/log.md`:

```markdown
## YYYY-MM-DD — kb-doc-summary 批量 enrich 2012/

- 变更类型: 新建 Source concept 页
- 变更范围: N 页
- 输入: kb-md/2012/ 下 N 个 md
- 输出: kb/sources/2012/ 下 N 个 concept
- 作者: jack (via Hermes)
```

## Phase 6: 自查清单

| # | 检查项 |
|---|--------|
| 1 | frontmatter 必填字段齐 |
| 2 | `type: Source` 正确 |
| 3 | `description` ≤ 200 字 |
| 4 | `tags` 3-7 个 |
| 5 | slug 唯一,无特殊字符 |
| 6 | 输出路径为 `kb/sources/<year>/<slug>.md` |
| 7 | 至少 1 段内容摘要 |
| 8 | 跨引用格式 `[[/sources/<year>/<slug>]]` |
| 9 | `index.md` 已更新 |
| 10 | `log.md` 已更新(若 ≥10 页) |

## Output Quality Checklist

- ✅ 文件能用 OKF agent(Gemini/NotebookLM/qmd)直接消费
- ✅ 文件能用 Obsidian 打开(双向链接 + Graph View)
- ✅ 文件能用 git diff 看变更
- ✅ 文件能被 `kb-just-ask` 检索到
- ✅ 文件能被评测框架 lint 到

## Quick Reference

| Phase | 动作 | 自动 | 输入 |
|-------|------|------|------|
| 0 | 文件定位 + 抽 year/source | ✅ | md_path |
| 1 | 内容阅读 + 关键信息提取 | ✅ | md 文件 |
| 2 | 元数据抽取(LLM 抽) | ✅ | 内容 + 路径 |
| 3 | 生成 slug(去重) | ✅ | title |
| 4 | 写 concept 页 | ✅ | 模板 |
| 5 | 跨引用 + 索引 + log | ✅ | cross_refs |
| 6 | 自查清单 | ✅ | - |

**交互点**: 0 次(全自动)

## Guard Rails

| # | 检测信号 | 正确行为 | 错误行为 |
|---|---------|---------|---------|
| 1 | md 文件 < 100 字符(空文件) | 跳过,记录到 log | 写入空 concept |
| 2 | md 文件 frontmatter 已存在 | 保留并更新 | 覆盖 |
| 3 | slug 冲突 | 加 `-2` 后缀 | 覆盖 |
| 4 | year 路径缺失 | frontmatter.year=`[待补充]` | 报错 |
| 5 | entities 识别失败 | 留空数组 | 编造人名 |
| 6 | 跨引用目标不存在 | 仍写入,标 `[待创建]` | 假装存在 |
| 7 | description > 200 字 | 截断到 200 字 | 保留长文 |

## Downstream Handoff

生成的 concept 页可被:
- `kb-just-ask` 检索(Q&A)
- `kb-tech-solution` 引用(写方案时找相关 RFI)
- `kb-tech-review` 引用(评审时追溯)
- `qmd search`(BM25 + 向量 + 重排)
- Obsidian Graph View(看关联)

---

**maintainer**: jack (via Hermes)
**version**: 0.1
**created**: 2026-06-26
**status**: draft
