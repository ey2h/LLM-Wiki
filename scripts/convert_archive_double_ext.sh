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

# 2026-06-27:跟 GitHub ey2h/LLM-Wiki parse_pdf.sh 保持一致 — 不设 ulimit,
# 信任 mineru + 系统 OOM killer 自动管内存。实测 ulimit -m 会破坏 vllm 8MB KV cache mmap,
# 导致所有扫描 PDF 'memory allocation of 8388608 bytes failed' 全失败。

NFS="/mnt/nfs"
SRC_BASE="$NFS/项目存档"
DST_BASE="$NFS/LLM-WIKI/raw"
LOG_DIR="/home/jack/projects/ai-rd-system/toolchain/logs"
MD_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin"
EXTRACT_SCRIPT="/home/jack/LLM-Wiki/scripts/extract_md_images.py"  # 2026-06-27:拆 base64 → images/ + 改 md 引用

# 2026-06-27 v11:扫描 PDF 走 GPU(mineru vlm-engine 独占),其它文件并发后台跑
# 之前 v10 是单线程,扫描 PDF 占满 30s/张 时,office/text 被卡死
# 设计:
#   - 扫描 PDF (avg < 30):同步跑,独占 GPU
#   - 非扫描 PDF + 所有 Office + txt/log:后台并发(max N worker)
#   - 每 batch 收 N 个非扫描任务 + 0-N 个扫描任务,扫描在 batch 内同步跑完后 wait 全部后台
MAX_PARALLEL="${MAX_PARALLEL:-4}"     # v11 新增:非扫描文件并发 worker 数
BATCH_SCAN_LIMIT="${BATCH_SCAN_LIMIT:-3}"  # v11 新增:每个 batch 内最大扫描文件数
SCAN_CACHE_DIR="${LOG_DIR}/.scan_cache"     # v11 新增:扫描判断 cache(避免每批重复探测)
mkdir -p "$SCAN_CACHE_DIR"
export SCAN_CACHE_DIR

# v11 新增:快速判断 PDF 是否扫描件(带 cache)
is_scanned_quick() {
    local pdf="$1"
    local rel_hash=$(echo "$pdf" | md5sum | cut -c1-16)
    local cache_file="$SCAN_CACHE_DIR/$rel_hash"
    if [ -f "$cache_file" ]; then
        cat "$cache_file"
        return
    fi
    local probe=$(python3 "$PY_SCANNER" "$pdf" 30 2>&1)
    local avg=$(echo "$probe" | python3 -c "import sys,json;d=json.load(sys.stdin);print(int(d['avg_chars']))" 2>/dev/null || echo "0")
    local result=$([ "$avg" -lt 30 ] && echo "1" || echo "0")
    echo "$avg" > "$cache_file"
    echo "$result"
}

