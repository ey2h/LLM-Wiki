---
type: Source
title: Therm 软件幕墙节点计算日志(玻璃幕墙)
description: LBNL Therm 软件对浦东嘉里中心裙楼玻璃幕墙节点逐次计算的执行日志,记录每个 THM 文件路径、计算状态(complete/not successful)与错误代码 0/2,共 364 行多次重算过程
tags: [浦东嘉里中心, Therm, LBNL, 玻璃幕墙, 节点热工, 计算日志]
created: 2026-06-26
updated: 2026-06-26
year: 2012
project: 浦东嘉里中心
entities: [LBNL Therm, Judy]
cross_refs: [pudong-kerry-thermal-design]
doc_type: md
scan_status: native
tier: final
language: zh
source_file: /mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/玻璃幕墙/ThermLog.md
quality_score: 0.75
related:
  - /sources/2012/pudong-kerry-thermal-design
resource: file:///mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/玻璃幕墙/ThermLog.md
---

# Therm 软件幕墙节点计算日志(玻璃幕墙)

## 概述

LBNL Therm 软件对浦东嘉里中心裙楼玻璃幕墙节点(THM 文件)多次重算的执行日志,记录计算
时间、文件路径、计算状态(complete / not successful)、错误代码(0=OK,2=失败)。属于热工
计算的工程过程文件,**不是设计输入**,但可作为 K 值复核的证据链。

## 关键信息

- 项目: 浦东嘉里中心裙楼玻璃幕墙
- 类型: 软件计算日志(原始过程)
- 软件: LBNL Therm 6
- 关键观察:
  - 单节点多次重算常见(失败 → 改输入 → 重算)
  - 错误代码 2 通常是几何或材料定义问题
  - 操作系统残留路径 `C:\Users\Judy\Desktop\JLZX\4-317бĻǽ\` 暴露源工作机

## 内容摘要

### 日志格式

每条记录 4 行:日期时间、THM 文件绝对路径、Calculation 状态、错误码(0=OK / 2=失败)。

### 主要节点

AD-007-2 / AD-007-3 / AD-003-1 等多个玻璃幕墙节点 THM。Sun Jan 31 16:57 起多次重算,
直到 17:03 第一次成功(AD-007-2),20:06 AD-007-3 一次过,21:08 AD-003-1 重算 2 次后过。

### 异常

文件路径含乱码 `бĻǽ`(俄文或编码损坏),说明原工作机 Judy 桌面有非英文路径,可能导致
Therm 内部路径处理问题,这也是为什么重算这么多次。

## 引用片段

> Sun Jan 31 17:03:35 2010 / Calculation complete. / 0

> Sun Jan 31 17:02:38 2010 / Calculation not successful / 2

## 跨引用

- [[/sources/2012/pudong-kerry-thermal-design]] — 同项目热工设计计算书,本日志是其工程过程

## 元数据

- 源文件: `/mnt/nfs/LLM-WIKI/raw/2012/浦东嘉里中心保温计算/JLZX/玻璃幕墙/ThermLog.md`
- md 文件: `kb-md/2012/浦东嘉里中心保温计算/JLZX/玻璃幕墙/ThermLog.md`
- slug: `therm-log-curtain-wall`
- 入库时间: 2026-06-26
- 维护者: jack (via Hermes kb-doc-summary SKILL 1 v0.1)