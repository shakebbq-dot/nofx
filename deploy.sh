#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# NOFX AI Trading System - 一键部署脚本
# 自动安装 Docker、拉取代码、配置并启动服务
# Usage: bash deploy.sh [安装目录]
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

print_title() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# ------------------------------------------------------------------------
# 检测系统类型
# ------------------------------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=debian
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS=rhel
        OS_VERSION=$(cat /etc/redhat-release)
    else
        OS=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
    
    print_info "检测到系统: $OS $OS_VERSION"
}

# ------------------------------------------------------------------------
# 检查是否为 root 或 sudo 用户
# ------------------------------------------------------------------------
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_warning "需要 sudo 权限来安装 Docker"
        print_info "请输入密码以继续..."
        sudo -v
    fi
    print_success "已获得 sudo 权限"
}

# ------------------------------------------------------------------------
# 安装 Docker
# ------------------------------------------------------------------------
install_docker() {
    print_title "步骤 1/5: 安装 Docker"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker 已安装: $DOCKER_VERSION"
    else
        print_info "正在安装 Docker..."
        
        # 使用官方安装脚本
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh
        
        print_success "Docker 安装完成"
    fi
    
    # 检测 Docker Compose 命令
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
        print_success "Docker Compose 已就绪 (内置版本)"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        print_success "Docker Compose 已就绪 (独立版本)"
    else
        print_error "Docker Compose 未安装！Docker 20.10+ 应该包含内置版本"
        exit 1
    fi
    
    # 将当前用户添加到 docker 组（如果尚未添加）
    if ! groups $USER | grep -q docker; then
        print_info "将用户 $USER 添加到 docker 组..."
        sudo usermod -aG docker $USER
        print_warning "需要重新登录或运行 'newgrp docker' 才能使用 Docker"
        print_info "正在激活 docker 组..."
        newgrp docker <<EOF || true
EOF
    fi
    
    # 启动 Docker 服务
    print_info "启动 Docker 服务..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # 验证安装
    docker --version
    $COMPOSE_CMD --version
    print_success "Docker 环境准备就绪"
}

# ------------------------------------------------------------------------
# 检查并安装必要工具
# ------------------------------------------------------------------------
install_dependencies() {
    print_title "步骤 2/5: 安装必要工具"
    
    # 检查并安装 git, curl, jq
    local deps=""
    command -v git &> /dev/null || deps="$deps git"
    command -v curl &> /dev/null || deps="$deps curl"
    command -v jq &> /dev/null || deps="$deps jq"
    
    if [ -n "$deps" ]; then
        print_info "正在安装: $deps"
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            sudo apt-get update
            sudo apt-get install -y $deps
        elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
            sudo yum install -y $deps || sudo dnf install -y $deps
        fi
        print_success "依赖安装完成"
    else
        print_success "所有依赖已安装"
    fi
}

# ------------------------------------------------------------------------
# 克隆或更新代码仓库
# ------------------------------------------------------------------------
clone_repository() {
    print_title "步骤 3/5: 获取代码仓库"
    
    REPO_URL="https://github.com/Watimer/nofx.git"
    INSTALL_DIR="${1:-/opt/nofx}"
    
    print_info "安装目录: $INSTALL_DIR"
    
    if [ -d "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR/.git" ]; then
        print_info "目录已存在，正在更新代码..."
        cd "$INSTALL_DIR"
        git pull || {
            print_warning "更新失败，可能需要手动处理冲突"
            exit 1
        }
        print_success "代码更新完成"
    else
        print_info "正在克隆仓库..."
        if [ -d "$INSTALL_DIR" ]; then
            print_warning "目录 $INSTALL_DIR 已存在但不是 Git 仓库"
            read -p "是否删除并重新克隆？(y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
            else
                print_error "请手动处理目录 $INSTALL_DIR"
                exit 1
            fi
        fi
        
        sudo mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone "$REPO_URL" "$INSTALL_DIR"
        sudo chown -R $USER:$USER "$INSTALL_DIR"
        print_success "代码克隆完成"
    fi
    
    cd "$INSTALL_DIR"
    print_success "当前工作目录: $(pwd)"
}

# ------------------------------------------------------------------------
# 配置防火墙
# ------------------------------------------------------------------------
configure_firewall() {
    print_title "步骤 4/5: 配置防火墙"
    
    if command -v ufw &> /dev/null; then
        print_info "检测到 UFW 防火墙"
        if sudo ufw status | grep -q "Status: active"; then
            print_info "正在开放端口 3000 和 8080..."
            sudo ufw allow 3000/tcp
            sudo ufw allow 8080/tcp
            print_success "防火墙规则已添加"
        else
            print_info "UFW 未激活，跳过"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        print_info "检测到 firewalld"
        if sudo systemctl is-active --quiet firewalld; then
            print_info "正在开放端口 3000 和 8080..."
            sudo firewall-cmd --permanent --add-port=3000/tcp
            sudo firewall-cmd --permanent --add-port=8080/tcp
            sudo firewall-cmd --reload
            print_success "防火墙规则已添加"
        else
            print_info "firewalld 未激活，跳过"
        fi
    else
        print_info "未检测到常见防火墙，请手动配置端口 3000 和 8080"
    fi
}

