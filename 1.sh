#!/bin/bash

# 定义错误日志路径
ERROR_LOG="/root/docker_script_error.log"

# 日志记录函数
log_error() {
    local task="$1"
    local reason="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $task 失败。" >>"$ERROR_LOG"
    echo "原因: $reason" >>"$ERROR_LOG"
    echo "-----------------------------------" >>"$ERROR_LOG"
}

# 检测 Docker 和 Docker Compose 状态
check_docker_status() {
    if docker --version &>/dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        DOCKER_STATUS="✔ Docker          已安装 ($DOCKER_VERSION)"
    else
        DOCKER_STATUS="✘ Docker          未安装"
    fi

    if docker compose --version &> /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version | awk '{print $4}' | sed 's/,//')
        COMPOSE_STATUS="✔ Docker Compose  已安装 ($COMPOSE_VERSION)"
    else
        COMPOSE_STATUS="✘ Docker Compose  未安装"
    fi
}

# 检测并显示当前状态
show_current_status() {
    clear
    check_docker_status
    SERVER_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")
    echo "当前系统状态:"
    echo "-----------------------------------"
    echo "$DOCKER_STATUS"
    echo "$COMPOSE_STATUS"
    echo "-----------------------------------"
    echo "当前服务器时间: $SERVER_TIME"
    echo "-----------------------------------"
}

# 安装 Docker 从官方源
install_docker_from_official() {
    echo "正在通过 Docker 官网安装 Docker 和 Docker Compose..."
    {
        # 移除旧版本
        apt-get remove -y docker docker-engine docker.io containerd runc &&
        # 更新软件包清单
        apt-get update &&
        # 安装必要的依赖
        apt-get install -y ca-certificates curl gnupg &&
        # 添加 Docker 的 GPG 密钥和官方源
        install -m 0755 -d /etc/apt/keyrings &&
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg &&
        chmod a+r /etc/apt/keyrings/docker.gpg &&
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null &&
        # 更新源并安装 Docker 软件包
        apt-get update &&
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin &&
        # 安装 Docker Compose 插件
        apt-get install -y docker-compose-plugin
    } || {
        log_error "安装 Docker 和 Docker Compose" "$(2>&1)"
        echo "安装失败，请检查错误日志：$ERROR_LOG"
        return
    }
    echo "Docker 和 Docker Compose 安装成功！"
}

# 修改系统时区为上海时间
set_shanghai_time() {
    echo "正在修改系统时区为上海时间..."
    {
        timedatectl set-timezone Asia/Shanghai
    } || {
        log_error "修改系统时区" "$(2>&1)"
        echo "修改时区失败，请检查错误日志：$ERROR_LOG"
        return
    }
    echo "-----------------------------------"
    echo "✔ 系统时区已修改为上海时间！"
    echo "-----------------------------------"
}

# 更新 Docker 和 Docker Compose
update_docker() {
    echo "正在更新 Docker..."
    install_docker_from_official
    echo "Docker 和 Docker Compose 更新成功！"
}

# 更新系统软件并安装必需工具
update_system() {
    echo "正在更新系统软件并安装必需工具..."
    FAILED_ITEMS=()
    {
        apt-get update && apt-get upgrade -y
    } || {
        log_error "更新系统软件" "$(2>&1)"
        echo "系统更新失败，请检查错误日志：$ERROR_LOG"
        return
    }

    for pkg in curl wget vim ufw; do
        if ! dpkg -l | grep -qw "$pkg"; then
            echo "安装 $pkg..."
            if ! apt-get install -y "$pkg"; then
                FAILED_ITEMS+=("$pkg")
                log_error "安装 $pkg" "$(2>&1)"
            fi
        else
            echo "✔ $pkg          已安装"
        fi
    done

    if [ ${#FAILED_ITEMS[@]} -eq 0 ]; then
        echo "-----------------------------------"
        echo "所有操作完成！未发现失败项。"
        echo "-----------------------------------"
    else
        echo "以下任务失败："
        for item in "${FAILED_ITEMS[@]}"; do
            echo "- 安装 $item"
        done
        echo "请查看错误日志 ($ERROR_LOG) 获取详情。"
    fi
}

# 删除 Docker 和 Docker Compose
remove_docker() {
    echo -e "\n正在删除 Docker 和 Docker Compose... 请耐心等待\n"
    
    # 移除 Docker 相关包
    if ! apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli docker-compose-plugin docker-buildx-plugin; then
        log_error "删除 Docker 和 Docker Compose" "$(2>&1)"
        return 1
    fi
    
    # 清理残留的包和依赖
    if ! apt-get autoremove -y && apt-get autoclean; then
        log_error "清理残留的包和依赖" "$(2>&1)"
        return 1
    fi

    # 清理残留的包和依赖
    if ! rm -rf /etc/docker && rm -rf /var/lib/docker && rm -rf /var/lib/containerd && rm -rf /etc/apt/keyrings/docker.asc && rm /etc/apt/sources.list.d/docker.list; then
        log_error "清理残留的包和依赖" "$(2>&1)"
        return 1
    fi    

    echo -e "\nDocker 和 Docker Compose 删除完成！\n"
}

yijian(){
    echo "-----------------------------------"
    update_system
    #echo "完成"
    echo "-----------------------------------"
    echo "更新时间"
    echo "-----------------------------------"
    set_shanghai_time
    echo "-----------------------------------"
    #echo "完成"
    install_docker_from_official
    #echo "完成"
}

# 主菜单
while true; do
    show_current_status
    echo "请选择要执行的任务:"
    echo "-----------------------------------"
    echo "1: 更新系统软件并安装必需工具"
    echo "2: 修改系统时间为上海时间"
    echo "3: 更新 Docker 和 Docker Compose"
    echo "4: 安装 Docker 和 Docker Compose"
    echo "5: 删除 Docker 和 Docker Compose"
    echo "6: 一键"
    echo "-----------------------------------"
    read -p "请选择要执行的任务 (1-5，输入q退出): " CHOICE
    case $CHOICE in
    1)
        update_system
        ;;
    2)
        set_shanghai_time
        ;;
    3)
        update_docker
        ;;
    4)
        install_docker_from_official
        ;;
    5)
        remove_docker
        ;;
    6)
        yijian
        ;;
    q)
        echo "退出脚本。"
        exit 0
        ;;
    *)
        echo "无效输入，请输入 1-5 的数字。"
        ;;
    esac
done
