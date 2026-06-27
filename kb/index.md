---
type: Schema
title: KB 索引
description: ai-rd-system 知识库总目录
created: 2026-06-26
updated: 2026-06-26
---

# ai-rd-system 知识库索引

> OKF v0.1 保留文件名。给 agent 做"渐进式披露"——先扫这个文件再决定要不要打开具体页。
> 给人类浏览用,这是"门面"。

## 灵魂层

- [[KB-META]] — 知识库 schema、目录结构、SKILL 拆法、评测闭环(本 KB 的"宪法")
- [[CLAUDE]] — SKILL 工作规范(给 agent 看,本文件待写)

## 按目录

### Concepts(业务/技术概念)

- 待 kb-doc-summary 自动生成

### Entities

- 待写

### Sources(原始文档摘要)

按年份:

- [[sources/2012/]] — 2012 年 NAS 文档(696 个 md 已转换,待 enrich)
- [[sources/2013/]] — 2013 年(待转)
- ...
- [[sources/2026/]] — 2026 年

### Code(代码知识化)

- 暂未启用(本项目主要是文档 KB,代码项目用独立 vault)

### Plans(设计方案)

- [[plans/curtain-wall-quote-v1-v1]] — 幕墙与外装修工程造价估算方案 v1(by SKILL 2, 2026-06-27)
  - 🟡 reviewed by [[reviews/curtain-wall-quote-v1-v1-20260627]] (35/50, needs_revision)

### Reviews(技术评审)

- [[reviews/curtain-wall-quote-v1-v1-20260627]] — Plan curtain-wall-quote-v1-v1 评审(SKILL 3 首次跑通,35/50 needs_revision)

### Queries(问答存档)

- 待 kb-qa 自动追加

### Playbooks(SOP)

- 待写

## 检索

```bash
# BM25 关键词
qmd search "保温系统"

# 语义检索
qmd search --semantic "硬发泡聚氨酯 vs 挤塑板"

# LLM 重排
qmd search --rerank "中航酒店幕墙"
```

## 阅读建议

1. **第一次来**:先读 [[KB-META]] 了解整个 KB 设计
2. **想写方案**:看 KB-META §4 的 8 个 SKILL + 用 `kb-tech-solution`
3. **想查资料**:用 `qmd search` 或 Obsidian Graph View
4. **想贡献**:看 CLAUDE.md(待写)+ 用 `kb-doc-summary` 自动生成

---

_本文件由 Hermes 协助生成于 2026-06-26_
