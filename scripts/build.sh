#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="${1:-$PWD/dist}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
app_dir="$output_dir/轻唱.app"
swift build -c release --product QingChang
binary="$(swift build -c release --show-bin-path)/QingChang"
staging="$(mktemp -d "$output_dir/.qingchang.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/轻唱.app"
mkdir -p "$bundle/Contents/MacOS"
install -m 755 "$binary" "$bundle/Contents/MacOS/QingChang"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QingChang</string>
<key>CFBundleIdentifier</key><string>cn.qingchang.karaoke.preview</string>
<key>CFBundleName</key><string>轻唱</string>
<key>CFBundleDisplayName</key><string>轻唱</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.6.0</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>轻唱使用麦克风显示音高、计算评分，并在你开启耳机监听后播放人声。声音仅在这台 Mac 上处理。</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier cn.qingchang.karaoke.preview "$bundle"
codesign --verify --deep --strict "$bundle"
if [ -e "$app_dir" ]; then mv "$app_dir" "$staging/previous.app"; fi
mv "$bundle" "$app_dir"
printf '%s\n' "$app_dir"
