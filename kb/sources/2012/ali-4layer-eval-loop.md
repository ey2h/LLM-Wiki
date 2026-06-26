---
type: Source
title: 4 层评测闭环 + 3σ₀ 阈值(阿里方案核心)
description: 阿里提出的 4 层 evaluation-driven 评测闭环 — L1 结构层 lint+schema_gate / L2 实用层 15 task gold 集 / L3 信号层 3σ₀ 阈值 / L4 治理层 ≥10 页变更必更 log,避免小幅波动误判为改进
tags: [评测闭环, 4层闭环, 3sigma, schema-gate, eval, 阿里]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: ai-rd-system
entities: [阿里团队]
cross_refs: [ali-wiki-overview, kb-meta, claude-md]
doc_type: md
scan_status: native
tier: final
language: zh
source_file: /home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
quality_score: 0.90
related:
  - /ali-wiki-overview
resource: file:///home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
---

# 4 层评测闭环 + 3σ₀ 阈值

## 概述

提炼自阿里 2026-06-06 文章 §5 评测闭环部分。ai-rd-system 项目已实现 L1 部分
(schema_gate.py + lint.py),其余 L2/L3/L4 待 Phase 3 后半段补全。

## 关键信息

- 项目: ai-rd-system 评测体系设计
- 类型: 设计方案/方法论
- 关键决策: 用 3σ₀ 阈值避免小幅波动误判(传统做法只看均值变化,容易噪音判真)

## 内容摘要

### L1 结构层(已实现 ✅)

- 每次 KB 变更跑 `kb/lint/schema_gate.py` 和 `kb/lint/lint.py`
- 不通过直接红灯,PR 阻塞门
- ai-rd-system 当前已实现:frontmatter 必填字段校验 + slug 唯一 + 跨引用格式 +
  type 枚举 + type→目录映射 + description 长度 + tags 数量 + ISO 8601 日期

### L2 实用层(待实现)

- 15 个固定 task(每个对应一类问题)
- 每次 KB 变更跑 r-N evaluation(rank-N 命中率)
- 基线对比,看是否退化

### L3 信号层(待实现)

- 任务提分需过 3σ₀ 才算"真改进"
- 避免小幅波动被误判为"改进"
- 这是阿里方案的精髓——传统 A/B 测试只看均值,容易把随机波动当真改进

### L4 治理层(部分实现)

- ≥10 页变更必更新 log.md + PR 写动机
- 防止"KB 静默增长"
- ai-rd-system 当前有 kb/log.md 占位,但还无强制流程

## 引用片段

> 3σ₀ 阈值:任务提分需过 3σ₀ 才算"真改进",避免小幅波动被误判为"改进"。

> L4 治理层:≥10 页变更必更新 log.md,防止"KB 静默增长"。

## 跨引用

- [[/sources/2012/ali-wiki-overview]] — 完整综述
- [[/kb/KB-META]] — 评测层设计落点(§5 评测闭环)
- [[/kb/CLAUDE]] — SKILL 自检要求(schema_gate 通过才能标 active)
- [[/kb/lint/schema_gate]] — 已实现的 L1 评测工具(待把 link 真实化)

## 元数据

- 源文件: `/home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md`
- md 文件: `kb-md/ali-wiki-overview.md`
- slug: `ali-4layer-eval-loop`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)