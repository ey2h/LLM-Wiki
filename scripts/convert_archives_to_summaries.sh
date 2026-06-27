#!/bin/bash
# convert_archives_to_summaries.sh — 压缩包清单摘要入 KB
# 配套 SKILL: skills/kb-archive-summary/SKILL.md
#
# 核心原则(同 SKILL 概述):
#   - 不真正解压(unzip -l / unrar l / 7z l / tar -tzf 只读清单)
#   - 不读内容(节省时间 + token + 不破坏原压缩包)
#   - 写 kb/sources/<year>/<name>.ext.md(Source type,document_type=Archive)
#   - 同名 .ext.md 已存在 → 跳过(不覆盖)
#
# 用法:
#   bash convert_archives_to_summaries.sh <year>            # 跑单年
#   bash convert_archives_to_summaries.sh all               # 跑 2013-2026
#   bash convert_archives_to_summaries.sh <year> --dry-run  # 演练(不写文件)
#   bash convert_archives_to_summaries.sh <path/to/file.zip> # 单文件
set -e

NFS="/mnt/nfs"
SRC_BASE="$NFS/项目存档"
KB_BASE="/home/jack/LLM-Wiki/kb"
LOG_DIR="/home/jack/LLM-Wiki/logs/convert"
PY_SCRIPT_DIR="/home/jack/LLM-Wiki/skills/kb-archive-summary/scripts"

DRY_RUN=0
if [ "${2:-}" = "--dry-run" ]; then
    DRY_RUN=1
fi

mkdir -p "$LOG_DIR"

# ============ 核心:读清单 + 生成摘要 ============

# 读 zip 清单 → 输出文件列表(文件名|大小|压缩后大小|日期)
list_zip() {
    local f="$1"
    unzip -l "$f" 2>/dev/null | awk 'NR>3 && /^[ ]+[0-9]+/ {
        # 行格式: "  NNN  YYYY-MM-DD HH:MM   path"
        # 提取文件大小(第1列)、日期(第3列起)、文件名
        size=$1; date=$3; time=$4;
        name="";
        for (i=5; i<=NF; i++) name = name " " $i;
        sub(/^ /, "", name);
        printf "%s|%s|%s|%s\n", name, size, $2, date " " time;
    }' | head -1000
}

list_rar() {
    local f="$1"
    unrar l "$f" 2>/dev/null | awk '/^[ ]+[0-9]+/ {
        size=$1;
        name="";
        for (i=NF; i>=1; i--) if ($i ~ /[0-9]{2}:[0-9]{2}/) { split($i, t, ":"); break; }
        # 简化:rar 输出格式不固定,只取文件名
        for (i=5; i<=NF; i++) name = name " " $i;
        sub(/^ /, "", name);
        printf "%s|%s||\n", name, size;
    }' | head -1000
}

list_7z() {
    local f="$1"
    7z l "$f" 2>/dev/null | awk '/^[ ]+[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
        date=$1; time=$2; attr=$3; size=$4;
        name="";
        for (i=6; i<=NF; i++) name = name " " $i;
        sub(/^ /, "", name);
        printf "%s|%s||%s\n", name, size, date " " time;
    }' | head -1000
}

list_targz() {
    local f="$1"
    tar -tzf "$f" 2>/dev/null | awk '{
        printf "%s|||%s\n", $0, "tar.gz";
    }' | head -1000
}

# 推断用途(基于关键词)
infer_purpose() {
    local top_dirs="$1"
    local key_files="$2"
    local combined="$top_dirs $key_files"
    case "$combined" in
        *投标*|*Tender*|*tender*) echo "投标文件" ;;
        *合同*|*Contract*|*contract*) echo "合同附件" ;;
        *图纸*|*Drawing*|*drawing*|*.dwg) echo "图纸批量" ;;
        *规范*|*Standard*|*standard*) echo "规范合集" ;;
        *清单*|*BOQ*|*boq*|*.xlsx) echo "造价清单" ;;
        *扫描*|*Scan*|*scan*) echo "扫描件归档" ;;
        *简历*|*CV*|*cv*|*Jack*) echo "个人文件" ;;
        *Shadowsocks*|*python-*|*jdk*|*node*) echo "软件/工具" ;;
        *幕墙*|*Curtain*|*curtain*) echo "幕墙工程" ;;
        *) echo "工程文档(默认)" ;;
    esac
}

