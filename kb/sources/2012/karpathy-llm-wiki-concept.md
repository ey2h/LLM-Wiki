---
type: Source
title: LLM-Wiki 主题思想(Karpathy 26 年 4 月新知识库模式)
description: Karpathy 26 年 4 月提出的 LLM-Wiki 核心思想——把 LLM 从 RAG 引擎变为持续维护个人 Wiki 的全职编辑,知识通过摄入/合并/交叉引用沉淀为活的、可演化的知识库
tags: [karpathy, llm-wiki, rag, kb, 主题思想, 持续生长]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: ai-rd-system
entities: [Andrej Karpathy]
cross_refs: [ali-wiki-overview, kb-meta]
doc_type: md
scan_status: native
tier: final
language: zh
source_file: /home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
quality_score: 0.88
related:
  - /ali-wiki-overview
resource: file:///home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
---

# LLM-Wiki 主题思想

## 概述

提炼自阿里 2026-06-06 文章 §2.1.1,完整阐述 Karpathy 26 年 4 月新提出的 LLM-Wiki 模式核心思想。
这是 ai-rd-system 项目的理论起点。

## 关键信息

- 项目: ai-rd-system 理论基础
- 类型: 概念提炼
- 关键决策: 本仓库采用持续生长型 Wiki 模式,而非传统 RAG

## 内容摘要

### 主题思想核心

LLM-Wiki 本质就是一个 SKILL / md 文件。核心思想是把 LLM 从"每次查询时重新检索的 RAG 引擎"
变成"持续维护个人 Wiki 的全职编辑"。

知识不再每次重新发现,而是被一次次摄入、合并、交叉引用,沉淀为一份"不断变厚的、活的、
可演化"的知识库。

### 为什么这个模式能 work

维护知识库的累活不是"读"和"想",而是迭代 wiki 的过程:更新交叉引用、改综述、标矛盾、
保一致性。人类放弃 wiki 是因为维护成本随规模超线性增长;但 LLM 不会累、不会忘、一次能改
多个文件,维护成本被压到接近零,wiki 才能长期活着。

## 引用片段

> LLM-Wiki 是由 Andrej Karpathy 于 26 年 4 月提出的"新知识库模式",本质就是一个 SKILL / md 文件。

> 维护知识库的累活不是"读"和"想",而是迭代 wiki 的过程。

## 跨引用

- [[/sources/2012/ali-wiki-overview]] — 完整综述(本概念页的来源)
- [[/kb/KB-META]] — 本仓库灵魂层,落地该思想的 schema

## 元数据

- 源文件: `/home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md`
- md 文件: `kb-md/ali-wiki-overview.md`
- slug: `karpathy-llm-wiki-concept`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)