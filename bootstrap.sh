#!/bin/bash
# If invoked via sh/dash (common when script has no execute bit), re-exec with bash.
# This script uses bashisms (echo -e, &>) that break under dash.
if [ -z "${BASH_VERSION:-}" ]; then
    exec /bin/bash "$0" "$@"
fi
set -e

# ============================================================
# VPS 一键部署脚本
# 安装 Tailscale + 自建 DERP + Caddy + frp server
# 使用前请确认：
#   1. 域名 DNS 已指向本机 IP
#   2. /files/ 下的配置文件已按实际值修改
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

step()  { echo -e "${BLUE}==>${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
die()   { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# -------------------------------------------------------------------
step "更新系统"
# -------------------------------------------------------------------
sudo apt update && sudo apt upgrade -y
ok "系统已更新"

# -------------------------------------------------------------------
step "安装 Tailscale"
# -------------------------------------------------------------------
if ! command -v tailscale &> /dev/null; then
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg" \
        | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).tailscale-keyring.list" \
        | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null
    sudo apt update && sudo apt install tailscale -y
fi
sudo tailscale up
echo ""
echo -e "${GREEN}>>> 请在浏览器中完成 Tailscale 登录，确认 VPS 在 admin console 里 online 后按回车继续${NC}"
read -r REPLY
ok "Tailscale 已就绪"

# -------------------------------------------------------------------
step "安装 Go 并编译 DERP"
# -------------------------------------------------------------------
if ! command -v go &> /dev/null; then
    sudo apt install golang-go -y
fi
if [ ! -f /root/go/bin/derper ]; then
    go install tailscale.com/cmd/derper@latest
fi
sudo cp "$(dirname "$0")/files/derper.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now derper
ok "DERP 已启动"

# -------------------------------------------------------------------
step "安装 Caddy"
# -------------------------------------------------------------------
if ! command -v caddy &> /dev/null; then
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update && sudo apt install caddy -y
fi
sudo cp "$(dirname "$0")/files/Caddyfile" /etc/caddy/Caddyfile
sudo systemctl reload caddy
ok "Caddy 已重载配置"

# -------------------------------------------------------------------
step "安装 frp server"
# -------------------------------------------------------------------
if ! command -v frps &> /dev/null; then
    FRP_VER=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest \
        | grep tag_name | cut -d '"' -f 4)
    TMPDIR=$(mktemp -d)
    wget -qO- "https://github.com/fatedier/frp/releases/download/${FRP_VER}/frp_${FRP_VER#v}_linux_amd64.tar.gz" \
        | sudo tar xz -C "$TMPDIR" --strip-components=1
    sudo cp "$TMPDIR/frps" /usr/local/bin/
    rm -rf "$TMPDIR"
fi
sudo mkdir -p /etc/frp
sudo cp "$(dirname "$0")/files/frps.toml" /etc/frp/
sudo cp "$(dirname "$0")/files/frps.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now frps
ok "frp server 已启动"

# -------------------------------------------------------------------
# 完成
# -------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  部署完成${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "验证命令:"
echo "  tailscale status"
echo "  systemctl status derper caddy frps"
echo "  journalctl -u derper -n 20"
echo "  journalctl -u caddy  -n 20"
echo "  journalctl -u frps   -n 20"
echo "  curl https://yourdomain.com"
