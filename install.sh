#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# NOFX AI Trading System - 服务器一键安装脚本
# 支持: Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+
# ═══════════════════════════════════════════════════════════════

set -e

# ------------------------------------------------------------------------
# 颜色定义
# ------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------
# 工具函数：彩色输出
# ------------------------------------------------------------------------
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# ------------------------------------------------------------------------
# 检测操作系统
# ------------------------------------------------------------------------
detect_os() {
    print_info "正在检测操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9.]*\).*/\1/')
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi
    
    print_success "检测到操作系统: $OS $OS_VERSION"
}

# ------------------------------------------------------------------------
# 检查是否为 root 用户
# ------------------------------------------------------------------------
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "建议不要使用 root 用户运行，将使用当前用户安装"
    fi
}

# ------------------------------------------------------------------------
# 更新系统包管理器
# ------------------------------------------------------------------------
update_package_manager() {
    print_header "更新系统包管理器"
    
    case $OS in
        ubuntu|debian)
            print_info "更新 apt 包列表..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl wget git build-essential
            ;;
        centos|rhel|fedora|rocky|almalinux)
            print_info "更新 yum/dnf 包列表..."
            if command -v dnf &> /dev/null; then
                sudo dnf update -y -q
                sudo dnf install -y -q curl wget git gcc gcc-c++ make
            else
                sudo yum update -y -q
                sudo yum install -y -q curl wget git gcc gcc-c++ make
            fi
            ;;
        *)
            print_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    print_success "系统包管理器更新完成"
}

# ------------------------------------------------------------------------
# 安装 Go
# ------------------------------------------------------------------------
install_go() {
    print_header "安装 Go 编程语言"
    
    REQUIRED_GO_VERSION="1.21"
    
    # 检查 Go 是否已安装
    if command -v go &> /dev/null; then
        INSTALLED_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
        print_info "检测到已安装 Go 版本: $INSTALLED_VERSION"
        
        # 比较版本
        if [ "$(printf '%s\n' "$REQUIRED_GO_VERSION" "$INSTALLED_VERSION" | sort -V | head -n1)" != "$REQUIRED_GO_VERSION" ]; then
            print_warning "Go 版本过低，需要 >= $REQUIRED_GO_VERSION，正在安装新版本..."
        else
            print_success "Go 版本满足要求 ($INSTALLED_VERSION >= $REQUIRED_GO_VERSION)"
            return 0
        fi
    fi
    
    # 安装 Go
    GO_VERSION="1.21.5"
    GO_ARCH="amd64"
    
    # 检测架构
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        GO_ARCH="arm64"
    fi
    
    print_info "下载 Go $GO_VERSION ($GO_ARCH)..."
    cd /tmp
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O go.tar.gz
    
    print_info "安装 Go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    
    # 添加 Go 到 PATH
    if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    print_success "Go $GO_VERSION 安装完成"
}

# ------------------------------------------------------------------------
# 安装 Node.js 和 npm
# ------------------------------------------------------------------------
install_nodejs() {
    print_header "安装 Node.js 和 npm"
    
    REQUIRED_NODE_VERSION="18"
    
    # 检查 Node.js 是否已安装
    if command -v node &> /dev/null; then
        INSTALLED_VERSION=$(node -v | grep -oP 'v\K[0-9]+')
        print_info "检测到已安装 Node.js 版本: v$INSTALLED_VERSION"
        
        if [ "$INSTALLED_VERSION" -ge "$REQUIRED_NODE_VERSION" ]; then
            print_success "Node.js 版本满足要求 (v$INSTALLED_VERSION >= v$REQUIRED_NODE_VERSION)"
            return 0
        else
            print_warning "Node.js 版本过低，需要 >= v$REQUIRED_NODE_VERSION，正在安装新版本..."
        fi
    fi
    
    # 使用 NodeSource 仓库安装 Node.js
    print_info "安装 Node.js 20.x LTS..."
    
    case $OS in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y -qq nodejs
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            if command -v dnf &> /dev/null; then
                sudo dnf install -y -q nodejs
            else
                sudo yum install -y -q nodejs
            fi
            ;;
    esac
    
    print_success "Node.js $(node -v) 和 npm $(npm -v) 安装完成"
}

# ------------------------------------------------------------------------
# 克隆或更新项目
# ------------------------------------------------------------------------
setup_project() {
    print_header "设置项目"
    
    if [ -d "nofx" ]; then
        print_info "项目目录已存在，更新代码..."
        cd nofx
        git pull || print_warning "git pull 失败，请手动检查"
    else
        print_info "克隆项目..."
        git clone https://github.com/tinkle-community/nofx.git
        cd nofx
    fi
    
    print_success "项目设置完成"
}

