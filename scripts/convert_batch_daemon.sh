#!/bin/bash
# convert_batch_daemon.sh — 按年跑单文件 + 压缩包摘要的 daemon
#
# 设计:
#   - 每年跑 2 个动作:convert_archive_double_ext.sh(单文件) + convert_archives_to_summaries.sh(压缩包)
#   - 跑完 1 年 → 写一行 daemon_progress.log(year + 成功/失败/跳过统计)
#   - 失败不致命:某年挂了,下年继续(daemon 自身不挂)
#   - 可中断可恢复:重跑 daemon 从中断年份继续(脚本幂等,已转跳过)
#
# 用法:
#   bash convert_batch_daemon.sh             # 跑 2013-2026
#   bash convert_batch_daemon.sh 2014 2020   # 跑 2014-2020
#   bash convert_batch_daemon.sh --dry-run   # 演练
#
set -e

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
echo "================================================" | tee -a "$PROGRESS_LOG"
echo "DAEMON 启动: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$PROGRESS_LOG"
echo "PID=$$" | tee -a "$PROGRESS_LOG"
echo "范围: $START_YEAR ~ $END_YEAR" | tee -a "$PROGRESS_LOG"
echo "DRY_RUN=$DRY_RUN" | tee -a "$PROGRESS_LOG"
echo "================================================" | tee -a "$PROGRESS_LOG"

# 跑单年
run_year() {
    local y="$1"
    echo "" | tee -a "$PROGRESS_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 跑 $y:" | tee -a "$PROGRESS_LOG"

    if [ $DRY_RUN -eq 1 ]; then
        echo "  [DRY] 单文件: bash $CONVERT_SINGLE $y --dry-run" | tee -a "$PROGRESS_LOG"
        echo "  [DRY] 压缩包: bash $CONVERT_ARCHIVE $y --dry-run" | tee -a "$PROGRESS_LOG"
        return
    fi

    # 1. 单文件转换
    echo "  [单文件] bash $CONVERT_SINGLE $y ..." | tee -a "$PROGRESS_LOG"
    if bash "$CONVERT_SINGLE" "$y" 2>&1 | tee -a "$PROGRESS_LOG"; then
        echo "  [单文件] $y 完成" | tee -a "$PROGRESS_LOG"
    else
        echo "  [单文件] $y 失败(继续下年)" | tee -a "$PROGRESS_LOG"
    fi

    # 2. 压缩包摘要
    echo "  [压缩包] bash $CONVERT_ARCHIVE $y ..." | tee -a "$PROGRESS_LOG"
    if bash "$CONVERT_ARCHIVE" "$y" 2>&1 | tee -a "$PROGRESS_LOG"; then
        echo "  [压缩包] $y 完成" | tee -a "$PROGRESS_LOG"
    else
        echo "  [压缩包] $y 失败(继续下年)" | tee -a "$PROGRESS_LOG"
    fi

    # 3. 跑完 1 年 → 写进度日志
    local year_md_count=$(ls "$LLM_WIKI/kb/sources/$y/" 2>/dev/null | wc -l)
    echo "$y: $(date '+%Y-%m-%d %H:%M:%S') - $year_md_count 个 .md(累计)" >> "$DAEMON_LOG"
    echo "  [进度] $y 累计: $year_md_count 个 .md" | tee -a "$PROGRESS_LOG"
}

# 主循环
for ((y=START_YEAR; y<=END_YEAR; y++)); do
    run_year "$y"
done

echo "" | tee -a "$PROGRESS_LOG"
echo "================================================" | tee -a "$PROGRESS_LOG"
echo "DAEMON 结束: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$PROGRESS_LOG"
echo "总进度见 $DAEMON_LOG" | tee -a "$PROGRESS_LOG"
echo "================================================" | tee -a "$PROGRESS_LOG"
