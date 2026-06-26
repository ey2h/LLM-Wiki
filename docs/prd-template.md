---
type: Schema
title: PRD 模板 — ai-rd-system 输入规范
description: ai-rd-system 接受的产品需求文档(PRD)规范 — 借鉴 Palantir 本体论的对象/链接/函数/Action 概念,保持 markdown + git diff 友好,9 段结构供 SKILL 2 (kb-tech-solution) 直接消费
tags: [prd, schema, palantir-ontology, input-spec, kb-tech-solution]
created: 2026-06-26
updated: 2026-06-26
version: 0.1
---

# PRD 模板 — ai-rd-system 输入规范

> **用途**: 用户给 ai-rd-system 提需求时,先按本模板写一份 PRD,再交给 SKILL 2 (kb-tech-solution)
> 出技术方案。
>
> **设计思想**: 借鉴 [Palantir Foundry 本体论](https://www.palantir.com/docs/foundry/object-model/objects-overview/)
> 的 **对象(Object) / 链接(Link) / 函数(Function) / Action Type** 四要素,
> 但**保持 markdown + git diff 友好**,不引入类型系统运行时。
>
> **配套 SKILL**: [kb-tech-solution](/skills/kb-tech-solution/SKILL.md)

---

## 1. Palantir 本体论借鉴了什么

| Palantir 概念 | ai-rd-system PRD 对应 | 用途 |
|--------------|----------------------|------|
| **Object**(对象) | `## 输入对象` / `## 输出对象` | 明确数据的形状,SKILL 知道怎么读 |
| **Link**(链接) | 对象之间的 `→` 引用 | 显式表达"订单引用客户" |
| **Function**(函数) | `## 验收标准` | 可重复执行的判断 |
| **Action Type** | `## 验收标准` 的人类环节 | 人在回路的工作流(审批/编辑/确认) |
| **Property Set** | 输入对象的字段表 | 类型化字段,SKILL 自动校验 |

**ai-rd-system 不抄的**:Ontology SDK / 实时数据集市 / Web 编辑器。这些是 Palantir 平台的工程,不是本体论本身。

---

## 2. PRD 9 段模板(强制)

```markdown
---
type: PRD
title: {PRD 中文标题}
description: {≤ 200 字摘要}
tags: [{3-7 个关键词}]
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
version: 0.1
status: draft
author: jack
---

# {PRD 标题}

## 1. 触发(Trigger)

{怎么触发这个 PRD / 什么场景下使用}

## 2. 输入对象(Input Objects)

{Palantir Object 风格 — 列出所有需要的输入数据,每字段注明类型/必填/来源}

| 字段 | 类型 | 必填 | 说明 | 来源 |
|------|------|------|------|------|
| {field} | {type} | {✅/❌} | {desc} | {user/upload/external} |

## 3. 输出对象(Output Objects)

{SKILL 2 产物的形状}

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| {field} | {type} | {✅/❌} | {desc} |

## 4. 对象链接(Object Links)

{显式声明输入对象之间 / 输入输出之间的关系}

```
{Input A} → {Output X}: 一对一
{Input B} → {Output Y}: 一对多
```

## 5. 约束(Constraints)

{硬约束 — SKILL 必须遵守,违反报错}

- 约束 1: ...
- 约束 2: ...

## 6. 验收标准(Acceptance)

{Palantir Function/Action 风格 — 可执行的判断 + 人的环节}

### 自动验收(机器跑)

- [ ] 输出包含 X 字段
- [ ] 计算公式 Y 通过
- [ ] ...

### 人工验收(人在回路)

- [ ] 用户确认 Z
- [ ] 用户审批 W

## 7. 反例(Anti-patterns)

{SKILL 不该做的 3-5 条 — 防止乱发挥}

- ❌ ...
- ❌ ...

## 8. 调用 SKILL(Downstream)

{本 PRD 触发哪些 SKILL,产物交给谁}

- 触发: `kb-tech-solution`
- 产出交给: 用户 / `kb-tech-review` / ...

## 9. 关联 KB

{相关的 KB concept / RFI / 规范 / 历史方案}

- [[/concepts/x]]
- [[/sources/2012/rfi-xxx]]
- ...

---

**version**: 0.1
**status**: draft
**author**: jack
```

---

## 3. 强制字段(写到 `kb/prds/<slug>.md`)

| 字段 | 必填 | 说明 |
|------|------|------|
| `type` | ✅ | 固定 `PRD` |
| `title` | ✅ | 中文标题 |
| `description` | ✅ | ≤ 200 字摘要 |
| `tags` | ✅ | 3-7 个关键词 |
| `created` / `updated` | ✅ | ISO 8601 日期 |
| `version` | ✅ | semver |
| `status` | ✅ | `draft / active / deprecated` |
| `author` | ✅ | 需求提出人 |

---

## 4. 校验规则(SKILL 2 加载 PRD 时跑)

1. **9 段齐全**:缺任何一段,SKILL 2 必须明确询问用户补齐
2. **输入对象至少 1 个**:空输入对象 → 报错
3. **输出对象至少 1 个**:SKILL 2 不知道交付什么 → 报错
4. **验收标准至少 1 条**:无验收 = 无质量门 → 警告但允许
5. **反例至少 1 条**:防止 SKILL 2 瞎发挥
6. **关联 KB 至少 1 个**:无关联 = SKILL 2 不查 KB → 输出质量低

---

## 5. 示例 PRD

见 [`kb/prds/curtain-wall-quote-v1.md`](/kb/prds/curtain-wall-quote-v1.md) — 幕墙造价估算 PRD 完整样例。

---

## 6. 命名规范

- 路径: `kb/prds/<slug>.md`(顶层 prds 目录,跟 sources/ 平级)
- slug 规则: `<domain>-<feature>-<version>`,例 `curtain-wall-quote-v1`
- 中文友好,允许保留中文 slug

---

## 7. 为什么不直接用 JSON Schema / TypeScript

| 候选 | 优点 | 缺点 | 决策 |
|------|------|------|------|
| **Markdown table**(本方案) | git diff 友好 / 任何编辑器可写 | 字段类型靠约定不靠校验 | ✅ 采用 |
| JSON Schema | 严格校验 | 学习曲线 / 不是 LLM 友好格式 | ❌ |
| TypeScript interface | 编译期类型 | 引入构建步骤 / LLM 不熟 | ❌ |
| OpenAPI YAML | 标准化 / 工具多 | 跟 markdown 风格割裂 | ❌ |

**关键考量**:SKILL 2 读 PRD 是 **LLM 解析**,不是**程序解析**。Markdown table 对 LLM 来说最自然,且符合 ai-rd-system 全栈 markdown 的风格统一。

---

**maintainer**: jack (via Hermes)
**status**: draft
**version**: 0.1