#!/usr/bin/env bash
# ===========================================================
# boot-marker.sh — 开机拦截器
#
# 目的:fnOS host 强 reset 时,无 guest-agent 通道,无法知道*为什么*重启。
#       但主机正常启动后,我们能记录"开机时间"和"距上次开机的间隔"。
#       配合 watchdog + kern.log,以后回查完整重启链路。
#
# 原理:
#   - 上次关机时间存在 /var/lib/misc/before_unbutu_was_alive
#   - 这次开机 systemd 会跑这个 ExecStartPre
#   - 写一行 "BOOT 时间戳" 到 /var/log/boot-marker.log
#   - 若距离上次开机 < 30 分钟 → 标记 "ANORMAL" (很可能是被 reset)
#
# 安装:
#   sudo cp scripts/boot-marker.sh /usr/local/bin/boot-marker
#   sudo chmod +x /usr/local/bin/boot-marker
#   sudo bash scripts/install_boot_marker.sh
# ===========================================================
set -euo pipefail

LOG=/var/log/boot-marker.log
STATE=/var/lib/misc/before_unbutu_was_alive

mkdir -p "$(dirname "$LOG")" "$(dirname "$STATE")"
touch "$LOG"

now=$(date '+%Y-%m-%d %H:%M:%S')
prev=""
anormal=0

# 读上次成功的"开机点"时间戳
if [ -f "$STATE" ]; then
    prev=$(cat "$STATE" 2>/dev/null || true)
    if [ -n "$prev" ]; then
        # 计算间隔
        prev_epoch=$(date -d "$prev" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        gap_min=$(( (now_epoch - prev_epoch) / 60 ))
        # 30 分钟内的 reboot → 异常(可能是 host reset,或 daemon crash + 重启 VM)
        if [ "$gap_min" -lt 30 ]; then
            anormal=1
        fi
    fi
fi

# 写本次开机点
echo "$now" > "$STATE"

# 标记
if [ "$anormal" -eq 1 ]; then
    tag="ANORMAL"
else
    tag="NORMAL"
fi

# 输出到 log
printf '[%s] BOOT %-7s gap=%s prev=%s\n' "$now" "$tag" "${gap_min:-?}min" "${prev:-<none>}" >> "$LOG"

# 也写到 systemd journal 的 dmsg
echo "[boot-marker] $tag gap=${gap_min:-?}min prev=${prev:-<none>}" | tee /dev/kmsg > /dev/null || true

exit 0
