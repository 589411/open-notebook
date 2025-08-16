# 🚀 Open Notebook 一鍵啟動指南

本目錄包含三個便捷的 shell 腳本，讓你能輕鬆管理 Open Notebook 服務。

## 📋 腳本說明

### 🟢 `start.sh` - 一鍵啟動所有服務
```bash
./start.sh
```

**功能：**
- ✅ 自動檢查並啟動 Docker Desktop
- ✅ 設置 Python 虛擬環境
- ✅ 檢查環境變數檔案（.env）
- ✅ 停止現有服務（避免端口衝突）
- ✅ 依序啟動：SurrealDB → API → Worker → Streamlit UI
- ✅ 提供彩色狀態顯示和錯誤處理
- ✅ 按 Ctrl+C 自動清理所有服務

### 🔴 `stop.sh` - 停止所有服務
```bash
./stop.sh
```

**功能：**
- 🛑 停止 Streamlit UI
- 🛑 停止背景工作程序
- 🛑 停止 API 服務
- 🛑 停止 SurrealDB 資料庫
- 🛑 清理暫存檔案

### 📊 `status.sh` - 檢查服務狀態
```bash
./status.sh
```

**功能：**
- 📊 顯示所有服務的運行狀態
- 🔗 顯示服務的訪問 URL
- 💡 提供使用提示

## 🌐 服務端點

啟動後可以訪問：
- **🖥️ 主界面**: http://localhost:8502
- **🔧 API**: http://localhost:5055
- **📚 API 文檔**: http://localhost:5055/docs

## ⚙️ 首次使用

1. **設置 API 金鑰**（必須）：
   ```bash
   # 編輯 .env 檔案，添加至少一個 AI 服務的 API 金鑰
   nano .env
   
   # 例如：
   OPENAI_API_KEY=sk-your-openai-key-here
   # 或
   ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here
   ```

2. **啟動服務**：
   ```bash
   ./start.sh
   ```

3. **瀏覽器訪問**: http://localhost:8502

## 🔧 故障排除

### 問題：Docker 啟動失敗
**解決方案：**
```bash
# 手動啟動 Docker Desktop
open /Applications/Docker.app
# 等待 Docker 完全啟動後重新執行
./start.sh
```

### 問題：端口被占用
**解決方案：**
```bash
# 停止所有服務
./stop.sh
# 檢查狀態
./status.sh
# 重新啟動
./start.sh
```

### 問題：虛擬環境錯誤
**解決方案：**
```bash
# 刪除現有虛擬環境並重新創建
rm -rf .venv
# 重新執行啟動腳本
./start.sh
```

## 📝 日誌檔案

腳本會生成以下日誌檔案：
- `api.log` - API 服務日誌
- `worker.log` - 背景工作程序日誌

可以使用以下命令查看：
```bash
# 查看 API 日誌
tail -f api.log

# 查看 Worker 日誌
tail -f worker.log
```

## 🎯 快速指令參考

```bash
# 啟動所有服務
./start.sh

# 檢查狀態
./status.sh

# 停止所有服務
./stop.sh

# 查看 API 日誌
tail -f api.log

# 查看 Worker 日誌
tail -f worker.log
```

---

🎉 **享受使用 Open Notebook！** 如有問題，請檢查日誌檔案或訪問項目的 GitHub 頁面獲取更多幫助。
