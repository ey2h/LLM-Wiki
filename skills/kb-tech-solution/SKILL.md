---
name: kb-tech-solution
description: Use when generating a technical solution from a PRD in ai-rd-system — loads the PRD from kb/prds/, queries KB for baseline/reference projects via kb-just-ask, applies the 9-phase workflow to produce a Plan document at kb/plans/<slug>.md, and submits for review via kb-tech-review
version: 0.1
status: draft
created: 2026-06-26
updated: 2026-06-26
maintainer: jack (via Hermes)
---

# kb-tech-solution — 技术方案生成

## Overview

**角色定义**: 你是一名资深幕墙/工程行业技术架构师,擅长基于 PRD 反查 KB 历史项目,
输出可执行、可评审、可追溯的技术方案文档。

**输出语言**: 中文为主,专有名词保留英文(规范号/材料型号)。

**核心流程**:
1. **加载 PRD**(从 `kb/prds/<slug>.md`)
2. **KB 反查**(用 `kb-just-ask` 找 baseline / 类似项目 / 规范引用)
3. **方案结构化**(按 PRD §3 输出对象填字段)
4. **质量门自检**(对照 PRD §6 验收标准)
5. **写 Plan 文档**(到 `kb/plans/<slug>.md`,type=Plan)
6. **提交评审**(调用 `kb-tech-review` 触发 CR)

**配套文档**:
- `docs/prd-template.md` — PRD 输入规范(Palantir 本体论风格)
- `kb/KB-META.md` — frontmatter 字段 / type 枚举
- `kb/log.md` — 变更日志(每次产出必更)

## When to Use

- 用户给了一份 PRD,要求出技术方案
- 用户口头/自然语言提需求,先调用本 SKILL 写 PRD 再生成方案
- 项目类型新 / 重复造轮子风险 → 先 KB 反查,再生成

## Do NOT use for

- 用户问"XX 怎么实现"(→ `kb-just-ask`)
- 已有方案的细节修订(→ `kb-doc-summary` 入 KB)
- 故障排查(→ `kb-problem-solve`)
- 架构设计(→ `kb-architecture-design`,只在 PRD 涉及架构时再用本 SKILL)

## Hard Gates

| # | 检查项 | 不通过时的行为 |
|---|--------|---------------|
| 1 | PRD 文件存在且 9 段齐全 | 报错并停止,提示用户补 PRD |
| 2 | PRD §2 输入对象 ≥ 1 个,§3 输出对象 ≥ 1 个 | 报错,提示用户补 PRD 字段 |
| 3 | PRD §5 约束 ≥ 1 条 | 警告但允许(可能项目太简单) |
| 4 | KB 反查至少 1 个 baseline(`reference_projects` 非空) | 报错:不允许凭空写方案 |
| 5 | 输出路径 `kb/plans/<slug>.md` | 不允许写到别处 |
| 6 | Plan frontmatter 必填字段齐(`type/title/description/created/updated/related_prd`) | 缺失用 `[待补充]` 占位 |
| 7 | 关联回 PRD(`related_prd: [[/prds/<slug>]]`) | 必须双向链接 |

## Phase 0: 加载 PRD

### 输入

```
PRD 路径: kb/prds/<slug>.md  (用户提供 slug 或由本 SKILL 推断)
```

### 动作

