#!/bin/bash
# convert_year.sh — 通用全量转换脚本(任意年份)
# 用法:bash convert_year.sh 2018                  # 只转 2018 全量
#       bash convert_year.sh 2018 --dry-run       # 干跑,看日志
#       bash convert_year.sh 2018 2019 2020       # 连续转多年
# 不传参默认用当前年
set -e

YEAR="${1:-$(date +%Y)}"
shift || true
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

NFS="/mnt/nfs"
SRC="$NFS/项目存档/$YEAR"
DST="$NFS/LLM-WIKI/raw/$YEAR"
LOG_DIR="/home/jack/projects/ai-rd-system/toolchain/logs"
LOG="$LOG_DIR/convert_${YEAR}_double_ext_$(date +%Y%m%d_%H%M%S).log"
MD_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin"
MN_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/mineru/bin"
PROJ_ROOT="/home/jack/projects/ai-rd-system"
PY_SCANNER="$PROJ_ROOT/scripts/pdf_is_scanned.py"

mkdir -p "$DST" "$LOG_DIR"

# 跳过扩展(小写比较)
SKIP_EXT="dwg dxf bak jpg arw cr2 thm rar zip 7z tar gz bz2 cab exe dll msi ins bin mp4 mpg mp3 dat st7 lsl lsa bxs mpp dwl dwl2 sat lid ctb wmf themepack xmcd crdownload tmp"

count_total=0
count_skip=0
count_pdf_text=0
count_pdf_scanned=0
count_pdf_scanned_done=0
count_md=0
count_md_fail=0
count_txt=0

