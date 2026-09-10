#!/bin/bash
# GLM Usage HUD：release 构建 → 组装 .app（Info.plist 键集校验）→ ad-hoc 签名 → 幂等安装到 ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GLM Usage HUD"
APP_DIR="$HOME/Applications/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

swift build -c release

NEW_HASH="$(shasum .build/release/glm-usage-hud | cut -d' ' -f1)"
OLD_HASH=""
if [ -f "$MACOS_DIR/glm-usage-hud" ]; then
  OLD_HASH="$(shasum "$MACOS_DIR/glm-usage-hud" | cut -d' ' -f1)"
fi
if [ "$NEW_HASH" = "$OLD_HASH" ] && [ -f "$CONTENTS_DIR/Info.plist" ]; then
  echo "产物未变化，跳过重装：$APP_DIR"
  exit 0
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp .build/release/glm-usage-hud "$MACOS_DIR/glm-usage-hud"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>glm-usage-hud</string>
	<key>CFBundleIdentifier</key>
	<string>com.sanren.glm-usage-hud</string>
	<key>CFBundleName</key>
	<string>GLM Usage HUD</string>
	<key>CFBundleDisplayName</key>
	<string>GLM Usage HUD</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.2.0</string>
	<key>CFBundleVersion</key>
	<string>3</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

# 最小键集逐项校验（缺失任一则失败）
for KEY in CFBundleExecutable CFBundleIdentifier CFBundlePackageType LSMinimumSystemVersion LSUIElement NSHighResolutionCapable; do
  /usr/libexec/PlistBuddy -c "Print :$KEY" "$CONTENTS_DIR/Info.plist" > /dev/null
done
EXEC_VALUE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$CONTENTS_DIR/Info.plist" | tr -d '[:space:]')"
if [ "$EXEC_VALUE" != "glm-usage-hud" ]; then
  echo "错误：CFBundleExecutable 必须精确等于 glm-usage-hud（当前：$EXEC_VALUE）" >&2
  exit 1
fi

codesign --force --sign - "$APP_DIR" > /dev/null 2>&1
codesign --verify --verbose "$APP_DIR" 2>&1 | sed 's/^/  /'

echo "已安装：$APP_DIR"
echo "启动：open \"$APP_DIR\""
