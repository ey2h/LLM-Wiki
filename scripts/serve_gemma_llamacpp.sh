#!/bin/bash
# serve_gemma_llamacpp.sh — 启动 Gemma 4 GGUF 推理服务
# 用法:
#   ./serve_gemma_llamacpp.sh e4b        # 起 E4B Q4_K_M(快,适合对话/agent)
#   ./serve_gemma_llamacpp.sh 12b        # 起 12B Q4_K_M(质量高,适合代码/推理)
#   ./serve_gemma_llamacpp.sh stop       # 停服务
#
# 端口: E4B=8001  12B=8002
# 模型: ~/models/gemma4-gguf/{e4b,12b}/

set -e

MODEL_DIR=~/models/gemma4-gguf
LLAMA_BIN=$(command -v llama-server)
if [ -z "$LLAMA_BIN" ]; then
    echo "❌ llama-server 不在 PATH(确认 ~/.local/bin 在 PATH 中)"
    exit 1
fi

start() {
    local kind=$1
    local port ctx

    case "$kind" in
        e4b)
            m=$MODEL_DIR/e4b/gemma-4-E4B-it-Q4_K_M.gguf
            p=$MODEL_DIR/e4b/mmproj-gemma-4-E4B-it-Q8_0.gguf
            port=8001
            ctx=8192
            ;;
        12b)
            m=$MODEL_DIR/12b/gemma-4-12B-it-Q4_K_M.gguf
            p=$MODEL_DIR/12b/mmproj-gemma-4-12B-it-Q8_0.gguf
            port=8002
            ctx=4096
            ;;
        *)
            echo "用法: $0 {e4b|12b|stop}"
            exit 1
            ;;
    esac

    [ -f "$m" ] || { echo "❌ 模型不存在: $m"; exit 1; }
    [ -f "$p" ] || { echo "❌ mmproj 不存在: $p"; exit 1; }

    # 检查端口是否被占用
    if ss -tln 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  端口 $port 已被占用,先 stop 再 start"
        exit 1
    fi

    echo "🚀 启动 Gemma 4 $kind:"
    echo "   模型: $m"
    echo "   mmproj: $p"
    echo "   端口: $port, ctx=$ctx"
    cd "$(dirname "$m")"
    exec "$LLAMA_BIN" \
        -m "$(basename "$m")" \
        --mmproj "$(basename "$p")" \
        -ngl 999 -c "$ctx" \
        --host 127.0.0.1 --port "$port" \
        -t 4
}

stop() {
    PID=$(ps -ef | grep "[l]lama-server" | awk '{print $2}')
    if [ -n "$PID" ]; then
        kill -9 $PID
        echo "✅ 已停 llama-server (PID=$PID)"
    else
        echo "(无 llama-server 在跑)"
    fi
}

case "${1:-}" in
    e4b|12b) start "$1" ;;
    stop)    stop ;;
    *)       echo "用法: $0 {e4b|12b|stop}"; exit 1 ;;
esac