# ------------------------------------------------------------------------
# 安装后端依赖
# ------------------------------------------------------------------------
install_backend_deps() {
    print_header "安装后端依赖 (Go Modules)"
    
    print_info "下载 Go 模块..."
    go mod download
    
    print_success "后端依赖安装完成"
}

# ------------------------------------------------------------------------
# 安装前端依赖
# ------------------------------------------------------------------------
install_frontend_deps() {
    print_header "安装前端依赖 (npm)"
    
    cd web
    print_info "安装 npm 包..."
    npm install
    
    print_success "前端依赖安装完成"
    cd ..
}

# ------------------------------------------------------------------------
# 构建项目
# ------------------------------------------------------------------------
build_project() {
    print_header "构建项目"
    
    # 构建后端
    print_info "构建后端..."
    go build -o nofx main.go
    print_success "后端构建完成"
    
    # 构建前端
    print_info "构建前端..."
    cd web
    npm run build
    cd ..
    print_success "前端构建完成"
}

# ------------------------------------------------------------------------
# 配置设置
# ------------------------------------------------------------------------
setup_config() {
    print_header "配置设置"
    
    if [ ! -f "config.json" ]; then
        print_info "创建配置文件..."
        cp config.json.example config.json
        
        print_warning "═══════════════════════════════════════════════════════════════"
        print_warning "请编辑 config.json 文件，填入你的 API 密钥："
        print_warning "  - Binance API Key & Secret"
        print_warning "  - DeepSeek/Qwen API Key"
        print_warning "  - 或其他交易所配置"
        print_warning "═══════════════════════════════════════════════════════════════"
        print_info "使用以下命令编辑: nano config.json"
        
        read -p "是否现在编辑配置文件? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} config.json
        fi
    else
        print_info "配置文件已存在，跳过创建"
    fi
    
    print_success "配置设置完成"
}

# ------------------------------------------------------------------------
# 创建 systemd 服务文件
# ------------------------------------------------------------------------
create_systemd_service() {
    print_header "创建 systemd 服务"
    
    SERVICE_FILE="/etc/systemd/system/nofx.service"
    CURRENT_USER=$(whoami)
    PROJECT_DIR=$(pwd)
    
    if [ -f "$SERVICE_FILE" ]; then
        print_warning "systemd 服务文件已存在，跳过创建"
        return 0
    fi
    
    print_info "创建 systemd 服务文件..."
    
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=NOFX AI Trading System
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/nofx
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    print_success "systemd 服务文件创建完成"
    
    print_info "使用以下命令管理服务:"
    print_info "  启动: sudo systemctl start nofx"
    print_info "  停止: sudo systemctl stop nofx"
    print_info "  重启: sudo systemctl restart nofx"
    print_info "  状态: sudo systemctl status nofx"
    print_info "  开机自启: sudo systemctl enable nofx"
}

# ------------------------------------------------------------------------
# 安装总结
# ------------------------------------------------------------------------
print_summary() {
    print_header "安装完成！"
    
    echo -e "${GREEN}✓${NC} Go $(go version | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+') 已安装"
    echo -e "${GREEN}✓${NC} Node.js $(node -v) 已安装"
    echo -e "${GREEN}✓${NC} npm $(npm -v) 已安装"
    echo -e "${GREEN}✓${NC} 项目依赖已安装"
    echo -e "${GREEN}✓${NC} 项目已构建"
    echo ""
    
    print_info "下一步："
    echo "  1. 编辑配置文件: nano config.json"
    echo "  2. 启动服务:"
    echo "     - 直接运行: ./nofx"
    echo "     - 使用 systemd: sudo systemctl start nofx"
    echo "     - 使用 Docker: ./start.sh start"
    echo ""
    echo "  3. 访问 Web 界面: http://localhost:3000"
    echo "  4. API 端点: http://localhost:8080"
    echo ""
    
    print_warning "⚠️  请确保在 config.json 中正确配置了 API 密钥！"
}

# ------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------
main() {
    clear
    print_header "NOFX AI Trading System - 服务器一键安装脚本"
    echo ""
    
    # 执行安装步骤
    detect_os
    check_root
    update_package_manager
    install_go
    install_nodejs
    setup_project
    install_backend_deps
    install_frontend_deps
    build_project
    setup_config
    create_systemd_service
    
    # 显示总结
    print_summary
}

# 执行主函数
main "$@"