1. 读 PRD frontmatter(必填字段: type/title/description/tags/created/updated/version/status/author)
2. 校验 PRD 9 段齐全(## 1-9 标题都在)
3. 解析 §2 输入对象(字段表)→ `inputs: dict`
4. 解析 §3 输出对象(字段表)→ `outputs: dict`
5. 解析 §5 约束 → `constraints: list[str]`
6. 解析 §6 验收标准 → `acceptance: list[dict]`(自动/人工)
7. 解析 §7 反例 → `anti_patterns: list[str]`
8. 解析 §9 关联 KB → `related_kb: list[str]`

### 输出

```python
prd = {
    "title": str,
    "description": str,
    "inputs": {field: {type, required, desc, source}},
    "outputs": {field: {type, required, desc}},
    "constraints": list[str],
    "acceptance": list[dict],
    "anti_patterns": list[str],
    "related_kb": list[str],
    "slug": str,
}
```

## Phase 1: KB 反查 baseline

### 输入

`prd["related_kb"]`(来自 PRD §9)+ `prd["inputs"]` 关键字段(`baseline_project` / `project_type` / `city`)

### 动作

1. **优先用 PRD §9 的关联 KB**(用户已经指了)
2. **若未指,自动 KB 反查**:
   - 调用 `kb-just-ask` 子任务: "找 {project_type} 类型 + {city} 城市 + 系统类型相似的项目"
   - 提取 `kb/sources/<year>/<slug>.md` 中 `project: {name}` 和 `year` 匹配的 Source 页
3. **提取 baseline 关键数据**:
   - 单价(各子项)
   - 面积(各子项)
   - 总造价
   - 关键决策(从 `## 内容摘要` 段抽)
4. **判定反查质量**:
   - ≥ 1 个 baseline → `confidence_score: 0.7-1.0`
   - 0 个 baseline,只能靠 SKILL 1 已有 Source → `confidence_score: 0.4-0.6`
   - 完全无 Source → `confidence_score: <0.4` + 警告用户

### 输出

```python
baselines = [
    {
        "slug": str,          # 例 "changzhou-zhonghang-quote-2708"
        "year": int,
        "project": str,
        "city": str,
        "total_cny": float,
        "unit_prices": {subsystem: cny_per_m2},
        "key_decisions": list[str],
        "confidence": float,
    }
]
```

## Phase 2: 方案结构化

### 输入

`prd` + `baselines`

### 动作

按 PRD §3 输出对象,**逐字段生成**:

| 输出字段 | 生成方法 |
|----------|----------|
| `summary_table` | 子系统 × 面积 × 单价 × 合计,基于 baselines 单价 × prd inputs 面积 |
| `unit_price_analysis` | 5 分项:人工/材料/机械/管理/利润,从 baseline Source 抽 |
| `total_quote_cny` | sum(sub_area × unit_price) |
| `breakdown_by_subsystem` | 各子系统造价占比 |
| `reference_projects` | baselines 的 slug 列表 |
| `confidence_score` | Phase 1 输出的置信度 |
| `risk_flags` | 哪些 baseline 没有 / 哪些字段用户没填 / city 不匹配 / 等 |
| `deliverable_xlsx`(可选) | 用 openpyxl 生成,输出路径 |

### 反例防御(对照 PRD §7)

每条 anti-pattern 检查一遍:
- ❌ 凭空单价 → 如果 baseline 全空,触发 Hard Gate #4
- ❌ city 差异忽略 → 如果 baseline city ≠ prd city,触发 risk_flag
- ❌ 混合质量等级 → 如果 baseline quality_tier 与 prd 不一致,触发 risk_flag
- ❌ 默认玻璃规格 → 如果 prd 没指定且 baseline 也没,触发 risk_flag
- ❌ 输出 SVG/PNG → 严格只输出 markdown table + xlsx

### 输出

```python
solution = {
    "summary_table": str,           # markdown table
    "unit_price_analysis": list[dict],
    "total_quote_cny": float,
    "breakdown": dict,
    "reference_projects": list[str],
    "confidence_score": float,
    "risk_flags": list[str],
    "deliverable_xlsx": str | None,
}
```

## Phase 3: 写 Plan 文档

### 输入

`prd` + `solution`

### 动作

1. **生成 slug**:`<prd_slug>-v<prd_version>` 例 `curtain-wall-quote-v1-v1`
   - 检查全局唯一 → 冲突加 `-2` 后缀
2. **构造 frontmatter**:
   ```yaml
   ---
   type: Plan
   title: {从 prd.title 推}
   description: {≤ 200 字摘要}
   tags: [{继承 prd.tags + KB 相关}]
   created: {YYYY-MM-DD}
   updated: {YYYY-MM-DD}
   version: 0.1
   status: draft
   related_prd: [[/prds/{prd_slug}]]
   reference_projects: [{baseline slugs}]
   confidence_score: {0-1}
   ---
   ```
3. **构造正文**(8 段):
   - `## 1. PRD 摘要`(从 prd 浓缩)
   - `## 2. KB 反查结果`(列出 baselines + 关键决策)
   - `## 3. 技术方案`(summary_table + breakdown)
   - `## 4. 综合单价分析`(unit_price_analysis 详情)
   - `## 5. 风险与偏差`(risk_flags)
   - `## 6. 验收对照`(PRD §6 acceptance checklist,逐条)
   - `## 7. 反例自检`(PRD §7 anti_patterns,逐条 ✓/✗)
   - `## 8. 后续`(触发 kb-tech-review)
4. **写文件**:`kb/plans/<slug>.md`
5. **更新 kb/index.md**(在 `plans/` 段加一行)
6. **更新 kb/log.md**(追加本次方案记录)

### 输出

- `kb/plans/<slug>.md` 文件路径
- 索引更新摘要

## Phase 4: 质量门自检

### 输入

`prd` + `solution` + 写好的 Plan 文件

### 动作

对照 PRD §6 acceptance **逐条验证**:

#### 自动验收

- [ ] `summary_table` 行数 = `sub_systems` 数量
- [ ] `summary_table` 合计 = `total_quote_cny`
- [ ] 每个 `unit_price_analysis` 含 5 分项
- [ ] `reference_projects` ≥ 1 个 slug,能在 `kb/sources/` 找到
- [ ] `confidence_score` ≥ 0.6(过低 → 警告)
- [ ] Plan `tags` ≥ 5 个,`description` ≤ 200 字
- [ ] schema_gate + lint 双绿灯

#### 人工验收(写到 Plan 的"待用户确认"段,不自动判断)

- [ ] 用户确认 total_quote_cny ± 15% baseline
- [ ] 用户确认 sub_systems 划分
- [ ] 用户确认 reference 选择

### 输出

```
质量门自检报告: {pass_count}/{total_count}
{✓ / ✗} {每条结果}
```

如果 ✗ > 0,**仍写 Plan**(用户可能接受偏差),但风险段必须列清楚。

## Phase 5: 提交评审

### 输入

`kb/plans/<slug>.md` 已写好

### 动作

1. **更新 Plan frontmatter**:`status: draft` → `status: pending_review`
2. **追加 reviewer 段**:`## 9. Reviewer 待办`
3. **触发 `kb-tech-review`** 子任务
4. **输出交付给用户**:
   - Plan 文件路径
   - 质量门报告
   - 评审请求清单

### 输出

```
✅ 技术方案已生成:
- 文件: kb/plans/curtain-wall-quote-v1-v1.md
- 质量门: 7/7 自动通过 + 3 条人工待确认
- 评审请求: 待 kb-tech-review 处理
```

## Phase 6: 自查清单

## Output Quality Checklist

- [ ] Plan frontmatter 必填字段齐(type=Plan + related_prd + reference_projects)
- [ ] Plan 9 段齐全(## 1-9)
- [ ] `related_prd` 双向链接回 PRD(`kb/prds/<slug>.md`)
- [ ] `reference_projects` 全部在 `kb/sources/` 下能找到
- [ ] `summary_table` 行数 = `sub_systems` 数量
- [ ] `summary_table` 合计 = `total_quote_cny`(±0.01)
- [ ] 每个 `unit_price_analysis` 含 5 分项
- [ ] `confidence_score` ≥ 0.6(否则必须在 risk_flags 标注)
- [ ] 所有 `risk_flags` 在 Plan §5 段有解释
- [ ] 反例自检(PRD §7)逐条 ✓/✗
- [ ] schema_gate + lint 双绿灯
- [ ] kb/index.md `plans/` 段已加链接
- [ ] kb/log.md 已追加本次记录

## Quick Reference

| Phase | 动作 | 自动 | 输入 |
|-------|------|------|------|
| 0 | 加载 PRD | ✅ | prd_path |
| 1 | KB 反查 baseline | ✅ | prd.related_kb + inputs |
| 2 | 方案结构化 | ✅ | prd + baselines |
| 3 | 写 Plan 文档 | ✅ | prd + solution |
| 4 | 质量门自检 | ✅ | PRD §6 acceptance |
| 5 | 提交评审 | ✅ | Plan 文件 |
| 6 | 自查清单 | ✅ | Plan + prd |

**交互点**:0 次(全自动)。如果 PRD §6 人工验收 > 0 条,会等用户确认(不算交互点)。

## Guard Rails

| # | 检测信号 | 正确行为 | 错误行为 |
|---|---------|---------|---------|
| 1 | PRD 文件不存在 | 报错,提示用户先写 PRD | 跳过 PRD 直接出方案 |
| 2 | PRD 9 段缺一段 | 报错指出缺哪段,停止 | 编内容补段 |
| 3 | KB 反查 0 个 baseline | 警告 + confidence_score < 0.4 + 风险段标注 | 凭空编单价 |
| 4 | baseline city ≠ prd city | 触发 risk_flag,提示 city 差异 | 直接套 baseline 单价 |
| 5 | baseline quality_tier 不匹配 | 触发 risk_flag | 直接套单价 |
| 6 | baseline 缺某子系统 | 该子系统标 `[待 KB 补充]` | 用其他子系统单价类推 |
| 7 | prd `total_area_m2` 为负数 / 0 | 报错,提示用户检查输入 | 算出 0 元方案 |
| 8 | 输出路径 `kb/plans/` 已存在 | 加 `-2` 后缀 | 覆盖旧 plan |
| 9 | anti-pattern 违反 | 风险段明确标注 + 重写该字段 | 强行保留违规输出 |
| 10 | `confidence_score` < 0.4 | 必须人工确认才能继续 | 自动走完流程 |

## Downstream Handoff

生成的 Plan 可被:
- **`kb-tech-review`** — 接收评审请求,产出 review 意见
- **`kb-just-ask`** — 用户后续问"这个方案用了哪些 baseline"
- **`kb-just-coding`** — 用户说"开始编码",拿 Plan 落地
- **`kb-doc-summary`** — 把新方案作为 Source 入 KB(若值得)
- **用户** — 直接看 `kb/plans/<slug>.md`,或 Excel 导出

---

**maintainer**: jack (via Hermes)
**version**: 0.1
**status**: draft