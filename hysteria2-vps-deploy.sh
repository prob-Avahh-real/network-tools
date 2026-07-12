#!/usr/bin/env bash
# =============================================================================
# 地球村 VPS 部署助手 — Hysteria2 自动安装
# Global Village VPS Deployer · 绕开 CMI 国际出口
# 用法:
#   1. 先买一台 HK/SG VPS (阿里云HK / 腾讯云HK / Vultr SG)
#   2. SSH 进去，运行本脚本
# 或
#   直接远程执行:
#   cat hysteria2-vps.sh | ssh root@YOUR_VPS_IP bash
# =============================================================================
set -euo

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
ok()   { printf "  ${GREEN}✔${NC} %s\n" "$*"; }

# ──────────────────────────────────────────────
# 阶段一: 系统检测
# ──────────────────────────────────────────────
check_system() {
    if [ "$(id -u)" -ne 0 ]; then err "需要 root 权限"; exit 1; fi
    if ! grep -qiE 'ubuntu|debian' /etc/os-release 2>/dev/null; then
        warn "脚本适配 Ubuntu/Debian，其他系统可能需手动调整"
    fi
    info "系统: $(uname -a | awk '{print $2}') | $(. /etc/os-release 2>/dev/null && echo "$NAME $VERSION_ID" || echo '?')"
    ok "系统检测通过"
}

# ──────────────────────────────────────────────
# 阶段二: 网络基准测试
# ──────────────────────────────────────────────
benchmark() {
    info "VPS 网络基准测试..."
    echo "  本机 IP: $(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 ip.sb 2>/dev/null || echo '?')"

    # 测到你的本地延迟 (中国移动)
    echo "  到中国移动延迟:"
    # 取多个国内节点测
    for node in "223.5.5.5" "119.29.29.29"; do
        local rtt; rtt=$(ping -c 3 -W 3 "$node" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "N/A")
        [ -z "$rtt" ] && rtt="N/A"
        echo "    $node → ${rtt}ms"
    done

    # 到 Cloudflare 延迟 (验证国际出口质量)
    local cf_rtt; cf_rtt=$(ping -c 3 -W 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "N/A")
    echo "    1.1.1.1 → ${cf_rtt}ms"

    # 测速
    if command -v speedtest-cli &>/dev/null; then
        speedtest-cli --simple 2>/dev/null || true
    else
        apt-get install -y -qq speedtest-cli 2>/dev/null && speedtest-cli --simple 2>/dev/null || \
            warn "speedtest-cli 安装失败，跳过测速"
    fi

    echo "  ✓ 预期: 到国内 <50ms → 适合做中转"
    echo "  ✗ 预期: 到国内 >150ms → 这台 VPS 离中国太远，换一台"
}

# ──────────────────────────────────────────────
# 阶段三: 安装 Hysteria2
# ──────────────────────────────────────────────
install_hysteria2() {
    info "安装 Hysteria2..."

    # 基础依赖
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq curl wget jq qrencode net-tools uuid-runtime 2>/dev/null || true

    # 使用一键脚本
    bash <(curl -fsSL https://raw.githubusercontent.com/georgetime1970/h2/main/h2.sh) 2>&1 || {
        err "一键脚本失败，备用方案..."
        # 直接安装
        local HY2_VER
        HY2_VER=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep tag_name | cut -d'"' -f4 || echo "v2.6.1")
        local ARCH; ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            *) ARCH="amd64" ;;
        esac
        wget -q "https://github.com/apernet/hysteria/releases/download/${HY2_VER}/hysteria-linux-${ARCH}" -O /usr/local/bin/hysteria
        chmod +x /usr/local/bin/hysteria
        ok "Hysteria2 二进制已安装"
    }

    # 验证
    if command -v hysteria &>/dev/null; then
        ok "Hysteria2 安装成功: $(hysteria version 2>/dev/null | head -1 || true)"
    else
        err "安装失败，检查网络连通性后重试"
        exit 1
    fi
}

# ──────────────────────────────────────────────
# 阶段四: 生成配置 (优化版)
# ──────────────────────────────────────────────
configure_hysteria2() {
    info "生成优化配置..."

    local PORT; PORT=$(shuf -i 10000-60000 -n 1)
    local PASSWORD; PASSWORD=$(uuidgen)
    local LOCAL_IP; LOCAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null || echo "?")
    local OBFUS; OBFUS=$(uuidgen | cut -d'-' -f1)

    # 创建配置目录
    mkdir -p /etc/hysteria

    # 生成自签名证书 (非域名模式)
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
        -days 3650 -subj "/CN=localhost" 2>/dev/null

    # 优化版 server 配置
    # 针对中国移动 CMI 场景的关键参数:
    #   - up/down: 自适应带宽
    #   - udpIdleTimeout: 移动 UDP 限速环境下的超时控制
    #   - quic: InitialStreamReceiveWindow 等调大缓解 UDP 丢包
    cat > /etc/hysteria/config.yaml << EOF
listen: :${PORT}

