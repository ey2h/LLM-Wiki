# 项目状态 — 2026-06-25

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

### Phase 2 — NAS 数据接入 → **改走 SMB** (commit `2f56ad5`)
- ~~NFS 路线~~ 弃(DSM Squash + Permission denied 折腾大)
- **走 gvfs 自动挂载**:Ubuntu 文件管理器访问 `smb://z720.local/jack 共享给我/`
  → 自动挂到 `/run/user/1000/gvfs/smb-share:server=z720.local,share=jack%20共享给我/`
- **符号链接 2 条** 进 `kb-source/`:
  - `z720-archives` → `项目存档`(历史归档,2012-2026 年度文件夹)
  - `z720-projects`  → `Projects`(当前活跃,BIM/Grasshopper/EY2H/MBA/Maijun 等)
- **`scripts/refresh_smb_mount.sh`**:登出/重启后挂载失效,跑这脚本重建链接
- **稳定性提示**:gvfs 路径是 session 级的,重启要重新登录 + 文件管理器点一下

## 📋 待启动

### Phase 3 — KB 架构 + 8 SKILL 包
- KB-META 设计未启动
- 8 个 SKILL 目录:`skills/` 下空骨架
- 评测闭环未设计
- **Phase 2 现在通了,可以从 z720-archives / z720-projects 直接抽取文档进 kb-md/**

## 🔧 待做小项
- [ ] `docs/INDEX.md` 加 serve-gemma 全局脚本 + refresh_smb_mount.sh 的引用
- [ ] `README.md` 快速开始加 SMB 接入说明
- [ ] `serve-gemma swap` 子命令(E4B/12B 一键切换)
- [ ] `convert.sh` 加 `--from z720-archives` 入口,直接转 NAS 文档
- [ ] 测一下 SMB 链路在 mineru + markitdown 下能不能直接读(性能/编码问题)

## 📦 当前 Git

```
main: 2f56ad5  (cleanup: 撤掉 Holo3.1 路线)
       c75511b  (docs: Holo3.1-4B 实测报告 — 已删除)
       c582840  (feat: Phase 1.5 Gemma 4 + Hermes fallback)
       6fe8a8e  (Phase 1 MinerU GPU)
```

## 🖥️ 当前资源

| 资源 | 状态 |
|---|---|
| GPU 显存 | 392M / 12.3G(完全空闲) |
| E4B server | ❌ 停(`serve-gemma e4b` 启动) |
| 12B server | ❌ 停(显存装不下 64K,平时不用) |
| Hermes 主模型 | MiniMax-M3(微信通道默认) |
| NAS SMB 挂载 | ✅ z720.local(需保持文件管理器登录状态) |
| fallback provider | gemma4-e4b(需手动起 server) |