#!/usr/bin/env bash
# ============================================================
# setup_env.sh — 创建/重建项目内的 Python 虚拟环境
# 用法: bash ~/projects/ai-rd-system/toolchain/setup_env.sh <env_name>
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVS_DIR="$SCRIPT_DIR/envs"

usage() {
    cat <<EOF
用法: bash $(basename "$0") <env_name>

可用预设环境:
  base          基础环境(无第三方包)
  markitdown    Microsoft markitdown + 通用文档解析
  mineru        OpenDataLab MinerU(需 GPU/CUDA)

示例:
  bash $(basename "$0") markitdown
  bash $(basename "$0") mineru
EOF
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

ENV_NAME="$1"
ENV_PATH="$ENVS_DIR/$ENV_NAME"

if [ -d "$ENV_PATH" ] && [ -n "$(ls -A "$ENV_PATH" 2>/dev/null | grep -v 'DESC.md')" ]; then
    echo "⚠️  环境已存在: $ENV_NAME  ($ENV_PATH)"
    read -rp "覆盖重建? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
    rm -rf "$ENV_PATH"
fi

mkdir -p "$ENV_PATH"

# 检查 uv(优先用 uv,快)
if command -v uv >/dev/null 2>&1; then
    echo "🚀 使用 uv 创建环境..."
    uv venv "$ENV_PATH" --python python3.11
else
    echo "🚀 使用 python3 -m venv 创建环境..."
    python3 -m venv "$ENV_PATH"
fi

# 写入描述文件
case "$ENV_NAME" in
    base)
        cat > "$ENV_PATH/DESC.md" <<EOD
# base — 基础环境

最精简的项目根环境,只装 pip + 通用工具。
所有其他环境(若使用 \`--system-site-packages\`)都可以基于它。
EOD
        ;;

    markitdown)
        cat > "$ENV_PATH/DESC.md" <<EOD
# markitdown — Microsoft markitdown

**用途**:把 Office / PDF / 图片 / 音视频 转成 markdown。
**典型用法**:
\`\`\`bash
source ~/projects/ai-rd-system/toolchain/env.sh markitdown
markitdown input.docx > output.md
\`\`\`
**官网**:https://github.com/microsoft/markitdown
EOD

        echo "📦 安装 markitdown + 全依赖..."
        "$ENV_PATH/bin/pip" install --upgrade pip wheel
        "$ENV_PATH/bin/pip" install "markitdown[all]"
        ;;

    mineru)
        cat > "$ENV_PATH/DESC.md" <<EOD
# mineru — OpenDataLab MinerU

**用途**:复杂 PDF(扫描件、论文、多栏、表格、公式)→ markdown。
**GPU**:需要 NVIDIA 显卡(A3000 推荐,16GB 显存)。
**典型用法**:
\`\`\`bash
source ~/projects/ai-rd-system/toolchain/env.sh mineru
magic-pdf -p input.pdf -o output_dir/
# 或新版本:
mineru -p input.pdf -o output_dir/
\`\`\`
**官网**:https://github.com/opendatalab/MinerU
EOD

        echo "📦 安装 MinerU(可能需要 CUDA toolkit)..."
        "$ENV_PATH/bin/pip" install --upgrade pip wheel
        # 注意:具体包名以 MinerU 官方文档为准
        # 旧版:magic-pdf / 新版:mineru
        "$ENV_PATH/bin/pip" install magic-pdf || \
        "$ENV_PATH/bin/pip" install mineru || \
        echo "⚠️  自动安装失败,请参考 MinerU 官方文档手动安装"
        ;;

    *)
        echo "⚠️  未知预设: $ENV_NAME,创建空环境"
        cat > "$ENV_PATH/DESC.md" <<EOD
# $ENV_NAME — 自定义环境
创建于 $(date +%Y-%m-%d)
EOD
        ;;
esac

echo ""
echo "✅ 环境创建完成: $ENV_NAME"
echo "   激活: source $SCRIPT_DIR/env.sh $ENV_NAME"
