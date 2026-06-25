#!/bin/bash
# lo_retry_failed.sh — 全量转换跑完后,补跑 markitdown 失败的 .doc/.ppt/.DOC
# 用 LibreOffice headless 转 .doc→txt / .ppt→pptx→markitdown
set -e

NFS="/mnt/nfs"
SRC="$NFS/项目存档/2012"
DST="$NFS/LLM-WIKI/raw/2012"
LOG_DIR="/home/jack/projects/ai-rd-system/toolchain/logs"
LATEST_LOG=$(ls -t "$LOG_DIR"/convert_2012_full_*.log 2>/dev/null | head -1)
MD_ENV="/home/jack/projects/ai-rd-system/toolchain/envs/markitdown/bin"

[ -z "$LATEST_LOG" ] && { echo "❌ 没找到 convert log"; exit 1; }
echo "=== 用 log: $LATEST_LOG ==="
echo ""

# 抽 markitdown failed 的文件
FAILED=0
FIXED=0
STILL_FAIL=0

while IFS= read -r line; do
    # 匹配 "⚠️ markitdown failed: <rel>"
    rel=$(echo "$line" | sed -nE 's/.*markitdown failed:[[:space:]]+(.*)/\1/p')
    [ -z "$rel" ] && continue
    src="$SRC/$rel"
    [ -f "$src" ] || { echo "⚠️ src 不存在: $rel"; continue; }

    ext_lower="$(echo "${src##*.}" | tr '[:upper:]' '[:lower:]')"
    case "$ext_lower" in
        doc)
            out="$DST/${rel}.doc.md"
            tmpdir=$(mktemp -d)
            echo "[$(date '+%H:%M:%S')] LO: $rel"
            if libreoffice --headless --convert-to txt --outdir "$tmpdir" "$src" >/dev/null 2>&1; then
                txt=$(find "$tmpdir" -name "*.txt" -type f 2>/dev/null | head -1)
                if [ -n "$txt" ] && [ -s "$txt" ]; then
                    cp "$txt" "$out"
                    FIXED=$((FIXED + 1))
                    echo "  ✅ $(stat -c%s "$out") B"
                else
                    STILL_FAIL=$((STILL_FAIL + 1))
                    echo "  ❌ 空"
                fi
            else
                STILL_FAIL=$((STILL_FAIL + 1))
                echo "  ❌ LO 失败"
            fi
            rm -rf "$tmpdir"
            ;;
        ppt)
            out="$DST/${rel}.ppt.md"
            tmpdir=$(mktemp -d)
            echo "[$(date '+%H:%M:%S')] LO: $rel"
            if libreoffice --headless --convert-to pptx --outdir "$tmpdir" "$src" >/dev/null 2>&1; then
                pptx=$(find "$tmpdir" -name "*.pptx" -type f 2>/dev/null | head -1)
                if [ -n "$pptx" ]; then
                    if "$MD_ENV/markitdown" "$pptx" > "$out" 2>/dev/null; then
                        FIXED=$((FIXED + 1))
                        echo "  ✅ $(stat -c%s "$out") B"
                    else
                        STILL_FAIL=$((STILL_FAIL + 1))
                        echo "  ❌ markitdown 失败"
                    fi
                else
                    STILL_FAIL=$((STILL_FAIL + 1))
                    echo "  ❌ 空"
                fi
            else
                STILL_FAIL=$((STILL_FAIL + 1))
                echo "  ❌ LO 失败"
            fi
            rm -rf "$tmpdir"
            ;;
    esac
    FAILED=$((FAILED + 1))
done < <(grep "markitdown failed" "$LATEST_LOG")

echo ""
echo "=== Retry 完成 ==="
echo "扫描:  $FAILED"
echo "修复:  $FIXED"
echo "仍败: $STILL_FAIL"
