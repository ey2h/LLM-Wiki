#!/usr/bin/env bash
# scripts/parse_pdf.sh
# 用 MinerU vlm-engine 解析 PDF,走 GPU,产物输出到指定目录
#
# 用法:
#   parse_pdf.sh <input.pdf> [output_dir]
#   parse_pdf.sh /path/to/dir/  [output_dir]    # 批量
#
# 前置:
#   - MinerU venv 在 toolchain/envs/mineru/
#   - CUDA toolkit 装在 /usr/lib/nvidia-cuda-toolkit
#   - HF 模型已下到 ~/.cache/huggingface/
#   - GPU 显存 >= 12G(改 gpu_memory_utilization 可调)
#
# 必设的环境变量(本脚本会自己设):
#   CUDA_HOME=/usr/lib/nvidia-cuda-toolkit
#   HF_ENDPOINT=https://hf-mirror.com
#   gpu_memory_utilization=0.85(mineru 源码已改默认)

set -euo pipefail

# ============ 路径 ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
VENV="$ROOT/toolchain/envs/mineru"
PY="$VENV/bin/python"
MINERU_BIN="$VENV/bin/mineru"

# 校验 venv
if [ ! -x "$MINERU_BIN" ]; then
  echo "❌ 找不到 $MINERU_BIN,请先装 MinerU" >&2
  exit 1
fi

# ============ 环境变量 ============
# 1. CUDA toolkit(让 flashinfer 找到 nvcc)
export CUDA_HOME=/usr/lib/nvidia-cuda-toolkit
export PATH="$CUDA_HOME/bin:$PATH"

# 2. HF 镜像(国内下模型)
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_DOWNLOAD_TIMEOUT=120

# ============ 参数 ============
if [ $# -lt 1 ]; then
  cat <<'USAGE'
用法:
  parse_pdf.sh <input.pdf|dir> [output_dir]

示例:
  parse_pdf.sh kb-source/contract.pdf kb-md/contract/
  parse_pdf.sh kb-source/ kb-md/
USAGE
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.pdf}_mineru}"
OUTPUT="${OUTPUT%/}_mineru"

mkdir -p "$OUTPUT"
LOG="${OUTPUT}/parse.log"

# ============ 跑 MinerU ============
echo "=== MinerU VLM 解析 ===" | tee "$LOG"
echo "输入: $INPUT" | tee -a "$LOG"
echo "输出: $OUTPUT" | tee -a "$LOG"
echo "GPU:  $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo N/A)" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# 后台跑(避免 5 分钟超时),然后轮询
nohup "$MINERU_BIN" -p "$INPUT" -o "$OUTPUT" -b vlm-engine >> "$LOG" 2>&1 &
PID=$!
echo "mineru pid: $PID"
echo "日志: $LOG"
echo ""
echo "轮询进度(每 30 秒):"
echo "  tail -f $LOG"
echo "  ps -p $PID"
echo ""

# 轮询 20 分钟
for i in $(seq 1 40); do
  sleep 30
  if ps -p "$PID" > /dev/null 2>&1; then
    PCT=$(grep -oE "Two Step Extraction: +[0-9]+%" "$LOG" 2>/dev/null | tail -1 | grep -oE "[0-9]+%" || echo "...")
    GPU=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | tr -d ' ')
    echo "[$i/40] 还在跑 | 进度: $PCT | GPU: $GPU"
  else
    echo "[$i/40] ✅ 完成"
    break
  fi
done

if ps -p "$PID" > /dev/null 2>&1; then
  echo "⚠️  20 分钟还没跑完,可继续等: tail -f $LOG"
  exit 0
fi

# 报告结果
echo ""
echo "=== 产物 ==="
find "$OUTPUT" -type f -name "*.md" -o -name "*.json" -o -name "*.pdf" 2>/dev/null | head -20
echo ""
if grep -q "Completed batch" "$LOG"; then
  PAGES=$(grep -oE "Processed [0-9]+/[0-9]+ pages" "$LOG" | tail -1)
  echo "✅ 成功: $PAGES"
else
  echo "❌ 失败,看日志: $LOG"
  tail -20 "$LOG"
  exit 1
fi
