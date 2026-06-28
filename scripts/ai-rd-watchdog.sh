#!/usr/bin/env bash
# ============================================================
# ai-rd-watchdog.sh — v11.7 daemon 守护 + 防 OOM 资源监管
#
# 设计目标(2026-06-29):
#   1. 监控 convert_year_*.sh / daemon 进程,死了自动重启
#   2. 资源硬上限:VLLM EngineCore >= 4 个或 RSS 总量 >= 24G → 杀最小 stale 进程
#   3. 防 OOM:systemd-oomd 配 user.slice 阈值
#   4. 写 watchdog.log + 给 weixin 报警
#
# 用法:
#   bash scripts/ai-rd-watchdog.sh start   # 后台跑
#   bash scripts/ai-rd-watchdog.sh stop
#   bash scripts/ai-rd-watchdog.sh status
#   bash scripts/ai-rd-watchdog.sh once    # 单次巡查
#
# systemd unit 配套:`~/.config/systemd/user/ai-rd-watchdog.service`
# ============================================================
set -u

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/ai-rd-watchdog.pid"
LOG_FILE="$HOME/projects/ai-rd-system/toolchain/logs/watchdog.log"
NFS="/mnt/nfs"

# 资源硬阈值(VM 30 GiB,留点余量给 system + Ollama)
MAX_TOTAL_RSS_GB=24          # 全部 RSS 加起来超过 24 GiB → 触发 stale cleanup
MAX_VLLM_ENGINES=3           # 同时在跑 VLLM::EngineCore 超过 3 个 → 触发 stale cleanup
OOM_POLICY_INTERVAL=300      # 每 5 分钟检查一次 systemd-oomd 配置

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2
}

alive_pids() {
    # v11.7 daemon 实际启动方式:bash scripts/convert_year_*.sh
    # 这里匹配所有 ai-rd 体系下的"工作进程"
    pgrep -f "convert_year_.*\.sh\|convert_double_ext\|toolchain/envs/mineru" | sort -u
}

