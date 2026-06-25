# TODO — 待办清单

> 上次更新:2026-06-25

## 优先级 P0(必须做,否则系统不完整)

### 阻塞项

- [ ] **NFS ACL 问题**(Phase 2)
  - 用户拍板:DSM 控制面板改 Squash = "无映射" vs 试 SMB
  - 阻塞:Phase 2 文档管线起不来

## 优先级 P1(下一步规划,用户决定走哪条)

### Phase 1.6 — Holo3.1 GUI agent(可选路线)
- [ ] 决定是否下载 Holo3.1 模型(4B/9B/35B-A3B)
- [ ] 写 `docs/holo3-roadmap.md` 集成方案
- [ ] 评估需要 GPU 资源
- **状态**:用户说"等会",**待用户确认**

### Phase 3 — KB 架构设计
- [ ] 写 `docs/kb-meta.md`:KB-META 字段设计(实体/关系/属性)
- [ ] 设计 8 个 SKILL 目录的职责划分
- [ ] 评测闭环:用什么工具测 SKILL 质量
- **状态**:未启动

## 优先级 P2(完善性,可穿插做)

### 文档完善
- [ ] `docs/INDEX.md` 加 serve-gemma 全局脚本的引用
- [ ] `README.md` 快速开始段落加 Gemma 4 fallback 用法
- [ ] `docs/roadmap.md` 加 Holo3.1 路线分析

### serve-gemma 增强
- [ ] `swap` 子命令(E4B/12B 一键切换)
- [ ] `logs` 子命令(看启动日志路径)
- [ ] `list` 子命令(列出可用模型)

### 备份与回滚
- [ ] 测试 `~/.hermes/config.yaml.bak.gemma-pre` 回滚流程
- [ ] 写 `docs/llama-cpp-deploy.md` 加"回滚 fallback"章节

## 优先级 P3(技术债/可选优化)

### MinerU 优化
- [ ] 测 2.5-Pro-2605-1.2B vs 其他 OCR 模型对比
- [ ] MinerU 服务化(目前是 CLI,改成 HTTP server?)
- [ ] 写 `docs/mineru-bench.md`:速度 vs 准确度数据

### 模型下回源
- [ ] E4B 在 HF 上是 google/gemma-4-e4b-it(已确认魔塔镜像同步)
- [ ] 把 mmproj 路径加到 README 快速开始

## ✅ 已完成(归档)

- [x] llama.cpp b9784 + CUDA 编译
- [x] Gemma 4 GGUF 模型下载(魔塔)
- [x] serve-gemma 全局脚本
- [x] Hermes fallback 双轨配置(custom + fallback)
- [x] E4B 64K ctx 启动测试
- [x] 12B UMA 64K ctx 测试(决策:不给 Hermes 用)
- [x] MinerU GPU 跑 32 页 PDF ✅
- [x] Git push 到 ey2h/LLM-Wiki SSH ✅