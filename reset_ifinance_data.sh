#!/usr/bin/env bash
# reset_ifinance_data.sh
# 清除 iFinance 模拟器中的所有账号和账单数据
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# 查找当前运行的 simulator 设备
DEVICE_ID=$(xcrun simctl list devices available | grep -E "iPhone|iPad" | grep -E "Booted|Running" | head -1 | sed 's/.*(\([^)]*\)).*/\1/' | awk '{print $1}')

if [[ -z "$DEVICE_ID" ]]; then
    echo "❌ 未找到正在运行的模拟器。请先启动 iPhone 模拟器，然后重试。"
    exit 1
fi

echo "📱 目标模拟器: $DEVICE_ID"

# 找到 App 的数据目录
APP_CONTAINER=$(xcrun simctl get_app_container "$DEVICE_ID" "com.liube.iFinance" data)

if [[ -z "$APP_CONTAINER" ]] || [[ ! -d "$APP_CONTAINER" ]]; then
    echo "❌ 找不到 App 容器。可能未安装或 App 名不同。"
    echo "   请检查 bundle identifier 是否为 com.liube.iFinance"
    exit 1
fi

SQLITE_PATH="$APP_CONTAINER/Library/Application Support/iFinance.sqlite"

if [[ ! -f "$SQLITE_PATH" ]]; then
    echo "⚠️  未找到 sqlite 文件: $SQLITE_PATH"
    echo "   可能是首次运行。跳过删除。"
else
    echo "🗑️  删除 Core Data 文件..."
    rm -f "$SQLITE_PATH" "${SQLITE_PATH}-shm" "${SQLITE_PATH}-wal"
    echo "✅ 已删除 $SQLITE_PATH"
fi

# 清除 UserDefaults
echo "🧹 清除 UserDefaults..."
defaults delete com.liube.iFinance "AuthLastLoginIdentifier" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthIsLoggedIn" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthLastActiveAt" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthUserIdentifier" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthEmail" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthPhone" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthPasswordHash" 2>/dev/null || true
defaults delete com.liube.iFinance "AuthPasswordSalt" 2>/dev/null || true
defaults delete com.liube.iFinance "UserProfileNickname" 2>/dev/null || true
echo "✅ UserDefaults 已清除"

# 停止 App（如果正在运行）
echo "⏹️  停止 App..."
xcrun simctl terminate "$DEVICE_ID" "com.liube.iFinance" 2>/dev/null || true

echo ""
echo "🎉 所有账号数据已清除！现在可以重新打开 App 注册新账号。"