# 生成 KB Source Markdown 文件
generate_summary() {
    local archive_path="$1"
    local year="$2"
    local ext="$3"
    local out_path="$4"

    local base=$(basename "$archive_path")
    local archive_name="$base"
    local archive_size_bytes=$(stat -c%s "$archive_path" 2>/dev/null || echo "0")
    local archive_size_mb=$(echo "scale=2; $archive_size_bytes / 1048576" | bc 2>/dev/null || echo "?")

    # 读清单(2026-06-27 修:GBK→UTF-8 转码,zip 内 Windows 文件名常见 GBK)
    local inventory=""
    case "$ext" in
        zip) inventory=$(unzip -l "$archive_path" 2>/dev/null | iconv -f GBK -t UTF-8//IGNORE 2>/dev/null | awk 'NR>3 && /^[ ]+[0-9]+/ {
            size=$1; date=$3; time=$4;
            name="";
            for (i=5; i<=NF; i++) name = name " " $i;
            sub(/^ /, "", name);
            printf "%s|%s|%s|%s\n", name, size, $2, date " " time;
        }' | head -1000) ;;
        rar) inventory=$(unrar l "$archive_path" 2>/dev/null | iconv -f GBK -t UTF-8//IGNORE 2>/dev/null | awk '/^[ ]+[0-9]+/ {
            size=$1;
            name="";
            for (i=5; i<=NF; i++) name = name " " $i;
            sub(/^ /, "", name);
            printf "%s|%s||\n", name, size;
        }' | head -1000) ;;
        7z) inventory=$(7z l "$archive_path" 2>/dev/null | iconv -f GBK -t UTF-8//IGNORE 2>/dev/null | awk '/^[ ]+[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            date=$1; time=$2; attr=$3; size=$4;
            name="";
            for (i=6; i<=NF; i++) name = name " " $i;
            sub(/^ /, "", name);
            printf "%s|%s||%s\n", name, size, date " " time;
        }' | head -1000) ;;
        tar.gz) inventory=$(tar -tzf "$archive_path" 2>/dev/null | awk '{
            printf "%s|||%s\n", $0, "tar.gz";
        }' | head -1000) ;;
    esac

    # 解析 inventory
    local file_count=$(echo -n "$inventory" | grep -c '^' 2>/dev/null || echo "0")
    local total_uncompressed=$(echo "$inventory" | awk -F'|' '{sum+=$2} END {print sum+0}')
    local total_uncompressed_mb=$(echo "scale=2; $total_uncompressed / 1048576" | bc 2>/dev/null || echo "?")

    # 顶层目录(取每个文件路径的第 1 段)
    local top_dirs=$(echo "$inventory" | awk -F'|' '{print $1}' | awk -F'/' '{print $1}' | sort -u | grep -v '^\.\?$' | head -10 | tr '\n' ', ' | sed 's/,$//')

    # 文件类型分布(从文件名扩展名)
    local type_dist=$(echo "$inventory" | awk -F'|' '{print $1}' | awk -F'.' '{print tolower($NF)}' | sort | uniq -c | sort -rn | head -10)

    # Top 10 大文件
    local top_files=$(echo "$inventory" | awk -F'|' '{printf "%s\t%s\n", $2, $1}' | sort -rn | head -10)

    # 关键文件名(挑大小 top 5 + 名称含"投标/合同/图纸"等的)
    local key_files=$(echo "$inventory" | awk -F'|' '$1 ~ /投标|合同|图纸|清单|规范|说明|正文/ {print $1}' | head -20)

    # 推断用途
    local purpose=$(infer_purpose "$top_dirs" "$key_files")

    # 关键词(top_dirs 前 5 + key_files 抽词)
    local keywords=$(echo "$top_dirs $key_files" | tr ',/' ' \n' | grep -v '^$' | head -10 | tr '\n' ',' | sed 's/,$//')

    # 关联项目(从文件名抽项目关键词 — 简化:取顶层目录第 2 段作为可能项目)
    local related_projects=$(echo "$inventory" | awk -F'|' '{print $1}' | awk -F'/' 'NF>=3 {print $2}' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')

    # 生成 Markdown
    cat > "$out_path" <<EOF
---
title: 压缩包清单摘要 — $archive_name
slug: ${base%.$ext}.$ext
description: 压缩包 $archive_name($archive_size_mb MB,$file_count 个文件)的清单摘要;用途推断:$purpose;未解压内容,仅 KB 索引
type: Source
document_type: Archive
archive_path: "$archive_path"
archive_ext: "$ext"
archive_size_bytes: $archive_size_bytes
archive_size_mb: "$archive_size_mb"
file_count: $file_count
total_uncompressed_bytes: $total_uncompressed
total_uncompressed_mb: "$total_uncompressed_mb"
purpose_inferred: "$purpose"
top_keywords: [$keywords]
related_projects: "$related_projects"
confidence: low
created: $(date +%Y-%m-%d)
updated: $(date +%Y-%m-%d)
tags: [archive, $ext, $year, compressed, auto-summary]  # 5 tags: archive + ext + year + compressed + auto-summary
maintainer: jack (via Hermes)
---

# 压缩包清单摘要 — $archive_name

> 由 SKILL \`kb-archive-summary\` 自动生成(2026-06-27)
> 源路径:\`$archive_path\`
> **未解压内容,仅 KB 索引**

---

## §1 压缩包元信息

| 项 | 值 |
|---|---|
| 文件名 | \`$archive_name\` |
| 类型 | \`.$ext\` |
| 源路径 | \`$archive_path\` |
| 压缩包大小 | $archive_size_mb MB($archive_size_bytes bytes) |
| 解压后大小(估) | $total_uncompressed_mb MB($total_uncompressed bytes) |
| 压缩率(估) | $(echo "scale=1; $archive_size_bytes * 100 / ($total_uncompressed + 1)" | bc 2>/dev/null || echo "?")% |
| 文件数 | $file_count |
| 年份推断 | \`$year\` |
| 处理时间 | $(date '+%Y-%m-%d %H:%M:%S') |

## §2 解压清单摘要

### 文件类型分布(top 10)

\`\`\`
$type_dist
\`\`\`

### 顶层目录

$top_dirs

### Top 10 大文件

| 大小(bytes) | 文件名 |
|---:|---|
$(echo "$top_files" | awk -F'\t' '{printf "| %s | \`%s\` |\n", $1, $2}')

## §3 完整解压清单(前 100 行)

| 文件名 | 大小(bytes) | 压缩后(bytes) | 日期 |
|--------|---:|---:|---|
$(echo "$inventory" | head -100 | awk -F'|' '{printf "| \`%s\` | %s | %s | %s |\n", $1, $2, $3, $4}')

$(if [ "$file_count" -gt 100 ]; then echo "…还有 $((file_count - 100)) 个文件(摘要未列,需手动解压)"; fi)

## §4 用途推断

**推断结果**:**$purpose**

**推断依据**:
- 顶层目录:$top_dirs
- 关键文件名:$(echo "$key_files" | head -5 | tr '\n' ';' | sed 's/;$//')

## §5 关键文件

以下文件可能值得深读(按大小 top + 命名关键词):

$(echo "$key_files" | head -10 | awk '{print "- `" $0 "`"}')

## §6 关联项目

**推断关联项目**(从文件路径第 2 段):
$(if [ -n "$related_projects" ]; then echo "- $related_projects"; else echo "- (无明显项目关联)"; fi)

## §7 置信度评估

**置信度**:**低**

**原因**:
- 仅读清单,未读任何文件内容
- 文件名启发式推断用途,**可能错误**
- 关联项目推断基于路径段,**可能不准确**
- 真正用途需手动解压 + 阅读后才知

## §8 处理建议

- [ ] **手动解压**: \`mkdir -p /tmp/$base/ && cd /tmp/$base/ && unzip "$archive_path"\`
- [ ] **跑 SKILL 1**: 对解压后关键 PDF / Office 走完整 Source 摘要
- [ ] **若压缩包价值不大**: 跳过,保留此清单摘要作为 KB 索引
- [ ] **若压缩包损坏**: 删 KB 摘要,NFS 原文件不动

## §9 跨引用

(暂无相关 Source;未来若跑 SKILL 1 深读其中文档,在此追加 \`[[/kb/sources/<year>/<slug>]]\` 链接)

---

**maintainer**: jack (via Hermes)
**skill**: kb-archive-summary v0.1
**generated_at**: $(date '+%Y-%m-%d %H:%M:%S')
EOF
}

# ============ 主流程 ============

process_archive() {
    local archive_path="$1"
    local year="$2"
    local ext="$3"

    local base=$(basename "$archive_path")
    local out_dir="$KB_BASE/sources/$year"
    local out_path="$out_dir/${base}.md"

    # Hard Gate #1:文件存在 + 可读
    [ -f "$archive_path" ] || return
    case "$ext" in
        zip) unzip -l "$archive_path" >/dev/null 2>&1 || { echo "  [FAIL] zip 损坏: $archive_path"; return; } ;;
        rar) unrar l "$archive_path" >/dev/null 2>&1 || { echo "  [FAIL] rar 损坏: $archive_path"; return; } ;;
        7z) 7z l "$archive_path" >/dev/null 2>&1 || { echo "  [FAIL] 7z 损坏: $archive_path"; return; } ;;
        tar.gz) tar -tzf "$archive_path" >/dev/null 2>&1 || { echo "  [FAIL] tar.gz 损坏: $archive_path"; return; } ;;
    esac

    # Hard Gate #3:同名 .md 已存在 → 跳过
    if [ -f "$out_path" ]; then
        echo "  [SKIP] 已存在: $out_path"
        return
    fi

    mkdir -p "$out_dir"

    if [ $DRY_RUN -eq 1 ]; then
        echo "  [DRY] would write: $out_path"
        return
    fi

    generate_summary "$archive_path" "$year" "$ext" "$out_path"

    # Hard Gate #8:文件 ≥ 500 字符
    if [ ! -f "$out_path" ] || [ $(stat -c%s "$out_path") -lt 500 ]; then
        rm -f "$out_path"
        echo "  [FAIL] 输出 < 500 字符: $archive_path"
        return
    fi

    echo "  [OK] $archive_path → $out_path"
}

# 入口
case "${1:-}" in
    "")
        echo "用法: $0 <year|all|<path/to/file.ext>>"
        echo "  <year>:        2013-2026 任一年份"
        echo "  all:           跑 2013-2026"
        echo "  <path/...>:    单个压缩包路径"
        echo "  [--dry-run]:   演练(不写文件)"
        exit 1
        ;;
    all)
        for y in 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
            echo "=== 跑 $y ==="
            find "$SRC_BASE/$y" -type f \( -name "*.zip" -o -name "*.rar" -o -name "*.7z" -o -name "*.tar.gz" \) 2>/dev/null | while read f; do
                ext="${f##*.}"
                [ "$ext" = "gz" ] && [[ "$f" == *.tar.gz ]] && ext="tar.gz"
                process_archive "$f" "$y" "$ext"
            done
        done
        ;;
    [0-9]*|[12][0-9][0-9][0-9])
        # 单年份
        year="$1"
        echo "=== 跑 $year ==="
        find "$SRC_BASE/$year" -type f \( -name "*.zip" -o -name "*.rar" -o -name "*.7z" -o -name "*.tar.gz" \) 2>/dev/null | while read f; do
            ext="${f##*.}"
            [ "$ext" = "gz" ] && [[ "$f" == *.tar.gz ]] && ext="tar.gz"
            process_archive "$f" "$year" "$ext"
        done
        ;;
    *.zip|*.rar|*.7z|*.tar.gz)
        # 单文件
        f="$1"
        [ -f "$f" ] || { echo "文件不存在: $f"; exit 1; }
        # 推断年份(从路径含 /20XX/)
        year=$(echo "$f" | grep -oE '/20[0-9]{2}/' | head -1 | tr -d '/' || echo "unknown")
        [ -z "$year" ] && year="unknown"
        ext="${f##*.}"
        [ "$ext" = "gz" ] && [[ "$f" == *.tar.gz ]] && ext="tar.gz"
        echo "=== 单文件: $f (year=$year) ==="
        process_archive "$f" "$year" "$ext"
        ;;
esac
