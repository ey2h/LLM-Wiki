#!/usr/bin/env bash
# install_watchdog.sh — 安装 ai-rd-watchdog user systemd unit
set -euo pipefail

SRC="$(dirname "$0")/ai-rd-watchdog.service"
DEST="$HOME/.config/systemd/user/ai-rd-watchdog.service"

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

echo "✓ copied to $DEST"
echo ""
echo "现在执行:"
echo "  loginctl enable-linger jack    # 允许 user service 在无登录会话时运行"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable ai-rd-watchdog.service"
echo "  systemctl --user start ai-rd-watchdog.service"
echo "  systemctl --user status ai-rd-watchdog.service"
