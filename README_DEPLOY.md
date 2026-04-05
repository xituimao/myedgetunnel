# 云服务器部署说明

本文档说明如何将 EdgeTunnel 项目部署到云服务器。

## 目录

- [快速开始](#快速开始)
- [部署方式](#部署方式)
- [服务器配置](#服务器配置)
- [环境变量](#环境变量)
- [常用命令](#常用命令)
- [故障排查](#故障排查)

## 快速开始

### 前提条件

- 云服务器: YOUR_SERVER_IP
- SSH 访问权限
- Node.js 18+ (部署脚本会自动安装)

### 一键部署

```bash
# 方式 1: 使用自动部署脚本 (需要 sshpass)
./deploy.sh

# 方式 2: 使用手动部署脚本 (交互式)
./deploy-manual.sh
```

## 部署方式

### 方式一: 自动部署 (推荐)

**前提**: 安装 sshpass

```bash
# Ubuntu/Debian
sudo apt-get install sshpass

# macOS
brew install hudochenkov/sshpass/sshpass
```

**执行部署**:

```bash
chmod +x deploy.sh
./deploy.sh
```

脚本将自动完成:
- ✅ 创建部署包
- ✅ 上传到服务器
- ✅ 安装 Node.js 和 PM2
- ✅ 安装项目依赖
- ✅ 启动应用
- ✅ 配置防火墙
- ✅ 设置开机自启

### 方式二: 手动部署

**步骤 1: 连接到服务器**

```bash
ssh root@YOUR_SERVER_IP
```

**步骤 2: 安装 Node.js 和 PM2**

```bash
# 安装 Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 安装 PM2
npm install -g pm2
```

**步骤 3: 创建部署目录**

```bash
mkdir -p /opt/myedgetunnel
cd /opt/myedgetunnel
```

**步骤 4: 上传文件**

在本地执行:

```bash
# 打包项目文件
tar -czf myedgetunnel.tar.gz package.json server.js _worker.js ecosystem.config.cjs .env.example nginx/

# 上传到服务器
scp myedgetunnel.tar.gz root@YOUR_SERVER_IP:/opt/myedgetunnel/
```

**步骤 5: 在服务器上解压并安装**

```bash
cd /opt/myedgetunnel
tar -xzf myedgetunnel.tar.gz

# 安装依赖
npm install --production

# 复制环境变量文件
cp .env.example .env

# 编辑环境变量 (可选)
nano .env
```

**步骤 6: 启动应用**

```bash
# 使用 PM2 启动
pm2 start ecosystem.config.cjs

# 保存 PM2 配置
pm2 save

# 设置开机自启
pm2 startup
```

**步骤 7: 配置防火墙**

```bash
# UFW (Ubuntu)
ufw allow 8080/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# firewalld (CentOS/RHEL)
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload
```

## 服务器配置

### 访问地址

部署完成后可通过以下地址访问:

| 地址 | 说明 |
|------|------|
| http://YOUR_SERVER_IP:8080 | 主页 |
| http://YOUR_SERVER_IP:8080/admin | 管理后台 |
| http://YOUR_SERVER_IP:8080/login | 登录页面 |

### 默认配置

| 配置项 | 值 |
|--------|------|
| 端口 | 8080 |
| 管理密码 | 通过 ADMIN 环境变量设置 |
| 部署目录 | /opt/myedgetunnel |

**⚠️ 重要**: 首次登录后请立即修改管理员密码!

### 使用 Nginx 反向代理 (可选)

如果希望通过 80/443 端口访问:

```bash
# 安装 Nginx
apt-get install nginx

# 复制配置文件
cp /opt/myedgetunnel/nginx/edgetunnel.conf /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/edgetunnel.conf /etc/nginx/sites-enabled/

# 测试配置
nginx -t

# 重启 Nginx
systemctl restart nginx
```

配置后可通过 http://YOUR_SERVER_IP 访问 (无需端口号)。

## 环境变量

编辑 `/opt/myedgetunnel/.env` 文件配置环境变量:

```bash
# 服务端口
PORT=8080

# 管理员密码 (必填)
ADMIN=your-strong-password

# 快速订阅密钥 (可选)
KEY=your-secret-key

# 其他可选配置
HOST=
UUID=
PATH=/
PROXYIP=
URL=
GO2SOCKS5=
```

### 环境变量说明

| 变量名 | 说明 | 必填 | 默认值 |
|--------|------|------|--------|
| PORT | 服务端口 | 否 | 8080 |
| ADMIN | 管理员密码 | 是 | 必须设置强密码 |
| KEY | 快速订阅密钥 | 否 | - |
| HOST | 强制固定伪装域名 | 否 | - |
| UUID | 强制固定UUID | 否 | - |
| PATH | 强制固定路径 | 否 | / |
| PROXYIP | 更换默认内置PROXYIP | 否 | - |
| URL | 主页反代伪装 | 否 | - |
| GO2SOCKS5 | 强制使用socks5访问名单 | 否 | - |

修改环境变量后需要重启应用:

```bash
pm2 restart myedgetunnel
```

## 常用命令

### PM2 进程管理

```bash
# 查看应用状态
pm2 status

# 查看日志
pm2 logs myedgetunnel

# 查看最近 100 行日志
pm2 logs myedgetunnel --lines 100

# 清除日志
pm2 flush

# 重启应用
pm2 restart myedgetunnel

# 停止应用
pm2 stop myedgetunnel

# 启动应用
pm2 start myedgetunnel

# 删除应用
pm2 delete myedgetunnel

# 查看详细信息
pm2 show myedgetunnel

# 监控资源使用
pm2 monit
```

### 系统管理

```bash
# 查看端口占用
netstat -tunlp | grep 8080

# 查看进程
ps aux | grep node

# 查看系统资源
htop
# 或
top

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

## 更新部署

### 方式 1: 使用部署脚本

```bash
# 在本地执行
./deploy.sh
```

### 方式 2: 手动更新

```bash
# 1. 连接到服务器
ssh root@YOUR_SERVER_IP

# 2. 备份当前版本 (可选)
cd /opt
tar -czf myedgetunnel-backup-$(date +%Y%m%d).tar.gz myedgetunnel/

# 3. 上传新文件并重启
cd /opt/myedgetunnel
# 上传新的代码文件后...
npm install --production
pm2 restart myedgetunnel
```

## 故障排查

### 1. 应用无法启动

```bash
# 查看错误日志
pm2 logs myedgetunnel --err

# 查看所有日志
pm2 logs myedgetunnel

# 手动启动查看详细错误
cd /opt/myedgetunnel
node server.js
```

### 2. 端口被占用

```bash
# 查看端口占用
netstat -tunlp | grep 8080

# 杀死占用进程
kill -9 <PID>

# 或修改端口
nano /opt/myedgetunnel/.env
# 修改 PORT=8081
pm2 restart myedgetunnel
```

### 3. 无法访问

**检查清单**:

1. 应用是否运行: `pm2 status`
2. 端口是否监听: `netstat -tunlp | grep 8080`
3. 防火墙是否允许: `ufw status` 或 `firewall-cmd --list-all`
4. 查看日志: `pm2 logs myedgetunnel`

**常见解决方案**:

```bash
# 重启应用
pm2 restart myedgetunnel

# 检查防火墙
ufw allow 8080/tcp

# 查看详细错误
pm2 logs myedgetunnel --err --lines 50
```

### 4. WebSocket 连接失败

如果使用 Nginx，确保 WebSocket 配置正确:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

### 5. 内存不足

```bash
# 查看内存使用
free -h

# 重启应用释放内存
pm2 restart myedgetunnel

# 限制应用内存使用
# 编辑 ecosystem.config.cjs
max_memory_restart: '300M'  # 降低内存限制
```

## 性能优化

### 1. 使用集群模式

编辑 `/opt/myedgetunnel/ecosystem.config.cjs`:

```javascript
module.exports = {
  apps: [{
    name: 'myedgetunnel',
    script: './server.js',
    instances: 'max',  // 使用所有 CPU 核心
    exec_mode: 'cluster',
    // ...
  }]
};
```

重启应用:

```bash
pm2 restart myedgetunnel
```

### 2. 启用日志轮转

```bash
# 安装日志轮转模块
pm2 install pm2-logrotate

# 配置
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 10
pm2 set pm2-logrotate:compress true
```

### 3. 监控和告警

```bash
# 安装 PM2 Plus (可选)
pm2 link <secret> <public>

# 查看实时监控
pm2 monit
```

## 安全建议

1. **修改默认密码**: 登录后台后立即修改管理员密码
2. **配置 HTTPS**: 使用 Let's Encrypt 免费证书
3. **限制访问**: 配置防火墙规则
4. **定期更新**: 保持系统和依赖更新
5. **备份数据**: 定期备份配置和数据
6. **监控日志**: 定期检查应用日志

### 配置 HTTPS (推荐)

```bash
# 安装 Certbot
apt-get install certbot python3-certbot-nginx

# 获取证书 (替换为你的域名)
certbot --nginx -d your-domain.com

# 证书会自动续期
```

## 备份和恢复

### 备份

```bash
# 备份整个应用
cd /opt
tar -czf myedgetunnel-backup-$(date +%Y%m%d).tar.gz myedgetunnel/

# 仅备份配置
cp /opt/myedgetunnel/.env /opt/myedgetunnel-env-backup-$(date +%Y%m%d)
```

### 恢复

```bash
# 恢复整个应用
cd /opt
tar -xzf myedgetunnel-backup-20260310.tar.gz

# 恢复配置
cp /opt/myedgetunnel-env-backup-20260310 /opt/myedgetunnel/.env

# 重启应用
cd /opt/myedgetunnel
pm2 restart myedgetunnel
```

## 卸载

如需完全卸载应用:

```bash
# 停止并删除 PM2 应用
pm2 delete myedgetunnel
pm2 save

# 删除应用文件
rm -rf /opt/myedgetunnel

# 删除 Nginx 配置 (如果有)
rm /etc/nginx/sites-enabled/edgetunnel.conf
rm /etc/nginx/sites-available/edgetunnel.conf
systemctl restart nginx
```

## 技术支持

- **原项目文档**: https://github.com/cmliu/edgetunnel
- **PM2 文档**: https://pm2.keymetrics.io/
- **Node.js 文档**: https://nodejs.org/
- **Nginx 文档**: https://nginx.org/

## 常见问题

### Q: 如何修改端口?

编辑 `.env` 文件修改 `PORT` 变量，然后重启应用。

### Q: 如何查看实时日志?

使用 `pm2 logs myedgetunnel` 命令。

### Q: 应用重启后配置丢失?

确保修改了 `.env` 文件而不是直接修改环境变量。

### Q: 如何配置多个实例?

编辑 `ecosystem.config.cjs` 文件，将 `instances` 设置为需要的数量。

---

**注意**: 本项目仅供学习和研究使用，请遵守当地法律法规。