total_rss_kb() {
    # 所有 alive 进程的 RSS 总和(KiB)
    local pids="$1"
    [ -z "$pids" ] && { echo 0; return; }
    ps -o rss= -p $pids 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

vllm_engine_count() {
    pgrep -af "VLLM::EngineCore" | wc -l
}

# 找最老的 stale mineru/vllm 子进程(grandchild 类型:PPID 不是 daemon)
stale_pids() {
    local daemon_pids="$1"
    # 列出所有 VLLM/mineru 进程,排除 daemon 直属子进程
    ps -eo pid,ppid,etime,cmd --no-headers 2>/dev/null \
        | grep -E "(VLLM::EngineCore|mineru|python.*vllm)" \
        | grep -v "grep" \
        | awk -v daemons="$daemon_pids" '
            BEGIN { split(daemons, d, " "); for (i in d) is_daemon[d[i]] = 1 }
            {
                ppid=$2; etime=$3; pid=$1
                cmd=""
                for (i=4;i<=NF;i++) cmd = cmd " " $i
                # 排除 daemon 直属子进程 / system 进程
                if (!is_daemon[ppid] && ppid != 1) {
                    # 按 etime 排序时降序(最老的在前,优先杀)
                    print etime " " pid " " ppid " " cmd
                }
            }' \
        | sort -rn | head -10
}

kill_stale() {
    local reason="$1"
    local daemon_pids
    daemon_pids=$(alive_pids | tr '\n' ' ')
    log "🧹 stale cleanup: $reason"
    local stale_list
    stale_list=$(stale_pids "$daemon_pids")
    if [ -z "$stale_list" ]; then
        log "  无 stale 进程"
        return 0
    fi
    echo "$stale_list" | while read -r etime pid ppid cmd; do
        [ -z "$pid" ] && continue
        log "  → kill PID=$pid (PPID=$ppid, etime=$etime) $cmd"
        kill -9 "$pid" 2>/dev/null || true
    done
    sleep 2
}

ensure_convert_alive() {
    # 当前没有任何 convert_year / daemon 进程
    if ! alive_pids | grep -q .; then
        log "⚠️  无 alive 进程 — 检查是否需要启动"
        # 这里不主动启动,留给上层(用户或 start_daemon.sh);
        # watchdog 只保 alive,不死就 OK
        return 1
    fi
    return 0
}

# 系统级 OOM 防御:配置 systemd-oomd 让 user.slice 不杀 daemon 主进程
configure_oomd() {
    local conf="$HOME/.config/systemd/user/ai-rd-override.conf"
    mkdir -p "$(dirname "$conf")"
    cat > "$conf" <<'EOF'
# 让 systemd-oomd 对 user.slice 高占用时优先 throttle,不主动 kill
# MemoryHigh=24G → 触发回收,MemoryMax=28G → 硬上限
[Manager]
DefaultMemoryHigh=24G
DefaultMemoryMax=28G
EOF
    systemctl --user daemon-reload 2>/dev/null || true
}

send_alert() {
    local msg="$1"
    log "🔔 ALERT: $msg"
    # 这里调用 hermes-cli 发 weixin;先 stub,后续接
    if command -v hermes >/dev/null 2>&1; then
        hermes notify --channel weixin --message "$msg" 2>/dev/null || true
    fi
}

once() {
    local daemon_pids
    daemon_pids=$(alive_pids | tr '\n' ' ')
    
    # 检查 1:有活进程吗
    if [ -z "$daemon_pids" ]; then
        log "📋 watchdog tick: no active convert job"
        return 0
    fi
    
    # 检查 2:RSS 总量
    local rss_kb
    rss_kb=$(total_rss_kb "$daemon_pids")
    local rss_gb=$((rss_kb / 1024 / 1024))
    log "📊 watchdog tick: alive=$(echo $daemon_pids | wc -w) total_rss=${rss_gb}G"
    
    if [ "$rss_gb" -ge "$MAX_TOTAL_RSS_GB" ]; then
        kill_stale "total_rss=${rss_gb}G >= ${MAX_TOTAL_RSS_GB}G"
        send_alert "ai-rd watchdog: RSS ${rss_gb}G 触发 stale cleanup"
    fi
    
    # 检查 3:VLLM 引擎数
    local vllm_n
    vllm_n=$(vllm_engine_count)
    if [ "$vllm_n" -ge "$MAX_VLLM_ENGINES" ]; then
        log "📊 vllm_engines=$vllm_n 触发 stale cleanup"
        kill_stale "vllm_engines=$vllm_n >= $MAX_VLLM_ENGINES"
    fi
    
    # 检查 4:NFS 还活着
    if ! mountpoint -q "$NFS" 2>/dev/null; then
        send_alert "NFS 挂载点 $NFS 已掉线"
    fi
}

loop() {
    log "🚀 watchdog 启动 PID=$$"
    configure_oomd
    
    while true; do
        once || true
        sleep "$OOM_POLICY_INTERVAL"
    done
}

cmd="${1:-}"
case "$cmd" in
    start)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "⚠️  watchdog 已运行 PID=$(cat "$PID_FILE")"
            exit 0
        fi
        nohup bash "$0" _loop >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        log "✅ watchdog 启动 PID=$(cat "$PID_FILE"),PID_FILE=$PID_FILE"
        ;;
    _loop) loop ;;
    stop)
        if [ -f "$PID_FILE" ]; then
            local_pid=$(cat "$PID_FILE")
            kill -TERM "$local_pid" 2>/dev/null || true
            rm -f "$PID_FILE"
            log "🛑 watchdog 停止 PID=$local_pid"
        fi
        ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "🟢 watchdog PID=$(cat "$PID_FILE")"
            alive_pids | head -5 | sed 's/^/  alive: /'
        else
            echo "🔴 watchdog 未运行"
        fi
        ;;
    once) once ;;
    *) echo "用法: $0 {start|stop|status|once}" ;;
esac
