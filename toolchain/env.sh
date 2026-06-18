#!/usr/bin/env bash
# ============================================================
# env.sh — 统一激活项目内的 Python 虚拟环境
# 用法: source ~/projects/ai-rd-system/toolchain/env.sh <env_name>
# 可选参数: --check   只检查环境是否安装,不激活
# ============================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_DIR="$PROJECT_ROOT/toolchain"
ENVS_DIR="$TOOLCHAIN_DIR/envs"

usage() {
    cat <<EOF
用法:
  source $(basename "$0") <env_name>     # 激活环境
  source $(basename "$0") --check <name>  # 只检查,不激活
  source $(basename "$0") --list          # 列出所有可用环境

可用环境:
EOF
    if [ -d "$ENVS_DIR" ]; then
        for d in "$ENVS_DIR"/*/; do
            [ -d "$d" ] || continue
            name=$(basename "$d")
            desc=""
            [ -f "$d/DESC.md" ] && desc=$(head -1 "$d/DESC.md" 2>/dev/null | sed 's/^#* *//')
            printf "  %-15s %s\n" "$name" "$desc"
        done
    fi
}

# 参数解析
CHECK_ONLY=false
LIST_ONLY=false
ENV_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_ONLY=true; shift ;;
        --list) LIST_ONLY=true; shift ;;
        -h|--help) usage; return 0 2>/dev/null || exit 0 ;;
        *) ENV_NAME="$1"; shift ;;
    esac
done

if $LIST_ONLY; then
    usage
    return 0 2>/dev/null || exit 0
fi

if [ -z "$ENV_NAME" ]; then
    echo "❌ 错误:未指定环境名" >&2
    usage >&2
    return 1 2>/dev/null || exit 1
fi

ENV_PATH="$ENVS_DIR/$ENV_NAME"
ACTIVATE="$ENV_PATH/bin/activate"

if [ ! -f "$ACTIVATE" ]; then
    echo "❌ 环境未安装: $ENV_NAME" >&2
    echo "   期望路径: $ENV_PATH" >&2
    echo "   安装方法: cd $PROJECT_ROOT/toolchain && bash setup_env.sh $ENV_NAME" >&2
    if $CHECK_ONLY; then
        return 1 2>/dev/null || exit 1
    fi
    return 1 2>/dev/null || exit 1
fi

if $CHECK_ONLY; then
    echo "✅ 环境已就绪: $ENV_NAME  ($ENV_PATH)"
    return 0 2>/dev/null || exit 0
fi

# 记录项目根目录,供脚本内部用
export AI_RD_ROOT="$PROJECT_ROOT"
export AI_RD_TOOLCHAIN="$TOOLCHAIN_DIR"
# 把 bin 加到 PATH 前面
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

# shellcheck disable=SC1090
source "$ACTIVATE"

# 提示信息
echo "✅ 已激活环境: $ENV_NAME"
echo "   Python:  $(which python3)"
echo "   路径:    $VIRTUAL_ENV"
echo "   AI_RD_ROOT=$AI_RD_ROOT"
