#!/bin/bash

# Open Notebook 一鍵啟動腳本
# 適用於 Mac M1 環境

set -e  # 如果任何命令失敗就退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 函數：印出彩色訊息
print_status() {
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
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}🚀 Open Notebook 一鍵啟動腳本${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# 檢查是否在正確的目錄
check_directory() {
    if [[ ! -f "pyproject.toml" ]] || [[ ! -f "app_home.py" ]]; then
        print_error "請確保在 open-notebook 專案根目錄執行此腳本"
        exit 1
    fi
}

# 檢查 Docker 是否運行
check_docker() {
    print_status "檢查 Docker 狀態..."
    if ! docker info >/dev/null 2>&1; then
        print_warning "Docker 未運行，正在啟動 Docker Desktop..."
        open /Applications/Docker.app
        print_status "等待 Docker 啟動（這可能需要 30-60 秒）..."
        
        # 等待 Docker 啟動，最多等待 120 秒
        local count=0
        while ! docker info >/dev/null 2>&1; do
            if [ $count -ge 24 ]; then  # 24 * 5 = 120 秒
                print_error "Docker 啟動超時，請手動啟動 Docker Desktop 後重試"
                exit 1
            fi
            echo -n "."
            sleep 5
            ((count++))
        done
        echo
        print_success "Docker 已啟動"
    else
        print_success "Docker 已運行"
    fi
}

# 檢查並啟動虛擬環境
setup_environment() {
    print_status "檢查 Python 環境..."
    
    if [[ ! -d ".venv" ]]; then
        print_warning "未找到 .venv 目錄，正在創建虛擬環境..."
        if command -v uv >/dev/null 2>&1; then
            uv sync
        else
            print_error "UV 未安裝，請先安裝 UV 套件管理器"
            print_error "執行: pip install uv"
            exit 1
        fi
    fi
    
    # 啟動虛擬環境
    if [[ -f ".venv/bin/activate" ]]; then
        source .venv/bin/activate
        print_success "虛擬環境已啟動 ($(python --version))"
    else
        print_error "虛擬環境啟動失敗"
        exit 1
    fi
}

# 檢查環境變數檔案
check_env_file() {
    print_status "檢查環境變數檔案..."
    if [[ ! -f ".env" ]]; then
        print_warning "未找到 .env 檔案，正在從範例建立..."
        cp .env.example .env
        print_warning "請編輯 .env 檔案添加你的 API 金鑰"
        print_warning "至少需要設置一個 AI 服務的 API 金鑰（如 OPENAI_API_KEY）"
    fi
    print_success "環境變數檔案已準備"
}

# 停止現有服務
stop_existing_services() {
    print_status "停止現有服務..."
    
    # 停止可能運行的進程
    pkill -f "streamlit run app_home.py" >/dev/null 2>&1 || true
    pkill -f "surreal-commands-worker" >/dev/null 2>&1 || true
    pkill -f "run_api.py" >/dev/null 2>&1 || true
    pkill -f "uvicorn api.main:app" >/dev/null 2>&1 || true
    
    # 停止 Docker 容器
    docker compose down >/dev/null 2>&1 || true
    
    print_success "現有服務已停止"
}

# 啟動資料庫
start_database() {
    print_status "啟動 SurrealDB 資料庫..."
    
    # 確保 docker.env 檔案存在（Docker Compose 需要）
    if [[ ! -f "docker.env" ]]; then
        cp .env docker.env
        print_status "已創建 docker.env 檔案"
    fi
    
    docker compose up -d surrealdb
    
    # 等待資料庫啟動
    sleep 5
    
    # 檢查資料庫是否啟動成功
    if docker compose ps surrealdb 2>/dev/null | grep -q "Up"; then
        print_success "SurrealDB 資料庫已啟動"
    else
        print_error "SurrealDB 啟動失敗"
        print_error "請檢查 Docker 日誌: docker compose logs surrealdb"
        exit 1
    fi
}

# 啟動 API 服務
start_api() {
    print_status "啟動 API 後端服務..."
    
    # 在背景啟動 API
    nohup python run_api.py > api.log 2>&1 &
    API_PID=$!
    
    # 等待 API 啟動
    sleep 3
    
    # 檢查 API 是否啟動
    if kill -0 $API_PID 2>/dev/null; then
        print_success "API 後端已啟動 (PID: $API_PID)"
        echo $API_PID > api.pid
    else
        print_error "API 啟動失敗"
        exit 1
    fi
}

# 啟動背景工作程序
start_worker() {
    print_status "啟動背景工作程序..."
    
    # 在背景啟動 worker
    nohup python -m surreal_commands.worker --import-modules commands > worker.log 2>&1 &
    WORKER_PID=$!
    
    # 等待 worker 啟動
    sleep 2
    
    # 檢查 worker 是否啟動
    if kill -0 $WORKER_PID 2>/dev/null; then
        print_success "背景工作程序已啟動 (PID: $WORKER_PID)"
        echo $WORKER_PID > worker.pid
    else
        print_warning "背景工作程序啟動失敗，但這不會影響基本功能"
    fi
}

# 啟動 Streamlit UI
start_ui() {
    print_status "啟動 Streamlit Web UI..."
    print_success "所有服務已啟動！"
    echo
    print_header
    echo -e "${CYAN}🌐 Web UI: ${NC}http://localhost:8502"
    echo -e "${CYAN}🔗 API: ${NC}http://localhost:5055"
    echo -e "${CYAN}📚 API 文檔: ${NC}http://localhost:5055/docs"
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${YELLOW}按 Ctrl+C 停止所有服務${NC}"
    echo
    
    # 啟動 Streamlit（前景運行）
    streamlit run app_home.py --server.port 8502
}

# 清理函數（當腳本被中斷時調用）
cleanup() {
    echo
    print_status "正在停止所有服務..."
    
    # 停止 Streamlit
    pkill -f "streamlit run app_home.py" >/dev/null 2>&1 || true
    
    # 停止 API
    if [[ -f "api.pid" ]]; then
        kill $(cat api.pid) >/dev/null 2>&1 || true
        rm -f api.pid
    fi
    
    # 停止 Worker
    if [[ -f "worker.pid" ]]; then
        kill $(cat worker.pid) >/dev/null 2>&1 || true
        rm -f worker.pid
    fi
    
    # 停止 Docker 容器
    docker compose down >/dev/null 2>&1 || true
    
    print_success "所有服務已停止"
    exit 0
}

# 設置中斷處理
trap cleanup SIGINT SIGTERM

# 主要執行流程
main() {
    print_header
    
    check_directory
    check_docker
    setup_environment
    check_env_file
    stop_existing_services
    start_database
    start_api
    start_worker
    start_ui
}

# 執行主函數
main "$@"
