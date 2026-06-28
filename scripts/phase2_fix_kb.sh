#!/usr/bin/env bash
# Phase 2: 修复 KB 产物结构 v3 (final)
#   A. 加 frontmatter (YAML) — 所有外层 .md
#   C. 删除内层重复 .md (<basename>.<ext>/<basename>.<ext>.md)
#
# 关键设计:
#   - 不重命名资产目录 (避免 NFS "目录已存在" 冲突)
#   - 不改图片路径 (已经是相对路径 ./<basename>.<ext>/images/)
#   - 检测已加 frontmatter 的 .md 跳过 (idempotent)
#   - 检测内层 .md 用父目录名 == stem
#   - KB_ROOT 末尾是 4 位数字 → 用作 year;否则从路径首段提取
#
# 用法:
#   phase2_fix_kb.sh <kb_root> [--dry-run] [--resume]
#   phase2_fix_kb.sh <kb_root> [--rollback]   # 删 frontmatter (从第二个 --- 起)
#   phase2_fix_kb.sh <kb_root> [--type1=N] [--type2=N]
#
# v3 已知 bug 修复 (2026-06-28):
#   - year 从 KB_ROOT 末尾 4 位数字推断,不再用 cut -d/ -f1
#   - src_path = rel_path%.md (不再拼 .$ext)
#
# 已验证样本 (10 个外层 + 318 个内层):
#   - 4 个 .md 跑过 2 轮 (1 个 typo 修复)
#   - 318 个内层重复全部删除成功
#   - 当前 KB 状态:2012 有 4 个外层有 frontmatter,其他干净

set -euo pipefail

KB_ROOT="${1:?用法: $0 <kb_root> [--dry-run] [--rollback] [--resume] [--type1=N] [--type2=N]}"
DRY_RUN=0
ROLLBACK=0
RESUME=0
TYPE1_LIMIT=0
TYPE2_LIMIT=0

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=1; shift ;;
        --rollback) ROLLBACK=1; shift ;;
        --resume)   RESUME=1; shift ;;
        --type1=*)  TYPE1_LIMIT="${1#*=}"; shift ;;
        --type2=*)  TYPE2_LIMIT="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

log() { echo "[$(date '+%H:%M:%S')] $*"; }
dry() { [[ $DRY_RUN -eq 1 || $ROLLBACK -eq 1 ]] && echo "[DRY] $*" || eval "$@"; }

log "=== Phase 2 修复脚本 v3 (final) ==="
log "KB_ROOT: $KB_ROOT  DRY_RUN: $DRY_RUN  ROLLBACK: $ROLLBACK  RESUME: $RESUME"
[[ $TYPE1_LIMIT -gt 0 ]] && log "TYPE1_LIMIT: $TYPE1_LIMIT"
[[ $TYPE2_LIMIT -gt 0 ]] && log "TYPE2_LIMIT: $TYPE2_LIMIT"

# 收集 .md,分类
# 排除 mineru 中间产物: input.md / input_*.json / layout.json / content_list.json 等
declare -a type1_files=()       # 有 asset_dir
declare -a type2_files=()       # 无 asset_dir
declare -a inner_dup_files=()   # 内层重复
declare -a skipped=()           # 跳过 (mineru 中间产物)
while IFS= read -r md_file; do
    dir=$(dirname "$md_file")
    base=$(basename "$md_file")
    stem="${base%.md}"
    parent_dir=$(basename "$dir")

    # 排除 mineru 中间产物
    case "$base" in
        input.md|input_*.md|*.layout.md|*.content_list.md)
            skipped+=("$md_file")
            continue
            ;;
    esac

    # 内层重复:父目录 == stem
    if [[ "$parent_dir" == "$stem" ]]; then
        inner_dup_files+=("$md_file")
        continue
    fi

    # 外层
    if [[ -d "$dir/$stem" ]]; then
        type1_files+=("$md_file")
    else
        type2_files+=("$md_file")
    fi
done < <(find "$KB_ROOT" -name "*.md" -type f 2>/dev/null | sort)

log "Type 1 (有 asset_dir): ${#type1_files[@]} 个"
log "Type 2 (无 asset_dir): ${#type2_files[@]} 个"
log "内层重复 .md: ${#inner_dup_files[@]} 个 (只删)"
log "跳过 (mineru 中间产物): ${#skipped[@]} 个"

