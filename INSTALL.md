# 🚀 NOFX 服务器一键安装指南

## 快速开始

### 方法一：使用一键安装脚本（推荐）

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/tinkle-community/nofx/main/install.sh | bash

# 或者克隆项目后运行
git clone https://github.com/tinkle-community/nofx.git
cd nofx
chmod +x install.sh
./install.sh
```

### 方法二：使用 Docker（最简单）

```bash
# 克隆项目
git clone https://github.com/tinkle-community/nofx.git
cd nofx

# 使用 Docker Compose 启动
./start.sh start
```

## 📋 系统要求

### 最低要求
- **操作系统**: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+, 或兼容的 Linux 发行版
- **CPU**: 2 核心
- **内存**: 2GB RAM
- **磁盘**: 10GB 可用空间
- **网络**: 稳定的互联网连接

### 推荐配置
- **CPU**: 4+ 核心
- **内存**: 4GB+ RAM
- **磁盘**: 20GB+ 可用空间（SSD 推荐）

## 📦 手动安装步骤

如果一键安装脚本不适用于你的系统，可以按照以下步骤手动安装：

### 1. 安装 Go (>= 1.21)

```bash
# Ubuntu/Debian
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# CentOS/RHEL
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

验证安装：
```bash
go version
```

### 2. 安装 Node.js (>= 18)

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs
```

验证安装：
```bash
node -v
npm -v
```

### 3. 克隆项目

```bash
git clone https://github.com/tinkle-community/nofx.git
cd nofx
```

### 4. 安装依赖

```bash
# 安装后端依赖
go mod download

# 安装前端依赖
cd web
npm install
cd ..
```

### 5. 构建项目

```bash
# 构建后端
go build -o nofx main.go

# 构建前端
cd web
npm run build
cd ..
```

### 6. 配置

```bash
# 复制配置文件模板
cp config.json.example config.json

# 编辑配置文件
nano config.json
```

在 `config.json` 中配置：
- API 密钥（Binance, DeepSeek, Qwen 等）
- 交易所设置
- 交易参数

### 7. 启动服务

#### 方法 A: 直接运行

```bash
./nofx
```

#### 方法 B: 使用 systemd（推荐用于生产环境）

```bash
# 创建服务文件
sudo tee /etc/systemd/system/nofx.service > /dev/null <<EOF
[Unit]
Description=NOFX AI Trading System
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/nofx
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable nofx
sudo systemctl start nofx

# 查看状态
sudo systemctl status nofx
```

#### 方法 C: 使用 Docker

```bash
./start.sh start
```

## 🔧 安装脚本功能说明

一键安装脚本 (`install.sh`) 会自动完成以下操作：

1. ✅ 检测操作系统类型
2. ✅ 更新系统包管理器
3. ✅ 安装 Go (>= 1.21)
4. ✅ 安装 Node.js (>= 18) 和 npm
5. ✅ 克隆或更新项目代码
6. ✅ 安装后端依赖（Go modules）
7. ✅ 安装前端依赖（npm packages）
8. ✅ 构建后端和前端
9. ✅ 创建配置文件（如果不存在）
10. ✅ 创建 systemd 服务文件（可选）

## 🌐 访问服务

安装完成后，访问以下地址：

- **Web 界面**: http://localhost:3000
- **API 端点**: http://localhost:8080
- **健康检查**: http://localhost:8080/health

## 🔍 故障排查

### 问题 1: Go 命令未找到

```bash
# 检查 Go 是否在 PATH 中
which go

# 如果未找到，添加到 PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### 问题 2: Node.js 版本过低

```bash
# 检查版本
node -v

# 如果版本过低，使用 nvm 安装新版本
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
```

### 问题 3: 端口被占用

```bash
# 检查端口占用
sudo lsof -i :8080  # 后端端口
sudo lsof -i :3000  # 前端端口

# 修改 config.json 中的端口配置
```

### 问题 4: 构建失败

```bash
# 清理并重新构建
cd web
rm -rf node_modules dist
npm install
npm run build
cd ..

# 重新构建后端
go clean
go build -o nofx main.go
```

### 问题 5: 权限问题

```bash
# 确保脚本有执行权限
chmod +x install.sh
chmod +x start.sh
chmod +x nofx
```

## 📚 更多信息

- [Docker 部署指南](DOCKER_DEPLOY.md)
- [配置说明](README.zh-CN.md#配置说明)
- [常见问题](常见问题.md)

## 💬 获取帮助

如有问题，请访问：
- [GitHub Issues](https://github.com/tinkle-community/nofx/issues)
- [Telegram 开发者社区](https://t.me/nofx_dev_community)

## ⚠️ 重要提示

1. **API 密钥安全**: 请妥善保管你的 API 密钥，不要泄露给他人
2. **测试环境**: 建议先在测试环境或使用小金额测试
3. **风险提示**: 自动交易存在风险，请谨慎使用
4. **防火墙**: 如需外网访问，请配置防火墙规则开放相应端口

---

**祝交易顺利！** 🚀