# 2026-06-27 markitdown --keep-data-uris 拆图:把 base64 内嵌图拆到 images/,md 引用改相对路径
# 跟扫描 PDF mineru 产物结构一致(<base>.ext.md.d/<base>.ext.md + images/)
extract_md_images() {
    local md_file="$1"
    [ -f "$md_file" ] || return 0
    python3 "$EXTRACT_SCRIPT" "$md_file" 2>>"$LOG" || true
}
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
        # PDF CAD 图纸跳过(2026-06-27 用户要求)
        # 命名模式: S-XX-XX-XX.pdf (结构图) / S-XX-L9-XX.pdf / CW-AXX-NN.pdf (幕墙图)
        # 这些是 CAD 输出 PDF,内容是图纸非文本,对 KB 无用
        local base_no_ext="${base%.pdf}"
        # S- 开头(结构图)+ 至少 2 段短码(数字或字母)
        # CW- 开头(幕墙图 Curtain Wall)
        if echo "$base_no_ext" | grep -qE '^(S(-[A-Za-z0-9]+){2,}|CW-[A-Za-z0-9]+-[0-9]+)'; then
            count_skip=$((count_skip + 1))
            echo "  [SKIP-CAD-PDF] $rel" >> "$LOG"
            return
        fi
        local probe=$(python3 "$PY_SCANNER" "$src" 30 2>&1)
        local avg=$(echo "$probe" | python3 -c "import sys,json;d=json.load(sys.stdin);print(int(d['avg_chars']))" 2>/dev/null || echo "0")
        if [ "$avg" -lt 30 ]; then
            count_pdf_scanned=$((count_pdf_scanned + 1))
            echo "[SCAN avg=$avg] $rel"
            # 2026-06-27 v5:改用 mineru-api 长跑(8002)+ vllm 长跑(8000)
            # mineru 跑 扫描 PDF 必走 /tasks 协议,只有 mineru-api/mineru-router 实现
            # 架构:
            #   mineru CLI → mineru-api :8002 (实现 FastAPI /tasks 协议)
            #                  ↓
            #                 vllm :8000 (OpenAI 协议,提供 VLM 模型)
            # CLI 参数:
            #   --api-url : mineru-api base URL (8002)
            #   -u/--url : OpenAI server URL (vllm 8000),通过 task body 传到 mineru-api
            local tmpdir=$(mktemp -d)
            # 2026-06-27 v6 修复 segfault:中文路径 + 老 PDF 内部 P:\4.0 Projects\...
            # 让 pdfium/ghostscript 在 ASCII 路径上跑;在 tmpdir 里建符号链接也行
            local safe_src="$tmpdir/input.pdf"
            if ! cp "$src" "$safe_src" 2>>"$LOG"; then
                echo "  ⚠️ cp to ascii tmp failed: $rel" >> "$LOG"
                rm -rf "$tmpdir"
                return
            fi
            # 2026-06-27 v8:切回 vlm-engine 本地 GPU(commit 6fe8a8e 成功路径)
            # vlm-http-client 需要 mineru-api+vllm 8000/8002 协同,显存争抢 → torch CUDA OOM → 子进程 exit=139
            # vlm-engine:mineru 自己加载模型直接 GPU 推理,无 HTTP 链路,显存只占一份
            # 需求:CUDA_HOME + HF_ENDPOINT(国内镜像)+ tmpdir (commit 6fe8a8e)
            # 缺:telemetry 关闭(commit 6fe8a8e 修过)
            if env UNSTRUCTURED_DISABLE_TELEMETRY=1 TMPDIR=/home/jack/tmp \
                CUDA_HOME=/usr/lib/nvidia-cuda-toolkit HF_ENDPOINT=https://hf-mirror.com \
                timeout 300 "$MN_ENV/mineru" -p "$safe_src" -o "$tmpdir" \
                -b vlm-engine \
                >> "$LOG" 2>&1; then
                local found=$(find "$tmpdir" -name "*.md" -type f 2>/dev/null | head -1)
                if [ -n "$found" ]; then
                    # 2026-06-27 改:把全部产物装 <base>.pdf/ 子目录(图纸截图/现场照片/layout PDF 等)
                    # 顶层 <base>.pdf.md 仍是 schema Gate 主入口
                    # <base>.pdf/ 子目录 = 完整资产,Obsidian 直接渲染
                    # md 引用 ./<base>.pdf/images/<hash>.jpg 相对路径
                    local src_dir=$(dirname "$found")
                    local asset_dir="$(dirname "$dst_file")/${base}"  # base = CW-A1-01.pdf
                    rm -rf "$asset_dir"  # 清掉旧的(重跑覆盖)
                    mkdir -p "$asset_dir"
                    # cp md + images/ + layout/origin pdf + content_list json 等
                    cp -r "$src_dir"/. "$asset_dir"/
                    # 顶层 dst_file 是 schema Gate 主入口;cp md + sed 改 images/ 引用路径
                    cp "$found" "$dst_file"
                    # 把 md 里的 images/<hash>.jpg 改成 ./<base>/images/<hash>.jpg
                    sed -i "s|images/|./${base}/images/|g" "$dst_file"
                    count_pdf_scanned_done=$((count_pdf_scanned_done + 1))
                else
                    echo "  ⚠️ mineru OK but no .md in $tmpdir: $rel" >> "$LOG"
                fi
            else
                echo "  ⚠️ mineru failed (exit=$?): $rel" >> "$LOG"
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
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            # 加 --norestore --nologo --nolockcheck + timeout 120s(2026-06-27 OOM 防护)
            if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to docx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local docx=$(find "$tmpdir" -name "*.docx" -type f 2>/dev/null | head -1)
                if [ -n "$docx" ]; then
                    if "$MD_ENV/markitdown" --keep-data-uris "$docx" > "$dst_file" 2>> "$LOG"; then
                        extract_md_images "$dst_file"
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
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        # 加 --norestore --nologo --nolockcheck 减少 LO 自身内存(2026-06-27)
        if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to pptx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
            local pptx=$(find "$tmpdir" -name "*.pptx" -type f 2>/dev/null | head -1)
            if [ -n "$pptx" ]; then
                if "$MD_ENV/markitdown" --keep-data-uris "$pptx" > "$dst_file" 2>> "$LOG"; then
                    extract_md_images "$dst_file"
                else
                    echo "  ⚠️ markitdown failed (.ppt→pptx): $rel" >> "$LOG"
                    count_md_fail=$((count_md_fail + 1))
                fi
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
        count_md=$((count_md + 1))
        local tmpdir=$(mktemp -d)
        local lo_ok=0
        for try in 1 2 3; do
            # 加 --norestore --nologo --nolockcheck + timeout 120s(2026-06-27 OOM 防护)
            if timeout 120 libreoffice --headless --norestore --nologo --nolockcheck --convert-to xlsx --outdir "$tmpdir" "$src" >> "$LOG" 2>&1; then
                local xlsx=$(find "$tmpdir" -name "*.xlsx" -type f 2>/dev/null | head -1)
                if [ -n "$xlsx" ] && "$MD_ENV/markitdown" --keep-data-uris "$xlsx" > "$dst_file" 2>> "$LOG"; then
                    extract_md_images "$dst_file"
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
        if "$MD_ENV/markitdown" --keep-data-uris "$src" > "$dst_file" 2>> "$LOG"; then
            extract_md_images "$dst_file"
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

    # v11 新增:后台任务队列 + pid 数组
    bg_queue=()
    bg_pids=()

    # v11 新增:启动后台 worker 函数(把任务加入队列,达到 MAX_PARALLEL 触发 wait)
    flush_bg_queue() {
        if [ ${#bg_queue[@]} -eq 0 ]; then return 0; fi
        # v11 bugfix:用 temp file 收集子 shell 的 count_total/count_skip 等更新
        # 子 shell 修改变量不影响主 shell,所以用 tmpfile 做 IPC
        local tmp_counts=$(mktemp)
        for q in "${bg_queue[@]}"; do
            (
                # 子 shell:跑 run_one,然后把本地的 count_total/count_skip/count_* 增量写 tmpfile
                local _before_total=$count_total
                local _before_skip=$count_skip
                local _before_skip_exists=$count_skip_exists
                local _before_pdf_text=$count_pdf_text
                local _before_pdf_scanned=$count_pdf_scanned
                local _before_pdf_scanned_done=$count_pdf_scanned_done
                local _before_md=$count_md
                local _before_md_fail=$count_md_fail
                local _before_txt=$count_txt
                run_one "$q" >> "$LOG" 2>&1
                local _delta=$((count_total - _before_total))
                local _dskip=$((count_skip - _before_skip))
                local _dskip_exists=$((count_skip_exists - _before_skip_exists))
                local _dpdf_text=$((count_pdf_text - _before_pdf_text))
                local _dpdf_scanned=$((count_pdf_scanned - _before_pdf_scanned))
                local _dpdf_scanned_done=$((count_pdf_scanned_done - _before_pdf_scanned_done))
                local _dmd=$((count_md - _before_md))
                local _dmd_fail=$((count_md_fail - _before_md_fail))
                local _dtxt=$((count_txt - _before_txt))
                echo "$_delta $_dskip $_dskip_exists $_dpdf_text $_dpdf_scanned $_dpdf_scanned_done $_dmd $_dmd_fail $_dtxt" >> "$tmp_counts"
            ) &
            bg_pids+=($!)
        done
        bg_queue=()
        # 等所有后台 worker 完成
        for pid in "${bg_pids[@]}"; do wait "$pid" 2>/dev/null; done
        bg_pids=()
        # 累加 tmpfile 里的 delta 到主 shell 计数
        while read -r _d _ds _dse _dpt _dps _dpsd _dm _dmf _dt; do
            count_total=$((count_total + _d))
            count_skip=$((count_skip + _ds))
            count_skip_exists=$((count_skip_exists + _dse))
            count_pdf_text=$((count_pdf_text + _dpt))
            count_pdf_scanned=$((count_pdf_scanned + _dps))
            count_pdf_scanned_done=$((count_pdf_scanned_done + _dpsd))
            count_md=$((count_md + _dm))
            count_md_fail=$((count_md_fail + _dmf))
            count_txt=$((count_txt + _dt))
        done < "$tmp_counts"
        rm -f "$tmp_counts"
    }

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
            pdf)
                # v11 新增:判断扫描 vs 非扫描,扫描同步跑(独占 GPU),非扫描并发
                local scan=$(is_scanned_quick "$src")
                if [ "$scan" = "1" ]; then
                    # 扫描 PDF:同步跑(独占 GPU)
                    # 收一波:当前 batch 后台 worker 满了就先 wait
                    if [ ${#bg_pids[@]} -ge $MAX_PARALLEL ]; then
                        for pid in "${bg_pids[@]}"; do wait "$pid" 2>/dev/null; done
                        bg_pids=()
                    fi
                    run_one "$src"
                else
                    # 非扫描 PDF:扔后台(并发)
                    bg_queue+=("$src")
                fi
                ;;
            docx|doc|xlsx|xls|pptx|ppt|txt|log)
                # v11 新增:非扫描文档扔后台(并发)
                bg_queue+=("$src")
                ;;
            *)
                count_skip=$((count_skip + 1))
                continue
                ;;
        esac

        # v11 新增:后台队列达到阈值就 flush
        if [ ${#bg_queue[@]} -ge $MAX_PARALLEL ]; then
            flush_bg_queue
        fi
    done < <(cd "$SRC" && find . -type f -not -path './@eaDir/*' 2>/dev/null | sed 's|^\./||')

    # v11 新增:文件末尾 flush 剩余后台任务
    flush_bg_queue

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