# Holo3.1 集成路线(Phase 1.6)

> 最后更新:2026-06-25 · 基于 H Company 2026-06-01 官方发布

## 1. 真实情况(2026-06-25 官网)

| 项 | 值 |
|---|---|
| 发布日期 | 2026-06-01 |
| 发布方 | H Company(法国 Paris,前 Holistic AI) |
| 基座 | **Qwen 3.5 家族**(不是 Qwen 3.6) |
| 模型尺寸 | 0.8B / 4B / 9B / 35B-A3B(MoE 3B 激活)|
| 量化 | BF16 / FP8 / Q4 GGUF / **NVFP4 W4A16** |
| License | 35B-A3B = **Apache 2.0** ✅ 开放 |

## 2. 基准成绩(H Company 官方)

### AndroidWorld 67% → 79.3% (35B-A3B)
| 模型 | Holo3(2025-03) | Holo3.1(2026-06) |
|---|---|---|
| 35B-A3B | 67% | **79.3%** |
| 4B/9B | 58% | **71%** |
| 0.8B | — | (未公开,估计 55% 上下)|

### 量化精度对比(OSWorld, 35B-A3B)
- BF16:基线
- FP8 / NVFP4:跟 BF16 几乎同分(只低 ~2 分)
- Q4 GGUF:略低 ~5 分

### DGX Spark 加速(单卡 NVIDIA 特殊硬件)
- BF16 → 1.0×
- FP8 → 1.27×
- NVFP4 → **1.74×**
- 端到端步时 6.8s → 3.3s(**~2×**)

⚠️ **A3000 是 RTX 桌面卡,不支持 NVFP4**。只能走 Q4 GGUF。

## 3. A3000 12G 兼容性

| 模型 | GGUF Q4_K_M | 显存估算 | A3000 12G |
|---|---|---|---|
| Holo3.1-0.8B | ~0.6G | 1G | ✅ 随便跑 |
| **Holo3.1-4B** | **3.2G** | **5G** | ✅ 能跑 + 余 7G |
| Holo3.1-9B | ~6.5G | 9G | ⚠️ 满载 |
| Holo3.1-35B-A3B | ~20G | 22G+ | ❌ 跑不动(35B MoE 太大了)|

**推荐**: Holo3.1-4B(主选)+ Holo3.1-9B(选配,跟 E4B/12B 同样问题"一次只跑一个")

## 4. 可用的 GGUF 源

| 源 | 内容 | 推荐度 |
|---|---|---|
| **`Hcompany/Holo-3.1-35B-A3B-GGUF`** | 官方量化(只 35B) | ⭐ 35B 唯一官方源 |
| **`prithivMLmods/Holo-3.1-4B-GGUF`** | 4B 社区量化,**带 mmproj-bf16 676M** | ⭐ 4B 首选(齐了)|
| `mradermacher/Holo-3.1-4B-GGUF` | 4B 老牌 imatrix 专家量化 | 备选 |
| `mradermacher/Holo-3.1-9B-GGUF` | 9B imatrix 量化 | 备选 |

⚠️ **国内拉 HF**:走 `HF_ENDPOINT=https://hf-mirror.com`(我们之前下 Gemma 4 用的镜像)
⚠️ **魔塔镜像**:确认 Hcompany 是否同步(Holo3.1 太新,2026-06-01 发布,魔塔可能滞后)

## 5. 集成方案

### 方案 A:Holo3.1 替换 Gemma 4 E4B 作为 Hermes fallback

**优势**: Holo3.1 是 VLM(看图),E4B 也是 VLM,能力接近
**劣势**: Holo3.1 专攻 GUI agent,普通对话/代码能力可能不如 E4B 通用
**结论**: **不推荐** —— 通用能力可能下降,失去了 E4B fallback 的意义

### 方案 B:Holo3.1 作为独立的"GUI 自动化"SKILL(推荐)

新建 `skills/holo3-gui-agent/`,职责:
- **看截图 → 决定下一步操作**(点哪里、输什么)
- 集成 **Holotab 风格的 harness**(H Company 提到会发 desktop agent harness)
- 可对接:**Playwright**(web)、**xdotool**(Linux 桌面)、**Android Debug Bridge**(移动)

应用场景:
- 自动跑回归测试(GUI 端)
- 自动填表/抓数据
- 抓 bug 复现截图

### 方案 C:作为 mineru 的 OCR 后处理(辅助)

Holo3.1 强在 UI 截图理解,可以**二次校验** MinerU 转的 md 是否漏掉表格/图标
**但有 overlap**: MinerU 已经看 PDF 截图了

## 6. 推荐执行路径(用户决定)

### 路径 1(保守):只调研,不下
- 写完本文档 → ✅ 完成
- TODO 标"未启动"
- 等 H Company 发 desktop harness 再动手

### 路径 2(我推荐):先下 4B 试水
1. `hf download prithivMLmods/Holo-3.1-4B-GGUF`(~3.2G)
2. 启 `llama-server -m Holo-3.1-4B-Q4_K_M.gguf --mmproj Holo-3.1-4B.mmproj-bf16.gguf`
3. 跑 3-5 个 GUI 截图理解测试
4. 决定要不要做方案 B(GUI agent SKILL)

### 路径 3(激进):直接搭 GUI agent SKILL
- 先完成路径 2 验证
- 然后写 `skills/holo3-gui-agent/` 的 SKILL.md
- 集成 Playwright + xdotool

## 7. 跟主线的关系

| 主线 phase | Holo3.1 是否相关 |
|---|---|
| Phase 2(批量文档转 md)| ❌ 不直接相关 |
| Phase 3(KB-META schema)| ❌ 不相关 |
| Phase 4(第一批 KB 页面)| ❌ 不相关 |
| Phase 5(核心 SKILL)| ✅ **可作为 "kb-auto-test" SKILL 的视觉引擎** |
| Phase 6(评测闭环)| ✅ **可用 Holo3.1 自动抓 SKILL 输出截图 + 评测** |

**结论**: Holo3.1 是"评测自动化"和"GUI 测试"的好工具,**不是知识库本身**。

## 8. 待决策(给 jack)

- [x] **跑路径 2**:✅ 测完(见 `docs/holo3-test-report.md`)
  - 下 Holo3.1-4B Q4_K_M ✅(hf-mirror,5 分钟)
  - 启 llama-server ✅(4.4G 显存,58 tok/s)
  - 跑 5 个测试 ❌ 发现**致命问题**:Q4 量化 + 短 prompt 会无限循环
  - GUI grounding 坐标错 190px
- [ ] **下一步:试 Q5_K_M / Q8_0?** 还是直接跳过 Holo3.1?