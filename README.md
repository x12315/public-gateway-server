# VPS 部署说明

## 前置条件

- Debian 12/13 (Bookworm/Trixie)，最小化安装
- 已开放端口：22 (SSH)、443 (HTTPS)、12345 (DERP)、7000 (frp)、3478 (STUN)
- 一个域名，DNS 已解析到 VPS IP（通配 `*` 记录）
- Tailscale 账号已登录

## 一键部署

```bash
sudo apt install git -y
git clone https://github.com/<your-username>/server-infra.git
cd server-infra/vps-config
bash bootstrap.sh
```

脚本执行流程：
1. `apt update && upgrade` 更新系统
2. 安装 Tailscale 并等待你完成登录
3. 安装 Go → 编译 DERP → 写入 systemd → 启动
4. 安装 Caddy → 写入 `/etc/caddy/Caddyfile` → 重载
5. 下载 frp → 写入 systemd → 启动
6. 输出验证命令

## 手动验证

```bash
tailscale status                                  # 三端 online
systemctl status derper caddy frps                # 全 active
journalctl -u derper -n 20                        # DERP 日志
journalctl -u caddy -n 20                         # Caddy 日志
curl https://yourdomain.com                       # HTTPS 响应
```

## 添加新服务

### Web 服务（自用，Tailscale only）

编辑 `/etc/caddy/Caddyfile`：

```caddyfile
home.yourdomain.com {
    reverse_proxy <家里主机-tailscale-ip>:<端口>
}
```

```bash
sudo systemctl reload caddy
```

### 游戏端口转发（给朋友）

编辑 `/etc/frp/frps.toml`，加：

```toml
[[proxies]]
name = "minecraft"
type = "udp"
localIP = "127.0.0.1"
localPort = 25565
remotePort = 25565
```

> 这段配置在**家里主机**的 `/etc/frp/frpc.toml` 里，VPS 端只需保证端口不被防火墙挡。

## 迁移到新 VPS

### 迁移有状态数据

```bash
# 在笔记本上执行
# 1. 从旧 VPS 拉状态
ssh old-vps "sudo tar czf /tmp/vps-state.tar.gz /var/lib/tailscale/tailscaled.state /var/lib/caddy/"
scp old-vps:/tmp/vps-state.tar.gz /tmp/

# 2. 推到新 VPS
scp /tmp/vps-state.tar.gz new-vps:/tmp/
ssh new-vps "sudo tar xzf /tmp/vps-state.tar.gz -C / && sudo systemctl restart tailscaled caddy"
```

### 在新 VPS 上重跑部署

```bash
git clone <this-repo>
cd vps-config && bash bootstrap.sh
```

| 组件 | 有状态数据 | 不迁的影响 |
|------|-----------|-----------|
| Tailscale | `/var/lib/tailscale/tailscaled.state` | 新 VPS 在 tailnet 里是"新设备"，需重配 ACL/tag |
| Caddy | `/var/lib/caddy/` (TLS 证书) | Let's Encrypt 自动重签，频繁重签可能触发速率限制 |
| DERP | 无状态 | — |
| frp | 无状态 | — |
