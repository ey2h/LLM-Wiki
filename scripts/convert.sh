#!/usr/bin/env bash
# ============================================================
# convert.sh — 一键批量转换文档到 markdown
#
# 调度策略:
#   .docx .pptx .xlsx  → markitdown
#   .pdf(纯文本)        → markitdown
#   .pdf(扫描件/复杂)   → MinerU(GPU)
#   .jpg .png(图带字)  → MinerU OCR
#   .html .txt .md     → 直接复制
#
# 用法:
#   bash convert.sh <input_dir> [<output_dir>]
#   bash convert.sh --dry-run <input_dir>
#
# 默认: input_dir=kb-source/   output_dir=kb-md/
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"
LOG_DIR="$TOOLCHAIN_DIR/logs"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

INPUT_DIR="${1:-$PROJECT_ROOT/kb-source}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/kb-md}"

# 路径转绝对
INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/convert_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "============================================================"
log "📂 输入目录: $INPUT_DIR"
log "📂 输出目录: $OUTPUT_DIR"
log "📝 日志文件: $LOG_FILE"
log "============================================================"

if [ ! -d "$INPUT_DIR" ]; then
    log "❌ 输入目录不存在: $INPUT_DIR"
    exit 1
fi

# 计数
declare -A STATS=( [markitdown]=0 [mineru]=0 [copy]=0 [skip]=0 [fail]=0 )

# 决定处理方式
route_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")

    case "$ext" in
        docx|pptx|xlsx|html|htm|epub|txt|md|rtf)
            echo "markitdown"
            ;;
        pdf)
            # 默认全走 MinerU VLM(GPU,精度 95.39,版面还原)
            # 想省时间可改成:小文件走 markitdown(纯文本 PDF)
            echo "mineru"
            ;;
        jpg|jpeg|png|bmp|tiff|webp)
            echo "mineru"
            ;;
        doc|ppt|xls)
            # 旧版 Office 格式
            echo "skip"
            ;;
        *)
            echo "skip"
            ;;
    esac
}

# 环境检查
check_env() {
    local env_name="$1"
    if [ -f "$TOOLCHAIN_DIR/envs/$env_name/bin/activate" ]; then
        return 0
    fi
    return 1
}

if ! check_env markitdown; then
    log "⚠️  markitdown 环境未安装,需要先跑:"
    log "   bash $TOOLCHAIN_DIR/setup_env.sh markitdown"
fi

if ! check_env mineru; then
    log "⚠️  mineru 环境未安装,需要先跑:"
    log "   bash $TOOLCHAIN_DIR/setup_env.sh mineru"
fi

# 遍历文件
processed=0
total=0
while IFS= read -r -d '' file; do
    total=$((total + 1))
    rel="${file#$INPUT_DIR/}"
    out_name="${rel%.*}.md"
    out_path="$OUTPUT_DIR/$out_name"

    route=$(route_file "$file")
    STATS[$route]=$(( ${STATS[$route]:-0} + 1 ))

    log "🔄 [$route] $rel"

    if $DRY_RUN; then
        continue
    fi

    mkdir -p "$(dirname "$out_path")"

    case "$route" in
        markitdown)
            if check_env markitdown; then
                # shellcheck disable=SC1091
                source "$TOOLCHAIN_DIR/env.sh" markitdown >/dev/null 2>&1
                if markitdown "$file" > "$out_path" 2>>"$LOG_FILE"; then
                    processed=$((processed + 1))
                else
                    log "   ❌ 失败: $rel"
                    STATS[fail]=$(( ${STATS[fail]:-0} + 1 ))
                fi
            else
                log "   ⏭️  跳过(环境未装): $rel"
                STATS[skip]=$(( ${STATS[skip]:-0} + 1 ))
            fi
            ;;

        mineru)
            if check_env mineru; then
                # shellcheck disable=SC1091
                source "$TOOLCHAIN_DIR/env.sh" mineru >/dev/null 2>&1
                # 调封装好的 parse_pdf.sh(已设好 CUDA_HOME + HF 镜像 + gpu_mem)
                local_out_dir="${out_path%.md}_mineru"
                if bash "$SCRIPT_DIR/parse_pdf.sh" "$file" "$(dirname "$out_path")" >>"$LOG_FILE" 2>&1; then
                    processed=$((processed + 1))
                else
                    log "   ❌ 失败: $rel"
                    STATS[fail]=$(( ${STATS[fail]:-0} + 1 ))
                fi
            else
                log "   ⏭️  跳过(环境未装): $rel"
                STATS[skip]=$(( ${STATS[skip]:-0} + 1 ))
            fi
            ;;

        copy)
            cp "$file" "$out_path"
            processed=$((processed + 1))
            ;;

        skip)
            log "   ⏭️  不支持的格式: $rel"
            ;;
    esac
done < <(find "$INPUT_DIR" -type f -print0 | sort -z)

log "============================================================"
log "📊 统计: 总 $total 个文件"
log "   markitdown: ${STATS[markitdown]}"
log "   mineru:     ${STATS[mineru]}"
log "   copy:       ${STATS[copy]}"
log "   skip:       ${STATS[skip]}"
log "   fail:       ${STATS[fail]:-0}"
if ! $DRY_RUN; then
    log "   ✅ 成功处理: $processed"
fi
log "============================================================"
