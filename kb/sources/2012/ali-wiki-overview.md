---
type: Source
title: 阿里 Wiki 知识库 + 技能包 — AI 研发自动化系统综述
description: 阿里团队 2026-06-06 发表的对 LLM-Wiki 知识库 + SKILL 技能包研发自动化体系的完整介绍,涵盖 Karpathy 主题思想、KB 三层架构、Obsidian 平台、8 个 SKILL 拆解、4 层评测闭环与 3σ₀ 阈值机制
tags: [llm-wiki, kb, skill, 阿里, 研发自动化, okf, ai-rd-system]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: ai-rd-system
entities: [Andrej Karpathy, 阿里团队, 欣逸AI]
cross_refs: [kb-meta, claude-md]
doc_type: md
scan_status: native
tier: final
language: zh
source_file: /home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
quality_score: 0.92
related:
  - /kb-meta
  - /claude-md
resource: file:///home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md
---

# 阿里 Wiki 知识库 + 技能包 — AI 研发自动化系统综述

## 概述

本文是阿里团队 2026-06-06 发表的对 LLM-Wiki 知识库 + SKILL 技能包研发自动化体系的完整介绍,
作为 ai-rd-system 项目的核心参考文档。文章追溯 Karpathy 26 年 4 月提出的"新知识库模式",
提出持续生长型 Wiki 的核心思想——LLM 作为全职 Wiki 编辑而非临时 RAG 检索器。

## 关键信息

- 项目: ai-rd-system(本仓库)对标阿里方案的本地实现
- 日期: 2026-06-06 发表,2026-06-26 入库
- 类型: 综述参考文档
- 关键决策:
  - 借鉴 Karpathy LLM-Wiki 主题思想 + 阿里 8 个 SKILL 拆解 + Google OKF 格式层
  - 不直接抄阿里,叠加 Google OKF v0.1 作为 vendor-neutral 格式标准
  - 评测闭环采用阿里 4 层 + 3σ₀ 阈值,避免小幅波动误判

## 内容摘要

### 2. 背景介绍

文章 2.1 节系统阐述 LLM-Wiki 主题思想。Karpathy 26 年 4 月提出该模式,本质是 SKILL/md 文件。
核心转变是把 LLM 从"每次查询时重新检索的 RAG 引擎"变成"持续维护个人 Wiki 的全职编辑",
知识被一次次摄入、合并、交叉引用,沉淀为不断变厚、活的、可演化的知识库。LLM 维护 wiki
成本接近零,这是该模式可行的关键。

### 3. 使用指南

文章 3.1 节给出首次使用流程,3.2 节说明 KB 维护操作(添加/更新/索引),3.3 节讲解 SKILL
的编写规范与触发机制。ai-rd-system 项目在 kb/CLAUDE.md v0.1 中提炼了通用 9 段 SKILL 规范,
可视为本节的本地化精炼。

### 4. 8 个 SKILL 拆解

文章提出 8 个核心 SKILL:写技术方案、技术评审、编码实现、测试准备、专业答疑、问题排查
等。ai-rd-system 项目在 kb/KB-META.md §4 列出相同 8 个 SKILL 的实现进度,
当前仅 SKILL 1 `kb-doc-summary` v0.1 完成,SKILL 2-8 待写。

### 5. 评测闭环

文章提出 4 层 evaluation-driven 闭环:L1 结构层(每次 KB 变更跑 lint+schema)、
L2 实用层(15 task gold 集 r-N evaluation)、L3 信号层(3σ₀ 阈值判改进真伪)、
L4 治理层(≥10 页变更必更 log.md)。ai-rd-system 已实现 L1 部分(schema_gate.py + lint.py)。

## 引用片段

> LLM-Wiki 是由 Andrej Karpathy 于 26 年 4 月提出的"新知识库模式",本质就是一个 SKILL / md 文件。

> 维护知识库的累活不是"读"和"想",而是迭代 wiki 的过程:更新交叉引用、改综述、标矛盾、保一致性。

> 最终目标:全自动研发流程,即用户提供 prd,剩下工作都交给它。

## 跨引用

- [[/kb/KB-META]] — 本仓库的灵魂层 schema,直接对标阿里 KB-META 思想
- [[/kb/CLAUDE]] — SKILL 统一规范,本地化提炼自阿里 8 SKILL 描述
- [[/skills/kb-doc-summary]] — 已落地的 SKILL 1(对标阿里 8 SKILL 中的"知识管理"角色)

## 元数据

- 源文件: `/home/jack/projects/ai-rd-system/kb-md/ali-wiki-overview.md`
- md 文件: `kb-md/ali-wiki-overview.md`
- slug: `ali-wiki-overview`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)