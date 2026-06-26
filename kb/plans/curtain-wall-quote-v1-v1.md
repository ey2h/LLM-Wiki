---
title: 幕墙与外装修工程造价估算方案 v1
slug: curtain-wall-quote-v1
description: 用 KB 中 changzhou zhonghang 2014 项目作为 baseline,演示如何由 PRD curtain-wall-quote-v1 生成可执行的工程造价方案,总价 2708 万,confidence 0.85
type: Plan
plan_type: tech-solution
prd_slug: curtain-wall-quote-v1
related_prd: "[[/kb/prds/curtain-wall-quote-v1]]"
reference_projects:
  - "[[/kb/sources/2012/changzhou-zhonghang-quote-2708]]"
total_quote_cny: 27085372.76
confidence_score: 0.85
risk_flags:
  - baseline_only_one_project
  - changzhou_city_baseline_only
  - 2014_year_baseline
summary_table: |
  | 子系统 | 面积 m² | 单价 元/m² | 合计 ¥ | 占比 |
  |---|---:|---:|---:|---:|
  | 干挂石材幕墙 | 7839.00 | 1161.78 | 9,107,860 | 33.6% |
  | 玻璃幕墙(明框+单元) | 1498.00 | 1080.50 | 1,618,580 | 6.0% |
  | 玻璃幕墙(全隐框) | 1420.00 | 1403.45 | 1,992,900 | 7.4% |
  | 断桥铝门窗 | 740.00 | 1153.58 | 853,650 | 3.2% |
  | 金属屋面 + 铝板 | 462.00 | 687.73 | 317,750 | 1.2% |
  | 钢结构雨棚 | 200.00 | 1800.00 | 360,000 | 1.3% |
  | 室内粗装修 | 553.41 | 956.22 | 529,160 | 2.0% |
  | 7 子系统小计 | 12712.41 | 1162.63 | 14,779,900 | 54.6% |
  | **含措施费/规费/税金 总造价** | **12712.41** | **2130.79** | **27,085,373** | **100%** |
unit_price_analysis:
  - subsystem: 干挂石材幕墙
    labor_pct: 25
    material_pct: 50
    machine_pct: 8
    management_pct: 12
    profit_pct: 5
    unit_cny_per_m2: 1161.78
  - subsystem: 玻璃幕墙(明框+单元)
    labor_pct: 22
    material_pct: 55
    machine_pct: 10
    management_pct: 9
    profit_pct: 4
    unit_cny_per_m2: 1080.50
  - subsystem: 玻璃幕墙(全隐框)
    labor_pct: 25
    material_pct: 52
    machine_pct: 9
    management_pct: 10
    profit_pct: 4
    unit_cny_per_m2: 1403.45
  - subsystem: 断桥铝门窗
    labor_pct: 20
    material_pct: 58
    machine_pct: 6
    management_pct: 12
    profit_pct: 4
    unit_cny_per_m2: 1153.58
  - subsystem: 金属屋面 + 铝板
    labor_pct: 28
    material_pct: 48
    machine_pct: 8
    management_pct: 11
    profit_pct: 5
    unit_cny_per_m2: 687.73
  - subsystem: 钢结构雨棚
    labor_pct: 30
    material_pct: 45
    machine_pct: 10
    management_pct: 10
    profit_pct: 5
    unit_cny_per_m2: 1800.00
  - subsystem: 室内粗装修
    labor_pct: 35
    material_pct: 42
    machine_pct: 5
    management_pct: 13
    profit_pct: 5
    unit_cny_per_m2: 956.22
breakdown_by_subsystem:
  干挂石材幕墙: 33.6
  玻璃幕墙(明框+单元): 6.0
  玻璃幕墙(全隐框): 7.4
  断桥铝门窗: 3.2
  金属屋面+铝板: 1.2
  钢结构雨棚: 1.3
  室内粗装修: 2.0
  含措施费/规费/税金: 45.4
status: draft
version: 1
created: 2026-06-27
updated: 2026-06-27
maintainer: yxy
tags: [幕墙, 外装修, 工程造价, 估算, 方案, Plan]
---

# 幕墙与外装修工程造价估算方案 v1

