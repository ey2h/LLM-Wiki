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
| markitdown | Office/PDF/图片 → md(纯文本) | `toolchain/envs/markitdown/` ✅ |
| MinerU | 复杂 PDF(扫描件/论文/表格) → md,**GPU vlm-engine** | `toolchain/envs/mineru/` ✅ (8.3G) |
| llama.cpp | GGUF 推理服务(E4B / 12B)| `~/.local/bin/llama-server` ✅ (b9784 + CUDA,自编译) |
| Gemma 4 GGUF | 本地 LLM/多模态推理(E4B 55 tok/s,12B 25 tok/s)| `~/models/gemma4-gguf/` ✅ |

**所有可执行入口在 `toolchain/bin/` 或 `~/.local/bin/`**,已经 PATH 化。

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

### 4. 启动 Gemma 4 GGUF 推理服务(按需)

**全局脚本**:`~/.local/bin/serve-gemma`(自动 PATH 化,任何目录可用)。

```bash
# 启动 E4B(port 8001,快,55 tok/s,5G 显存)
serve-gemma e4b

# 启动 12B(port 8002,质量高,25 tok/s,9.5G 显存)
serve-gemma 12b

# 停 / 状态 / 探活
serve-gemma stop
serve-gemma status
serve-gemma health
```

**一次只跑一个** — A3000 12G 装不下两个模型同时(16G > 12G)。日常保持空闲,按需启动。E4B 配为 Hermes 的 fallback provider(主模型挂了自动接)。详细见 [`docs/llama-cpp-deploy.md`](./docs/llama-cpp-deploy.md)。

---

## 📊 进度

- [x] Phase 0 — 目录骨架、工具链、文档初始化
- [x] Phase 1 — 工具链安装(markitdown ✅ + MinerU GPU ✅)
- [x] Phase 1.5 — 本地 LLM 推理(llama.cpp b9784 + CUDA ✅ + Gemma 4 E4B/12B GGUF ✅)
- [ ] Phase 2 — 批量文档转 md(第一轮摄入)
- [ ] Phase 3 — KB-META.md / CLAUDE.md schema 编写
- [ ] Phase 4 — 第一批 KB 页面(entities / concepts / sources)
- [ ] Phase 5 — 核心 SKILL(kb-tech-solution)开发
- [ ] Phase 6 — 评测闭环搭建(15 task gold 集)

### Phase 1 详情
- **markitdown[all]**:venv 110 包,转 HTML 7.2M → 80K md 验证通过
- **MinerU v3.3.1 GPU 版**:venv 8.3G,torch 2.11+cu130,vllm 0.21,MinerU2.5-Pro 1.2B 模型(2.2G)
- **测试**:32 页合同 PDF 53 秒解析完,双栏表格 / 法律条款 / 银行账号 全部识别
- **装法/排错**:`docs/mineru-gpu-install.md`(5 个坑都记录了)
- **脚本**:`scripts/parse_pdf.sh`(封装 MinerU 调用)+ `scripts/convert.sh`(智能路由)

### Phase 1.5 详情(本地 LLM 推理)
- **llama.cpp b9784 + CUDA**:自编译(Linux 唯一路径,因为 GitHub release + conda-forge 都没 Linux CUDA prebuilt)
- **Gemma 4 GGUF Q4_K_M**(魔塔下载):
  - E4B:5.0G,显存 4.7G,**55-57 tok/s**(port 8001)
  - 12B:6.9G,显存 9.5G,**25-26 tok/s**(port 8002)
- **多模态**:支持 image input(走 mmproj),text+image+audio 多模态
- **OpenAI 兼容 API**:`/v1/chat/completions` 可直接对接
- **测试**:简单问答 / 中文常识 / 代码生成 / 组合数学 全部通过
- **装法/排错**:`docs/llama-cpp-deploy.md`(5 个坑:无 Linux CUDA prebuilt / CUDA 头文件路径 / modelscope 参数 / thinking 模式吞 content 等)
- **脚本**:`~/.local/bin/serve-gemma`(全局,e4b / 12b / stop / status / health)
- **Hermes fallback**:`custom_providers` + `fallback_providers` 配 E4B(主模型挂了接上);**一次只跑一个**(A3000 12G 装不下两个同时),平时空闲按需 `serve-gemma e4b` 5 秒起好
- **下一步**:**Phase 1.6** Holo3.1(Computer-Use VLM,基于 Qwen) — 已分析,等 SKILL 框架搭好后接入

---

## 📚 参考资料

- `~/桌面/AI研发自动化系统:阿里Wiki知识库+技能包.html` — 主要参考文章
- `docs/reference/` — 拆解出来的章节笔记

---

## 📝 维护者

jack · 2026-06-17 起

**最后更新**:2026-06-25 (Phase 1.5 收尾:STATUS.md + TODO.md 上线)

> 详细进度大盘:`docs/STATUS.md` · 待办:`docs/TODO.md`
