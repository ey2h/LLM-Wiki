# 竞品调研:Yuxi (xerrors/Yuxi)

> **调研日期**: 2026-06-26
> **目的**: 厘清 Yuxi 与 ai-rd-system 的定位差异,避免被同类项目带偏
> **结论**: 不迁移到 Yuxi,但有 3 个点可借鉴

---

## 1. 一句话定位

| 项目 | 一句话 |
|------|--------|
| **Yuxi (语析)** | 多租户 Agent Harness SaaS 平台 — 装好就能用的产品 |
| **ai-rd-system (LLM-Wiki)** | 个人/团队 KB + SKILL 研发框架 — 自己维护的规范体系 |

**核心差异**:**Yuxi 是平台**(`docker-compose up` 一键起服务),**LLM-Wiki 是方法论**(git repo + markdown + 自写 lint)。

---

## 2. 详细对比

| 维度 | Yuxi | ai-rd-system |
|------|------|--------------|
| **形态** | 完整 Web 平台(Vue 3 + FastAPI + 多用户/权限) | 纯 markdown vault + git repo + 评测脚本 |
| **核心组件** | LangChain / LangGraph / LightRAG / Neo4j / Milvus / MinerU / MCP / DeepAgents | OKF v0.1 markdown / LLM-Wiki 概念页 / 自写 schema_gate + lint |
| **部署** | `docker-compose up` | git clone + 写 SKILL.md |
| **使用方式** | 浏览器 UI / CLI / API | agent 读 SKILL.md / CLI 跑 lint |
| **知识表示** | 向量库(Milvus)+ 图谱(Neo4j)+ 文档分块 | markdown frontmatter + bundle-relative 双链(无向量化) |
| **Agent 框架** | LangGraph 多 agent 编排 / 挂载 Skills / MCP 协议 | 8 个 SKILL 各管一段研发流程,路由靠 SKILL description |
| **评测** | 不强调(平台型不评自己) | 4 层闭环(阿里风格)+ schema_gate/lint 自动化 |
| **目标用户** | 企业 IT/知识管理员 | 一个人或小团队 |
| **复杂度** | 2,219 commits,完整产品 | 9 commits,Phase 3 起步 |
| **类似物** | Dify / FastGPT / Coze / 阿里百炼 | Karpathy LLM-Wiki 模式 + 阿里研发自动化思路 |

---

## 3. 可借鉴点(3 个)

### 3.1 LightRAG 检索层 🔍

**Yuxi 做法**:Milvus 向量库 + Neo4j 图谱,混合检索。
**ai-rd-system 现状**:全靠 markdown + git grep,**没有语义检索**。问"哪个 RFI 提到聚氨酯保温"只能 grep `聚氨酯`,无法扩展到"硬发泡聚氨酯"、"PU 发泡"等变体。
**借鉴方式**:加一个 `kb/search/` 层(可选),用轻量向量化(BGE-small 或 Qwen3-embedding)做语义检索,**输出仍是 markdown 双链,不破坏现有 git diff 优势**。
**优先级**:中(等 KB 超过 200 页再说,现在 18 页 grep 够用)

### 3.2 MCP 协议包 SKILL 🔌

**Yuxi 做法**:Skills 通过 MCP 协议挂载,平台统一管理。
**ai-rd-system 现状**:agent 直接读 `skills/<name>/SKILL.md`,自己解析。
**借鉴方式**:把每个 SKILL 包成 MCP server(`kb-doc-summary-mcp` / `kb-just-ask-mcp` 等),Claude/Cursor 等 IDE 直接挂载。
**优先级**:高(2026 下半年 MCP 标准化,可显著降低 agent 接入成本)
**风险**:MCP 是 Anthropic 主导,如果走偏有 lock-in 风险。OKF v0.1 是 vendor-neutral,SKILL 仍以 markdown 为主,MCP 只是包装层。

### 3.3 Neo4j 知识图谱(谨慎) 🕸️

**Yuxi 做法**:文档 → 图谱,支持图遍历推理。
**ai-rd-system 现状**:`[[/sources/x]]` 双链本质是图,但**没有图遍历工具**。Obsidian Graph View 是视觉化,不是真图查询。
**借鉴方式**:从 `[[/concepts/x]]` 自动生成 Neo4j 节点边,加 `/entities/` 实体抽取 SKILL。
**优先级**:低(双链目前够用,图谱是 overkill)
**风险**:Neo4j 引入运维负担,与"零依赖 markdown + git"的核心优势冲突。

---

## 4. 不借鉴的点(明确划界)

### 4.1 不迁移到 Yuxi 平台 ❌

- 一旦部署,迁移成本极高(用户数据/权限/插件)
- ai-rd-system 的核心优势是 **完全可控 + git diff 可审计 + 零依赖**
- Yuxi 是"装好就能用",ai-rd-system 是"自己长出来"

### 4.2 不抄 LangGraph 多 agent 编排 ❌

- LangGraph 是 DAG 工作流,适合**确定流程**(客服机器人)
- 研发流程是**混沌对话**(用户问"X 怎么改",agent 反问几次才懂)
- ai-rd-system 的 SKILL 是"按需调用"模式(LLM 自己选),不是"工作流"模式

### 4.3 不抄 Vue + FastAPI 整套 ❌

- 我们不需要 Web UI(KB 是 agent 读的,不是人看的)
- Obsidian + 任意文本编辑器已经够用
- 引入 Web UI 会重新变成"维护产品"而不是"维护知识"

---

## 5. 决策与下一步

**决策**:**保持 ai-rd-system 当前架构**,有选择地借鉴 Yuxi 的 3 个点。

| 借鉴项 | 触发时机 | 实施方式 |
|--------|----------|----------|
| LightRAG 检索层 | KB > 200 页 或 用户问"找不到某个 RFI" | 加 `kb/search/` 子目录,纯可选 |
| MCP 包 SKILL | Claude/Cursor 用户量大 或 跨 IDE 需求 | SKILL.md 保持 markdown,加 `mcp-server.py` 包装 |
| Neo4j 知识图谱 | 不确定 | **暂不引入**,除非有明确查询需求 |

**下一步**:继续 Phase 3 主线 — 写 SKILL 2-8 + 跑 SKILL 1 在 2012 之外的其他年份(2026-06-26 已完成 SKILL 1 端到端试跑)。

---

## 6. 参考链接

- [xerrors/Yuxi GitHub](https://github.com/xerrors/Yuxi) — 项目主页
- [Yuxi 文档](https://xerrors.github.io/Yuxi) — 官方文档
- [DeepWiki Yuxi](https://deepwiki.com/xerrors/Yuxi) — 自动生成的 wiki

---

**maintainer**: jack (via Hermes)
**status**: active
**version**: 0.1