#!/bin/bash

# === 配置区域 ===
TARGET_VERSION="1.116.0"
# ===============

echo "🚀 开始降级 VSCode 到版本 $TARGET_VERSION..."

# 1. 智能检测芯片架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    ARCH_LABEL="Apple Silicon"
    DOWNLOAD_URL="https://update.code.visualstudio.com/${TARGET_VERSION}/darwin-arm64/stable"
else
    ARCH_LABEL="Intel"
    DOWNLOAD_URL="https://update.code.visualstudio.com/${TARGET_VERSION}/darwin/stable"
fi

echo "🖥️  检测到芯片架构: $ARCH_LABEL"
echo "🔗  下载链接: $DOWNLOAD_URL"

# 2. 彻底清理当前版本 (解决降级后崩溃或配置冲突的关键)
echo "🧹 正在清理现有版本及缓存..."
killall "Visual Studio Code" 2>/dev/null
rm -rf /Applications/Visual\ Studio\ Code.app
rm -rf ~/Library/Application\ Support/Code
rm -rf ~/Library/Caches/com.microsoft.VSCode
rm -rf ~/Library/Preferences/com.microsoft.VSCode.helper.plist
rm -rf ~/Library/Preferences/com.microsoft.VSCode.plist
rm -rf ~/Library/Saved\ Application\ State/com.microsoft.VSCode.savedState
rm -rf ~/.vscode
echo "✅ 清理完成。"

# 3. 下载指定版本
ZIP_FILE="/tmp/vscode-${TARGET_VERSION}.zip"
echo "⬇️  正在下载 VSCode $TARGET_VERSION..."
curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"

# 检查下载是否成功
if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ 下载失败，请检查版本号是否正确或网络是否通畅。"
    exit 1
fi

# 4. 解压并安装
echo "📦 正在解压并安装..."
unzip -q -o "$ZIP_FILE" -d /tmp/
mv /tmp/Visual\ Studio\ Code.app /Applications/

# 5. 移除安全隔离属性 (避免 macOS 拦截)
xattr -dr com.apple.quarantine /Applications/Visual\ Studio\ Code.app

# 6. 清理临时文件
rm "$ZIP_FILE"

echo "🎉 降级完成！当前版本信息："
code --version