#!/usr/bin/env bash
# =============================================================================
# 地球村网络优化器  Global Village Network Optimizer  v3.0
# 2026-05-19 · macOS / Linux · 智能区域检测 + PPPoE适配 + DNS/TCP优化
# =============================================================================
set -euo

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

BACKUP_DIR="/tmp/net-optimizer-backup-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/tmp/net-optimizer-$(date +%Y%m%d-%H%M%S).log"
OS=""; OS_VERSION=""; REGION=""; DNS_OVER_TCP=false
DRY_RUN=false; VERBOSE=false
APPLY_DNS=true; APPLY_TCP=true; APPLY_MTU=true; APPLY_BBR=true

banner() {
    printf '%b' "${CYAN}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║        🌍 地球村网络优化器  Global Village Optimizer        ║\n"
    printf "║        Network Diagnostic & Enhancement Suite v3.0          ║\n"
    printf "╚══════════════════════════════════════════════════════════════╝\n"
    printf '%b' "${NC}\n"
}

log()  { printf "[%s] %b\n" "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
info() { printf "${GREEN}[INFO]${NC} %s\n" "$*" | tee -a "$LOG_FILE"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" | tee -a "$LOG_FILE"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$*" | tee -a "$LOG_FILE"; }
ok()   { printf "  ${GREEN}✔${NC} %s\n" "$*"; }
fail() { printf "  ${RED}✘${NC} %s\n" "$*"; }
skip() { printf "  ${YELLOW}→${NC} %s\n" "$*"; }

detect_os() {
    case "$(uname -s)" in
        Linux)
            if [ -f /etc/os-release ]; then . /etc/os-release; OS="${ID}"; OS_VERSION="${VERSION_ID}"
            elif [ -f /etc/debian_version ]; then OS="debian"; OS_VERSION="$(cat /etc/debian_version)"
            elif [ -f /etc/redhat-release ]; then OS="rhel"; OS_VERSION="unknown"
            fi ;;
        Darwin) OS="macos"; OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')" ;;
        *) OS="unknown" ;;
    esac
    info "检测操作系统: ${OS} ${OS_VERSION}"
}

