---
name: kb-doc-convert
description: Use when batch-converting raw office documents (PDF/DOCX/PPTX/XLSX/DOC/PPT/XLS/TXT/LOG) into markdown for downstream KB ingestion — routes by file type to markitdown, MinerU (for scanned PDFs), or LibreOffice→markitdown (for legacy Office), preserves source directory structure, applies the 原名.ext.md naming convention, and skips Office temp files / non-document extensions
version: 0.1
status: draft
created: 2026-06-27
updated: 2026-06-27
maintainer: jack (via Hermes)
---

# kb-doc-convert — 文档批量转 Markdown

## Overview

**角色定义**: 你是一个文档转换工程师,负责把项目存档下的二进制办公文档(.pdf/.doc/.docx/.ppt/.pptx/.xls/.xlsx/.txt/.log)批量转成 markdown,放到 raw/ 对应目录下,供 SKILL 1 (`kb-doc-summary`) 入库消费。

**输出语言**: 文件名/路径保留原文(中文/英文/数字都直接保留),markdown 内容保留原文档语言。

**核心流程**:
1. **扫描源目录**(`项目存档/<year>/`)→ 找出未转文档(原名.ext.md 不存在)
2. **判断文件类型** → 路由到 markitdown / pdftotext / MinerU / LibreOffice+markitdown
3. **PDF 扫描判断**(用 `pdf_is_scanned.py`)→ 文本 PDF 走 pdftotext,扫描 PDF 走 MinerU
4. **转换** → 输出 `LLM-WIKI/raw/<year>/<原目录路径>/<原名.ext.md>`
5. **记录日志** + 失败文件清单(供后续重试)

**配套文档**:
- `kb/KB-META.md` — frontmatter 字段 / type 枚举(本 SKILL 不产出 KB 页,只产 raw 中间文件)
- `docs/convert-batch-status-2026-06-27.md` — 当前后台跑批状态
- `~/LLM-Wiki/scripts/convert_archive_double_ext.sh` — 实际执行脚本(本 SKILL 的"代码实现")

## When to Use

- 项目存档下有新的未转文档需要入库
- 想把 PDF/Word/Excel/PPT 批量转 markdown
- MinerU/Markitdown 链路验证(抽几个不同类型文件跑通)
- 想知道某个目录有多少"漏转"文件

## Do NOT use for

- 写 KB concept 页(SKILL 1 `kb-doc-summary` 的工作)
- 写技术方案(SKILL 2 `kb-tech-solution` 的工作)
- 单个文件快速预览(用对应工具命令行直跑就行,不要用本 SKILL)
- 已经转好的 markdown 入库(SKILL 1 处理)

## Hard Gates

| # | 检查项 | 不通过时的行为 |
|---|--------|---------------|
| 1 | 源目录 `项目存档/<year>/` 存在且可读 | 报错,exit 1 |
| 2 | 目标目录 `LLM-WIKI/raw/<year>/` 可写(或可创建) | 报错,exit 1 |
| 3 | 必需工具存在(markitdown / LibreOffice / pdftotext / pdfinfo) | 报错指出缺哪个 |
| 4 | 命名规则:`<原名(含扩展名)>.md` | 不允许改成其他命名 |
| 5 | 跳过非文档扩展(dwg/dxf/bak/jpg/arw/.../zip/rar) | 静默跳过 |
| 6 | 跳过 Office 临时文件(`~$xxx`) | 静默跳过 |
| 7 | 同名 `.md` 已存在 | 跳过(不覆盖),记 `count_skip_exists` |
| 8 | LibreOffice 转换失败重试 3 次 | 3 次都败,记 `count_md_fail`,继续下一个 |

## Phase 0: 扫描源目录,找出未转文档

### 输入

- `SRC_BASE` = `/mnt/nfs/项目存档/<year>/`
- `DST_BASE` = `/mnt/nfs/LLM-WIKI/raw/<year>/`

### 动作

```bash
cd "$SRC"
find . -type f -not -path './@eaDir/*' -not -path './.DS_Store' \
  \( -name "*.pdf" -o -name "*.docx" -o -name "*.doc" \
     -o -name "*.pptx" -o -name "*.ppt" \
     -o -name "*.xlsx" -o -name "*.xls" \
     -o -name "*.txt" -o -name "*.log" \)
```

### 输出

未转文件列表(每项 = `相对路径`,扩展名小写)。

## Phase 1: PDF 扫描判断

### 输入

- PDF 文件路径

### 动作

调用 `pdf_is_scanned.py`(由 `~/LLM-Wiki/scripts/pdf_is_scanned.py` 提供):

