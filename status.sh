#!/bin/bash

# Open Notebook 服務狀態檢查腳本

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}📊 Open Notebook 服務狀態${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

check_service() {
    local service_name="$1"
    local process_pattern="$2"
    local url="$3"
    
    if pgrep -f "$process_pattern" >/dev/null 2>&1; then
        echo -e "${service_name}: ${GREEN}✅ 運行中${NC}"
        if [[ -n "$url" ]]; then
            echo -e "  ${CYAN}🔗 $url${NC}"
        fi
        return 0
    else
        echo -e "${service_name}: ${RED}❌ 未運行${NC}"
        return 1
    fi
}

check_docker_service() {
    local service_name="$1"
    local container_name="$2"
    
    if docker compose ps "$container_name" 2>/dev/null | grep -q "Up"; then
        echo -e "${service_name}: ${GREEN}✅ 運行中${NC}"
        return 0
    else
        echo -e "${service_name}: ${RED}❌ 未運行${NC}"
        return 1
    fi
}

print_header

echo "🔍 檢查服務狀態..."
echo

# 檢查資料庫
check_docker_service "📊 SurrealDB 資料庫" "surrealdb"

# 檢查 API
check_service "🔧 API 後端" "run_api.py|uvicorn api.main:app" "http://localhost:5055"

# 檢查 Worker
check_service "⚙️  背景工作程序" "surreal-commands-worker"

# 檢查 UI
check_service "🌐 Streamlit UI" "streamlit run app_home.py" "http://localhost:8502"

echo
echo -e "${BLUE}💡 提示：${NC}"
echo -e "  • 啟動所有服務: ${CYAN}./start.sh${NC}"
echo -e "  • 停止所有服務: ${CYAN}./stop.sh${NC}"
echo -e "  • 檢查狀態: ${CYAN}./status.sh${NC}"
