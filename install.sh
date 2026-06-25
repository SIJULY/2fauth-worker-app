#!/bin/bash
set -e

# 全局变量
INSTALL_DIR="/opt/2fa"
# 已经为您修改为最新的仓库地址
REPO_URL="https://github.com/SIJULY/2fauth-worker-app.git"

# 检查命令是否存在
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# 1. 安装功能
install_2fa() {
  echo "================================================="
  echo "   开始安装 2FAuth Worker"
  echo "================================================="

  if [ -d "$INSTALL_DIR" ]; then
    echo "[!] 目录 $INSTALL_DIR 已存在。如果是要更新，请在主菜单选择 2。如果要重新安装，请先选择 3 卸载。"
    exit 1
  fi

  # 安装基础依赖
  if ! command_exists curl; then
    echo "[*] 正在安装 curl..."
    apt-get update -y && apt-get install -y curl || yum install -y curl
  fi
  
  if ! command_exists docker; then
    echo "[*] 正在安装 Docker..."
    curl -fsSL https://get.docker.com | bash -s docker
  fi

  if ! command_exists docker && ! docker compose version > /dev/null 2>&1 && ! command_exists docker-compose; then
    echo "[-] Docker Compose 未安装，请检查 Docker 安装状态。"
    exit 1
  fi

  echo "[*] 正在从 GitHub 获取项目文件..."
  git clone $REPO_URL $INSTALL_DIR
  cd $INSTALL_DIR

  echo "================================================="
  echo "   配置 GitHub OAuth 登录信息"
  echo "-------------------------------------------------"
  echo " 获取密钥教程 (仅需 1 分钟)："
  echo " 1. 浏览器打开: https://github.com/settings/developers"
  echo " 2. 点击右上方按钮 [New OAuth App]"
  echo " 3. Homepage URL 填写你准备用来访问的地址 (例如 http://8.8.8.8:3000)"
  echo " 4. Callback URL 填写地址 + /oauth/callback (例如 http://8.8.8.8:3000/oauth/callback)"
  echo " 5. 注册后，复制页面上的 Client ID"
  echo " 6. 点击 [Generate a new client secret] 生成并复制 Client Secret"
  echo "================================================="
  read -p "请输入允许登录的 GitHub 邮箱 (如 admin@example.com): " GITHUB_EMAIL
  read -p "请输入 GitHub Client ID: " GITHUB_CLIENT_ID
  read -p "请输入 GitHub Client Secret: " GITHUB_CLIENT_SECRET
  read -p "请输入你在第 3 步填写的访问地址 (如 http://8.8.8.8:3000 或 https://你的域名): " DOMAIN_URL
  
  # 去除域名末尾的斜杠
  DOMAIN_URL=${DOMAIN_URL%/}

  echo "[*] 正在生成随机的安全密钥..."
  ENC_KEY=$(openssl rand -hex 32)
  JWT_SEC=$(openssl rand -hex 32)

  cat << ENV_EOF > .env
ENCRYPTION_KEY=$ENC_KEY
JWT_SECRET=$JWT_SEC
OAUTH_ALLOWED_USERS=${GITHUB_EMAIL}
OAUTH_GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID}
OAUTH_GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
OAUTH_GITHUB_REDIRECT_URI=${DOMAIN_URL}/oauth/callback
ENV_EOF

  echo "[*] 环境配置文件 .env 已生成。"

  echo "================================================="
  echo " 请选择访问模式："
  echo " 1) 默认 IP + 端口模式"
  echo " 2) 域名模式 (自动配置 Caddy 反向代理并申请 SSL)"
  echo "================================================="
  read -p "请输入对应数字 [1-2] (默认 1): " MODE_CHOICE
  MODE_CHOICE=${MODE_CHOICE:-1}

  DOMAIN=""
  if [ "$MODE_CHOICE" == "2" ]; then
    read -p "请输入你的域名 (例如 2fa.example.com，请确保已解析到本服务器IP): " DOMAIN
    if [ -z "$DOMAIN" ]; then
      echo "[-] 域名不能为空，将回退到 IP+端口 模式。"
      MODE_CHOICE="1"
    else
      echo "[*] 正在配置 Caddy 反向代理..."
      if ! command_exists caddy; then
        echo "[*] 检测到未安装 Caddy，正在尝试自动安装..."
        # 针对 Debian/Ubuntu 系统
        if command_exists apt-get; then
          apt-get update -y && apt-get install -y debian-keyring debian-archive-keyring apt-transport-https || true
          curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || true
          curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list || true
          apt-get update -y && apt-get install caddy -y || true
        fi
        
        # 针对 CentOS / 如果上面的安装失败，直接使用静态二进制文件安装
        if ! command_exists caddy; then
           echo "[!] 使用官方包管理器安装 Caddy 失败，尝试一键脚本安装静态版本..."
           curl -fsSL "https://caddyserver.com/api/download?os=linux&arch=amd64" -o /usr/bin/caddy
           chmod +x /usr/bin/caddy
           
           cat << CADDY_EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