# 应用限制
[[ $TYPE1_LIMIT -gt 0 && ${#type1_files[@]} -gt $TYPE1_LIMIT ]] && type1_files=("${type1_files[@]:0:$TYPE1_LIMIT}")
[[ $TYPE2_LIMIT -gt 0 && ${#type2_files[@]} -gt $TYPE2_LIMIT ]] && type2_files=("${type2_files[@]:0:$TYPE2_LIMIT}")
log "实际处理: type1=${#type1_files[@]} type2=${#type2_files[@]} inner_dup=${#inner_dup_files[@]}"

# --- ROLLBACK 模式: 删所有 frontmatter ---
do_rollback() {
    local md_file="$1"
    # 检查是否有 frontmatter
    if ! head -1 "$md_file" 2>/dev/null | grep -q '^---$'; then
        return
    fi
    log "── ROLLBACK: $md_file"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "   [DRY] 删 frontmatter (从第二个 --- 后开始)"
        return
    fi
    awk 'BEGIN{cnt=0} /^---$/{cnt++; if(cnt==2){found=1; next}} found{print}' "$md_file" > "$md_file.tmp" \
        && mv "$md_file.tmp" "$md_file"
    log "   ✓ 删 frontmatter"
}

# --- 删除内层重复 ---
do_inner_dup() {
    local md_file="$1"
    log "── 内层重复 (删): $md_file"
    if [[ $DRY_RUN -eq 1 ]]; then
        log "   [DRY] rm '$md_file'"
    else
        rm "$md_file"
        log "   ✓ rm"
    fi
}

# --- 处理外层: 加 frontmatter + 删内层 dup ---
do_outer() {
    local md_file="$1"
    local dir stem ext pure_basename base
    dir=$(dirname "$md_file")
    base=$(basename "$md_file")
    stem="${base%.md}"
    ext="${stem##*.}"
    pure_basename="${stem%.*}"

    log ""
    log "── $md_file"
    log "   ext=$ext  pure_basename=$pure_basename"

    # 1. 删内层重复
    local inner_md="$dir/$stem/$base"
    if [[ -f "$inner_md" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log "   [DRY] rm '$inner_md' (内层重复)"
        else
            rm "$inner_md"
            log "   ✓ rm 内层重复"
        fi
    fi

    # 2. 加 frontmatter (idempotent)
    if head -1 "$md_file" 2>/dev/null | grep -q '^---$'; then
        log "   ⊘ 已有 frontmatter,跳过"
        return
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        log "   [DRY] 加 frontmatter (year/source_path/basename/ext/file_size/mtime/extractor)"
        return
    fi

    # 推断 year
    local rel_path src_path file_size mtime year last_segment
    rel_path="${md_file#$KB_ROOT/}"
    src_path="${rel_path%.md}"           # 去掉 .md
    file_size=$(stat -c%s "$md_file" 2>/dev/null || echo 0)
    mtime=$(stat -c%y "$md_file" 2>/dev/null | cut -d. -f1)
    last_segment=$(basename "$KB_ROOT")
    if [[ "$last_segment" =~ ^[0-9]{4}$ ]]; then
        year="$last_segment"
    else
        year=$(echo "$rel_path" | cut -d/ -f1 | grep -oE '^[0-9]{4}' || echo "unknown")
    fi

    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile" <<EOF
---
year: $year
source_path: $src_path
basename: $pure_basename
ext: ${ext,,}
file_size: $file_size
mtime: $mtime
converted_at: $(date -Iseconds)
extractor: markitdown
---

EOF
    cat "$md_file" >> "$tmpfile"
    mv "$tmpfile" "$md_file"
    log "   ✓ 加 frontmatter (year=$year size=$file_size)"
}

# --- 主循环 ---
fixed_outer=0; fixed_dup=0; rolled_back=0
if [[ $ROLLBACK -eq 1 ]]; then
    # 回滚模式: 所有外层 .md
    for f in "${type1_files[@]}" "${type2_files[@]}"; do
        do_rollback "$f"
        rolled_back=$((rolled_back + 1))
    done
    log ""
    log "=== 回滚完成 ==="
    log "回滚数: $rolled_back"
elif [[ $RESUME -eq 1 ]]; then
    # resume 模式: 跳过已有 frontmatter 的,只处理没处理的
    # (already implemented via idempotent check in do_outer)
    log "(resume 模式: 跳过已有 frontmatter 的)"
    for f in "${type1_files[@]}"; do
        do_outer "$f"
        fixed_outer=$((fixed_outer + 1))
    done
    for f in "${type2_files[@]}"; do
        do_outer "$f"
        fixed_outer=$((fixed_outer + 1))
    done
    for f in "${inner_dup_files[@]}"; do
        do_inner_dup "$f"
        fixed_dup=$((fixed_dup + 1))
    done
    log ""
    log "=== resume 完成 ==="
    log "外层处理: $fixed_outer"
    log "内层删除: $fixed_dup"
else
    # 默认模式
    for f in "${type1_files[@]}"; do
        do_outer "$f"
        fixed_outer=$((fixed_outer + 1))
    done
    for f in "${type2_files[@]}"; do
        do_outer "$f"
        fixed_outer=$((fixed_outer + 1))
    done
    for f in "${inner_dup_files[@]}"; do
        do_inner_dup "$f"
        fixed_dup=$((fixed_dup + 1))
    done
    log ""
    log "=== 完成 ==="
    log "外层修复 (frontmatter + 删内层): $fixed_outer"
    log "内层重复删除: $fixed_dup"
fi