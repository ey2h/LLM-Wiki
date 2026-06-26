---
type: PRD
title: 幕墙与外装修工程造价估算 v1
description: 输入项目面积 + 城市 + 系统清单,按 ai-rd-system 已入库的造价数据(常州中航大酒店 2708 万示例)输出 7 大子项估算表 + 综合单价分析 + Excel 导出
tags: [幕墙, 造价估算, 综合单价, Excel导出, kb-tech-solution, v1]
created: 2026-06-26
updated: 2026-06-26
version: 0.1
status: draft
author: jack
---

# 幕墙与外装修工程造价估算 v1

## 1. 触发(Trigger)

**场景**:项目前期(方案阶段/投标报价阶段),业主或总包要求快速估算幕墙造价。
**触发方式**:
- 手动上传项目参数(markdown 表格 / Excel / 自然语言)
- 从 KB 历史项目推断(例:已知项目面积 + 类型,反查同类型历史造价)

## 2. 输入对象(Input Objects)

| 字段 | 类型 | 必填 | 说明 | 来源 |
|------|------|------|------|------|
| `project_name` | string | ✅ | 项目名,例 "常州中航大酒店" | user |
| `project_type` | enum | ✅ | `hotel / office / mall / residential` | user |
| `city` | string | ✅ | 城市,影响材料价 + 人工费 + 风荷载 | user |
| `total_area_m2` | number | ✅ | 总幕墙面积 m² | user |
| `sub_systems` | list[object] | ✅ | 子系统清单,见下表 | user |
| `baseline_project` | string | ❌ | 参考历史项目,例 "常州中航大酒店" | user / KB 反查 |
| `quality_tier` | enum | ❌ | `low / mid / high`,默认 `mid` | user |
| `delivery_deadline` | date | ❌ | 投标截止日 | user |

### `sub_systems` 字段结构

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | ✅ | 子系统名,例 "主楼玻璃幕墙及石材包柱系统" |
| `area_m2` | number | ✅ | 该子系统面积 |
| `system_type` | enum | ✅ | `glass-stone / granite-back-bolt / steel-grille / hidden-frame / canopy / louver / door / metal-roof / window` |
| `glass_spec` | string | ❌ | 例 "6+12A+6+1.14+6 LOW-E 钢化夹胶中空" |
| `stone_spec` | string | ❌ | 例 "泰国白麻花岗岩" |
| `tier_override` | enum | ❌ | 子系统级质量覆盖 |

## 3. 输出对象(Output Objects)

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `summary_table` | markdown_table | ✅ | 7 大子项汇总表(子系统 / 面积 / 单价 / 合计) |
| `unit_price_analysis` | list[object] | ✅ | 综合单价分析明细(人工 / 材料 / 机械 / 管理 / 利润) |
| `total_quote_cny` | number | ✅ | 总造价,人民币元 |
| `breakdown_by_subsystem` | object | ✅ | 按子系统的造价占比饼图数据 |
| `reference_projects` | list[string] | ✅ | 引用的 KB 历史项目 slug,例 `changzhou-zhonghang-quote-2708` |
| `confidence_score` | float | ✅ | 0-1,SKILL 自评(基于历史相似度) |
| `deliverable_xlsx` | file_path | ❌ | 可选:导出 Excel 路径 |
| `risk_flags` | list[string] | ✅ | 例 "未指定 LOW-E 钢化要求 → 用了 baseline 默认" |

## 4. 对象链接(Object Links)

```
Input: project_name
    ↓ (1:1)
Output: summary_table.title_column

Input: sub_systems[].area_m2
    ↓ (sum)
Output: total_quote_cny (per subsystem)

Input: baseline_project
    ↓ (1:1 lookup KB)
Output: reference_projects[]
    ↓ (refines)
Output: unit_price_analysis

Input: city
    ↓ (region adjustment)
Output: unit_price_analysis.material_cost
```

## 5. 约束(Constraints)

- **必须基于 KB 历史项目**:不允许凭空编单价,所有单价引用自 `kb/sources/<year>/` 中至少 1 个真实项目
- **子系统至少 3 个,最多 8 个**:少于 3 个是子项报价,不是幕墙总报价
- **city 必须是 GB/T 2260 行政区划代码或城市名**:不接受模糊描述("华东某城市")
- **total_quote_cny 必须在 ±15% 区间与 baseline_project 对比**:超 15% 必须 SKILL 显式说明原因
- **不输出 SVG/PNG 图**:只输出 markdown table + 可选 xlsx 文件

## 6. 验收标准(Acceptance)

### 自动验收(机器跑)

- [ ] `summary_table` 行数 = `sub_systems` 数量
- [ ] `summary_table` 合计行 = `total_quote_cny`
- [ ] 每个 `unit_price_analysis` 条目含 5 个分项:人工 / 材料 / 机械 / 管理 / 利润
- [ ] `reference_projects` 至少 1 个 slug,且能在 `kb/sources/` 下找到
- [ ] `confidence_score` ≥ 0.6(过低 → 警告:KB 历史数据不足)
- [ ] 所有 `risk_flags` 在 KB 中有对应解释(`kb/concepts/<slug>` 或注释)
- [ ] `tags` ≥ 5 个,`description` ≤ 200 字(schema_gate)
- [ ] 输出 schema_gate + lint 双绿灯

### 人工验收(人在回路)

- [ ] 用户确认 `total_quote_cny` 与历史经验一致(±15%)
- [ ] 用户确认 `sub_systems` 划分正确(可调整子项名)
- [ ] 用户确认 `baseline_project` 选择合理(可换 reference)
- [ ] 用户确认 Excel 输出格式(如有)

## 7. 反例(Anti-patterns)

- ❌ **不输出凭空单价** — "玻璃幕墙 1500 元/m²,纯估算" — 必须引用 KB
- ❌ **不忽略 city 差异** — 张家港与上海材料价 / 人工费不同,baseline 不能直接套
- ❌ **不输出 SVG/PNG 图** — 输出 markdown table + xlsx 文件即可,LLM 不该画图
- ❌ **不混合不同质量等级项目** — high-tier 酒店不能套 mid-tier 写字楼 baseline
- ❌ **不假设玻璃规格** — baseline 没的玻璃型号必须 `risk_flags` 标注,不能默认 LOW-E

## 8. 调用 SKILL(Downstream)

- **触发 SKILL**: `kb-tech-solution`(消费本 PRD,生成技术方案文档)
- **可能引用 SKILL**:
  - `kb-just-ask`(反查 KB:用户问"有没有常州类似项目")
  - `kb-doc-summary`(生成 concept 页,把新估算入 KB)
- **产出交给**: 用户(投标报价)+ `kb/sources/<year>/<slug>-quote.md`(KB 入库)+ 可选 xlsx 文件

## 9. 关联 KB

- [[/sources/2012/changzhou-zhonghang-quote-2708]] — 常州中航大酒店 2708 万完整示例(本 PRD 主要 baseline)
- [[/sources/2012/changzhou-zhonghang-cost-breakdown]] — 同项目综合单价分析明细
- [[/sources/2012/jack-wu-cv]] — 项目顾问背景
- [[/concepts/curtain-wall-system-classification]] — 幕墙系统分类(7 大子项依据)
- [[/concepts/unit-price-composition]] — 综合单价组成(5 分项依据)

---

**version**: 0.1
**status**: draft
**author**: jack

> **下一步**: 写完本 PRD 后,运行 `kb-tech-solution` SKILL 验证可消费性。