detect_region() {
    if [ -n "${FORCE_REGION:-}" ]; then
        REGION="$FORCE_REGION"; info "区域已手动指定: ${REGION}"; return; fi
    info "自动检测网络区域..."
    local dl=999 il=999
    if command -v ping &>/dev/null; then
        if [ "$OS" = "macos" ]; then
            dl=$(ping -c 2 -t 3 223.5.5.5 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
            il=$(ping -c 2 -t 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
        else
            dl=$(ping -c 2 -W 3 223.5.5.5 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
            il=$(ping -c 2 -W 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "999")
        fi
    fi
    [ -z "$dl" ] && dl=999; [ -z "$il" ] && il=999
    dl=$(printf "%.0f" "$dl" 2>/dev/null || echo 999)
    il=$(printf "%.0f" "$il" 2>/dev/null || echo 999)
    echo "    国内DNS (223.5.5.5): ${dl}ms   国际DNS (1.1.1.1): ${il}ms"
    if [ "$dl" -lt 50 ] 2>/dev/null && [ "$il" -gt 100 ] 2>/dev/null; then
        REGION="cn"; ok "检测到 中国内地网络环境 → 国内DNS为主"; else
        REGION="intl"; ok "检测到 国际网络环境 → 全球最优DNS"; fi
}

check_root() {
    if [ "$OS" = "macos" ]; then return 0; fi
    if [ "$(id -u)" -ne 0 ]; then err "需要 root 权限: sudo $0"; exit 1; fi
}

backup_existing() {
    mkdir -p "$BACKUP_DIR"; info "备份现有配置到: $BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak" 2>/dev/null || true
    cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
    cp /etc/hosts "$BACKUP_DIR/hosts.bak" 2>/dev/null || true
    sysctl -a 2>/dev/null > "$BACKUP_DIR/sysctl-current.txt" || true
    ok "配置备份完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段一: 全面诊断
# ═══════════════════════════════════════════════════════════════
diagnose_network() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段一: 网络现状全面诊断\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    info "收集系统网络信息..."
    echo "  主机名: $(hostname 2>/dev/null || echo N/A)"
    echo "  内核版本: $(uname -r)"; echo "  架构: $(uname -m)"

    # 活跃接口
    info "活跃网络接口:"
    if [ "$OS" = "macos" ]; then
        for iface in $(ifconfig -l 2>/dev/null); do
            local ip; ip=$(ifconfig "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' || true)
            [ -n "$ip" ] && echo "    ${iface} → ${ip}"
        done
    else
        ip -br addr show 2>/dev/null | grep -v '^lo' || ifconfig 2>/dev/null | grep -E '^[a-z]' | cut -d: -f1
    fi

    # 默认网关
    info "默认路由:"
    if [ "$OS" = "macos" ]; then
        netstat -rn 2>/dev/null | grep '^default' | head -3 || echo "    (无)"
    else
        ip route show default 2>/dev/null || route -n 2>/dev/null | grep '^0.0.0.0' || echo "    (无)"
    fi

    # 当前 DNS
    info "当前 DNS 配置:"
    if [ -f /etc/resolv.conf ]; then
        grep '^nameserver' /etc/resolv.conf 2>/dev/null || echo "    (无 nameserver 条目)"
    else
        echo "    未找到 /etc/resolv.conf"
    fi
    if [ "$OS" = "macos" ]; then
        scutil --dns 2>/dev/null | grep 'nameserver\[' | head -6 || true
    fi

    # DNS 延迟
    info "测试 DNS 解析延迟 (google.com × 5次):"
    local total=0 dns_count=0
    for i in 1 2 3 4 5; do
        local t=""
        if command -v dig &>/dev/null; then
            t=$(dig +time=5 +tries=1 google.com 2>/dev/null | grep 'Query time' | awk '{print $4}' || true)
        elif command -v nslookup &>/dev/null; then
            local ts
            if command -v perl &>/dev/null; then
                ts=$(perl -MTime::HiRes=time -e 'printf "%.0f", time*1000')
            else
                ts=$(date +%s)000
            fi
            nslookup google.com 2>/dev/null >/dev/null || true
            local te
            if command -v perl &>/dev/null; then
                te=$(perl -MTime::HiRes=time -e 'printf "%.0f", time*1000')
            else
                te=$(date +%s)000
            fi
            t=$((te - ts)) 2>/dev/null || true
        fi
        [ -z "$t" ] && t="超时"
        echo "    第${i}次: ${t}ms"
        case "$t" in ''|超时|N/A|0) ;; *) total=$((total + t)); dns_count=$((dns_count + 1)) ;; esac
    done
    if [ "$dns_count" -gt 0 ] 2>/dev/null; then
        local avg=$((total / dns_count)); echo "    DNS 平均延迟: ${avg}ms"
        [ "$avg" -gt 100 ] && warn "DNS 延迟过高 (>100ms)" || [ "$avg" -gt 50 ] && warn "DNS 延迟偏高 (>50ms)" || ok "DNS 延迟正常"
    fi

    # ICMP 延迟
    info "ICMP 延迟到关键节点:"
    for target in 1.1.1.1 8.8.8.8 223.5.5.5; do
        local rtt; local name=""; case "$target" in
            1.1.1.1) name="Cloudflare";; 8.8.8.8) name="Google";; 223.5.5.5) name="阿里DNS";; esac
        if [ "$OS" = "macos" ]; then
            rtt=$(ping -c 3 -t 5 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "超时")
        else
            rtt=$(ping -c 3 -W 5 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "超时")
        fi
        [ -z "$rtt" ] && rtt="超时"
        printf "    %-15s (%s): %sms\n" "$name" "$target" "$rtt"
    done

    # 国际出口分析
    if command -v traceroute &>/dev/null; then
        info "国际出口路由分析 (traceroute 1.1.1.1):"
        traceroute -m 15 1.1.1.1 2>/dev/null || true
        warn "观察 hop 延迟突变点——超过 50ms 的跳跃即为国际出口瓶颈"
    fi

    # 下载测速
    info "下载速度实测 (Cloudflare 1MB):"
    local dl_speed; dl_speed=$(curl -s -o /dev/null -w '%{speed_download}' --connect-timeout 10 \
        'https://speed.cloudflare.com/__down?bytes=1048576' 2>/dev/null || echo "0")
    if [ "${dl_speed:-0}" != "0" ] 2>/dev/null; then
        local dl_mbps; dl_mbps=$(python3 -c "import sys; print(f'{int(sys.argv[1])*8/1e6:.1f}')" "${dl_speed}" 2>/dev/null || \
            echo "scale=1;${dl_speed}*8/1000000" | bc 2>/dev/null || echo "N/A")
        echo "    速度: ${dl_speed} bytes/sec (~${dl_mbps} Mbps)"
        [ "${dl_mbps%%.*}" -lt 5 ] 2>/dev/null && warn "国际带宽 <5 Mbps —— BBR优化后预计提升 2-5x"
    else
        skip "下载测速失败"
    fi

    # TCP 拥塞控制
    info "TCP 拥塞控制算法:"
    if [ "$OS" = "macos" ]; then
        echo "    macOS: $(sysctl net.inet.tcp.cc algorithm 2>/dev/null || echo '未知')"
    else
        echo "    拥塞控制: $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo unknown)"
        echo "    队列规则: $(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}' || echo unknown)"
    fi

    # MTU
    info "网络接口 MTU:"
    if [ "$OS" = "macos" ]; then
        ifconfig 2>/dev/null | grep -E '^[a-z]|mtu' | grep -v 'lo' | head -20 || true
    else
        ip link show 2>/dev/null | grep -E '^[0-9]+:|mtu' | grep -v 'lo:' | head -20 || true
    fi

    echo ""; ok "阶段一诊断完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段二: DNS 优化 (区域感知)
