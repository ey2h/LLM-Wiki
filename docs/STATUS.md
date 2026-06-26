# 项目状态 — 2026-06-26

> 每个 commit 后回写。反映"现在真实能跑什么"。

## ✅ 已完成

### Phase 0 — 项目骨架 (commit `4d425e6`)
- 工作目录:`~/projects/ai-rd-system/`
- 推到 GitHub:`ey2h/LLM-Wiki` (SSH,无需 token)
- 结构:`kb-source/` + `kb-md/` + `kb/` + `skills/` + `toolchain/` + `scripts/` + `docs/`

### Phase 1 — MinerU 2.5 GPU 文档解析 (commit `6fe8a8e`)
- 工具链:`uv 0.11.21` + Python 3.11 venv
- 装了 markitdown(纯文本)+ mineru[all](GPU)
- MinerU 2.5-Pro-2605-1.2B(2.2G)HF mirror 下完
- **A3000 跑通 32 页 PDF → 53 秒出 57KB md** ✅
- 显存占用 patch:gpu_memory_utilization 0.5 → 0.85

### Phase 1.5 — Gemma 4 本地推理 + Hermes fallback (commit `c582840`)
- **llama.cpp b9784 + CUDA** 源码编译(比 GitHub release b9754 新 1 commit)
- 安装到:`~/.local/bin/{llama-server, llama-cli, llama-quantize, llama-gguf-hash}`
- **Gemma 4 GGUF 模型** 下到 `~/models/gemma4-gguf/`:
  - E4B:5.0G Q4_K_M + 534M mmproj
  - 12B:6.9G Q4_K_M + 152M mmproj
- **全局脚本 `serve-gemma`**:`e4b|12b|stop|status|health`,不依赖项目路径
- **Hermes config 配好**:custom_providers + fallback_providers 双轨
  - E4B 64K context(显存 5.7G,A3000 12G 装得下)
  - 12B 未配(12G 显存 64K ctx 必走 UMA,挤爆,放弃给 Hermes)
- **Hermes fallback 测过**:`hermes chat --provider gemma4-e4b` 跑通 ✅
- **方案 B(完全空闲按需启动)**:server 默认不起,触发 fallback 前手动 `serve-gemma e4b`

### Phase 1.6 — Holo3.1 试水 → **撤回** (cleanup `2f56ad5`)
- H Company 4B GGUF 跑通 server,token/s 健康(60 tok/s,首 token 91ms)
- **GUI grounding 坐标偏 190px + Q4 量化中文短 prompt 循环 bug** —— 不可用
- Wayland mutter + SSH 进程无法做真实点击(portal/permission/ydotool 三重卡)
- **全清掉**:模型 / server / ydotool / xdotool / grim / wtype / portal-gnome / dbus-gi / 文档

### Phase 1.7 — MinerU 3.4.0 + NAS 文档全量转换 (commits `18a2561` → `373511b` → `bb2d8a7`)
- **升级**:`pip install -U mineru[all]`(清华镜像)3.3.1 → 3.4.0
- **OCR 升级到 PP-OCRv6**(准确率 +11%,速度 +100%)
- **NAS 数据接入走 NFS**(`/mnt/nfs/{项目存档,LLM-WIKI}`,DSM export 双 share)
- **扫描件判别**:`scripts/pdf_is_scanned.py` 中间 3 页 avg char < 30 → 扫描件

#### 文档转换策略(固化)
| 格式 | 路径 | 原因 |
|------|------|------|
| `.pdf` 非扫描 | `pdftotext -layout` | 系统命令,中英保版式,快 |
| `.pdf` 扫描件 | mineru GPU `-m auto` | 含表格/LaTeX/OCR,70s/19页,7G 显存 |
| `.docx/.xlsx/.xls/.pptx` | markitdown | 直接吃 |
| `.doc/.ppt`(旧 binary) | LibreOffice headless → docx/pptx → markitdown | markitdown 0.1.6 (PyPI 最新 May 2026) 不支持 .doc/.ppt,**LO 走 docx 中转保留 Word 结构**(不能直接 txt 丢格式) |
| `.txt/.log` | `cp` | 直接当 md |
| `.dwg/.dxf/.bak/.JPG/.ARW/.CR2/.THM/.rar/.zip` 等 | 跳过 | 不是文本 |

#### 路径 bug 修复(commit `18a2561`)
- 原 `ls -laR | awk '{print $NF}'` 拼接相对路径会丢子目录前缀,**子目录文件 95% 路径错**
- 改用 `cd $SRC && find . -type f -not -path './@eaDir/*'` → 真实相对路径
- 跳过 Synology thumbnail 目录 `@eaDir/` 和 macOS `.DS_Store`

