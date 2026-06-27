#!/bin/bash
# convert_archive_double_ext.sh — 把 项目存档/<year>/ 未转文档转 md → LLM-WIKI/raw/<year>/
# 与 convert_year_2012.sh 的区别:
#   - 输出命名规则: 原名.ext.md(如 RFI.pdf → RFI.pdf.md)
#   - 不重新处理 2012(convert_year_2012.sh 已跑过,使用 原名.md 规则)
#   - 输入目录: 项目存档/<year>/  (跨 2013-2026)
#   - 输出目录: LLM-WIKI/raw/<year>/  (沿用 2012)
#
# 策略(同 convert_year_2012.sh):
#   - PDF → 先判扫描件(中间 3 页 avg char < 30 → mineru GPU,否则 pdftotext -layout)
#   - docx/xlsx/xls/pptx/ppt → markitdown
#   - doc → LibreOffice headless → docx → markitdown
#   - txt/log → 直接 cp 当 md
#   - dwg/dxf/bak/JPG/ARW/CR2/THM/rar/zip 等跳过
#   - 同名已存在(.md) → 跳过(已转过的不覆盖)
#
# 用法:
#   bash convert_archive_double_ext.sh <year>            # 跑单年
#   bash convert_archive_double_ext.sh all               # 跑 2013-2026
#   bash convert_archive_double_ext.sh <year> --dry-run  # 演练
set -e

# OOM 防护(2026-06-27):限制单进程内存,避免 OOM killer 杀 daemon
ulimit -v 4194304  # 4GB 虚拟内存
ulimit -m 4194304  # 4GB 驻留内存

# OOM 防护(2026-06-27):检查系统内存压力,>=80% 跳过该文件
check_memory_pressure() {
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
    if [ "$mem_used_pct" -ge 80 ]; then
        echo "  ⚠️ memory_pressure: ${mem_used_pct}% used (>=80%)" >> "$LOG"
        return 0  # 0 = 有压力,跳过
    fi
    return 1  # 1 = 无压力,继续
}

NFS="/mnt/nfs"
SRC_BASE="$NFS/项目存档"
DST_BASE="$NFS/LLM-WIKI/raw"
LOG_DIR="/home/jack/projects/ai-rd-system/toolchain/logs"
MD_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin"
MN_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/mineru/bin"
PROJ_ROOT="/home/jack/projects/ai-rd-system"
PY_SCANNER="$PROJ_ROOT/scripts/pdf_is_scanned.py"

# 跳过扩展(小写比较)
SKIP_EXT="dwg dxf bak jpg arw cr2 thm rar zip 7z tar gz bz2 cab exe dll msi ins bin mp4 mpg mp3 dat st7 lsl lsa bxs mpp dwl dwl2 sat lid ctb wmf themepack xmcd crdownload tmp"

count_total=0
count_skip=0
count_skip_exists=0
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

    # dry-run 模式:只打印,不真转
    if [ "${DRY_RUN:-0}" = "1" ]; then
        echo "  [DRY] would process: $rel (ext=$ext_lower)"
        count_total=$((count_total + 1))
        return
    fi

    # OOM 防护(2026-06-27):每文件之间 sleep 1,给系统喘息
    sleep 1


    # 输出命名规则(2026-06-27 新版):原名.ext.md
    # 例:RFI.pdf → RFI.pdf.md;2月29日初稿.docx → 2月29日初稿.docx.md
    # txt/log 例外:foo.txt → foo.txt.md
    local out_suffix="md"
    [ "$ext_lower" = "txt" ] || [ "$ext_lower" = "log" ] && out_suffix="txt.md"

    local base="$(basename "$src")"           # RFI-WH-CW-185.pdf
    local rel_dir="$(dirname "$rel")"         # 浦东嘉里中心保温计算/1-石材
    local dst_file="$DST/$rel_dir/$base.$out_suffix"  # 原名.ext.md

    # 已存在 → 跳过(避免重复转,改用 rename_double_ext.py 反向归一)
    if [ -f "$dst_file" ]; then
        count_skip_exists=$((count_skip_exists + 1))
        return
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
        if check_memory_pressure; then
            echo "  ⚠️ memory_pressure_skip (.doc): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            sleep 30
            return
        fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            # 加 --norestore --nologo --nolockcheck + timeout 120s(2026-06-27 OOM 防护)
            if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to docx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
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
        # OOM 防护(2026-06-27):跳过当前 .ppt 文件,等内存恢复后再转
        if check_memory_pressure; then
            echo "  ⚠️ memory_pressure_skip (.ppt): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            sleep 30
            return
        fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        # 加 --norestore --nologo --nolockcheck 减少 LO 自身内存(2026-06-27)
        if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to pptx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
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
        if check_memory_pressure; then
            echo "  ⚠️ memory_pressure_skip (.xls): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            sleep 30
            return
        fi
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            # 加 --norestore --nologo --nolockcheck + timeout 120s(2026-06-27 OOM 防护)
            if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to xlsx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
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
        echo "--- 进度: total=$count_total skip_exists=$count_skip_exists done=$((count_pdf_text+count_pdf_scanned_done+count_md+count_txt)) ---"
    fi
}

convert_year() {
    local y="$1"
    local SRC="$SRC_BASE/$y"
    local DST="$DST_BASE/$y"
    local LOG="$LOG_DIR/convert_${y}_double_ext_$(date +%Y%m%d_%H%M%S).log"

    mkdir -p "$DST" "$LOG_DIR"

    echo "=== 全量转 $y/(原名.ext.md 命名) ==="
    echo "源: $SRC"
    echo "目: $DST"
    echo "日志: $LOG"
    echo ""

    # 重置 counters
    count_total=0
    count_skip=0
    count_skip_exists=0
    count_pdf_text=0
    count_pdf_scanned=0
    count_pdf_scanned_done=0
    count_md=0
    count_md_fail=0
    count_txt=0

    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        case "$rel" in
            @eaDir/*|.DS_Store) continue ;;
        esac
        src="$SRC/$rel"
        [ -f "$src" ] || continue

        # 跳过 Office 临时文件(~$ 开头)
        case "$(basename "$src")" in
            ~\$*) count_skip=$((count_skip + 1)); continue ;;
        esac

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
    echo "=== $y 完成 ==="
    echo "总文件:     $count_total"
    echo "跳过(已存在): $count_skip_exists"
    echo "跳过(扩展): $count_skip"
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
}

# 主入口
# 解析参数:支持 <year|all> [--dry-run]
YEAR_ARG=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        *) YEAR_ARG="$arg" ;;
    esac
done

case "${YEAR_ARG:-}" in
    all)
        for y in 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
            convert_year "$y"
            echo ""
            echo "==============================================="
            echo ""
        done
        ;;
    *)
        if [ -z "${YEAR_ARG:-}" ]; then
            echo "用法: $0 <year|all> [--dry-run]"
            echo "  <year>:    2013-2026 任一年份"
            echo "  all:       跑 2013-2026"
            echo "  --dry-run: 演练(不写文件)"
            exit 1
        fi
        convert_year "$YEAR_ARG"
        ;;
esac