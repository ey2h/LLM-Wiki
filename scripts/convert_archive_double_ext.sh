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
set -o pipefail  # v11.5:不用 -e (允许 trap 内 nvidia-smi/dmesg 失败),不用 -u (LOG 未定义会触发)

# 2026-06-28 v11.5:加 EXIT trap 记 daemon 死因到 log + 杀所有子进程
# 之前 daemon 被 hermes-gateway systemd 重启连带 SIGKILL,只看到进程没了,不知道死因
# trap 会在以下信号时触发,记日志到 logs/convert/daemon_exit_<timestamp>.log:
#   EXIT (正常退出) / SIGTERM (15) / SIGINT (2) / SIGHUP (1)
# 报告内容:信号 + 退出码 + 当前目录 + 累计运行时间 + 死前最后处理的 10 个文件 +
#           子进程列表 + GPU 状态 + 内存状态 + dmesg OOM 痕迹 + hermes-gateway systemd 状态
cleanup_daemon() {
    local exit_code=$?
    local signal=${1:-EXIT}
    local logfile="/home/jack/LLM-Wiki/logs/convert/daemon_exit_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== Daemon Exit Report ==="
        echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "信号: $signal"
        echo "退出码: $exit_code"
        echo "当前目录: $(pwd)"
        echo "Daemon 累计运行: $(ps -o etime= -p $$ 2>/dev/null || echo 'N/A')"
        echo ""
        echo "=== 死前最后处理的 10 个文件 ==="
        # 找最近修改的 toolchain log 文件(LOG 变量在 convert_year 内部,trap 内不可见)
        local _last_toolchain_log
        _last_toolchain_log=$(ls -t /home/jack/projects/ai-rd-system/toolchain/logs/convert_*_double_ext_*.log 2>/dev/null | head -1)
        if [ -n "$_last_toolchain_log" ] && [ -f "$_last_toolchain_log" ]; then
            grep -E '\[(SCAN|MD|PDF|TXT) (OK|FAIL)' "$_last_toolchain_log" 2>/dev/null | tail -10 || echo "(toolchain log 无匹配)"
        else
            echo "(找不到 toolchain log,daemon 启动阶段就死)"
        fi
        echo ""
        echo "=== 子进程 (应该被 cleanup 杀掉) ==="
        ps -eo pid,ppid,pcpu,pmem,rss,cmd --forest 2>/dev/null | grep -B1 -A1 "convert_archive_double_ext" | head -20 || echo "(无子进程)"
        echo ""
        echo "=== 当前 GPU 状态 ==="
        nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv 2>/dev/null || echo "(nvidia-smi 失败)"
        echo ""
        echo "=== 内存 ==="
        free -h | head -2
        echo ""
        echo "=== OOM 痕迹 (dmesg 最近 10 分钟) ==="
        dmesg --since "10 min ago" 2>/dev/null | grep -iE "oom|killed" | tail -10 || echo "(dmesg 无权限或无 OOM)"
        echo ""
        echo "=== systemd hermes-gateway 状态 ==="
        systemctl --user status hermes-gateway.service 2>&1 | head -25 || echo "(systemctl 失败)"
    } > "$logfile" 2>&1
    # 杀所有子进程(mineru/markitdown/libreoffice)
    pkill -P $$ 2>/dev/null
    pkill -f "mineru --keep-data-uris" 2>/dev/null
    pkill -f "markitdown --keep-data-uris" 2>/dev/null
    pkill -f "libreoffice --headless" 2>/dev/null
}
trap 'cleanup_daemon EXIT' EXIT
trap 'cleanup_daemon SIGTERM; exit 143' TERM
trap 'cleanup_daemon SIGINT; exit 130' INT
trap 'cleanup_daemon SIGHUP; exit 129' HUP

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
#
# 2026-06-27 v11.4:MAX_PARALLEL 默认 0 → 2 (改回并发,接受偶尔被 hermes-gateway 重启杀)
# 原因:v11.3 (MAX_PARALLEL=0) 单线程太慢,2012 跑了 8 分钟只处理 1 个文件
# 实际原因不是 OOM/过热,是 hermes-gateway systemd 重启(00:25)时 kill background daemon
# 改回 MAX_PARALLEL=2:
#   - 接受偶尔 daemon 被 hermes 重启连带 SIGKILL(daemon 启动会自动 resume skip_exists)
#   - 后台 markitdown × 2 + 扫描 PDF 同步 → 整体吞吐 ×2-3
#   - 内存峰值 8-10G,需要 12G+ available 留 5G buffer
# 备用方案:用 systemd user service 跑 daemon 脱离 hermes-gateway 控制(待定)
MAX_PARALLEL="${MAX_PARALLEL:-4}"          # v11.7: 2 → 4 (内存 30G,放宽并发;hermes-gateway 杀频率下降)
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
    local result_tag=""  # v11.1:成功/失败标记,主进程 stdout 可见

    if [ "$ext_lower" = "pdf" ]; then
        # PDF CAD 图纸跳过(2026-06-27 + 2026-06-28 扩展)
        # v11.6 新增: 路径含 /cad/ (大小写不敏感) + 文件名 [大写][大写][数字]+ 命名模式 (PD/PE/PG/...图号)
        # 命名模式:
        #   - S-XX-XX-XX.pdf (结构图)
        #   - S-XX-L9-XX.pdf
        #   - CW-AXX-NN.pdf (幕墙图 Curtain Wall)
        #   - [A-Z][A-Z][0-9]+(-[0-9]+)?.pdf (CAD 图号,如 PD610/PE030/PD300-1)
        # 注: 没要求 P 开头, 大写字母 + 大写字母 + 数字 就够 (避免 PZW123.pdf 这种误伤)
        local base_no_ext="${base%.pdf}"
        if echo "$base_no_ext" | grep -qE '^(S(-[A-Za-z0-9]+){2,}|CW-[A-Za-z0-9]+-[0-9]+|[A-Z][A-Z][0-9]+(-[0-9]+)?)'; then
            count_skip=$((count_skip + 1))
            echo "  [SKIP-CAD-PDF] $rel" >> "$LOG"
            return
        fi
        # v11.6 新增: 路径含 /cad/ (大小写不敏感) 也算 CAD 图纸
        if echo "$src" | grep -qiE '/cad/'; then
            count_skip=$((count_skip + 1))
            echo "  [SKIP-CAD-PDF path] $rel" >> "$LOG"
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
                    echo "[SCAN OK] $rel"  # v11.1:成功标记(stdout,主进程可见)
                    result_tag="[SCAN OK]"
                else
                    echo "  ⚠️ mineru OK but no .md in $tmpdir: $rel" >> "$LOG"
                    echo "[SCAN FAIL no-md] $rel"  # v11.1:失败标记
                    result_tag="[SCAN FAIL]"
                fi
            else
                local _exit=$?
                echo "  ⚠️ mineru failed (exit=$_exit): $rel" >> "$LOG"
                echo "[SCAN FAIL exit=$_exit] $rel"  # v11.1:失败标记
                result_tag="[SCAN FAIL]"
            fi
            rm -rf "$tmpdir"
        else
            count_pdf_text=$((count_pdf_text + 1))
            if pdftotext -layout "$src" "$dst_file" 2>> "$LOG"; then
                result_tag="[PDF OK]"
            else
                echo "  ⚠️ pdftotext failed: $rel" >> "$LOG"
                result_tag="[PDF FAIL]"
            fi
        fi
    elif [ "$ext_lower" = "txt" ] || [ "$ext_lower" = "log" ]; then
        cp "$src" "$dst_file"
        count_txt=$((count_txt + 1))
        result_tag="[TXT OK]"
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
                        result_tag="[MD OK .doc]"
                        break
                    fi
                fi
            fi
            sleep 2
        done
        if [ $lo_ok -eq 0 ]; then
            echo "  ⚠️ LO→docx→md 失败 (重试3次): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            result_tag="[MD FAIL .doc]"
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
                    result_tag="[MD OK .ppt]"
                else
                    echo "  ⚠️ markitdown failed (.ppt→pptx): $rel" >> "$LOG"
                    count_md_fail=$((count_md_fail + 1))
                    result_tag="[MD FAIL .ppt]"
                fi
            else
                echo "  ⚠️ lo→pptx empty: $rel" >> "$LOG"
                count_md_fail=$((count_md_fail + 1))
                result_tag="[MD FAIL .ppt no-pptx]"
            fi
        else
            echo "  ⚠️ lo failed (.ppt): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            result_tag="[MD FAIL .ppt lo]"
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
                    result_tag="[MD OK .xls]"
                    break
                fi
            fi
            sleep 2
        done
        if [ $lo_ok -eq 0 ]; then
            echo "  ⚠️ LO→xlsx→md 失败 (重试3次): $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            result_tag="[MD FAIL .xls]"
        fi
        rm -rf "$tmpdir"
    else
        count_md=$((count_md + 1))
        if "$MD_ENV/markitdown" --keep-data-uris "$src" > "$dst_file" 2>> "$LOG"; then
            extract_md_images "$dst_file"
            result_tag="[MD OK .$ext_lower]"
        else
            echo "  ⚠️ markitdown failed: $rel" >> "$LOG"
            count_md_fail=$((count_md_fail + 1))
            result_tag="[MD FAIL .$ext_lower]"
        fi
    fi

    local end=$(date +%s)
    local sz=$(stat -c%s "$dst_file" 2>/dev/null || echo "0")
    # v11.1:末尾行加 result_tag(成功/失败标记,主进程 stdout 可见,grep -E '\[(SCAN|MD|PDF|TXT) (OK|FAIL)' 可过滤)
    [ -z "$result_tag" ] && result_tag="[SKIP]"
    echo "${result_tag} [$rel]($((end-start))s ${sz}B)"

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

    # v11.6 预先 markitdown 队列:
    # 把 find 输出 tee 到 named pipe,主循环 read + 后台并行预读 office/text 文件塞 bg_queue
    # 这样即使 main loop 在同步跑扫描 PDF,markitdown worker 已经在跑(空闲时间不浪费)
    #
    # 策略:
    #   1. find 输出 → fifo
    #   2. main loop 从 fifo read 处理 (扫描 PDF 同步,其他塞 bg_queue)
    #   3. 后台 "prefill" 任务**主动**从 fifo 后续 read office/text,**预先**塞 bg_queue
    #
    # 但 fifo 单 reader 限制,所以方案简化:
    #   - 主循环一次 read 1 个处理
    #   - 主循环在每行处理**前**,如果 bg_queue 未满,**主动 peek 后续 N 个 office/text 文件**
    #   - 用文件描述符复制 (exec 3< <(find)) 保存可重读的副本
    #
    # 实施难点:bash 进程替换只能 read 一次。
    # 最稳的方案: 把 find 输出全部写到 /tmp/.files_${y}.list,主循环一次 read 1 个处理,
    # 处理每个文件时,检查 bg_queue 长度,如果 < MAX_PARALLEL,**主动从 list 里 prefill**
    #
    # v11.6 实现: 启动时一次性写出 /tmp/.files_${y}.list + 同时初始化 bg_queue 预先填充 office/text
    local files_list="/tmp/.files_${y}.list"
    # v11.7: 按扩展名排序 — .docx/.xlsx/.pptx/.txt/.log 先跑 (markitdown 快,几秒),
    #        .pdf 后跑 (mineru VLM 慢,1-3 分钟)。
    # 原理:提取 basename 扩展名,office/text (0) 排前,pdf (1) 排后,其他 (2) 末尾。
    # sort key: "<ext_priority>|<original_path>" 保证同优先级的保留 find inode 顺序。
    (cd "$SRC" && find . -type f -not -path './@eaDir/*' 2>/dev/null | sed 's|^\./||' \
       | awk -F. '{
           ext=tolower($NF);
           pri=2;
           if (ext=="docx"||ext=="doc"||ext=="xlsx"||ext=="xls"||ext=="pptx"||ext=="ppt"||ext=="txt"||ext=="log"||ext=="csv"||ext=="md"||ext=="rtf"||ext=="odt"||ext=="ods"||ext=="odp") pri=0;
           else if (ext=="pdf") pri=1;
           printf "%d|%s\n", pri, $0;
         }' \
       | sort -t'|' -k1,1n -k2 \
       | cut -d'|' -f2) > "$files_list"
    local total_files=$(wc -l < "$files_list")
    echo "[v11.6] 预扫描文件清单: $total_files 个 → $files_list"

    # v11.6 预先 markitdown 队列:
    # 在主循环开始前,主动把所有 office/text 文件**预先**塞进 bg_queue
    # 这样 main loop 处理扫描 PDF 同步跑时,bg_queue 已经满了,markitdown worker 自动启动
    #
    # 优化:不全部预塞(可能 OOM),而是**预留 MAX_PARALLEL** 个空位给主循环新文件,
    # 预先塞 (MAX_PARALLEL * 2) 个 office/text 文件
    local _prefill_count=0
    local _prefill_max=$MAX_PARALLEL  # v11.6 fix: 只塞 MAX_PARALLEL 个,避免一次启 8 worker OOM
    while IFS= read -r rel; do
        [ -z "$rel" ] && continue
        case "$rel" in
            @eaDir/*|.DS_Store) continue ;;
        esac
        src="$SRC/$rel"
        [ -f "$src" ] || continue
        case "$(basename "$src")" in
            ~\$*) continue ;;
        esac
        base=$(basename "$src")
        ext_lower="$(echo "${base##*.}" | tr '[:upper:]' '[:lower:]')"
        # 只预填 office/text 和非扫描 PDF (但扫描判断要 call python,先不预填非扫描 PDF)
        case "$ext_lower" in
            docx|doc|xlsx|xls|pptx|ppt|txt|log)
                # 检查是否已存在 (skip_exists)
                # v11.6 fix: 正确命名规则是 ${rel}.md (rel 已经包含 .docx 等扩展)
                # 例: 工作进度确认及满足汇报要求.docx → 工作进度确认及满足汇报要求.docx.md
                local dst_check="$DST/$rel.md"
                # txt/log 例外: foo.txt → foo.txt.md (rel 已经是 .txt 了)
                case "$ext_lower" in
                    txt|log) dst_check="$DST/$rel.md" ;;  # rel=foo.txt, dst=foo.txt.md (不变)
                    *) dst_check="$DST/$rel.md" ;;  # rel=xx.docx, dst=xx.docx.md
                esac
                [ -f "$dst_check" ] && continue
                bg_queue+=("$src")
                _prefill_count=$((_prefill_count + 1))
                [ $_prefill_count -ge $_prefill_max ] && break
                ;;
        esac
    done < "$files_list"
    echo "[v11.6] 预先 markitdown 队列: $_prefill_count 个 office/text 文件已塞入 bg_queue"
    # v11.6: bg_queue 已经预填,主循环处理扫描 PDF 时 markitdown worker 自动启动
    # 立即 flush 让 worker 起来 (不等 main loop 处理)
    if [ $_prefill_count -gt 0 ]; then
        echo "[v11.6] 立即 flush_bg_queue 启动 $_prefill_count 个 markitdown worker"
        flush_bg_queue
    fi

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
                # v11 新增:判断扫描 vs 非扫描
                # 扫描 PDF 同步跑(独占 GPU,不能并发),期间 markitdown 后台 worker 继续跑(只用 CPU)
                # 非扫描 PDF → 扔后台(并发)
                local scan=$(is_scanned_quick "$src")
                if [ "$scan" = "1" ]; then
                    # 扫描 PDF:同步跑(独占 GPU,不等后台 worker — 后台用 CPU 不冲突)
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

        # v11 新增:后台队列达到阈值就 flush(只等后台,不等扫描 PDF)
        if [ ${#bg_queue[@]} -ge $MAX_PARALLEL ]; then
            flush_bg_queue
        fi
    done < "$files_list"

    # v11.6: 清理 tmp files_list
    rm -f "$files_list"

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
# 解析参数:支持 <year> [<year_end>] [--dry-run]
#   <year>:       单年 (e.g. 2026)
#   <y1> <y2>:    范围 (e.g. 2012 2025 → 跑 2012,2013,...,2025)
#   all:          跑 2013-2026(2012 走 convert_year_2012.sh 旧路径)
#   --dry-run:    演练
YEAR_START=""
YEAR_END=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        all) YEAR_START="all" ;;
        *)
            if [ -z "$YEAR_START" ]; then
                YEAR_START="$arg"
            elif [ -z "$YEAR_END" ]; then
                YEAR_END="$arg"
            fi
            ;;
    esac
done

# 范围模式 vs 单年/all
if [ "$YEAR_START" = "all" ]; then
    # all 模式:跑 2013-2026(2012 之前已用 convert_year_2012.sh 转完,不在此覆盖)
    for y in 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025 2026; do
        convert_year "$y"
        echo ""
        echo "==============================================="
        echo ""
    done
elif [ -n "$YEAR_END" ] && [ "$YEAR_START" != "$YEAR_END" ]; then
    # 范围模式:2012 2025 → 2012..2025
    echo "=== 范围模式: $YEAR_START..$YEAR_END ==="
    for y in $(seq "$YEAR_START" "$YEAR_END"); do
        convert_year "$y"
        echo ""
        echo "==============================================="
        echo ""
    done
elif [ -n "$YEAR_START" ]; then
    # 单年模式
    convert_year "$YEAR_START"
else
    echo "用法: $0 <year> [<year_end>] [--dry-run]"
    echo "  <year>:       单年 (e.g. 2026)"
    echo "  <y1> <y2>:    范围 (e.g. 2012 2025 → 跑 2012..2025)"
    echo "  all:          跑 2013-2026"
    echo "  --dry-run:    演练(不写文件)"
    exit 1
fi