# ------------------------------------------------------------------------
# 交互式配置 config.json
# ------------------------------------------------------------------------
configure_app() {
    print_title "步骤 5/5: 配置应用程序"
    
    if [ -f "config.json" ]; then
        print_warning "config.json 已存在"
        read -p "是否要重新配置？(y/N): " reconfirm
        if [[ ! "$reconfirm" =~ ^[Yy]$ ]]; then
            print_info "使用现有配置文件"
            return
        fi
    fi
    
    if [ ! -f "config.json.example" ]; then
        print_error "找不到 config.json.example 模板文件"
        exit 1
    fi
    
    print_info "从模板创建配置文件..."
    cp config.json.example config.json
    
    print_warning ""
    print_warning "═══════════════════════════════════════════════════════════════"
    print_warning "  重要：需要手动编辑 config.json 填入你的 API 密钥"
    print_warning "═══════════════════════════════════════════════════════════════"
    print_warning ""
    print_info "配置文件位置: $(pwd)/config.json"
    print_info ""
    print_info "需要配置的内容："
    print_info "  1. Binance API Key 和 Secret Key（如果使用 Binance）"
    print_info "  2. DeepSeek/Qwen API Key（AI 模型密钥）"
    print_info "  3. 交易所相关配置（Hyperliquid/Aster 等）"
    print_info "  4. 初始余额和扫描间隔"
    print_info ""
    
    # 询问是否现在编辑
    read -p "是否现在编辑配置文件？(Y/n): " edit_now
    if [[ ! "$edit_now" =~ ^[Nn]$ ]]; then
        # 尝试使用常见的编辑器
        if command -v nano &> /dev/null; then
            nano config.json
        elif command -v vim &> /dev/null; then
            vim config.json
        elif command -v vi &> /dev/null; then
            vi config.json
        else
            print_warning "未找到常见编辑器，请手动编辑: $(pwd)/config.json"
        fi
    fi
    
    print_success "配置文件已创建"
}

# ------------------------------------------------------------------------
# 启动服务
# ------------------------------------------------------------------------
start_services() {
    print_title "启动 Docker 服务"
    
    # 检测 compose 命令
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        print_error "Docker Compose 未找到"
        exit 1
    fi
    
    print_info "正在构建并启动服务（首次运行可能需要几分钟）..."
    $COMPOSE_CMD up -d --build
    
    print_success "服务启动中..."
    sleep 5
    
    # 检查服务状态
    print_info "检查服务状态..."
    $COMPOSE_CMD ps
    
    print_success ""
    print_success "═══════════════════════════════════════════════════════════════"
    print_success "  部署完成！"
    print_success "═══════════════════════════════════════════════════════════════"
    print_success ""
    print_info "访问地址："
    
    # 获取服务器 IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
    
    print_info "  前端界面: http://$SERVER_IP:3000"
    print_info "  后端 API:  http://$SERVER_IP:8080"
    print_info "  健康检查: http://$SERVER_IP:8080/health"
    print_info ""
    print_info "常用命令："
    print_info "  查看日志: cd $INSTALL_DIR && $COMPOSE_CMD logs -f"
    print_info "  查看状态: cd $INSTALL_DIR && $COMPOSE_CMD ps"
    print_info "  停止服务: cd $INSTALL_DIR && $COMPOSE_CMD stop"
    print_info "  重启服务: cd $INSTALL_DIR && $COMPOSE_CMD restart"
    print_info "  更新代码: cd $INSTALL_DIR && git pull && $COMPOSE_CMD up -d --build"
    print_info ""
    print_warning "如果服务器有防火墙，请确保开放端口 3000 和 8080"
    print_warning "如果使用云服务器，请在安全组中开放相应端口"
}

# ------------------------------------------------------------------------
# 主函数
# ------------------------------------------------------------------------
main() {
    print_title "NOFX AI Trading System - 一键部署脚本"
    
    print_info "开始部署流程..."
    print_info "安装目录: ${1:-/opt/nofx}"
    
    # 执行部署步骤
    detect_os
    check_sudo
    install_dependencies
    install_docker
    clone_repository "${1:-/opt/nofx}"
    configure_firewall
    configure_app
    start_services
    
    print_success "\n🎉 部署完成！"
}

# 执行主函数
main "$@"