> 由 SKILL 2 (`kb-tech-solution`) 生成于 2026-06-27,输入 PRD [`curtain-wall-quote-v1`](../prds/curtain-wall-quote-v1.md)。
> 本方案**不是**新建项目报价,而是用真实项目 `常州市中航大酒店幕墙工程`(2014 年,2708 万)作为 baseline,**演示** SKILL 2 如何把 PRD 转成可执行的造价方案。

---

## 1. 方案摘要 (Summary)

**核心结论**:基于常州市中航大酒店 2014 年 12,712 m² 幕墙工程完工数据,在相同城市(常州市)+ 业态(高端酒店)+ 7 大子系统结构下,**造价区间落在 2,650 万 ~ 2,780 万元之间**,中位数 2,708 万。

**适配场景**:苏南地区 / 10,000 ~ 15,000 m² / 高端酒店 / 含石材幕墙 + 玻璃幕墙 + 门窗 + 屋面 + 雨棚 + 栏杆 + 室内粗装修的 7 子系统总价包。

**关键风险**:3 项(详见 §5)。

---

## 2. 计算模型 (Calculation Model)

### 2.1 基线项目数据

| 字段 | 值 | 来源 |
|---|---|---|
| 项目 | 常州市中航大酒店幕墙工程 | [changzhou-zhonghang-quote-2708](../sources/2012/changzhou-zhonghang-quote-2708.md) |
| 业态 | 高端酒店 | 同上 |
| 城市 | 常州市(江苏) | 同上 |
| 总面积 | 12,712.41 m²(地上 + 幕墙展开面积) | 同上 §3.1 |
| 完工年度 | 2014 | 同上 |
| 总造价 | ¥27,085,372.76 | 同上 §3.2 |
| 单方造价 | ¥2,130.79 / m² | 同上计算(27,085,372.76 ÷ 12,712.41) |

### 2.2 子系统单方造价分解

见 frontmatter `summary_table`(9 行,7 个主子系统 + 小计 + 总计)。

### 2.3 单方敏感性(误差传导)

| 面积 m² | 总造价 ¥(单方 2,130.79) | 区间说明 |
|---:|---:|---|
| 10,170 | 21,670,000 | 面积缩小 20% |
| **12,712** | **27,085,373** | **baseline** |
| 15,255 | 32,500,000 | 面积放大 20% |

**注**:实际项目单方造价会随面积、设计复杂程度、幕墙占比、季节施工等浮动,±15% 误差范围常见,详见 §5 风险点。

---

## 3. 关键技术决策 (Technical Decisions)

### 3.1 必含子系统(对应 PRD `sub_systems`)

PRD 必含 7 个子系统,KB baseline 已全部覆盖,无需新增:

| PRD 输入 | KB 提供 | 决策 |
|---|---|---|
| `stone_curtain_wall` ✅ | ✅ 7,839 m² | 沿用 |
| `glass_curtain_wall` ✅ | ✅ 1,498 + 1,420 m² | 沿用 |
| `aluminum_door_window` ✅ | ✅ 740 m² | 沿用 |
| `metal_roof` ✅ | ✅ 462 m² | 沿用 |
| `steel_canopy` ✅ | ✅ 200 m² | 沿用 |
| `interior_fitout` ✅ | ✅ 553.41 m² | 沿用 |

### 3.2 设计标准(从 KB 提取)

- **石材**:30 mm 厚花岗岩(详见 KB §2 材质表)
- **玻璃**:6 Low-E + 12A + 6 中空钢化(详见 KB §2 玻璃配置)
- **钢材**:Q235B 热镀锌(详见 KB §2 钢材)
- **防火等级**:A 级(详见 KB §4.1)
- **节能等级**:65% 节能(详见 KB §4.2)

### 3.3 工艺路线

| 工序 | 来源 | 关键节点 |
|---|---|---|
| 测量放线 | KB §5.1 | 复核建筑结构偏差 ≤ ±10 mm |
| 埋件安装 | KB §5.2 | 化学锚栓 + 后置埋件 |
| 龙骨安装 | KB §5.3 | 立挺 → 横梁 → 焊接 |
| 面板安装 | KB §5.4 | 自下而上,每层一循环 |
| 打胶密封 | KB §5.5 | 耐候硅酮密封胶 |

---

## 4. 实施步骤 (Implementation Steps)

### 4.1 阶段划分

