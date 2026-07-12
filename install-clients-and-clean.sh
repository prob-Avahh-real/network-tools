#!/usr/bin/env bash
# =============================================================================
# 代理客户端安装 & Clash 清理助手 for macOS
# =============================================================================
# 用法:
#   bash ~/projects/network-tools/install-clients-and-clean.sh
# =============================================================================

# 不启用 errexit — 每一步独立，失败不影响后续
set -u

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()   { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
ok()    { printf "  ${GREEN}✔${NC} %s\n" "$*"; }
skip()  { printf "  ${CYAN}─${NC} %s\n" "$*"; }

DOWNLOAD_DIR="${HOME}/Downloads"

# ────────────────────────────────────────────────────
# 辅助: 检查是否已安装 (Applications 下存在同名 .app)
# ────────────────────────────────────────────────────
is_installed() {
  local app_name="$1"
  [ -d "/Applications/${app_name}.app" ]
}

# ────────────────────────────────────────────────────
# 辅助: 检查是否已下载 (Downloads 下存在文件)
# ────────────────────────────────────────────────────
is_downloaded() {
  local filename="$1"
  [ -f "${DOWNLOAD_DIR}/${filename}" ]
}

# ────────────────────────────────────────────────────
# 辅助: 下载文件，尝试多个 URL
# ────────────────────────────────────────────────────
try_download() {
  local name="$1"
  local output="$2"
  shift 2
  local urls=("$@")

  for url in "${urls[@]}"; do
    info "尝试 ${name}: $(basename "$url")"
    if curl -fL --connect-timeout 10 --retry 2 -sS "$url" -o "$output" 2>/dev/null; then
      local size
      size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo "?")
      if [ "$size" != "?" ] && [ "$size" -lt 1000 ]; then
        warn "文件太小 ($size bytes)，可能不是有效文件，继续尝试下一链接..."
        continue
      fi
      ok "${name} 已下载: ${output} (${size} bytes)"
      return 0
    else
      warn "  → 失败"
    fi
  done

  return 1
}