CADDY_EOF
           mkdir -p /etc/caddy
           touch /etc/caddy/Caddyfile
           systemctl daemon-reload
           systemctl enable --now caddy
        fi
      fi

      CADDY_FILE="/etc/caddy/Caddyfile"
      if [ ! -f "$CADDY_FILE" ]; then
         mkdir -p /etc/caddy
         touch $CADDY_FILE
      fi

      # 检查域名是否已经在 caddyfile 中
      if grep -q "$DOMAIN" "$CADDY_FILE"; then
         echo "[*] $CADDY_FILE 中已包含该域名的配置，跳过添加。"
      else
         echo "" >> $CADDY_FILE
         echo "$DOMAIN {" >> $CADDY_FILE
         echo "    reverse_proxy 127.0.0.1:3000" >> $CADDY_FILE
         echo "}" >> $CADDY_FILE
         
         systemctl reload caddy || systemctl restart caddy
         echo "[*] Caddy 反向代理配置完成！"
      fi
    fi
  fi

  echo "[*] 正在编译和启动 Docker 容器..."
  if docker compose version > /dev/null 2>&1; then
    docker compose up -d --build
  else
    docker-compose up -d --build
  fi

  echo "================================================="
  echo "   安装完成！"
  echo "   配置目录: $INSTALL_DIR"
  echo "   务必执行 \`nano $INSTALL_DIR/.env\` 修改 OAUTH_ALLOWED_USERS"
  echo "   并在修改后执行 \`docker compose up -d\` 重载容器。"
  echo " "
  if [ "$MODE_CHOICE" == "2" ]; then
    echo "   访问地址: https://$DOMAIN"
  else
    echo "   访问地址: http://<你的服务器IP>:3000"
  fi
  echo "================================================="
}

# 2. 更新功能
update_2fa() {
  echo "================================================="
  echo "   正在更新 2FAuth Worker"
  echo "================================================="
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "[-] 目录 $INSTALL_DIR 不存在，请先安装。"
    exit 1
  fi
  
  cd $INSTALL_DIR
  echo "[*] 正在拉取最新代码..."
  git pull origin main || git pull origin master

  echo "[*] 正在重新启动容器以应用更新..."
  if docker compose version > /dev/null 2>&1; then
    docker compose down
    docker compose up -d --build
  else
    docker-compose down
    docker-compose up -d --build
  fi
  
  echo "================================================="
  echo "   更新完成！"
  echo "================================================="
}

# 3. 卸载功能
uninstall_2fa() {
  echo "================================================="
  echo "   正在卸载 2FAuth Worker"
  echo "================================================="
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "[-] 目录 $INSTALL_DIR 不存在，无需卸载。"
    exit 1
  fi

  read -p "确定要卸载并删除所有数据吗？此操作不可恢复！(y/N): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    cd $INSTALL_DIR
    if docker compose version > /dev/null 2>&1; then
      docker compose down -v || true
    else
      docker-compose down -v || true
    fi
    cd /
    rm -rf $INSTALL_DIR
    echo "[*] 项目文件及容器已彻底删除。"
    echo "[!] 注意：如果你配置了 Caddy 反向代理，请手动编辑 /etc/caddy/Caddyfile 移除对应域名配置。"
    echo "================================================="
    echo "   卸载完成！"
    echo "================================================="
  else
    echo "[*] 已取消卸载。"
  fi
}

# 显示主菜单
echo "================================================="
echo "   2FAuth Worker 一键管理脚本"
echo "================================================="
echo " 1. 安装 2FAuth"
echo " 2. 更新 2FAuth"
echo " 3. 卸载 2FAuth"
echo " 0. 退出"
echo "================================================="
read -p "请输入数字 [0-3]: " MENU_CHOICE

case $MENU_CHOICE in
  1)
    install_2fa
    ;;
  2)
    update_2fa
    ;;
  3)
    uninstall_2fa
    ;;
  0)
    exit 0
    ;;
  *)
    echo "[-] 无效的选项"
    exit 1
    ;;
esac
