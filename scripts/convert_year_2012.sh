#!/bin/bash
# convert_year_2012.sh — 全量把 项目存档/2012/ 转 md → LLM-WIKI/raw/2012/
# 策略:
#   - PDF → 先判扫描件(中间 3 页 avg char < 30 → mineru GPU,否则 pdftotext -layout)
#   - docx/xlsx/xls/pptx/ppt → markitdown
#   - doc → markitdown(已知失败,后续 antiword/pandoc 兜底)
#   - txt/log → 直接 cp 当 md
#   - dwg/dxf/bak/JPG/ARW/CR2/THM/rar/zip 等跳过
set -e

NFS="/mnt/nfs"
SRC="$NFS/项目存档/2012"
DST="$NFS/LLM-WIKI/raw/2012"
LOG_DIR="/home/jack/projects/ai-rd-system/toolchain/logs"
LOG="$LOG_DIR/convert_2012_full_$(date +%Y%m%d_%H%M%S).log"
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

    # 输出命名规则(2026-06-26 修复):
    # - 原: RFI.pdf → RFI.pdf.md (重复 .pdf 后缀,丑)
    # - 新: RFI.pdf → RFI.md (只加 .md)
    # 唯一性靠目录路径保证(同 dir 同名会冲突,但 NAS 上几乎不出现)
    # 同名冲突场景: 同 dir 下 RFI.pdf + RFI.doc → 都变 RFI.md,后写覆盖
    # 当前策略: 后写覆盖(简单可预测);后续可加 -pdf / -doc 后缀
    local base="$(basename "$src")"        # RFI-WH-CW-185.pdf
    local base_no_ext="${base%.*}"         # RFI-WH-CW-185
    local rel_dir="$(dirname "$rel")"      # 浦东嘉里中心保温计算/1-石材
    local dst_file="$DST/$rel_dir/$base_no_ext.$out_suffix"
    # 同名冲突检测(同 dir 下不同扩展名 → 都变 base.md → 后写覆盖,记录警告)
    if [ -f "$dst_file" ]; then
        echo "  ⚠️ 同名覆盖: $dst_file 已存在" >> "$LOG"
    fi
    mkdir -p "$(dirname "$dst_file")"

    local start=$(date +%s)

    if [ "$ext_lower" = "pdf" ]; then
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
        cp "$src" "$dst_file"
        count_txt=$((count_txt + 1))
    elif [ "$ext_lower" = "doc" ]; then
        # 旧 binary 格式 → LibreOffice headless → docx → markitdown
        # (不能直接转 txt,会丢格式;docx 路径保留 Word 结构)
        # LO 对 NFS 中文路径偶发失败,加 retry
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            if libreoffice --headless --convert-to docx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local docx=$(find "$tmpdir" -name "*.docx" -type f 2>/dev/null | head -1)
                if [ -n "$docx" ]; then
                    if "$MD_ENV/markitdown" "$docx" > "$dst_file" 2>> "$LOG"; then
                        lo_ok=1
                        break
                    fi
                fi
            fi
            sleep 2
        done
        if [ $lo_ok -eq 0 ]; then
            echo "  ⚠️ LO→docx→md 失败 (重试3次): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
        fi
        rm -rf "$tmpdir"
    elif [ "$ext_lower" = "ppt" ]; then
        # 旧 binary → LibreOffice → pptx → markitdown(保留幻灯片结构)
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        if libreoffice --headless --convert-to pptx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
            local pptx=$(find "$tmpdir" -name "*.pptx" -type f 2>/dev/null | head -1)
            if [ -n "$pptx" ]; then
                "$MD_ENV/markitdown" "$pptx" > "$dst_file" 2>> "$LOG" || {
                    echo "  ⚠️ markitdown failed (.ppt→pptx): $rel" >> "$LOG"
                    count_md_fail=$((count_md_fail + 1))
                }
            else
                echo "  ⚠️ lo→pptx empty: $rel" >> "$LOG"
                count_md_fail=$((count_md_fail + 1))
            fi
        else
            echo "  ⚠️ lo failed (.ppt): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
        fi
        rm -rf "$tmpdir"
    elif [ "$ext_lower" = "xls" ]; then
        # .xls 大写/双点等异常文件名 markitdown 不认,LO → xlsx → markitdown
        # (LO 兜底保留 Excel 表格结构)
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            if libreoffice --headless --convert-to xlsx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local xlsx=$(find "$tmpdir" -name "*.xlsx" -type f 2>/dev/null | head -1)
                if [ -n "$xlsx" ] && "$MD_ENV/markitdown" "$xlsx" > "$dst_file" 2>> "$LOG"; then
                    lo_ok=1
                    break
                fi
            fi
            sleep 2
        done
        if [ $lo_ok -eq 0 ]; then
            echo "  ⚠️ LO→xlsx→md 失败 (重试3次): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
        fi
        rm -rf "$tmpdir"
    else
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

echo "=== 全量转 2012/ ==="
echo "源: $SRC"
echo "目: $DST"
echo "日志: $LOG"
echo ""

# 用 find -printf "%P" 给相对路径(避免 ls -laR 拼接 bug)
# 同时跳过 @eaDir(Synology thumbnail 目录)和 .DS_Store
while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    case "$rel" in
        @eaDir/*|.DS_Store) continue ;;
    esac
    src="$SRC/$rel"
    [ -f "$src" ] || continue   # 防止非常规文件
    
    base=$(basename "$src")
    ext_lower="$(echo "${base##*.}" | tr '[:upper:]' '[:lower:]')"

    # 跳过的扩展
    skip=0
    for s in $SKIP_EXT; do
        if [ "$ext_lower" = "$s" ]; then
            skip=1
            break
        fi
    done
    if [ $skip -eq 1 ]; then
        count_skip=$((count_skip + 1))
        continue
    fi

    # 只处理文档类型
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
echo "=== 完成 ==="
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