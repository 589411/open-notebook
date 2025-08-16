#!/bin/bash

# Open Notebook 服務停止腳本

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}🛑 Open Notebook 服務停止${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_header

print_status "停止 Streamlit UI..."
pkill -f "streamlit run app_home.py" >/dev/null 2>&1 || true

print_status "停止背景工作程序..."
pkill -f "surreal-commands-worker" >/dev/null 2>&1 || true

print_status "停止 API 服務..."
pkill -f "run_api.py" >/dev/null 2>&1 || true
pkill -f "uvicorn api.main:app" >/dev/null 2>&1 || true

print_status "停止資料庫..."
docker compose down >/dev/null 2>&1 || true

# 清理 PID 檔案
rm -f api.pid worker.pid >/dev/null 2>&1 || true

print_success "所有 Open Notebook 服務已停止"
