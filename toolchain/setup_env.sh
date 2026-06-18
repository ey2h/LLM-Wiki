#!/usr/bin/env bash
# ============================================================
# setup_env.sh — 创建/重建项目内的 Python 虚拟环境
#
# 用 uv(快、自动下载 Python)而不是 python -m venv:
#   - uv venv <path> --python 3.11 自动下载并使用 Python 3.11
#   - uv pip install 极速装包(并行下载,带 cache)
#
# 用法: bash ~/projects/ai-rd-system/toolchain/setup_env.sh <env_name>
#       bash ~/projects/ai-rd-system/toolchain/setup_env.sh markitdown 3.11
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVS_DIR="$SCRIPT_DIR/envs"

# 确保 uv 在 PATH
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
    echo "❌ 未找到 uv,请先安装: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    exit 1
fi

usage() {
    cat <<EOF
用法: bash $(basename "$0") <env_name> [<python_version>]

参数:
  env_name          base / markitdown / mineru / <自定义>
  python_version    可选,默认 3.11(可填 3.10 / 3.12 / 3.13)

预设环境说明:
  base          基础环境(无第三方包)
  markitdown    Microsoft markitdown + 通用文档解析
  mineru        OpenDataLab MinerU(运行需 GPU/CUDA,安装不需)
EOF
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

ENV_NAME="$1"
PY_VERSION="${2:-3.11}"

ENV_PATH="$ENVS_DIR/$ENV_NAME"

if [ -d "$ENV_PATH" ] && [ -n "$(ls -A "$ENV_PATH" 2>/dev/null | grep -v 'DESC.md')" ]; then
    echo "⚠️  环境已存在: $ENV_NAME  ($ENV_PATH)"
    read -rp "覆盖重建? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
    rm -rf "$ENV_PATH"
fi

mkdir -p "$ENV_PATH"

write_desc() {
    case "$1" in
        base)
            cat > "$ENV_PATH/DESC.md" <<EOD
# base — 基础环境

最精简的项目根环境,只装 pip + 通用工具。
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
            ;;
        *)
            cat > "$ENV_PATH/DESC.md" <<EOD
# $1 — 自定义环境
创建于 $(date +%Y-%m-%d)
EOD
            ;;
    esac
}

echo "🚀 uv 创建环境 $ENV_NAME (Python $PY_VERSION)..."
uv venv "$ENV_PATH" --python "$PY_VERSION" --seed

write_desc "$ENV_NAME"

case "$ENV_NAME" in
    base)
        echo "✅ 基础环境就绪"
        ;;

    markitdown)
        echo "📦 安装 markitdown[all]..."
        uv pip install --python "$ENV_PATH/bin/python" --upgrade pip wheel
        uv pip install --python "$ENV_PATH/bin/python" "markitdown[all]"
        echo "✅ markitdown 环境就绪"
        ;;

    mineru)
        echo "📦 安装 MinerU..."
        uv pip install --python "$ENV_PATH/bin/python" --upgrade pip wheel
        # 旧版叫 magic-pdf,新版叫 mineru,两个都试
        if ! uv pip install --python "$ENV_PATH/bin/python" magic-pdf 2>/dev/null; then
            uv pip install --python "$ENV_PATH/bin/python" mineru || \
                echo "⚠️  自动安装失败,请参考 MinerU 官方文档手动安装"
        fi
        echo "✅ mineru 环境就绪(运行需 GPU)"
        ;;

    *)
        echo "✅ 空环境创建完成,需要装什么自己 uv pip install"
        ;;
esac

echo ""
echo "🎉 完成"
echo "   激活: source $SCRIPT_DIR/env.sh $ENV_NAME"
