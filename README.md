# AI 研发自动化系统 (AI-RD-System)

> 基于 LLM-Wiki 知识库 + 专家 SKILL 包的研发自动化平台。
> 参考:阿里《AI 研发自动化系统:Wiki 知识库 + 技能包》

---

## 🎯 项目目标

**用户给 PRD,剩下都交给 AI。**

完整覆盖研发链路:写技术方案 → 技术评审 → 编码实现 → 测试准备 → 测试修复 → 专业答疑 → 问题排查。

---

## 📐 架构(三层)

```
┌─────────────────────────────────────────────────────────────┐
│ L3 Schema  ←  KB-META.md / CLAUDE.md (LLM 的工作规范)        │
├─────────────────────────────────────────────────────────────┤
│ L2 Wiki    ←  kb/ (LLM 维护的互链 markdown 知识库)           │
├─────────────────────────────────────────────────────────────┤
│ L1 Sources ←  kb-source/ (原始文档,只读) + 代码仓(只读)       │
└─────────────────────────────────────────────────────────────┘
                       +
        skills/  (8 个专家技能,按需路由)
```

---

## 🗂️ 目录结构(快速索引)

| 目录 | 作用 | Git |
|---|---|---|
| `kb-source/` | L1 原始材料(docx/pdf/pptx/图片),**只读** | ❌ 太大 |
| `kb-md/` | markitdown/MinerU 转出的中间 md | ❌ 可重新生成 |
| `kb/` | L2 真正的知识库(LLM 全权维护) | ✅ |
| `skills/` | 8 个 SKILL 包,每个一个子目录 | ✅ |
| `toolchain/` | 工具链:Python 环境 + 启动脚本 | ❌ 太大 |
| `scripts/` | 一键转换、评测、部署脚本 | ✅ |
| `docs/` | 设计文档、规划、对比笔记 | ✅ |

**详细地图见 [`INDEX.md`](./INDEX.md)** ← ⭐ 每次找东西先看这个

---

## 🛠️ 工具链

工具都装在 `toolchain/envs/` 下,激活用 `source toolchain/env.sh <env_name>`。

| 工具 | 用途 | 环境 |
|---|---|---|
| markitdown | Office/PDF/图片 → md(纯文本) | `toolchain/envs/markitdown/` |
| MinerU | 复杂 PDF(扫描件/论文/表格) → md | `toolchain/envs/mineru/` |

**所有可执行入口在 `toolchain/bin/`**,已经 PATH 化。

---

## 🚀 快速开始

### 1. 激活工具环境

```bash
# markitdown 环境
source ~/projects/ai-rd-system/toolchain/env.sh markitdown

# MinerU 环境(需要 GPU)
source ~/projects/ai-rd-system/toolchain/env.sh mineru
```

### 2. 一键转换文档

```bash
# 把 kb-source/ 下的所有文档转 md,落到 kb-md/
~/projects/ai-rd-system/scripts/convert.sh ~/projects/ai-rd-system/kb-source
```

### 3. 跑 SKILL

待 SKILL 包开发完后,通过 Claude Code / Aone-Copilot / Hermes 加载 `skills/`。

---

## 📊 进度

- [x] Phase 0 — 目录骨架、工具链、文档初始化
- [ ] Phase 1 — 工具链安装(markitdown + MinerU)
- [ ] Phase 2 — 批量文档转 md(第一轮摄入)
- [ ] Phase 3 — KB-META.md / CLAUDE.md schema 编写
- [ ] Phase 4 — 第一批 KB 页面(entities / concepts / sources)
- [ ] Phase 5 — 核心 SKILL(kb-tech-solution)开发
- [ ] Phase 6 — 评测闭环搭建(15 task gold 集)

---

## 📚 参考资料

- `~/桌面/AI研发自动化系统:阿里Wiki知识库+技能包.html` — 主要参考文章
- `docs/reference/` — 拆解出来的章节笔记

---

## 📝 维护者

jack · 2026-06-17 起
