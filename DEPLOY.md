# EdgeTunnel 云服务器部署指南

本项目原本是为 Cloudflare Workers/Pages 设计的，现已适配可在传统云服务器上运行。

## 服务器信息

- **服务器 IP**: YOUR_SERVER_IP
- **默认端口**: 8080
- **默认管理密码**: 请通过 `ADMIN` 环境变量设置强密码

## 快速部署

### 方法一：自动部署脚本（推荐）

1. 确保本地安装了 `sshpass`：
   ```bash
   # Ubuntu/Debian
   sudo apt-get install sshpass

   # macOS
   brew install hudochenkov/sshpass/sshpass
   ```

2. 运行部署脚本：
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

部署脚本将自动完成以下操作：
- 创建部署包
- 上传到服务器
- 安装 Node.js 和 PM2
- 安装项目依赖
- 启动应用
- 配置防火墙

### 方法二：手动部署

如果无法使用自动部署脚本，可以手动部署：

1. **连接到服务器**：
   ```bash
   ssh root@YOUR_SERVER_IP
   ```

2. **安装 Node.js**（如果未安装）：
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
   apt-get install -y nodejs
   ```

3. **安装 PM2**（进程管理器）：
   ```bash
   npm install -g pm2
   ```

4. **上传项目文件**：
   ```bash
   # 在本地执行
   scp -r package.json server.js _worker.js ecosystem.config.cjs .env.example root@YOUR_SERVER_IP:/opt/myedgetunnel/
   ```

5. **在服务器上安装依赖并启动**：
   ```bash
   cd /opt/myedgetunnel
   npm install --production

   # 复制环境变量文件
   cp .env.example .env

   # 编辑环境变量（可选）
   nano .env

   # 启动应用
   pm2 start ecosystem.config.cjs
   pm2 save
   pm2 startup
   ```

6. **配置防火墙**：
   ```bash
   # UFW
   ufw allow 8080/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp

   # 或 firewalld
   firewall-cmd --permanent --add-port=8080/tcp
   firewall-cmd --permanent --add-port=80/tcp
   firewall-cmd --permanent --add-port=443/tcp
   firewall-cmd --reload
   ```

## 访问应用

部署完成后，可以通过以下地址访问：

- **主页**: http://YOUR_SERVER_IP:8080
- **管理后台**: http://YOUR_SERVER_IP:8080/admin
- **登录页面**: http://YOUR_SERVER_IP:8080/login

请通过 `ADMIN` 环境变量设置强密码后方可登录

## 配置 Nginx 反向代理（可选）

如果希望使用 80/443 端口，可以配置 Nginx：

1. **安装 Nginx**：
   ```bash
   apt-get install nginx
   ```

2. **配置 Nginx**：
   ```bash
   cp nginx/edgetunnel.conf /etc/nginx/sites-available/edgetunnel
   ln -s /etc/nginx/sites-available/edgetunnel /etc/nginx/sites-enabled/
   ```

3. **测试并重启 Nginx**：
   ```bash
   nginx -t
   systemctl restart nginx
   ```

配置完成后，可以通过 http://YOUR_SERVER_IP 访问（不需要端口号）。

## 环境变量配置

编辑 `/opt/myedgetunnel/.env` 文件可以修改以下配置：

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| PORT | 服务端口 | 8080 |
| ADMIN | 管理员密码 | 必须通过环境变量设置强密码 |
| KEY | 快速订阅密钥 | - |
| HOST | 强制固定伪装域名 | - |
| UUID | 强制固定UUID | - |
| PATH | 强制固定路径 | / |
| PROXYIP | 更换默认内置PROXYIP | - |
| URL | 主页反代伪装 | - |
| GO2SOCKS5 | 强制使用socks5访问名单 | - |

修改环境变量后，需要重启应用：
```bash
pm2 restart myedgetunnel
```

## 常用管理命令

```bash
# 查看应用状态
pm2 status

# 查看日志
pm2 logs myedgetunnel

# 实时日志
pm2 logs myedgetunnel --lines 100

# 重启应用
pm2 restart myedgetunnel

# 停止应用
pm2 stop myedgetunnel

# 启动应用
pm2 start myedgetunnel

# 查看详细信息
pm2 show myedgetunnel

# 监控资源使用
pm2 monit
```

## 更新部署

当需要更新代码时：

```bash
# 方法一：使用部署脚本
./deploy.sh

# 方法二：手动更新
ssh root@YOUR_SERVER_IP
cd /opt/myedgetunnel
# 上传新文件后
npm install --production
pm2 restart myedgetunnel
```

## 故障排查

### 1. 应用无法启动

```bash
# 查看错误日志
pm2 logs myedgetunnel --err

# 检查端口占用
netstat -tunlp | grep 8080

# 手动启动查看错误
cd /opt/myedgetunnel
node server.js
```

### 2. 无法访问

- 检查防火墙配置
- 检查应用是否运行：`pm2 status`
- 检查端口是否监听：`netstat -tunlp | grep 8080`
- 查看日志：`pm2 logs myedgetunnel`

### 3. WebSocket 连接失败

- 如果使用 Nginx，确保 WebSocket 配置正确
- 检查防火墙是否允许 WebSocket 连接

## 安全建议

1. **修改默认密码**：登录管理后台后立即修改管理员密码
2. **配置 HTTPS**：使用 Let's Encrypt 免费证书
3. **限制访问**：配置防火墙规则，仅允许必要的 IP 访问
4. **定期更新**：保持系统和依赖包更新
5. **备份配置**：定期备份 `.env` 文件和 KV 数据

## 配置 HTTPS（可选）

使用 Let's Encrypt 免费证书：

```bash
# 安装 Certbot
apt-get install certbot python3-certbot-nginx

# 获取证书（将 your-domain.com 替换为你的域名）
certbot --nginx -d your-domain.com

# 证书会自动续期
```

## 性能优化

1. **使用集群模式**：
   编辑 `ecosystem.config.cjs`，将 `instances` 改为 `max` 或具体数字

2. **启用 Nginx 缓存**：
   在 Nginx 配置中添加缓存规则

3. **监控资源使用**：
   ```bash
   pm2 install pm2-logrotate  # 日志轮转
   pm2 set pm2-logrotate:max_size 10M
   ```

## 卸载

如需卸载应用：

```bash
ssh root@YOUR_SERVER_IP
pm2 delete myedgetunnel
pm2 save
rm -rf /opt/myedgetunnel
```

## 技术支持

如遇到问题，请查看：
- 项目原始文档：https://github.com/cmliu/edgetunnel
- PM2 文档：https://pm2.keymetrics.io/
- Nginx 文档：https://nginx.org/en/docs/

---

**注意**：本项目仅供学习和研究使用，请遵守当地法律法规。
