#!/bin/bash
# rename_no_double_ext.sh — 把 LLM-WIKI/raw/<year>/ 下所有 *.X.md 重命名为 *.md
# 例: RFI.pdf.md → RFI.md (去掉重复的 .pdf 后缀)
# 用法: bash scripts/rename_no_double_ext.sh [year]
set -e

YEAR="${1:-2012}"
NFS="/mnt/nfs"
DST="$NFS/LLM-WIKI/raw/$YEAR"

[ -d "$DST" ] || { echo "❌ $DST 不存在"; exit 1; }

echo "=== 迁移 $DST ==="
echo ""

RENAMED=0
SKIPPED=0
COLLISION=0

# 找所有 .X.md 文件(排除普通 .md)
find "$DST" -type f -name "*.md" 2>/dev/null | while read -r f; do
    # 只处理 "扩展名.md" 形式(eg .pdf.md, .docx.md, .xlsx.md)
    base="$(basename "$f")"
    # 检查倒数第二个扩展
    # RFI.pdf.md → base=RFI.pdf.md, last_ext=.md, second_last=.pdf
    case "$base" in
        *.*.md)
            # 双重扩展,需要重命名
            new_base="${base%.*}"      # RFI.pdf
            new_base="${new_base%.*}"   # RFI
            new_f="$(dirname "$f")/$new_base.md"
            if [ -f "$new_f" ] && [ "$f" != "$new_f" ]; then
                echo "  ⚠️ 冲突(已存在): $f → $new_f"
                COLLISION=$((COLLISION + 1))
            else
                mv "$f" "$new_f"
                echo "  ✅ $base → $new_base.md"
                RENAMED=$((RENAMED + 1))
            fi
            ;;
        *)
            SKIPPED=$((SKIPPED + 1))
            ;;
    esac
done

echo ""
echo "=== 完成 ==="
echo "重命名: $RENAMED"
echo "跳过(纯 .md): $SKIPPED"
echo "冲突: $COLLISION"