#### LibreOffice 兜底(commits `373511b` → `bb2d8a7`)
- markitdown converters 目录**只有 `_docx/_pptx`,没有 `_doc/_ppt`** —— PyPI 0.1.6 已最新
- **LO 对 NFS 中文路径偶发 `Error: source file could not be loaded`** —— 加 3 次 retry + sleep 2
- `scripts/lo_retry_failed.sh`:扫 `convert_*.log` 里 `markitdown failed` 行,**只对 .doc/.ppt 重试用 LO 处理**

#### 全量进度(2026-06-26 后台跑)
- 源:`/mnt/nfs/项目存档/2012/`,目标:`/mnt/nfs/LLM-WIKI/raw/2012/`
- 2012 共 2869 文件,**可转换 696**(`pdf:336 + doc:88 + docx:38 + xls:48 + xlsx:127 + pptx:25 + ppt:. + txt/log:23`)
- 跳过 ~2173(dwg/dxf/JPG/ARW/CR2/THM/rar/zip/tmp/@eaDir)
- 后台跑旧版脚本(无 LO),已扫 280+ 个,等跑完跑 `lo_retry_failed.sh` 补 .doc/.ppt
- 估算:markitdown 文档类 1-3s/个,mineru 扫描件 60-120s/个,总 1-2 小时

#### GPU A3000 12G 占用
- 静态 ~370 MiB
- mineru vlm-engine 峰值 ~7 GB(2.15G vlm + 773M unimernet + OCR models)

### Phase 2 — NAS 数据接入 → **走 NFS** (commit `fea3314`)
- ~~SMB 路线~~ 试过 → **改 NFS**(DSM 端 NFS export 已加)
- **NFS 挂载**:`192.168.1.101:/fs/1000/nfs` → `/mnt/nfs`
  - 包含两个 share:`项目存档/`(历史归档)+ `LLM-WIKI/`(知识库)
- **SMB gvfs 备选**:`/run/user/1000/gvfs/smb-share:server=z720.local,share=jack%20共享给我/`
- **符号链接** `kb-source/z720-archives` + `z720-projects`(指 SMB 路径,刷新用 `scripts/refresh_smb_mount.sh`)

## 📋 待启动

### Phase 3 — KB 架构 + 8 SKILL 包
- KB-META 设计未启动
- 8 个 SKILL 目录:`skills/` 下空骨架
- 评测闭环未设计
- **Phase 2 现在通了,可以从 z720-archives / z720-projects 直接抽取文档进 kb-md/**
- **2012 全量跑完后**,要做:
  - 抽 2013/2014/.../2026 各年度(SMB 路径相同策略)
  - 抽 Projects/(BIM/C#/EY2H/JJS/MBA/Maijun 新项目,2014+)
  - 整理 kb-md/ 抽进 kb/ 知识库

## 🔧 待做小项
- [ ] `docs/INDEX.md` 加 serve-gemma 全局脚本 + refresh_smb_mount.sh + convert_year_2012.sh 引用
- [ ] `README.md` 快速开始加 NFS 接入说明
- [ ] `serve-gemma swap` 子命令(E4B/12B 一键切换)
- [ ] `convert_year.sh <year>` 通用脚本(支持任意年份,2012 是特例)
- [ ] GPU 利用率优化:mineru 串行跑扫描件是瓶颈,可考虑并行 2 个 PDF(显存吃满)
- [ ] 阈值优化:`avg < 30` 偏宽,有些空 PDF 也被判非扫描,降阈值到 10 可补救

## 📦 当前 Git

```
main: bb2d8a7  (fix: .doc 走 docx + LO retry)
       373511b  (feat: LibreOffice headless 兜底)
       18a2561  (fix: find -printf 修复路径 bug)
       fea3314  (Phase 2 NFS)
       2f56ad5  (cleanup: 撤掉 Holo3.1 路线)
       c75511b  (docs: Holo3.1-4B 实测报告 — 已删除)
       c582840  (feat: Phase 1.5 Gemma 4 + Hermes fallback)
       6fe8a8e  (Phase 1 MinerU GPU)
```

## 🖥️ 当前资源

| 资源 | 状态 |
|---|---|
| GPU 显存 | 392M 静态,~7GB mineru 峰值(12.3G 总) |
| E4B server | ❌ 停(`serve-gemma e4b` 启动) |
| 12B server | ❌ 停(显存装不下 64K,平时不用) |
| Hermes 主模型 | MiniMax-M3(微信通道默认) |
| NAS NFS 挂载 | ✅ `/mnt/nfs/{项目存档,LLM-WIKI}` |
| NAS SMB 备选 | ✅ `/run/user/1000/gvfs/smb-share:z720.local/` |
| fallback provider | gemma4-e4b(需手动起 server) |
| mineru 版本 | 3.4.0(GPU) |
| markitdown 版本 | 0.1.6(PyPI 最新) |
| LibreOffice | 26.2.3.2(`libreoffice --headless` headless 模式可用) |
| 后台进程 | `convert_year_2012.sh`(pid 30934)预计 1-2 小时跑完 |
