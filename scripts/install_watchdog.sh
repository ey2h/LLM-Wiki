#!/usr/bin/env bash
# install_watchdog.sh — 安装 ai-rd-watchdog + ai-rd-daemon user systemd unit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/systemd/user/ai-rd-watchdog.service"
DEST_DAEMON="$HOME/.config/systemd/user/ai-rd-daemon.service"

mkdir -p "$(dirname "$DEST")"
cp "$SCRIPT_DIR/ai-rd-watchdog.service" "$DEST"
cp "$SCRIPT_DIR/ai-rd-daemon.service" "$DEST_DAEMON"
echo "✓ copied to $DEST"
echo "✓ copied to $DEST_DAEMON"
echo ""
echo "现在执行:"
echo "  loginctl enable-linger jack    # 允许 user service 在无登录会话时运行"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable ai-rd-watchdog.service    # 监控,先起"
echo "  systemctl --user enable ai-rd-daemon.service      # 转换daemon,按需启"
echo "  systemctl --user start ai-rd-watchdog.service"
echo "  systemctl --user status ai-rd-watchdog.service"
echo ""
echo "启动 daemon(跑全 2013-2026):"
echo "  systemctl --user start ai-rd-daemon.service"
echo "  journalctl --user -u ai-rd-daemon -f"