# ═══════════════════════════════════════════════════════════════
optimize_dns() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段二: DNS 优化 (区域: ${REGION})\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    [ "$APPLY_DNS" != "true" ] && { skip "DNS 优化已跳过"; return; }

    local DNS_PRIMARY="" DNS_SECONDARY="" DNS_TERTIARY=""
    if [ "$REGION" = "cn" ]; then
        DNS_PRIMARY="223.5.5.5"; DNS_SECONDARY="119.29.29.29"; DNS_TERTIARY="8.8.8.8"
        info "采用 国内DNS为主: 阿里(223.5.5.5) + 腾讯(119.29.29.29) + Google兜底"
    else
        DNS_PRIMARY="1.1.1.1"; DNS_SECONDARY="9.9.9.9"; DNS_TERTIARY="8.8.8.8"
        info "采用 全球最优DNS: Cloudflare(1.1.1.1) + Quad9 + Google兜底"
    fi

    # UDP DNS 丢包检测
    local udp_fail=0
    if command -v dig &>/dev/null; then
        for i in 1 2 3; do
            dig +time=3 +tries=1 +notcp @"${DNS_PRIMARY}" google.com 2>/dev/null | grep -q 'Query time' || udp_fail=$((udp_fail+1))
        done
        [ "$udp_fail" -ge 1 ] && warn "UDP DNS 丢包: ${udp_fail}/3 — 建议 --dns-over-tcp"
    fi

    info "配置最优 DNS..."

    # 按平台路由 — macOS 必须第一个判断！
    if [ "$OS" = "macos" ]; then
        local IFACE; IFACE=$(route get default 2>/dev/null | grep 'interface:' | awk '{print $2}')
        local SVC=""
        if [ -n "$IFACE" ]; then
            SVC=$(networksetup -listallhardwareports 2>/dev/null | awk -v iface="$IFACE" '
                /Hardware Port:/ { gsub(/.*: /, "", $0); port=$0 }
                /Device:/ && $2 == iface { print port; exit }
            ')
        fi
        [ -z "$SVC" ] && SVC="Wi-Fi"
        networksetup -setdnsservers "$SVC" "$DNS_PRIMARY" "$DNS_SECONDARY" "$DNS_TERTIARY" 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        killall -HUP mDNSResponder 2>/dev/null || true
        ok "macOS DNS 已配置 (${SVC}: ${DNS_PRIMARY}, ${DNS_SECONDARY}, ${DNS_TERTIARY})"

    elif command -v resolvectl &>/dev/null; then
        local IFACE; IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
        [ -z "$IFACE" ] && IFACE="eth0"
        resolvectl dns "$IFACE" "$DNS_PRIMARY" "$DNS_SECONDARY" "$DNS_TERTIARY" 2>/dev/null || true
        resolvectl domain "$IFACE" "~." 2>/dev/null || true
        systemctl restart systemd-resolved 2>/dev/null || true
        ok "systemd-resolved DNS 配置完成"

    elif command -v nmcli &>/dev/null; then
        local conns; conns=$(nmcli -t -f UUID con show --active 2>/dev/null || echo "")
        for c in $conns; do
            [ -z "$c" ] && continue
            nmcli con mod "$c" ipv4.dns "$DNS_PRIMARY $DNS_SECONDARY $DNS_TERTIARY" 2>/dev/null || true
            nmcli con mod "$c" ipv4.ignore-auto-dns yes 2>/dev/null || true
        done
        nmcli con reload 2>/dev/null || true; ok "NetworkManager DNS 配置完成"

    elif [ -f /etc/resolv.conf ]; then
        local opts="timeout:2 attempts:3 rotate"
        [ "$DNS_OVER_TCP" = "true" ] && opts="${opts} use-vc"
        cat > /etc/resolv.conf << EOF
nameserver ${DNS_PRIMARY}
nameserver ${DNS_SECONDARY}
nameserver ${DNS_TERTIARY}
options ${opts}
EOF
        ok "/etc/resolv.conf DNS 配置完成"
    else
        warn "未检测到可配置的 DNS 管理方式"
    fi

    [ "$DNS_OVER_TCP" = "true" ] && info "DNS over TCP 模式已启用"
    echo ""; ok "阶段二 DNS 优化完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段三: TCP/IP 优化
# ═══════════════════════════════════════════════════════════════
optimize_tcp() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段三: TCP/IP 内核参数优化\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    [ "$APPLY_TCP" != "true" ] && { skip "TCP 优化已跳过"; return; }

    if [ "$OS" = "macos" ]; then
        info "应用 macOS TCP 优化..."
        sysctl -w net.inet.tcp.autorcvbufmax=2097152 2>/dev/null || true
        sysctl -w net.inet.tcp.autosndbufmax=2097152 2>/dev/null || true
        sysctl -w net.inet.tcp.sendspace=1048576 2>/dev/null || true
        sysctl -w net.inet.tcp.recvspace=1048576 2>/dev/null || true
        sysctl -w net.inet.tcp.fastopen=3 2>/dev/null || true
        sysctl -w net.inet.tcp.slowstart_flightsize=20 2>/dev/null || true
        sysctl -w net.inet.tcp.path_mtu_discovery=1 2>/dev/null || true
        sysctl -w net.inet.tcp.rfc1323=1 2>/dev/null || true
        sysctl -w net.inet.tcp.win_scale_factor=4 2>/dev/null || true
        sysctl -w net.inet.udp.recvspace=2097152 2>/dev/null || true
        sysctl -w kern.ipc.maxsockbuf=8388608 2>/dev/null || true
        ok "macOS TCP 优化完成"
        return
    fi

    # Linux BBR
    modprobe tcp_bbr 2>/dev/null || true
    info "应用 Linux TCP/IP 内核参数..."
    cat > /etc/sysctl.d/99-earth-village.conf << 'SYSCTLEOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_adv_win_scale = -2
net.core.optmem_max = 25165824
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 30000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
vm.swappiness = 10
SYSCTLEOF
    sysctl --system 2>/dev/null || sysctl -p /etc/sysctl.d/99-earth-village.conf 2>/dev/null || true
    ok "Linux TCP/IP 优化完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段四: MTU & MSS
# ═══════════════════════════════════════════════════════════════
optimize_mtu() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段四: MTU & MSS 优化\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    [ "$APPLY_MTU" != "true" ] && { skip "MTU 优化已跳过"; return; }

    info "探测路径 MTU (目标: 223.5.5.5)..."
    local optimal_mtu=1500
    for size in 1472 1460 1450 1440 1400 1350 1300; do
        if [ "$OS" = "macos" ]; then
            ping -c 2 -D -s "$size" 223.5.5.5 2>/dev/null | grep -q 'from' && { optimal_mtu=$((size+28)); break; }
        else
            ping -c 2 -M do -s "$size" 223.5.5.5 2>/dev/null | grep -q 'bytes from' && { optimal_mtu=$((size+28)); break; }
        fi
    done
    info "路径 MTU: ${optimal_mtu}"

    local need_fix=false
    if [ "$OS" != "macos" ]; then
        # PPPoE 检测
        local ppp_iface; ppp_iface=$(ip link show 2>/dev/null | grep -oP '^\d+: ppp\d+' | awk '{print $2}' | tr -d ':' | head -1)
        [ -n "$ppp_iface" ] && warn "检测到 PPPoE 接口: ${ppp_iface}" && need_fix=true

        # 双层 NAT 检测
        local priv_hops; priv_hops=$(traceroute -n -m 5 1.1.1.1 2>/dev/null | grep -cE '^\s+[0-9]+\s+(10\.|172\.1[6-9]|172\.2[0-9]|172\.3[0-1]|192\.168\.)' || echo 0)
        [ "${priv_hops:-0}" -gt 1 ] 2>/dev/null && warn "检测到双层/多层 NAT" && need_fix=true

        [ "$optimal_mtu" -lt 1500 ] 2>/dev/null && need_fix=true
    fi

    # macOS MTU 提示
    if [ "$OS" = "macos" ] && [ "$optimal_mtu" -lt 1500 ] 2>/dev/null; then
        need_fix=true
        warn "路径 MTU 偏小 (${optimal_mtu}) — 可能存在 PPPoE 或 ISP 限制"
        echo "    建议检查: 系统偏好设置 → 网络 → 高级 → 硬件 → MTU"
    fi

    # MSS 钳制 (仅 Linux)
    if [ "$need_fix" = "true" ] && command -v iptables &>/dev/null; then
        local clamp_mss=$((optimal_mtu - 40))
        info "应用 MSS 钳制: TCP MSS → ${clamp_mss}"
        iptables -t mangle -C OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$clamp_mss" 2>/dev/null || \
            iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$clamp_mss" 2>/dev/null || true
        ok "MSS 钳制已应用"
    fi

    echo ""; ok "阶段四 MTU/MSS 优化完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段五: 工具安装
# ═══════════════════════════════════════════════════════════════
install_tools() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段五: 网络工具安装\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    if [ "$OS" = "macos" ]; then
        command -v brew &>/dev/null || { warn "Homebrew 未安装，跳过"; return; }
        for tool in mtr; do
            command -v "$tool" &>/dev/null || brew install "$tool" 2>/dev/null || warn "${tool} 安装失败"
        done
    elif command -v apt-get &>/dev/null; then
        apt-get update -qq 2>/dev/null
        apt-get install -y -qq mtr dnsutils ethtool 2>/dev/null || true
    fi
    ok "工具安装完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段六: 效果验证
# ═══════════════════════════════════════════════════════════════
verify_improvements() {
    printf '\n%b' "${BOLD}${BLUE}"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "  阶段六: 优化效果验证\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "${NC}"

    local dns_target="223.5.5.5"; [ "$REGION" != "cn" ] && dns_target="1.1.1.1"

    info "验证 DNS (${dns_target}):"
    local dns_ok=0 dns_total=0
    for i in 1 2 3 4 5; do
        local t
        if command -v dig &>/dev/null; then
            t=$(dig +time=5 +tries=1 @"${dns_target}" google.com 2>/dev/null | grep 'Query time' | awk '{print $4}' || true)
        else
            t="N/A"
        fi
        [ -z "$t" ] && t="超时"
        echo "    第${i}次: ${t}ms"
        case "$t" in ''|超时|N/A) ;; *) dns_total=$((dns_total+t)); dns_ok=$((dns_ok+1)) ;; esac
    done
    if [ "$dns_ok" -gt 0 ] 2>/dev/null; then
        local loss=$(((5-dns_ok)*20))
        echo "    平均: $((dns_total/dns_ok))ms  丢包: ${loss}%  成功率: ${dns_ok}/5"
        [ "$loss" -gt 0 ] && warn "仍有丢包 — 考虑 --dns-over-tcp"
    fi

    info "验证 TCP 参数:"
    if [ "$OS" = "macos" ]; then
        sysctl net.inet.tcp.fastopen net.inet.tcp.sendspace 2>/dev/null || true
    else
        sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc 2>/dev/null || true
    fi

    info "验证下载速度 (Cloudflare 1MB):"
    local dl_speed; dl_speed=$(curl -s -o /dev/null -w '%{speed_download}' --connect-timeout 10 \
        'https://speed.cloudflare.com/__down?bytes=1048576' 2>/dev/null || echo "0")
    if [ "${dl_speed:-0}" != "0" ] 2>/dev/null; then
        local dl_mbps; dl_mbps=$(python3 -c "import sys; print(f'{int(sys.argv[1])*8/1e6:.1f}')" "${dl_speed}" 2>/dev/null || \
            echo "scale=1;${dl_speed}*8/1000000" | bc 2>/dev/null || echo "N/A")
        echo "    速度: ~${dl_mbps} Mbps"
    fi

    echo ""; ok "验证完成"
}