run_one() {
    local src="$1"
    local rel="${src#$SRC/}"
    local ext_lower="$(echo "${src##*.}" | tr '[:upper:]' '[:lower:]')"

    local out_suffix="md"
    [ "$ext_lower" = "txt" ] || [ "$ext_lower" = "log" ] && out_suffix="txt.md"

    local base="$(basename "$src")"
    local base_no_ext="${base%.*}"
    local rel_dir="$(dirname "$rel")"
    local dst_file="$DST/$rel_dir/$base_no_ext.$out_suffix"
    mkdir -p "$(dirname "$dst_file")"

    local start=$(date +%s)

    if [ "$ext_lower" = "pdf" ]; then
        if $DRY_RUN; then
            echo "[DRY] pdf: $rel"
            return
        fi
        local probe=$(python3 "$PY_SCANNER" "$src" 30 2>&1)
        local avg=$(echo "$probe" | python3 -c "import sys,json;d=json.load(sys.stdin);print(int(d['avg_chars']))" 2>/dev/null || echo "0")
        if [ "$avg" -lt 30 ]; then
            count_pdf_scanned=$((count_pdf_scanned + 1))
            echo "[SCAN avg=$avg] $rel"
            local tmpdir=$(mktemp -d)
            if "$MN_ENV/mineru" -p "$src" -o "$tmpdir" >> "$LOG" 2>&1; then
                local found=$(find "$tmpdir" -name "*.md" -type f 2>/dev/null | head -1)
                if [ -n "$found" ]; then
                    cp "$found" "$dst_file"
                    count_pdf_scanned_done=$((count_pdf_scanned_done + 1))
                fi
            else
                echo "  ⚠️ mineru failed: $rel" >> "$LOG"
            fi
            rm -rf "$tmpdir"
        else
            count_pdf_text=$((count_pdf_text + 1))
            if pdftotext -layout "$src" "$dst_file" 2>> "$LOG"; then
                :
            else
                echo "  ⚠️ pdftotext failed: $rel" >> "$LOG"
            fi
        fi
    elif [ "$ext_lower" = "txt" ] || [ "$ext_lower" = "log" ]; then
        if $DRY_RUN; then echo "[DRY] $ext_lower: $rel"; return; fi
        cp "$src" "$dst_file"
        count_txt=$((count_txt + 1))
    elif [ "$ext_lower" = "doc" ]; then
        if $DRY_RUN; then echo "[DRY] doc: $rel"; return; fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            if libreoffice --headless --convert-to docx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local docx=$(find "$tmpdir" -name "*.docx" -type f 2>/dev/null | head -1)
                if [ -n "$docx" ] && "$MD_ENV/markitdown" "$docx" > "$dst_file" 2>> "$LOG"; then
                    lo_ok=1; break
                fi
            fi
            sleep 2
        done
        [ $lo_ok -eq 0 ] && { echo "  ⚠️ LO→docx→md 失败 (重试3次): $rel" >> "$LOG"; count_md_fail=$((count_md_fail + 1)); }
        rm -rf "$tmpdir"
    elif [ "$ext_lower" = "ppt" ]; then
        if $DRY_RUN; then echo "[DRY] ppt: $rel"; return; fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        if libreoffice --headless --convert-to pptx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
            local pptx=$(find "$tmpdir" -name "*.pptx" -type f 2>/dev/null | head -1)
            if [ -n "$pptx" ]; then
                "$MD_ENV/markitdown" "$pptx" > "$dst_file" 2>> "$LOG" || { echo "  ⚠️ markitdown failed (.ppt→pptx): $rel" >> "$LOG"; count_md_fail=$((count_md_fail + 1)); }
            else
                echo "  ⚠️ lo→pptx empty: $rel" >> "$LOG"; count_md_fail=$((count_md_fail + 1))
            fi
        else
            echo "  ⚠️ lo failed (.ppt): $rel" >> "$LOG"; count_md_fail=$((count_md_fail + 1))
        fi
        rm -rf "$tmpdir"
    elif [ "$ext_lower" = "xls" ]; then
        if $DRY_RUN; then echo "[DRY] xls: $rel"; return; fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            if libreoffice --headless --convert-to xlsx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local xlsx=$(find "$tmpdir" -name "*.xlsx" -type f 2>/dev/null | head -1)
                if [ -n "$xlsx" ] && "$MD_ENV/markitdown" "$xlsx" > "$dst_file" 2>> "$LOG"; then
                    lo_ok=1; break
                fi
            fi
            sleep 2
        done
        [ $lo_ok -eq 0 ] && { echo "  ⚠️ LO→xlsx→md 失败 (重试3次): $rel" >> "$LOG"; count_md_fail=$((count_md_fail + 1)); }
        rm -rf "$tmpdir"
    else
        if $DRY_RUN; then echo "[DRY] $ext_lower: $rel"; return; fi
        count_md=$((count_md + 1))
        if "$MD_ENV/markitdown" "$src" > "$dst_file" 2>> "$LOG"; then
            :
        else
            echo "  ⚠️ markitdown failed: $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
        fi
    fi

    local end=$(date +%s)
    local sz=$(stat -c%s "$dst_file" 2>/dev/null || echo "0")
    echo "[$(date '+%H:%M:%S')] $rel → $((end-start))s $sz B" >> "$LOG"

    count_total=$((count_total + 1))
    if [ $((count_total % 20)) -eq 0 ]; then
        echo "--- 进度: total=$count_total skip=$count_skip done=$((count_pdf_text+count_pdf_scanned_done+count_md+count_txt)) ---"
    fi
}

echo "=== 全量转 $YEAR/ ==="
echo "源: $SRC"
echo "目: $DST"
echo "日志: $LOG"
echo "DRY_RUN=$DRY_RUN"
echo ""

if [ ! -d "$SRC" ]; then
    echo "❌ 源目录不存在: $SRC"
    exit 2
fi

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    case "$rel" in
        @eaDir/*|.DS_Store) continue ;;
    esac
    src="$SRC/$rel"
    [ -f "$src" ] || continue

    base=$(basename "$src")
    ext_lower="$(echo "${base##*.}" | tr '[:upper:]' '[:lower:]')"

    skip=0
    for s in $SKIP_EXT; do
        if [ "$ext_lower" = "$s" ]; then
            skip=1; break
        fi
    done
    if [ $skip -eq 1 ]; then
        count_skip=$((count_skip + 1))
        continue
    fi

    case "$ext_lower" in
        pdf|docx|doc|xlsx|xls|pptx|ppt|txt|log)
            run_one "$src"
            ;;
        *)
            count_skip=$((count_skip + 1))
            ;;
    esac
done < <(cd "$SRC" && find . -type f -not -path './@eaDir/*' 2>/dev/null | sed 's|^\./||')

echo ""
echo "=== 完成 ($YEAR) ==="
echo "总文件:     $count_total"
echo "跳过:       $count_skip"
echo "非扫描PDF:  $count_pdf_text (pdftotext)"
echo "扫描件PDF:  $count_pdf_scanned_done / $count_pdf_scanned (mineru)"
echo "markitdown: $((count_md - count_md_fail)) / $count_md"
echo "txt/log:    $count_txt"
echo ""
echo "日志: $LOG"
echo ""
echo "=== 输出统计 ==="
find "$DST" -type f -name "*.md" 2>/dev/null | wc -l
du -sh "$DST" 2>&1
