#!/bin/bash
# convert_batch_daemon.sh — 按年跑单文件 + 压缩包摘要的 daemon
#
# 设计:
#   - 每年跑 2 个动作:convert_archive_double_ext.sh(单文件) + convert_archives_to_summaries.sh(压缩包)
#   - 跑完 1 年 → 写一行 daemon_progress.log(year + 成功/失败/跳过统计)
#   - 失败不致命:某年挂了,下年继续(daemon 自身不挂)
#   - 可中断可恢复:重跑 daemon 从中断年份继续(脚本幂等,已转跳过)
#
# 关键修复(2026-06-27):对齐 18a2561 跑成功的环境变量 + 不再用 pipe | tee
#   - pipe 让 mineru 的子进程 vllm 在 pipe 异常时 segfault
#   - 用 > $LOG_FILE 2>&1 重定向到文件,不走 pipe
#
# 用法:
#   bash convert_batch_daemon.sh             # 跑 2013-2026
#   bash convert_batch_daemon.sh 2014 2020   # 跑 2014-2020
#   bash convert_batch_daemon.sh --dry-run   # 演练
#
set -e

# 2026-06-27 关键修复:对齐 18a2561 成功路径的环境变量
# 不设这些,mineru 跑 PDF 时 flashinfer 找不到 nvcc → segfault
export CUDA_HOME=/usr/lib/nvidia-cuda-toolkit
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_DOWNLOAD_TIMEOUT=120
export PATH="$CUDA_HOME/bin:$PATH"

LLM_WIKI="/home/jack/LLM-Wiki"
LOG_DIR="$LLM_WIKI/logs/convert"
DAEMON_LOG="$LOG_DIR/daemon_progress.log"
PROGRESS_LOG="$LOG_DIR/daemon_status.log"  # daemon 实时状态(谁都能 tail)
CONVERT_SINGLE="$LLM_WIKI/scripts/convert_archive_double_ext.sh"
CONVERT_ARCHIVE="$LLM_WIKI/scripts/convert_archives_to_summaries.sh"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
    shift
fi

START_YEAR="${1:-2013}"
END_YEAR="${2:-2026}"

mkdir -p "$LOG_DIR"

# daemon 启动 banner
{
    echo "================================================"
    echo "DAEMON 启动: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "PID=$$"
    echo "范围: $START_YEAR ~ $END_YEAR"
    echo "DRY_RUN=$DRY_RUN"
    echo "================================================"
} >> "$PROGRESS_LOG"

# 跑单年
run_year() {
    local y="$1"
    {
        echo ""
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 跑 $y:"
    } >> "$PROGRESS_LOG"

    if [ $DRY_RUN -eq 1 ]; then
        {
            echo "  [DRY] 单文件: bash $CONVERT_SINGLE $y --dry-run"
            echo "  [DRY] 压缩包: bash $CONVERT_ARCHIVE $y --dry-run"
        } >> "$PROGRESS_LOG"
        return
    fi

    # 1. 单文件转换 — 关键:不用 pipe | tee(会让 mineru 启的 vllm segfault)
    # 重定向到独立 log 文件,18a2561 跑成功的 convert_year_2012.sh 用的就是这个方式
    local single_log="$LOG_DIR/${y}_single_$(date +%Y%m%d_%H%M%S).log"
    echo "  [单文件] bash $CONVERT_SINGLE $y (log=$single_log)" >> "$PROGRESS_LOG"
    if bash "$CONVERT_SINGLE" "$y" > "$single_log" 2>&1; then
        echo "  [单文件] $y 完成" >> "$PROGRESS_LOG"
    else
        echo "  [单文件] $y 失败(继续下年) — 看 $single_log" >> "$PROGRESS_LOG"
    fi

    # 2. 压缩包摘要 — 同样不用 pipe
    local archive_log="$LOG_DIR/${y}_archive_$(date +%Y%m%d_%H%M%S).log"
    echo "  [压缩包] bash $CONVERT_ARCHIVE $y (log=$archive_log)" >> "$PROGRESS_LOG"
    if bash "$CONVERT_ARCHIVE" "$y" > "$archive_log" 2>&1; then
        echo "  [压缩包] $y 完成" >> "$PROGRESS_LOG"
    else
        echo "  [压缩包] $y 失败(继续下年) — 看 $archive_log" >> "$PROGRESS_LOG"
    fi

    # 3. 跑完 1 年 → 写进度日志
    local year_md_count=$(ls "$LLM_WIKI/kb/sources/$y/" 2>/dev/null | wc -l)
    echo "$y: $(date '+%Y-%m-%d %H:%M:%S') - $year_md_count 个 .md(累计)" >> "$DAEMON_LOG"
    echo "  [进度] $y 累计: $year_md_count 个 .md" >> "$PROGRESS_LOG"
}

# 主循环
for ((y=START_YEAR; y<=END_YEAR; y++)); do
    run_year "$y"
done

{
    echo ""
    echo "================================================"
    echo "DAEMON 结束: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "总进度见 $DAEMON_LOG"
    echo "================================================"
} >> "$PROGRESS_LOG"