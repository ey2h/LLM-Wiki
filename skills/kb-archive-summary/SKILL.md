---
name: kb-archive-summary
description: Use when an archive file (.zip/.rar/.7z/.tar.gz) appears in the NFS archive — extracts the file listing without full decompression and writes a Source summary at kb/sources/<year>/<name>.ext.md, so the KB has a permanent index entry for the archive's contents even when the archive itself stays untouched on NFS
version: 0.1
status: draft
created: 2026-06-27
updated: 2026-06-27
maintainer: jack (via Hermes)

---

# kb-archive-summary — 压缩包清单摘要入 KB

## Overview

把 NFS 上的压缩包(.zip / .rar / .7z / .tar.gz)做成 KB Source,**只读清单不解压**,写 `<name>.ext.md` 到 `kb/sources/<year>/`。

**核心原则**:
- **不真正解压**(`unzip -l` / `unrar l` / `7z l` / `tar -tzf` 读清单即可)
- **不真正读内容**(节省时间 + 节省 token + 不破坏原压缩包)
- KB 摘要含:解压清单 + 文件统计 + 顶层结构推断 + 关键文件名关键词
- 原压缩包**永远在 NFS 上**(只读挂载,不可写),不删除不移动
- 未来如果某压缩包的内容**真正值得深读**,可手动解压 + 走 SKILL 1 完整流程

**与 SKILL 1 `kb-doc-summary` 区别**:
- SKILL 1 评**真实文档**(读全文、抽 entities、生成 markdown)
- 本 SKILL 评**压缩包**(只读清单、推断内容、不抽 entities)

## When to Use

1. daemon 跑批发现 .zip / .rar / .7z / .tar.gz 文件(单文件转换脚本跳过了它们)
2. 用户显式说"打开看看这个压缩包有什么"
3. 用户说"我有个 zip 文件想入 KB"
4. 跑批中途日志显示"跳过扩展: zip"

## Do NOT use for

1. **单个文档**(PDF / Office)→ 用 SKILL 1
2. **小文本文件**(txt / log / md)→ 用 SKILL 1
3. **压缩包内容值得深读**的情况 → 手动解压 + SKILL 1,**不**用本 SKILL(本 SKILL 只看清单)
4. **压缩包本身损坏无法读清单** → 记 log,跳过
5. **用户已知压缩包内容** → 直接写 KB Source,不跑本 SKILL

## Hard Gates

| # | 检查项 | 不通过时的行为 |
|---|--------|---------------|
| 1 | 压缩包存在且可读(`unzip -l` / `unrar l` / `7z l` / `tar -tzf` 不报错) | 记 log,跳过,**不**写空 Source |
| 2 | 输出路径 `kb/sources/<year>/<name>.ext.md` 合规 | 不允许写到别处 |
| 3 | 同名 Source 已存在(`.ext.md`)→ **跳过,不覆盖**(保留原 SKILL 1 产物) | 跳过,log 记一条 |
| 4 | 摘要必须含 ≥ 1 个**解压清单表格**(文件名 / 大小 / 类型) | 报错,缺则不写 |
| 5 | 摘要必须含 frontmatter 7 字段(type/title/description/created/updated/tags/maintainer) | 缺失用 `[待补充]` 占位 |
| 6 | type 必须是 `Source` + document_type `Archive` | schema_gate 不通过 |
| 7 | 压缩包体积 > 1 GB → 仍走清单(不解压),但 log 记"超大"警告 | 不跳过,继续 |
| 8 | 摘要长度必须 ≥ 500 字符(防"空摘要") | 不写,等补 |

## Phase 0: 压缩包发现与清单读取

### 输入
- 压缩包路径:`/mnt/nfs/项目存档/<rel_path>/<name>.zip`(或 .rar / .7z / .tar.gz)
- 年份(从路径推断):`$YEAR`

### 动作
1. 校验文件存在 + 类型识别(`file` 命令 + 扩展名)
2. 按类型选清单命令:
   - `.zip` → `unzip -l <path>`
   - `.rar` → `unrar l <path>`
   - `.7z` → `7z l <path>`
   - `.tar.gz` → `tar -tzf <path>`
3. 解析输出 → 提取文件名 / 大小 / 压缩后大小 / 日期(若是 zip 还含压缩率)
4. 统计:文件总数 / 总大小 / 顶层目录 / 文件类型分布(pdf/docx/xlsx/...)

### 输出
- 内存数据结构 `archive_inventory`:
  ```
  {
    "path": "<full path>",
    "name": "<basename>",
    "ext": "zip",
    "year": "2014",
    "file_count": 156,
    "total_size_uncompressed_bytes": 524288000,
    "total_size_compressed_bytes": 104857600,
    "top_dirs": ["投标文件/", "图纸/", "合同/"],
    "file_types": {"pdf": 89, "docx": 12, "xlsx": 5, "dwg": 50},
    "files": [
      {"name": "投标文件/正文.pdf", "size": 5242880, "compressed": 1048576, "date": "2014-08-15"},
      ...
    ]
  }
  ```

## Phase 1: 内容关键词抽取

### 输入
`archive_inventory` 数据结构

### 动作
1. 抽**顶层目录名**作为"内容主题"(如 `投标文件/` → 主题"投标")
2. 抽**关键文件名关键词**(挑大小 top 10 + 名称含"投标/合同/图纸/清单/规范"的文件名)
3. 推断压缩包**用途类别**:
   - 含 "投标" → 投标文件
   - 含 "合同" → 合同附件
   - 含 "图纸" / `.dwg` → 图纸批量
   - 含 "规范" → 规范合集
   - 含 "清单" / `.xlsx` → 造价清单
   - 含 "扫描" → 扫描件归档
   - 含 "简历" / `.doc` 含"Jack" → 个人文件
   - 含 "Shadowsocks" / `python-3.5.4` → 软件/工具
   - 兜底 → 工程文档(默认)

