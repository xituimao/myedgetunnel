#!/bin/bash

# EdgeTunnel 部署脚本
# 目标服务器: 69.5.7.220

set -e

echo "=========================================="
echo "EdgeTunnel 部署到云服务器"
echo "=========================================="

# 配置
SERVER_IP="69.5.7.220"
SERVER_USER="root"
SERVER_PASSWORD="Sx@3964117"
DEPLOY_DIR="/opt/myedgetunnel"
APP_NAME="myedgetunnel"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}提示: 本脚本将使用 sshpass 进行自动化部署${NC}"
echo -e "${YELLOW}如果没有安装 sshpass，请先运行: sudo apt-get install sshpass${NC}"
echo ""

# 检查 sshpass 是否安装
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}错误: 未找到 sshpass 命令${NC}"
    echo -e "${YELLOW}请安装 sshpass: sudo apt-get install sshpass${NC}"
    echo -e "${YELLOW}或者使用手动部署方式${NC}"
    exit 1
fi

echo -e "${GREEN}步骤 1/6: 创建部署包...${NC}"
# 创建临时目录
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/$APP_NAME"

# 复制必要文件
cp package.json "$TEMP_DIR/$APP_NAME/"
cp server.js "$TEMP_DIR/$APP_NAME/"
cp _worker.js "$TEMP_DIR/$APP_NAME/"
cp ecosystem.config.cjs "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true
cp .env.example "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true
cp -r nginx "$TEMP_DIR/$APP_NAME/" 2>/dev/null || true

# 打包
cd "$TEMP_DIR"
tar -czf "${APP_NAME}.tar.gz" "$APP_NAME"
cd - > /dev/null

echo -e "${GREEN}步骤 2/6: 连接到服务器并创建目录...${NC}"
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << EOF
    mkdir -p $DEPLOY_DIR
    echo "目录创建成功"
EOF

echo -e "${GREEN}步骤 3/6: 上传部署包到服务器...${NC}"
sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=no "$TEMP_DIR/${APP_NAME}.tar.gz" "$SERVER_USER@$SERVER_IP:$DEPLOY_DIR/"

echo -e "${GREEN}步骤 4/6: 解压并安装依赖...${NC}"
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << EOF
    cd $DEPLOY_DIR
    tar -xzf ${APP_NAME}.tar.gz
    cd $APP_NAME

    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        echo "安装 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi

    # 检查 PM2
    if ! command -v pm2 &> /dev/null; then
        echo "安装 PM2..."
        npm install -g pm2
    fi

    # 安装项目依赖
    echo "安装项目依赖..."
    npm install --production

    # 创建 .env 文件
    if [ ! -f .env ]; then
        echo "创建环境变量文件..."
        cat > .env << 'ENVEOF'
PORT=8080
ADMIN=admin123
KEY=勿动此默认密钥，有需求请自行通过添加变量KEY进行修改
HOST=
UUID=
PATH=/
PROXYIP=
URL=
GO2SOCKS5=
ENVEOF
    fi
EOF

echo -e "${GREEN}步骤 5/6: 启动应用...${NC}"
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'EOF'
    cd /opt/myedgetunnel/myedgetunnel

    # 停止旧的进程
    pm2 delete myedgetunnel 2>/dev/null || true

    # 启动应用
    pm2 start server.js --name myedgetunnel

    # 保存 PM2 配置
    pm2 save

    # 设置 PM2 开机自启
    pm2 startup systemd -u root --hp /root 2>/dev/null || true

    # 显示状态
    pm2 status
EOF

echo -e "${GREEN}步骤 6/6: 配置防火墙...${NC}"
sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" << 'EOF'
    # 检查是否有防火墙
    if command -v ufw &> /dev/null; then
        echo "配置 UFW 防火墙..."
        ufw allow 8080/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
    elif command -v firewall-cmd &> /dev/null; then
        echo "配置 firewalld 防火墙..."
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
    fi
EOF

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}=========================================="
echo "部署完成！"
echo "==========================================${NC}"
echo ""
echo -e "访问地址: ${GREEN}http://$SERVER_IP:8080${NC}"
echo -e "管理后台: ${GREEN}http://$SERVER_IP:8080/admin${NC}"
echo -e "管理密码: ${YELLOW}admin123${NC} (请登录后台修改)"
echo ""
echo "常用命令:"
echo "  查看日志: ssh root@$SERVER_IP 'pm2 logs myedgetunnel'"
echo "  重启应用: ssh root@$SERVER_IP 'pm2 restart myedgetunnel'"
echo "  停止应用: ssh root@$SERVER_IP 'pm2 stop myedgetunnel'"
echo "  查看状态: ssh root@$SERVER_IP 'pm2 status'"
echo ""
