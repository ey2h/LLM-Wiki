#!/usr/bin/env bash
# install_boot_marker.sh — 把 boot-marker.sh 装成 systemd path unit
# 开机后 30s 内必跑(覆盖所有 early boot 入口)
set -euo pipefail

SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/boot-marker.sh"
SCRIPT_DST="/usr/local/bin/boot-marker"

echo "=== 1. cp 到 /usr/local/bin/ ==="
sudo cp "$SCRIPT_SRC" "$SCRIPT_DST"
sudo chmod +x "$SCRIPT_DST"
sudo chown root:root "$SCRIPT_DST"

echo "=== 2. 写 systemd path unit ==="
# 用 .service + timer 还是直接 multi-user.target.wants?
# 多 target 都要触发(包括 rescue.target,emergency.target) → 用 generator
cat <<'EOF' | sudo tee /etc/systemd/system/boot-marker.service
[Unit]
Description=Mark boot event to /var/log/boot-marker.log
DefaultDependencies=no
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/boot-marker
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target rescue.target emergency.target
EOF
# 最稳的是 multi-user.target,因为 rescue/emergency 在 sysadmin 介入时才进
# 我们的目标:日常开机和崩溃开机都记

echo "=== 3. enable + start (现在跑一次) ==="
sudo systemctl daemon-reload
sudo systemctl enable boot-marker.service
sudo systemctl start boot-marker.service

echo "=== 4. 验证 ==="
sudo systemctl status boot-marker.service --no-pager | head -10
echo "---"
ls -la /var/log/boot-marker.log
tail -5 /var/log/boot-marker.log