# ═══════════════════════════════════════════════════════════════
# 主函数
# ═══════════════════════════════════════════════════════════════
main() {
    banner
    local FORCE_REGION=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=true; shift ;;
            --region=*) FORCE_REGION="${1#*=}"; shift ;;
            --dns-over-tcp) DNS_OVER_TCP=true; shift ;;
            --skip-dns) APPLY_DNS=false; shift ;;
            --skip-tcp) APPLY_TCP=false; shift ;;
            --skip-mtu) APPLY_MTU=false; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -h|--help) echo "用法: $0 [选项]"
                echo "  --dry-run       仅诊断"; echo "  --region=cn|intl  指定区域"
                echo "  --dns-over-tcp  DNS over TCP"; echo "  --skip-dns/tcp/mtu  跳过指定阶段"
                exit 0 ;;
            *) shift ;;
        esac
    done

    detect_os; detect_region

    if [ "$DRY_RUN" = "true" ]; then
        info "Dry-run 模式: 仅诊断，不做修改"
        diagnose_network; exit 0
    fi

    check_root; backup_existing
    diagnose_network; optimize_dns; optimize_tcp; optimize_mtu
    install_tools; verify_improvements

    printf '\n%b' "${BOLD}${GREEN}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║            🌍 地球村网络优化完成!  v3.0                      ║\n"
    printf "║  区域: ${REGION}    备份: ${BACKUP_DIR}\n"
    printf "╚══════════════════════════════════════════════════════════════╝%b\n" "${NC}"
    echo ""; info "后续:"
    [ "$OS" = "macos" ] && echo "  DNS: 已通过 networksetup 配置, mDNSResponder 已重启" || echo "  重启网络使生效"
    echo "  复测: curl -o /dev/null -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=1048576'"
    echo ""
}

main "$@"
