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

## ⏸️ 阻塞中

### Phase 2 — 群晖 NFS 挂载
- **状态**:技术层通,ACL 锁死
- `vers=3,nolock,soft` 挂得上,但 `/mnt/project` mode 000
- 客户端 jack 无权访问(DSM 默认 Squash 把 root → nobody)
- **DSM 控制面板 → 共享文件夹 → NFS 权限 → 高级设置 → Squash → "无映射"** 可解(用户决定是否开)
- SMB 备选方案未试

## 📋 待启动

### Phase 1.6 — Holo3.1 集成路线(commit `4eee922`)
- **H Company(法国)2026-06-01 发布**,基座 Qwen 3.5,Apache 2.0
- 4 个尺寸:0.8B / 4B / 9B / 35B-A3B(MoE 3B 激活)
- 量化:BF16 / FP8 / Q4 GGUF / NVFP4(A3000 不支持 NVFP4 硬件加速)
- AndroidWorld 67% → **79.3%**(35B-A3B)
- 4B/9B AndroidWorld 58% → **71%**
- **A3000 12G 兼容性**:4B 最佳(3.2G),9B 满载,35B 跑不动
- **GGUF 源推荐**:`prithivMLmods/Holo-3.1-4B-GGUF`(4B + mmproj 齐)
- **路线写完**:`docs/holo3-roadmap.md`(4.4K,121 行)
- **决策点**:是否下 4B 试水 / 走 GUI agent SKILL 路线

### Phase 3 — KB 架构 + 8 SKILL 包
- KB-META 设计未启动
- 8 个 SKILL 目录:`skills/` 下空骨架
- 评测闭环未设计

## 🔧 待做小项

- [ ] `docs/INDEX.md` 加 serve-gemma 全局脚本的引用
- [ ] `README.md` 快速开始加 fallback 使用说明
- [ ] `serve-gemma swap` 子命令(E4B/12B 一键切换)
- [ ] 把 Holo3.1 决策写到 `docs/roadmap.md`

## 📦 当前 Git

```
main: c582840
```

## 🖥️ 当前资源

| 资源 | 状态 |
|---|---|
| GPU 显存 | 572M / 12.3G(完全空闲) |
| E4B server | ❌ 停 |
| 12B server | ❌ 停 |
| Hermes 主模型 | MiniMax-M3(微信通道默认) |
| fallback provider | gemma4-e4b(需手动起 server) |