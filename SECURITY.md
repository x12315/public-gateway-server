# VPS 安全基线

## 用户设计

| 用户 | 类型 | 用途 |
|------|------|------|
| `deploy` | 普通用户 + sudo | 你 SSH 进来、跑 bootstrap、日常管理 |
| `caddy` | 系统用户 (nologin) | Caddy 进程降权，apt 包自动创建，别动它 |

不给 DERP 和 frps 单独建用户——Go 静态二进制攻击面极小，不值得加 systemd `User=` 的 debug 成本。

## 初始化（拿到新 VPS 第一件事）

```bash
# 1. 建日常用户
adduser deploy
usermod -aG sudo deploy

# 2. 拷 SSH key
cp -r ~/.ssh /home/deploy/
chown -R deploy:deploy /home/deploy/.ssh

# 3. 另开终端验证 deploy 能登，然后回来关 root SSH
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload sshd

# 4. 验证 root 登不进了
ssh root@<vps-ip>  # 应该被拒
```

## SSH 加固（/etc/ssh/sshd_config）

```ini
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

## 防火墙

```bash
# 只开用到的端口
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp       # SSH
ufw allow 443/tcp      # Caddy HTTPS
ufw allow 12345        # DERP
ufw allow 7000         # frp
ufw allow 3478/udp     # STUN
ufw enable
ufw status verbose
```

## 自动更新

```bash
# 安全补丁无人值守更新，不动软件大版本
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

## 日常使用

```bash
ssh deploy@<vps-ip>    # 日常登录
sudo apt update && sudo apt upgrade -y   # 手动更新
```
