#!/bin/bash

# EdgeTunnel 手动部署脚本（无需 sshpass）
# 目标服务器: 69.5.7.220

set -e

echo "=========================================="
echo "EdgeTunnel 手动部署指南"
echo "=========================================="
echo ""

# 配置
SERVER_IP="69.5.7.220"
SERVER_USER="root"
DEPLOY_DIR="/opt/myedgetunnel"
APP_NAME="myedgetunnel"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}本脚本将引导您完成手动部署${NC}"
echo -e "${YELLOW}请按照提示逐步操作${NC}"
echo ""

# 步骤 1
echo -e "${GREEN}========== 步骤 1/7: 创建部署包 ==========${NC}"
echo "正在创建部署包..."

TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/$APP_NAME"

cp package.json "$TEMP_DIR/$APP_NAME/"
cp server.js "$TEMP_DIR/$APP_NAME/"
cp _worker.js "$TEMP_DIR/$APP_NAME/"
cp ecosystem.config.cjs "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true
cp .env.example "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true
cp -r nginx "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true

cd "$TEMP_DIR"
tar -czf "${APP_NAME}.tar.gz" "$APP_NAME"
cd - > /dev/null

echo -e "${GREEN}✓ 部署包已创建: $TEMP_DIR/${APP_NAME}.tar.gz${NC}"
echo ""

# 步骤 2
echo -e "${GREEN}========== 步骤 2/7: 上传文件到服务器 ==========${NC}"
echo "请在另一个终端窗口执行以下命令上传文件："
echo ""
echo -e "${YELLOW}scp $TEMP_DIR/${APP_NAME}.tar.gz $SERVER_USER@$SERVER_IP:/tmp/${NC}"
echo ""
read -p "上传完成后，按 Enter 继续..."
echo ""

# 步骤 3
echo -e "${GREEN}========== 步骤 3/7: 连接到服务器 ==========${NC}"
echo "现在需要连接到服务器进行安装"
echo ""
echo -e "${YELLOW}请打开新终端窗口，执行以下命令连接到服务器：${NC}"
echo ""
echo -e "${YELLOW}ssh $SERVER_USER@$SERVER_IP${NC}"
echo -e "${YELLOW}密码: Sx@3964117${NC}"
echo ""
read -p "连接成功后，按 Enter 继续..."
echo ""

# 生成服务器端执行脚本
SERVER_SCRIPT="$TEMP_DIR/server-install.sh"
cat > "$SERVER_SCRIPT" << 'SERVEREOF'
#!/bin/bash
set -e

APP_NAME="myedgetunnel"
DEPLOY_DIR="/opt/myedgetunnel"

echo "=========================================="
echo "服务器端安装脚本"
echo "=========================================="
echo ""

# 创建目录
echo "创建部署目录..."
mkdir -p $DEPLOY_DIR
cd $DEPLOY_DIR

# 解压文件
echo "解压部署包..."
tar -xzf /tmp/${APP_NAME}.tar.gz
cd $APP_NAME

# 检查并安装 Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js 未安装，正在安装..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js 已安装: $(node --version)"
fi

# 检查并安装 PM2
if ! command -v pm2 &> /dev/null; then
    echo "PM2 未安装，正在安装..."
    npm install -g pm2
else
    echo "PM2 已安装: $(pm2 --version)"
fi

# 安装项目依赖
echo "安装项目依赖..."
npm install --production

# 创建 .env 文件
if [ ! -f .env ]; then
    echo "创建环境变量文件..."
    cp .env.example .env
fi

# 创建日志目录
mkdir -p logs

# 停止旧的进程
echo "停止旧进程..."
pm2 delete myedgetunnel 2>/dev/null || true

# 启动应用
echo "启动应用..."
pm2 start ecosystem.config.cjs

# 保存 PM2 配置
pm2 save

# 设置 PM2 开机自启
echo "设置开机自启..."
env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root

# 配置防火墙
echo "配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 8080/tcp || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=8080/tcp || true
    firewall-cmd --permanent --add-port=80/tcp || true
    firewall-cmd --permanent --add-port=443/tcp || true
    firewall-cmd --reload || true
fi

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
pm2 status
echo ""
echo "应用已启动，可通过以下地址访问："
echo "  http://$(hostname -I | awk '{print $1}'):8080"
echo "  管理后台: http://$(hostname -I | awk '{print $1}'):8080/admin"
echo ""
SERVEREOF

chmod +x "$SERVER_SCRIPT"

# 步骤 4
echo -e "${GREEN}========== 步骤 4/7: 上传安装脚本 ==========${NC}"
echo "请在另一个终端窗口执行以下命令上传安装脚本："
echo ""
echo -e "${YELLOW}scp $SERVER_SCRIPT $SERVER_USER@$SERVER_IP:/tmp/server-install.sh${NC}"
echo ""
read -p "上传完成后，按 Enter 继续..."
echo ""

# 步骤 5
echo -e "${GREEN}========== 步骤 5/7: 执行服务器端安装 ==========${NC}"
echo "现在在服务器的 SSH 会话中执行以下命令："
echo ""
echo -e "${YELLOW}bash /tmp/server-install.sh${NC}"
echo ""
read -p "安装完成后，按 Enter 继续..."
echo ""

# 步骤 6
echo -e "${GREEN}========== 步骤 6/7: 验证安装 ==========${NC}"
echo "在服务器的 SSH 会话中执行以下命令验证："
echo ""
echo -e "${YELLOW}pm2 status${NC}"
echo -e "${YELLOW}pm2 logs myedgetunnel --lines 20${NC}"
echo ""
read -p "验证完成后，按 Enter 继续..."
echo ""

# 步骤 7
echo -e "${GREEN}========== 步骤 7/7: 清理临时文件 ==========${NC}"
echo "清理本地临时文件..."
rm -rf "$TEMP_DIR"
echo -e "${GREEN}✓ 清理完成${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "部署完成！"
echo "==========================================${NC}"
echo ""
echo -e "访问地址: ${GREEN}http://$SERVER_IP:8080${NC}"
echo -e "管理后台: ${GREEN}http://$SERVER_IP:8080/admin${NC}"
echo -e "管理密码: ${YELLOW}admin123${NC} (请登录后台修改)"
echo ""
echo "常用命令 (在服务器上执行):"
echo "  查看日志: pm2 logs myedgetunnel"
echo "  重启应用: pm2 restart myedgetunnel"
echo "  停止应用: pm2 stop myedgetunnel"
echo "  查看状态: pm2 status"
echo ""
echo "详细文档请查看: DEPLOY.md"
echo ""