# ────────────────────────────────────────────────────
# 1. Hiddify — 推荐 App Store
# ────────────────────────────────────────────────────
download_hiddify() {
  echo ""
  echo "========== Hiddify =========="

  # 预检查: 已安装?
  if is_installed "Hiddify"; then
    skip "Hiddify.app 已安装在 /Applications，跳过下载"
    return 0
  fi

  # 预检查: 已下载?
  if is_downloaded "hiddify-macos.zip"; then
    skip "hiddify-macos.zip 已在 ~/Downloads，跳过下载"
    return 0
  fi

  info "推荐从 App Store 安装:"
  info "  https://apps.apple.com/app/hiddify-proxy-vpn/id6596777532"
  info "（自动更新，省心）"
  echo ""

  info "同时尝试从 GitHub 下载最新版..."

  # 尝试多个已知的 release 标签和文件名
  local output="${DOWNLOAD_DIR}/hiddify-macos.zip"
  local tag
  tag=$(curl -sfL https://api.github.com/repos/hiddify/hiddify-next/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

  local urls=()
  if [ -n "$tag" ]; then
    urls+=(
      "https://github.com/hiddify/hiddify-next/releases/download/${tag}/hiddify-macos-universal.zip"
      "https://github.com/hiddify/hiddify-next/releases/download/${tag}/Hiddify-MacOS.dmg"
      "https://github.com/hiddify/hiddify-next/releases/download/${tag}/Hiddify-MacOS-Installer.pkg"
    )
  fi
  # 回退: 直接 latest (可能不工作)
  urls+=(
    "https://github.com/hiddify/hiddify-next/releases/latest/download/hiddify-macos-universal.zip"
    "https://github.com/hiddify/hiddify-app/releases/latest/download/Hiddify-MacOS.dmg"
  )
  # 回退: 已知版本的直接链接
  urls+=(
    "https://github.com/hiddify/hiddify-next/releases/download/v2.0.5/hiddify-macos-universal.zip"
    "https://github.com/hiddify/hiddify-next/releases/download/v2.0.4/hiddify-macos-universal.zip"
  )

  try_download "Hiddify" "$output" "${urls[@]}" || {
    warn "所有 GitHub 链接均失败"
    info "请从 App Store 安装: https://apps.apple.com/app/hiddify-proxy-vpn/id6596777532"
  }
}

# ────────────────────────────────────────────────────
# 2. Throne (NekoRay 继任者)
# ────────────────────────────────────────────────────
download_throne() {
  echo ""
  echo "========== Throne (NekoRay 继任者) =========="

  # 预检查: 已安装?
  if is_installed "Throne"; then
    skip "Throne.app 已安装在 /Applications，跳过下载"
    return 0
  fi

  # 预检查: 已下载?
  if is_downloaded "Throne-macOS.zip"; then
    skip "Throne-macOS.zip 已在 ~/Downloads，跳过下载"
    return 0
  fi

  info "支持 Hysteria2 · macOS Intel + Apple Silicon"

  local output="${DOWNLOAD_DIR}/Throne-macOS.zip"

  # 获取最新 tag
  local tag
  tag=$(curl -sfL https://api.github.com/repos/throneproj/Throne/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

  local urls=()
  if [ -n "$tag" ]; then
    urls+=(
      "https://github.com/throneproj/Throne/releases/download/${tag}/Throne-macOS.zip"
      "https://github.com/throneproj/Throne/releases/download/${tag}/Throne-macos.zip"
    )
  fi
  urls+=(
    "https://github.com/throneproj/Throne/releases/download/v1.1.2/Throne-macOS.zip"
    "https://github.com/throneproj/Throne/releases/download/v1.1.1/Throne-macOS.zip"
  )

  try_download "Throne" "$output" "${urls[@]}" || {
    warn "Throne 下载失败"
    info "一键安装脚本（推荐）:"
    info "  bash <(curl -fsSL https://raw.githubusercontent.com/ohmydevops/nekoray-installer/main/throne-mac.sh)"
    info "或手动下载: https://github.com/throneproj/Throne/releases"
  }
}

# ────────────────────────────────────────────────────
# 3. V2rayU
# ────────────────────────────────────────────────────
download_v2rayu() {
  echo ""
  echo "========== V2rayU =========="

  # 预检查: 已安装?
  if is_installed "V2rayU"; then
    skip "V2rayU.app 已安装在 /Applications，跳过下载"
    return 0
  fi

  local arch="64"
  [[ "$(uname -m)" == "arm64" ]] && arch="arm64"

  # 预检查: 已下载?
  if is_downloaded "V2rayU-${arch}.dmg"; then
    skip "V2rayU-${arch}.dmg 已在 ~/Downloads，跳过下载"
    return 0
  fi

  local tag
  tag=$(curl -sfL https://api.github.com/repos/yanue/V2rayU/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

  local output="${DOWNLOAD_DIR}/V2rayU-${arch}.dmg"
  local urls=()
  if [ -n "$tag" ]; then
    urls+=("https://github.com/yanue/V2rayU/releases/download/${tag}/V2rayU-${arch}.dmg")
  fi
  urls+=(
    "https://github.com/yanue/V2rayU/releases/download/v4.2.5/V2rayU-${arch}.dmg"
    "https://github.com/yanue/V2rayU/releases/download/v4.2.3/V2rayU-${arch}.dmg"
  )

  # 注意: 这里用 eval 让变量展开
  eval "try_download 'V2rayU' '$output' ${urls[*]}" || {
    warn "V2rayU 下载失败"
    info "Homebrew 安装: brew install --cask v2rayu"
    info "手动下载: https://github.com/yanue/V2rayU/releases"
  }
}

# ────────────────────────────────────────────────────
# 4. Furious GUI
# ────────────────────────────────────────────────────
download_furious() {
  echo ""
  echo "========== Furious GUI =========="

  # 预检查: 已通过 pip 安装?
  if command -v furious &>/dev/null; then
    skip "Furious 已通过 pip 安装，跳过"
    return 0
  fi

  # 预检查: 已安装的 .app (如果存在)
  if is_installed "Furious"; then
    skip "Furious.app 已安装在 /Applications，跳过下载"
    return 0
  fi

  info "基于 PySide6 · 支持 Xray-core + Hysteria2"

  # 预检查: 已下载?
  local arch="x86_64"
  [[ "$(uname -m)" == "arm64" ]] && arch="arm64"

  if is_downloaded "Furious-macOS-${arch}.zip"; then
    skip "Furious-macOS-${arch}.zip 已在 ~/Downloads，跳过下载"
    return 0
  fi

  # 优先 pip (最可靠)
  if command -v pip3 &>/dev/null; then
    info "尝试 pip3 安装..."
    pip3 install Furious-GUI --break-system-packages 2>/dev/null || pip3 install Furious-GUI 2>/dev/null
    if command -v furious &>/dev/null; then
      ok "Furious GUI 已通过 pip 安装"
      info "运行: furious"
      return 0
    fi
    warn "pip 安装失败，尝试下载 DMG..."
  fi

  # 从 GitHub 下载
  local tag
  tag=$(curl -sfL https://api.github.com/repos/LorenEteval/Furious/releases/latest 2>/dev/null \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4 || echo "")

  local output="${DOWNLOAD_DIR}/Furious-macOS-${arch}.zip"
  local urls=()
  if [ -n "$tag" ]; then
    urls+=(
      "https://github.com/LorenEteval/Furious/releases/download/${tag}/Furious-macOS-${arch}.zip"
      "https://github.com/LorenEteval/Furious/releases/download/${tag}/Furious-${tag}-macOS-${arch}.dmg"
      "https://github.com/LorenEteval/Furious/releases/download/${tag}/Furious-macOS-${arch}.dmg"
    )
  fi
  # 已知版本回退
  urls+=(
    "https://github.com/LorenEteval/Furious/releases/download/0.6.3/Furious-macOS-arm64.zip"
    "https://github.com/LorenEteval/Furious/releases/download/0.6.3/Furious-macOS-x86_64.zip"
    "https://github.com/LorenEteval/Furious/releases/download/0.2.7/Furious-0.2.7-macos-x86_64.dmg"
  )

  eval "try_download 'Furious' '$output' ${urls[*]}" || {
    warn "Furious 下载失败"
    info "pip 安装: pip3 install Furious-GUI"
    info "手动下载: https://github.com/LorenEteval/Furious/releases"
  }
}

# ────────────────────────────────────────────────────
# 5. 卸载 Clash 系列 app
# ────────────────────────────────────────────────────
uninstall_clash() {
  echo ""
  echo "========== 卸载 Clash 系列 app =========="

  local apps=(
    "/Applications/ClashX.app"
    "/Applications/ClashX Pro.app"
    "/Applications/ClashX-Meta.app"
    "/Applications/Clash Meta.app"
    "/Applications/Clash Verge.app"
    "/Applications/Clash Nyanpasu.app"
    "/Applications/Stash.app"
    "/Applications/Clash for Windows.app"
  )

  # 先扫描，统计实际存在的
  local existing=()
  for app in "${apps[@]}"; do
    [ -d "$app" ] && existing+=("$app")
  done

  # 额外扫描
  while IFS= read -r -d '' p; do
    if echo "$(basename "$p")" | grep -qiE "clash|stash"; then
      [ -d "$p" ] && existing+=("$p")
    fi
  done < <(find /Applications -maxdepth 2 -type d \( -iname "*clash*" -o -iname "*stash*" \) -print0 2>/dev/null || true)

  # 去重
  local found=()
  for e in "${existing[@]}"; do
    local dup=0
    for f in "${found[@]}"; do
      [ "$f" = "$e" ] && { dup=1; break; }
    done
    [ "$dup" -eq 0 ] && found+=("$e")
  done

  if [ "${#found[@]}" -eq 0 ]; then
    info "未发现任何 Clash 系列 app，无需卸载"
    return 0
  fi

  warn "发现 ${#found[@]} 个 Clash 系列 app:"
  for app in "${found[@]}"; do
    echo "    $app"
  done
  echo ""

  local deleted=0
  for app in "${found[@]}"; do
    sudo rm -rf "$app" 2>/dev/null && { ok "已删除: $app"; ((deleted++)); } || err "删除失败: $app (需要 sudo 权限)"
  done

  ok "共删除 $deleted / ${#found[@]} 个"
}

# ────────────────────────────────────────────────────
# 6. 清理 Clash 残留
# ────────────────────────────────────────────────────
clean_clash() {
  echo ""
  echo "========== 清理 Clash 残留 =========="

  local paths=(
    "${HOME}/.config/clash"
    "${HOME}/Library/Application Support/com.west2online.ClashXPro"
    "${HOME}/Library/Preferences/com.west2online.ClashXPro.plist"
    "${HOME}/Library/WebKit/com.west2online.ClashXPro"
    "${HOME}/Library/HTTPStorages/com.west2online.ClashXPro"
    "${HOME}/Library/HTTPStorages/com.west2online.ClashXPro.binarycookies"
    "${HOME}/Library/Logs/ClashX Pro"
    "${HOME}/Library/Mobile Documents/iCloud~com~west2online~ClashX"
    "${HOME}/Library/Preferences/com.clashx.ClashX.plist"
    "${HOME}/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
    "${HOME}/Library/Preferences/io.github.clash-verge-rev.clash-verge-rev.plist"
    "${HOME}/Library/Application Support/Clash Nyanpasu"
  )

  local n=0
  for p in "${paths[@]}"; do
    [ -e "$p" ] || continue
    rm -rf "$p" 2>/dev/null && { ok "已清理: $p"; ((n++)); } || warn "需手动删: $p"
  done

  [ "$n" -eq 0 ] && info "无残留" || ok "共清理 $n 项"
}

# ────────────────────────────────────────────────────
# 主函数
# ────────────────────────────────────────────────────
main() {
  printf '%b' "${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║  代理客户端下载 & Clash 清理助手              ║"
  echo "╚══════════════════════════════════════════════╝"
  printf '%b\n' "${NC}"

  download_hiddify
  download_throne
  download_v2rayu
  download_furious
  uninstall_clash
  clean_clash

  echo ""
  printf '%b' "${GREEN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ✅ 执行完成                                   ║"
  echo "║                                               ║"
  echo "║  下载的文件在 ~/Downloads/ 下                   ║"
  echo "║  安装后打开 Hiddify 粘贴 Hysteria2 链接即可     ║"
  echo "╚══════════════════════════════════════════════╝"
  printf '%b\n' "${NC}"
}

main "$@"