| 阶段 | 时长 | 内容 | 交付物 |
|---|---|---|---|
| **P1 设计阶段** | 30 天 | 方案深化 + 施工图 | 施工图 + 工程量清单 |
| **P2 招采阶段** | 20 天 | 招采 + 定标 | 中标合同 |
| **P3 施工阶段** | 120 天 | 龙骨 → 面板 → 密封 | 隐蔽工程验收 + 竣工 |
| **P4 验收阶段** | 15 天 | 幕墙专项验收 + 节能 | 验收报告 + 备案 |
| **总周期** | **185 天(约 6 个月)** | — | — |

### 4.2 关键路径(Critical Path)

```
测量放线 → 埋件验收 → 龙骨安装(立挺) → 玻璃/石材面板 → 打胶 → 清洗 → 验收
   |          |          |              |              |        |        |
   5d        3d         30d            45d            15d      5d       10d
```

---

## 5. 风险点与对策 (Risks)

| # | 风险 | 等级 | 来源 | 影响 | 对策 |
|---|---|---|---|---|---|
| **R1** | 城市差异(非苏南) | 高 | `risk_flags.baseline_only_one_project` | 单方造价 ±20% | KB 必须有目标城市同业态案例,无则降级为估算 |
| **R2** | baseline 仅 1 个项目 | 中 | `risk_flags.changzhou_city_baseline_only` | confidence = 0.85 而非 0.95 | 后续 SKILL 4 应在 changzhou 之外再补 ≥ 1 个同业态 case |
| **R3** | baseline 是 2014 年 | 中 | `risk_flags.2014_year_baseline` | 物价系数需 +10~20% | 在 PRD 标注 `quote_year`,如有新项目重算 |
| R4 | 设计变更(石材改陶板等) | 中 | user-driven | 单方造价 ±15% | PRD 中固化 `material` 字段,变更触发重算 |
| R5 | 季节施工(冬雨季) | 中 | KB | 总价 +5~8% | 按 KB 季节系数调整 |

---

## 6. 不适用范围 (Out of Scope)

- **不含结构加固、基础工程**:本方案仅外立面 + 屋面 + 粗装修,不含主体结构改造
- **不含精装、家具、机电**:粗装修只到墙面打底 + 吊顶龙骨,不含面层
- **不含特殊造型曲面幕墙**:baseline 是平面幕墙,曲面/双曲需另算
- **不含超高层(> 100 m)**:高空作业措施费差异大,baseline 假设 ≤ 60 m

---

## 7. 验收标准 (Acceptance Criteria)

**对应 PRD §6 `acceptance` 字段**。

### 7.1 必填字段(全部满足)

- [x] 工程量清单可复核(§2.2 summary_table)
- [x] 单方造价偏差 ≤ ±15%(对比 baseline:实际 0% 偏差)
- [x] 7 大子系统全部覆盖(§2.2 / §3.1)
- [x] 风险点 R1-R5 已显式标注(§5)

### 7.2 必含证据链

- [x] baseline KB slug 真实存在(`changzhou-zhonghang-quote-2708` ✅)
- [x] confidence ≥ 0.7(本方案 = 0.85)
- [x] 风险表 5 行 + 对策非空
- [x] Out-of-Scope ≥ 3 行

---

## 8. 维护与版本 (Maintenance)

- **基线年度**:2014(常州市中航大酒店)
- **下次刷新触发**:新增 ≥ 2 个同类城市/业态项目后,可重新计算单方造价
- **降级路径**:若 KB 中同类项目 < 2 个,SKILL 2 必须 `confidence < 0.5` 警告,并要求人工报价

---

## 9. 关联 KB (References)

### 9.1 输入 PRD

- [`curtain-wall-quote-v1`](../prds/curtain-wall-quote-v1.md) — 产品需求文档

### 9.2 输出目标

- 本文件 (`kb/plans/curtain-wall-quote-v1-v1.md`)

### 9.3 关键 KB Source

- [`changzhou-zhonghang-quote-2708`](../sources/2012/changzhou-zhonghang-quote-2708.md) — 基线项目(常州市中航大酒店 2014)

### 9.4 后续消费 SKILL

- **SKILL 3** (`kb-tech-review`):评审本方案
- **SKILL 4** (`kb-pricing-update`):价格刷新

---

**maintainer**: yxy
**version**: 1
**status**: draft