### 输出
`archive_meta`:
```
{
  "purpose": "投标文件",
  "top_keywords": ["投标", "幕墙", "正荣", "工程量清单"],
  "key_files": ["投标文件/正文.pdf", "图纸/总图.dwg", ...]
}
```

## Phase 2: 摘要撰写

### 输入
`archive_inventory` + `archive_meta`

### 动作
1. 生成 frontmatter(7 必填字段)
2. 写 9 段正文:
   - **§1 压缩包元信息**(路径 / 大小 / 压缩率 / 文件数)
   - **§2 解压清单摘要**(类型分布饼图 + top 10 大文件 + 顶层目录)
   - **§3 完整解压清单表格**(所有文件,前 100 行,超过标"…还有 N 个")
   - **§4 用途推断**(基于关键词 + 顶层目录)
   - **§5 关键文件**(top 10 大小 + 关键命名)
   - **§6 关联项目**(从文件名 / 顶层目录推断,如 "正荣" → 关联正荣系列项目)
   - **§7 置信度评估**(默认低,因为没读内容)
   - **§8 处理建议**(手动解压 / 跳过 / 走 SKILL 1)
   - **§9 跨引用**(若有已知相关 Source,链之)

### 输出
`kb/sources/<year>/<name>.ext.md`(完整 9 段 + frontmatter)

## Phase 3: 命名 + 写入

### 输入
Phase 2 摘要文本

### 动作
1. 检查 `kb/sources/<year>/<name>.ext.md` 是否已存在
   - 存在 → Hard Gate #3 跳过
2. slug 唯一性检查(全局)
   - 冲突 → 加 `-2` / `-3` 后缀
3. 写文件
4. 校验文件 ≥ 500 字符(Hard Gate #8)

### 输出
- 实际文件路径 + 文件大小

## Phase 4: 自查 + log

### 输入
文件 + metadata

### 动作
1. 跑 `kb/lint/schema_gate.py` 单文件校验
2. log 追加一条:`kb-archive-summary: <path> → <out> (files=<n>, size=<MB>, purpose=<cat>)`

### 输出
- log 条目 + schema_gate 通过信号

## Output Quality Checklist

- [ ] frontmatter 7 字段齐(type=title+description+created+updated+tags+maintainer)
- [ ] type=Source + document_type=Archive
- [ ] §1 压缩包元信息含完整 4 字段(路径 / 大小 / 压缩率 / 文件数)
- [ ] §2 解压清单摘要含类型分布饼图
- [ ] §3 完整清单表格(全部文件,前 100 行 + "…还有 N 个")
- [ ] §4 用途推断基于关键词 + 顶层目录,不是凭空
- [ ] §5 关键文件含 top 10 + 命名关键词
- [ ] §6 关联项目(若有推断)
- [ ] §7 置信度评估(默认低 + 说明)
- [ ] §8 处理建议明确(手动解压 / 跳过 / 走 SKILL 1)
- [ ] 文件 ≥ 500 字符
- [ ] schema_gate 通过

## Quick Reference

| Phase | 动作 | 自动 | 输入 |
|-------|------|------|------|
| 0 | 读清单 + 抽 inventory | ✅ | archive_path |
| 1 | 抽关键词 + 推断用途 | ✅ | inventory |
| 2 | 写 9 段摘要 | ✅ | inventory + meta |
| 3 | 命名 + 写入 | ✅ | 摘要文本 |
| 4 | 自查 + log | ✅ | 文件 |

**交互点**:0 次(全自动)

## Guard Rails

| # | 检测信号 | 正确行为 | 错误行为 |
|---|---------|---------|---------|
| 1 | 压缩包损坏 / 清单命令报错 | 记 log,跳过,**不**写空 Source | 写空 Source |
| 2 | 同名 .ext.md 已存在 | 跳过(保留原 SKILL 1 产物或上次摘要) | 覆盖丢失 |
| 3 | 压缩包 > 1 GB | 仍走清单(不解压),log 记"超大" | 跳过 |
| 4 | 压缩包 > 5 GB | 警告 + 单独确认(可能 OOM) | 沉默继续 |
| 5 | 清单 > 10,000 文件 | 摘要只列前 100,§3 标"…还有 N 个" | 全列 OOM |
| 6 | 文件名乱码 / 解码错误 | 标 `[乱码]`,不抛错 | 抛错中断 |
| 7 | 用途无法推断 | 兜底"工程文档(默认)" | 抛错 |
| 8 | 关键词抽取空 | §4 标"用途不明,需手动查阅" | 编造用途 |
| 9 | slug 冲突 | 加 `-2` / `-3` 后缀 | 覆盖 |
| 10 | NFS 中文路径 | `unzip` / `tar` 加 `-O UTF-8` 或 `LANG=zh_CN.UTF-8` | 乱码中断 |

## Downstream Handoff

生成的 Source 可被:
- **SKILL 1 `kb-doc-summary`** — 若用户决定深读,可手动解压后跑 SKILL 1
- **人工 grep** — 在 KB 中搜索压缩包名(目前无 cross-source / experience-log SKILL,本 SKILL 仅做清单摘要)

---

**maintainer**: jack (via Hermes)
**version**: 0.1
**status**: draft