```bash
probe=$(python3 "$PY_SCANNER" "$pdf" 30)
avg=$(echo "$probe" | python3 -c "import sys,json;d=json.load(sys.stdin);print(int(d['avg_chars']))")
if [ "$avg" -lt 30 ]; then
    # 扫描版 → 走 MinerU
else
    # 文本版 → 走 pdftotext
fi
```

**判断算法**(`pdf_is_scanned.py is_scanned()`):
- 抽 3 页:第 3 页、中间页、倒数第 3 页(短文档逐页抽)
- 计算平均字符数(空白不计)
- 平均 < 30 → 扫描版
- 平均 ≥ 30 → 文本版

### 输出

- 文本 PDF → `pdftotext -layout`
- 扫描 PDF → `mineru -p ... -o tmp`

## Phase 2: 文件类型路由

### 路由表

| 扩展名(小写) | 工具 | 命令 |
|-------------|------|------|
| `pdf` (avg ≥ 30) | pdftotext | `pdftotext -layout "$src" "$dst"` |
| `pdf` (avg < 30) | MinerU | `mineru -p "$src" -o "$tmpdir"` 然后 `cp $(find $tmpdir -name '*.md' | head -1) $dst` |
| `docx` `pptx` `xlsx` | markitdown | `markitdown "$src" > "$dst"` |
| `doc` | LibreOffice → markitdown | `libreoffice --headless --convert-to docx --outdir $tmpdir $src` 然后 markitdown |
| `ppt` | LibreOffice → markitdown | `libreoffice --headless --convert-to pptx --outdir $tmpdir $src` 然后 markitdown |
| `xls` | LibreOffice → markitdown | `libreoffice --headless --convert-to xlsx --outdir $tmpdir $src` 然后 markitdown |
| `txt` `log` | `cp` | `cp "$src" "$dst"`(输出名为 `<原名>.txt.md`) |

### 工具路径

| 工具 | 路径 |
|------|------|
| markitdown | `/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin/markitdown` |
| mineru | `/home/jack/projects/ai-rd-system/toolchain/envs/mineru/bin/mineru` |
| LibreOffice | `/usr/bin/soffice`(也可用 `libreoffice`) |
| pdftotext / pdfinfo | `/usr/bin/pdftotext` / `/usr/bin/pdfinfo` |

## Phase 3: 命名 + 输出

### 命名规则

**原名.ext.md**(保留原始扩展名,加 `.md`):

| 原文件 | 输出 |
|--------|------|
| `RFI.pdf` | `RFI.pdf.md` |
| `幕墙分类.doc` | `幕墙分类.doc.md` |
| `2014_0212 Wind Tunnel.pdf` | `2014_0212 Wind Tunnel.pdf.md` |
| `plot.log` | `plot.log.md`(特例,加 `.txt.md` 同义) |
| `foo.txt` | `foo.txt.md` |

### 目录结构

**保持源目录结构**(原样拷贝子目录层级):

```
项目存档/2014/南宁华润/foo.pdf
  → LLM-WIKI/raw/2014/南宁华润/foo.pdf.md
```

### 跳过逻辑

```bash
# Office 临时文件
case "$(basename "$src")" in ~\$*) skip ;; esac

# 已存在
if [ -f "$dst" ]; then count_skip_exists++; return; fi

# 非文档扩展
SKIP_EXT="dwg dxf bak jpg arw cr2 thm rar zip 7z tar gz bz2 ..."
for s in $SKIP_EXT; do [ "$ext" = "$s" ] && skip=1; done
```

## Phase 4: 失败处理 + 重试

### LibreOffice 重试

`.doc`/`.ppt`/`.xls` 转换 LibreOffice 偶发失败(尤其中文路径 + NFS),重试 3 次:

```bash
for try in 1 2 3; do
    if libreoffice --headless --convert-to docx --outdir "$tmpdir" "$src" 2>>"$LOG"; then
        docx=$(find "$tmpdir" -name "*.docx" | head -1)
        if [ -n "$docx" ] && markitdown "$docx" > "$dst" 2>>"$LOG"; then
            success=1; break
        fi
    fi
    sleep 2
done
```

3 次都失败 → 记 `count_md_fail++`,继续下一个(不阻塞整体)。

### 跑批失败重试

跑批完成后,可用 `lo_retry_failed.sh`(已存在)批量重试 LO 失败文件。

### 跨年聚合

如果一次跑多个月份,所有年的失败文件可一并 retry:

```bash
grep "LO.*失败" /home/jack/projects/ai-rd-system/toolchain/logs/convert_*_double_ext_*.log \
  | sed 's/.*⚠️ //;s/:.*//' > /tmp/lo_failed.txt
# 然后人工逐个 LO 重试
```

