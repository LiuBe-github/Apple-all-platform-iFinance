#!/usr/bin/env bash
# 真机快速部署：构建 → 安装 → 启动，并把每个阶段的耗时打出来。
#
# 与「Xcode 里点 Run」的区别：
#   - 通过 devicectl 直接安装/启动，跳过 Xcode 的 Watch App 部署（配对手表时通常最慢的一步）
#   - 不附加调试器（不需要断点时更快；需要断点请回 Xcode 运行）
#   - 复用 Xcode 的 DerivedData，保持增量构建命中
#
# 用法：
#   scripts/run-on-device.sh                        # 默认 scheme iFinance，自动挑一台已连接真机
#   scripts/run-on-device.sh -s iFinanceSwiftData   # 指定 scheme
#   scripts/run-on-device.sh -d 00008140-XXXXXXXX   # 指定设备 UDID（xcrun devicectl list devices 可查看）
#   scripts/run-on-device.sh --console              # 启动后附着控制台输出
#   scripts/run-on-device.sh --no-build             # 跳过构建，直接安装已有产物

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="iFinance"
DEVICE=""
CONSOLE=0
DO_BUILD=1

usage() { sed -n '2,20p' "$0"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--scheme) SCHEME="${2:?缺少 scheme 名称}"; shift 2 ;;
    -d|--device) DEVICE="${2:?缺少设备 UDID}"; shift 2 ;;
    --console) CONSOLE=1; shift ;;
    --no-build) DO_BUILD=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1"; usage; exit 1 ;;
  esac
done

# 自动挑选一台「已连接且可用」的真机（排除模拟器与未解锁/未连接设备）
pick_device() {
  xcrun devicectl list devices 2>/dev/null \
    | grep -i 'physical' \
    | grep -viE 'unavailable|disconnected' \
    | grep -oE '([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})' \
    | head -1
}

if [[ -z "$DEVICE" ]]; then
  DEVICE="$(pick_device || true)"
fi
if [[ -z "$DEVICE" ]]; then
  echo "❌ 未找到可用的真机：请解锁 iPhone、确认已信任此电脑后重试"
  echo "   也可用 -d <UDID> 指定设备（xcrun devicectl list devices 查看）"
  exit 1
fi

DEST="platform=iOS,id=$DEVICE"
echo "📱 目标设备：$DEVICE"

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "▶︎ 构建 $SCHEME（增量）…"
  t0=$(date +%s)
  xcodebuild build -project iFinance.xcodeproj -scheme "$SCHEME" -destination "$DEST" -quiet
  echo "   ✔ 构建耗时 $(( $(date +%s) - t0 ))s"
fi

SETTINGS="$(xcodebuild -project iFinance.xcodeproj -scheme "$SCHEME" -destination "$DEST" -showBuildSettings 2>/dev/null)"
APP_PATH="$(printf '%s\n' "$SETTINGS" | awk -v target="$SCHEME" '
  /^Build settings for action build and target/ { inTarget = ($0 ~ ("target \"" target "\"")) }
  inTarget && / TARGET_BUILD_DIR = / { dir = $2 }
  inTarget && / WRAPPER_NAME = / { wrapper = $2 }
  END { print dir "/" wrapper }
')"
BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | awk -v target="$SCHEME" '
  /^Build settings for action build and target/ { inTarget = ($0 ~ ("target \"" target "\"")) }
  inTarget && / PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }
')"

if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 未找到构建产物：$APP_PATH（可先去掉 --no-build 重新构建）"
  exit 1
fi
echo "📦 产物：$APP_PATH"
echo "🔖 Bundle ID：$BUNDLE_ID"

echo "▶︎ 安装到设备（不部署 Watch App）…"
t1=$(date +%s)
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"
echo "   ✔ 安装耗时 $(( $(date +%s) - t1 ))s"

echo "▶︎ 启动…"
t2=$(date +%s)
if [[ "$CONSOLE" -eq 1 ]]; then
  xcrun devicectl device process launch --device "$DEVICE" --console --terminate-existing "$BUNDLE_ID"
else
  xcrun devicectl device process launch --device "$DEVICE" --terminate-existing "$BUNDLE_ID"
fi
echo "   ✔ 启动耗时 $(( $(date +%s) - t2 ))s"
echo "✅ 完成（未附加调试器、未重新部署 Watch App）"
