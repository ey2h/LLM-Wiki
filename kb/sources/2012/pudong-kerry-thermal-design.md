---
type: Source
title: 浦东嘉里中心裙楼幕墙热工性能设计计算书
description: 上海浦东嘉里中心裙楼幕墙按 JGJ/T151-2008 标准的冬夏季热工计算环境,LBNL WINDOWS6+Therm6 软件节点热工,中空 LOW-E + 单片玻璃参数定义,幕墙 K 值 / 结露分析的设计计算依据
tags: [浦东嘉里中心, 幕墙热工, JGJ/T151-2008, WINDOWS6, Therm6, LOW-E, K值, 节能, 节点热工]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: 浦东嘉里中心
entities: [JGJ/T151-2008, LBNL, WINDOWS6, Therm6]
cross_refs: [rfi-185-pudong-kerry-thermal, therm-log-curtain-wall]
doc_type: md
scan_status: native
tier: final
language: zh
source_file: /mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/结构热工性能设计计算(1).md
quality_score: 0.90
related:
  - /sources/2012/rfi-185-pudong-kerry-thermal
resource: file:///mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/结构热工性能设计计算(1).md
---

# 浦东嘉里中心裙楼幕墙热工性能设计计算书

## 概述

上海浦东嘉里中心裙楼幕墙热工性能设计计算,依据《建筑门窗玻璃幕墙热工计算规程》JGJ/T151-2008
定义冬/夏季标准计算条件,采用 LBNL 实验室 WINDOWS6 + Therm6 软件进行节点热工计算。文档
定义玻璃参数(中空 LOW-E + 单片/夹胶玻璃)与计算边界条件,作为后续 K 值/结露分析的设计依据。

## 关键信息

- 项目: 上海浦东嘉里中心裙楼
- 类型: 设计计算书(热工)
- 规范: JGJ/T 151-2008(冬夏季计算环境)
- 软件: LBNL WINDOWS6 + Therm6
- 关键决策:
  - 冬季 Tin=20℃ / Tout=-20℃,hc,in=3.6 hc,out=16 W/(m²·K)
  - 夏季 Tin=25℃ / Tout=30℃,hc,in=2.5 hc,out=16 W/(m²·K)
  - 传热系数计算取冬季 + Is=0 W/m²(无太阳辐射)
  - 玻璃采用中空 LOW-E + 单片(含夹胶)

## 内容摘要

### 1. 计算环境

冬季:室内 20℃ / 室外 -20℃,太阳辐射 Is=300 W/m²。夏季:室内 25℃ / 室外 30℃,太阳辐射
Is=500 W/m²。传热系数 K 值取冬季标准 + Is=0。

### 2. 计算软件

LBNL 实验室的 WINDOWS6(整体传热) + Therm6(节点热桥)双软件,前几年幕墙热工标配。

### 3. 玻璃参数

中空 LOW-E + 单片/夹胶玻璃。LOW-E 用于节能,单片用于造价/通透性平衡。夹胶用于安全部位
(裙楼、栏杆)。

## 引用片段

> 按《建筑门窗玻璃幕墙热工计算规程》JGJ/T151-2008 采用

> 采用 LNBL 实验室的 WINDOWS6 和 Therm6 软件进行节点热工计算

## 跨引用

- [[/sources/2012/rfi-185-pudong-kerry-thermal]] — 同项目 RFI,问的是保温方案变更
- [[/sources/2012/therm-log-curtain-wall]] — Therm 软件实际计算日志(玻璃幕墙/石材/铝板等节点)

## 元数据

- 源文件: `/mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/结构热工性能设计计算(1).md`
- md 文件: `kb-md/2012/浦东嘉里中心保温计算/JLZX/结构热工性能设计计算(1).md`
- slug: `pudong-kerry-thermal-design`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)