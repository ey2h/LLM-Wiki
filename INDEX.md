# 📍 INDEX — 项目地图

> 这是整个项目的"导航地图"。**每次找东西先看这里。**
> 最后更新:2026-06-18

---

## 🗺️ 顶层结构

```
~/projects/ai-rd-system/         ← 根目录(整个项目,git 仓库)
├── README.md                    ← 项目总览(做什么/怎么做/进度)
├── INDEX.md                     ← 你正在看的这个(地图)
├── .gitignore                   ← git 忽略规则
│
├── kb-source/                   ← 📥 L1 原始材料(只读,不进 git)
│                                  ├── docx / pdf / pptx / xlsx
│                                  └── 图片(jpg/png)
│
├── kb-md/                       ← 📄 markitdown/MinerU 转好的 md(中间产物)
│                                  ├── *.md
│                                  └── images/
│
├── kb/                          ← 📚 L2 真正的知识库(LLM 维护,进 git)
│   ├── KB-META.md               ←    入口:KB 的元信息 + 路径约定
│   ├── CLAUDE.md                ←    L3 Schema:LLM 的工作规范
│   ├── index.md                 ←    知识库目录(按主题/业务线分类)
│   ├── log.md                   ←    知识库变更日志
│   ├── entities/                ←    实体页(模块、核心类、接口)
│   ├── concepts/                ←    概念页(业务概念、技术概念)
│   ├── sources/                 ←    文档摘要(L1 → L2 的入口)
│   ├── code/                    ←    代码知识化
│   │   ├── modules/             ←      模块概述
│   │   ├── classes/             ←      核心类详情
│   │   └── diagrams/            ←      类关系图、调用链
│   ├── queries/                 ←    高价值问答存档
│   ├── assets/                  ←    图片等资源
│   └── scripts/                 ←    知识库维护脚本(lint 等)
│
├── skills/                      ← 🧠 SKILL 包(8 个专家技能)
│   ├── kb-just-ask/             ←    全能管家,路由到其他 SKILL
│   ├── kb-tech-solution/        ←    写技术方案
│   ├── kb-tech-review/          ←    技术评审
│   ├── kb-just-coding/          ←    编码实现
│   ├── kb-test-pre/             ←    测试方案 + 数据准备
│   ├── kb-test-fix/             ←    自动化测试修复
│   ├── kb-problem-solve/        ←    专业答疑
│   └── kb-sync/                 ←    知识库同步(git pull/push)
│
├── toolchain/                   ← 🔧 工具链(不进 git,太大)
│   ├── envs/                    ←    Python 虚拟环境
│   │   ├── base/                ←      基础环境(共同依赖)
│   │   ├── markitdown/          ←      markitdown 环境 ✅
│   │   └── mineru/              ←      MinerU GPU 环境 ✅ (8.3G, vlm-engine 可用)
│   ├── bin/                     ←    可执行包装脚本(PATH 化)
│   ├── MinerU-src/              ←    MinerU 源码 git clone(已改 utils.py)
│   └── logs/                    ←    各工具运行日志
│
├── scripts/                     ← 📜 顶层脚本(进 git)
│   ├── convert.sh               ←    一键文档转换(智能路由:PDF→MinerU GPU,Office→markitdown)
│   └── parse_pdf.sh             ←    MinerU GPU 解析 PDF 封装(设好 CUDA_HOME + HF 镜像)
│
└── docs/                        ← 📖 文档(进 git)
    ├── mineru-gpu-install.md    ←    MinerU GPU 装法 + 5 个坑的排错
    ├── plans/                   ←    各阶段实施计划
    ├── design/                  ←    设计文档(schema、SKILL 设计)
    └── reference/               ←    参考资料拆解(阿里文章各章节笔记)
```

---

## 🔑 关键文件速查表

| 想找什么 | 去这里 |
|---|---|
| 项目是什么 | `README.md` |
| 目录在哪 | 本文件 |
| 原始文档 | `kb-source/` |
| 转好的 md | `kb-md/` |
| 知识库入口 | `kb/KB-META.md` + `kb/index.md` |
| LLM 的工作规范 | `kb/CLAUDE.md` |
| 写技术方案怎么搞 | `skills/kb-tech-solution/SKILL.md` |
| 工具怎么装 | `toolchain/envs/<name>/` |
| 激活环境 | `source toolchain/env.sh <name>` |
| 一键转文档 | `scripts/convert.sh <dir>` |
| 单个 PDF 解析(GPU) | `scripts/parse_pdf.sh file.pdf out_dir/` |
| **Gemma 4 GGUF 服务** | `serve-gemma {e4b\|12b\|stop\|status\|health}` 全局脚本(`~/.local/bin/`)|
| MinerU 装法/排错 | `docs/mineru-gpu-install.md` |
| llama.cpp 装法/排错 | `docs/llama-cpp-deploy.md` |
| 阿里文章各章节笔记 | `docs/reference/` |

---

## 🧰 工具命令速查

```bash
# === 激活环境 ===
source ~/projects/ai-rd-system/toolchain/env.sh markitdown
source ~/projects/ai-rd-system/toolchain/env.sh mineru

# === 一键转文档 ===
~/projects/ai-rd-system/scripts/convert.sh <input_dir> [<output_dir>]

# === 查看 kb 状态 ===
cd ~/projects/ai-rd-system/kb && wc -l entities/*.md concepts/*.md

# === 知识库同步(未来 SKILL) ===
# (待 kb-sync skill 完成后)
```

---

## 📅 变更记录

| 日期 | 变更 |
|---|---|
| 2026-06-17 | 项目初始化,目录骨架 + 文档 + git 仓库建立 |
| 2026-06-18 | 创建 toolchain/(envs/bin/logs)+ scripts/convert.sh + .gitignore + .gitattributes,git init 并首个 commit (4d425e6) |
| 2026-06-18 | 装好 markitdown[all](阿里源),转 ali-wiki HTML 验证(80K md) |
| 2026-06-18 | 装好 MinerU v3.3.1 GPU 版:venv 8.3G + MinerU2.5-Pro 1.2B 模型(2.2G,HF 镜像)+ 改 utils.py gpu_mem 0.5→0.85 + CUDA toolkit 12.4 装好;32 页合同 PDF 53 秒解析完 |
| 2026-06-18 | 固化 parse_pdf.sh + 改 convert.sh PDF 路由走 MinerU + 写 docs/mineru-gpu-install.md(5 个坑全记录) |
| 2026-06-25 | Phase 1.5:全局编译 llama.cpp b9784 + CUDA(35 分钟),下 Gemma 4 E4B/12B GGUF(魔塔),E4B 55 tok/s 跑通,12B 25 tok/s 跑通 |
| 2026-06-25 | 写全局脚本 `~/.local/bin/serve-gemma`(e4b/12b/stop/status/health)+ 配 Hermes custom_providers + fallback_providers(E4B 64K ctx),一次只跑一个 |
| | |

---

## 📝 维护说明

- `INDEX.md` 是"地图",任何目录结构变化**必须同步更新**
- 新增 SKILL:在 `skills/` 加目录,SKILL.md 放里面,并在本文件速查表登记
- 新增工具链:在 `toolchain/envs/` 加环境,在本文件速查表登记
- 变更记录:表格加一行