# TLS
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

# 伪装
obfs:
  type: salamander
  salamander:
    password: "${OBFUS}"

# QUIC 参数 (针对 CMI 出口优化)
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 60s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false

# 带宽限制 (0 = 不限)
up: 0
down: 0

# UDP 超时
udpIdleTimeout: 60s

# 认证
auth:
  type: password
  password: "${PASSWORD}"

# 流量统计
trafficStats:
  listen: :${PORT2:-${PORT%?}2}

# ACL (可选: 只加速国际流量)
# acl: /etc/hysteria/acl.conf
EOF

    # 输出关键信息
    echo ""
    ok "===== Hysteria2 配置信息 (请保存) ====="
    echo "  服务器: ${LOCAL_IP}"
    echo "  端口:   ${PORT}"
    echo "  密码:   ${PASSWORD}"
    echo "  伪装:   ${OBFUS}"
    echo ""
    echo "  Hiddify/NekoRay 订阅链接:"
    echo "  hysteria2://${PASSWORD}@${LOCAL_IP}:${PORT}?insecure=1&obfs=salamander&obfs-password=${OBFUS}#HK-中转"
    echo ""
    echo "  QR Code (手机扫码直连):"
    qrencode -t ANSIUTF8 "hysteria2://${PASSWORD}@${LOCAL_IP}:${PORT}?insecure=1&obfs=salamander&obfs-password=${OBFUS}#HK-中转" 2>/dev/null || true
    echo ""

    # 保存到文件
    cat > /root/hy2-client.txt << CLIENTEOF
========== Hysteria2 客户端配置 ==========
服务器: ${LOCAL_IP}
端口:   ${PORT}
密码:   ${PASSWORD}
伪装:   ${OBFUS}
协议:   Hysteria2

Hiddify 导入链接 (复制到 Hiddify 粘贴):
hysteria2://${PASSWORD}@${LOCAL_IP}:${PORT}?insecure=1&obfs=salamander&obfs-password=${OBFUS}#HK-中转

Clash Meta (mihomo) 配置片段:
- name: "HK-中转"
  type: hysteria2
  server: ${LOCAL_IP}
  port: ${PORT}
  password: "${PASSWORD}"
  obfs: salamander
  obfs-password: "${OBFUS}"
  skip-cert-verify: true
CLIENTEOF
    ok "配置已保存到 /root/hy2-client.txt"
}

# ──────────────────────────────────────────────
# 阶段五: 创建 systemd 服务
# ──────────────────────────────────────────────
setup_service() {
    info "注册系统服务..."

    cat > /etc/systemd/system/hysteria2.service << 'EOF'
[Unit]
Description=Hysteria2 Proxy Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable hysteria2
    systemctl start hysteria2

    sleep 2
    if systemctl is-active --quiet hysteria2; then
        ok "Hysteria2 服务正在运行"
    else
        warn "服务启动失败，查看日志: journalctl -u hysteria2 -n 50 --no-pager"
    fi
}

# ──────────────────────────────────────────────
# 阶段六: 防火墙 & 优化
# ──────────────────────────────────────────────
setup_firewall() {
    info "配置防火墙..."

    # 放行 Hysteria2 端口
    if command -v ufw &>/dev/null; then
        local PORT; PORT=$(grep '^listen:' /etc/hysteria/config.yaml 2>/dev/null | awk -F': *' '{print $2}' || echo "10000")
        ufw allow "${PORT}/udp" 2>/dev/null || true
        ufw reload 2>/dev/null || true
        ok "UFW 已放行 UDP/${PORT}"
    fi

    # BBR 优化 (这台 VPS 也要开)
    info "启用 BBR + TCP 优化..."
    if ! grep -q 'bbr' /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null; then
        cat > /etc/sysctl.d/99-hy2-optimizer.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
EOF
        sysctl --system 2>/dev/null
        ok "VPS 端 TCP 优化已应用"
    fi
}

# ──────────────────────────────────────────────
# 主函数
# ──────────────────────────────────────────────
main() {
    printf '%b' "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     🌍 地球村 VPS 部署助手 — Hysteria2 自动安装             ║"
    echo "║     绕开 CMI 国际出口 · HK/SG 中转一键部署                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    printf '%b\n' "${NC}"

    check_system
    benchmark
    install_hysteria2
    configure_hysteria2
    setup_service
    setup_firewall

    printf '\n%b' "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     ✅ 部署完成                                               ║"
    echo "║     配置文件已保存到 /root/hy2-client.txt                     ║"
    echo "║     用 Hiddify 或 NekoRay 扫码导入即可                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    printf '%b\n' "${NC}"
    echo ""
    echo "  下一步:"
    echo "  1. 在本机打开 Hiddify → 添加 → 复制 link 粘贴"
    echo "  2. 测试: 全局代理后访问 https://speed.cloudflare.com/__down?bytes=104857600"
    echo "  3. 对比: 直连 13 Mbps vs 中转后速度"
    echo ""
}

main "$@"
