---
type: Source
title: 张家港地区风荷载计算书(Mathcad)
description: 张家港地区幕墙风荷载计算书(Mathcad 导出) — 50 年一遇基本风压 W0=0.45 kN/m²,地面粗糙度 B 类(GB50009-2001 2006 版第 7.2.1 条),含局部体型系数计算与按 A/B/C/D 类别分项的暴露参数;中英对照,典型 Mathcad 工程计算模板
tags: [风荷载, 张家港, Mathcad, GB50009-2001, 50年一遇, W0=0.45, 地面粗糙度B类, 局部体型系数]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: (张家港项目)
entities: [缪伟新, GB50009-2001]
cross_refs: []
doc_type: md
scan_status: native
tier: final
language: mixed
source_file: /mnt/nfs/LLM-WIKI/raw/2012/缪伟新/Mathcad - Wind Load as New Code.md
quality_score: 0.82
related: []
resource: file:///mnt/nfs/LLM-WIKI/raw/2012/缪伟新/Mathcad - Wind Load as New Code.md
---

# 张家港地区风荷载计算书(Mathcad)

## 概述

张家港地区幕墙**风荷载计算书**,Mathcad 工程计算导出(缪伟新),中英对照。基本风压
**W0=0.45 kN/m²**(50 年一遇),按 GB50009-2001(2006 年版)第 7.2.1 条判定地面粗糙度
**B 类**。包含局部体型系数(Local shape coefficient)与按 A/B/C/D 类别分项的暴露参数
计算。属典型 Mathcad 工程计算模板。

## 关键信息

- 地区: 张家港(江苏)
- 基本风压: W0 = **0.45 kN/m²**(50 年一遇)
- 规范: GB50009-2001(2006 年版)第 7.2.1 条
- 地面粗糙度: **B 类**
- 计算人: 缪伟新
- 类型: 风荷载设计计算(Mathcad 导出)
- 关键决策:
  - 张家港属沿海但非台风核心,基本风压 0.45 是中等水平
  - B 类(田野乡村)对应场地开阔度,幕墙体型系数相应调整

## 内容摘要

### 风压基本值

```
W0 := 0.45 kN/m²    (n = 50 year, ZhangJiaGang)
```

### 地面粗糙度分类

按 GB50009-2001 第 7.2.1 条:
- A = 1(近海海面、海岛)
- **B = 2(田野、乡村、丛林)**
- C = 3(城市)
- D = 4(密集高层)

张家港取 **ExpCat := B**。

### 局部体型系数

按 GB50009 附录,不同幕墙形状(平面/转角/女儿墙/雨篷等)对应不同 μs 值,本计算书后续
展开 1.1.1 节专门处理。

## 引用片段

> W0 := 0.45 kN/m²  张家港地区 50 年一遇风压(n=50 year, ZhangJiaGang)

> ExpCat := B  地面粗糙度 B 类

## 元数据

- 源文件: `/mnt/nfs/LLM-WIKI/raw/2012/缪伟新/Mathcad - Wind Load as New Code.md`
- md 文件: `kb-md/2012/缪伟新/Mathcad - Wind Load as New Code.md`
- slug: `zhangjiagang-wind-load-mathcad`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)