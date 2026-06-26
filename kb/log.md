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

---

_(本文件由 LLM 维护,任何 ≥10 页变更必追加记录)_
