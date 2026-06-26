---
type: Schema
title: KB 变更日志
description: 谁、什么时候、改了什么
created: 2026-06-26
updated: 2026-06-26
---

# KB 变更日志

> OKF v0.1 §7 保留文件名。LLM 维护 KB 时必更 ≥10 页变更的 PR。
> 阿里 KB-META 4 层治理层要求。

## 格式

```markdown
## YYYY-MM-DD — [变更标题]

- 变更类型: 新建概念 / 更新 / 修复 / 清理
- 变更范围: N 页
- 触发原因: ...
- 变更内容: ...
- 评测影响: ...
- 作者: jack (via Hermes)
```

---

## 2026-06-26 — Phase 3 KB-META v0.1 初始化

- 变更类型: 新建灵魂层
- 变更范围: 3 页(KB-META / index / log)
- 触发原因: Phase 3 启动,设计 OKF v0.1 + 阿里 KB-META 融合方案
- 变更内容:
  - `KB-META.md` v0.1(10.5K)—— 三家融合设计:OKF 格式层 + 阿里灵魂层 + Google 评测层
  - `index.md` v0.1(1.5K)—— KB 总目录
  - `log.md` v0.1(本文件)—— 变更日志
  - 目录骨架:concepts/ entities/ sources/<year>/ code/ queries/ playbooks/ plans/
- 评测影响: 无(初始版本,尚未有 gold set)
- 作者: jack (via Hermes)
- commit: 待 commit

## 2026-06-26 — Phase 3 规范层 + 评测层 + SKILL 1 端到端

- 变更类型: 新建规范 + 评测工具 + 18 个 Source concept 页
- 变更范围: 22 页(2 规范 + 2 lint 工具 + 18 concept)
- 触发原因: Phase 3 主线推进
- 变更内容:
  - `kb/CLAUDE.md` v0.1 — SKILL 工作规范(9 段结构 + Hard Gate + Guard Rail)
  - `kb/lint/schema_gate.py` v0.1 + 自测脚本 — L1 结构层评测
  - `kb/lint/lint.py` v0.1 — L1.5 语义 lint(孤页/断链/过时/重复/空页)
  - 18 个 Source concept 页(SKILL 1 在 2012 真实数据上跑通)
  - `docs/nfs-automount.md` — systemd automount 配置
- 评测影响: schema_gate 18/18 绿灯;lint 暴露 KB 不完整(7 孤页 + 6 真实断链)
- 8 commits 推到 origin/main:`89bec50..62bafbb`
- 作者: jack (via Hermes)

## 2026-06-26 — 竞品调研:Yuxi (xerrors/Yuxi)

- 变更类型: 调研笔记
- 变更范围: 1 篇调研文档
- 触发原因: 用户询问 Yuxi 与 ai-rd-system 区别
- 变更内容:
  - `docs/competitors/yuxi.md` — 定位差异 / 可借鉴点 / 决策:不迁移
- 决策: 借鉴 LightRAG 检索 + MCP 协议,但**不迁移到 Yuxi 平台**
- 未来可能: 加 LightRAG 检索层 / MCP 包 SKILL / Neo4j 知识图谱
- 作者: jack (via Hermes)

---

_(本文件由 LLM 维护,任何 ≥10 页变更必追加记录)_

## 2026-06-27 — SKILL 2 首次端到端跑通

- 产出 `kb/plans/curtain-wall-quote-v1-v1.md`(9.4KB,9 段齐全)
- 输入:`kb/prds/curtain-wall-quote-v1.md`(PRD)
- baseline:`kb/sources/2012/changzhou-zhonghang-quote-2708.md`
- schema_gate 20/20 绿灯
- 暴露 SKILL 2 缺陷 3 项(已记入下条 commit)