## Phase 5: 日志 + 统计

### 日志位置

`/home/jack/projects/ai-rd-system/toolchain/logs/convert_<year>_double_ext_<时间戳>.log`

### 日志内容

```
[09:14:42] 南宁华润/20140224 from GP/...pdf → 6s 535784 B
[09:14:43] 南宁华润/Presentation Facade...pptx → 1s 46911 B
[09:14:50] 南宁华润/经纬C地块项目...ppt → 3s 10052 B
⚠️ LO→docx→md 失败 (重试3次): xxx.doc
```

### 输出统计

```
=== 完成 ===
总文件:     7
跳过(已存在): 0
跳过(扩展): 202
非扫描PDF:  2 (pdftotext)
扫描件PDF:  0 / 0 (mineru)
markitdown: 3 / 3
txt/log:    2
```

## Phase 6: 跑完校验

跑完后做以下检查:

1. **覆盖率**:对比 `项目存档/<y>/` 各类型文件数 vs `LLM-WIKI/raw/<y>/` 同类型 `.md` 数
2. **失败清单**:grep 日志里的 `⚠️`,逐个处理
3. **空文件**:某些转换可能产出 0 字节(失败但没报错),需 `find raw/<y> -size 0`
4. **scan 误判**:抽查 `pdftotext` 转出的 PDF,如果文件 < 几 KB 但原 PDF 几十 MB,可能是误判

## Output Quality Checklist

- [ ] 脚本语法 OK(`bash -n convert_archive_double_ext.sh`)
- [ ] 工具齐全(markitdown + soffice + pdftotext + mineru)
- [ ] 跳过逻辑生效(`~$xxx`、扩展名过滤、已存在 .md)
- [ ] 命名规则一致(`原名.ext.md`)
- [ ] 目录结构保留(子目录层级)
- [ ] 失败重试(LO 3 次)
- [ ] 日志路径在 `/home/jack/projects/ai-rd-system/toolchain/logs/`
- [ ] 跑完输出统计(`total / skip / text_pdf / scan_pdf / md / fail`)
- [ ] 跑完写 log.md
- [ ] 后台跑用 `terminal(background=true, notify_on_complete=true)`

## Quick Reference

| Phase | 动作 | 自动 | 输入 |
|-------|------|------|------|
| 0 | 扫描未转文件 | ✅ | SRC, DST |
| 1 | PDF 扫描判断 | ✅ | PDF 路径 |
| 2 | 类型路由 | ✅ | 扩展名 |
| 3 | 命名 + 输出 | ✅ | src, dst |
| 4 | 失败重试 | ✅(LO 3 次) | 失败文件 |
| 5 | 日志 + 统计 | ✅ | 跑批过程 |
| 6 | 校验 | ⚠️ 半自动 | 日志 + 文件数 |

**交互点**: 0-1 次(只有跑批确认要 confirm)

## Guard Rails

| # | 检测信号 | 正确行为 | 错误行为 |
|---|---------|---------|---------|
| 1 | 源目录不存在 | 报错退出 | 跳过跑批,假装成功 |
| 2 | NFS 卸载(mount 找不到) | 报错,提示挂 NFS | 静默跑出空结果 |
| 3 | markitdown 路径不存在 | 报错指出 | 用 LibreOffice 兜底 |
| 4 | 转换产出 0 字节文件 | 标记 + 继续 | 假装成功 |
| 5 | 转换产出 > 50 MB md(异常大) | 警告(可能是误判) | 继续 |
| 6 | LibreOffice 失败 3 次 | 记 fail,继续 | 阻塞后续文件 |
| 7 | MinerU 失败(模型下载失败等) | 记 fail,继续 | 整批 abort |
| 8 | `~$xxx` 临时文件被处理 | 必须跳过 | 转空内容,污染 raw |
| 9 | PDF 扫描判断返回 avg=0 | 默认走 MinerU | 走 pdftotext 出空 |
| 10 | 输出 md 已存在 | 跳过 | 覆盖丢失旧版本 |

## Downstream Handoff

转换产出的 `.md` 文件被以下消费:

- **`kb-doc-summary` (SKILL 1)** — 主力消费方,从 `raw/<year>/<file>.ext.md` 抽取元数据 + 摘要,产出 `kb/sources/<year>/<slug>.md`
- **手工浏览** — 用户直接 `cat` 或 Obsidian 打开看原始内容
- **`kb-tech-solution` (SKILL 2)** — 引用具体文件作为 baseline(用 frontmatter `source_file`)
- **`kb-just-ask` (SKILL 8,待写)** — 检索时直接命中原文段落

---

**maintainer**: jack (via Hermes)
**version**: 0.1
**status**: draft